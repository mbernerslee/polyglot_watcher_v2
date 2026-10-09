defmodule PolyglotWatcherV2.IdleShutdownTest do
  use ExUnit.Case, async: false
  use Mimic

  alias PolyglotWatcherV2.{IdleShutdown, Puts, SystemWrapper}
  alias PolyglotWatcherV2.MCP.Handler
  alias PolyglotWatcherV2.Elixir.Cache

  setup :set_mimic_global

  @minute 60_000

  setup do
    {:ok, clock} = Agent.start_link(fn -> 0 end)
    Mimic.stub(Puts, :on_new_line, fn _, _ -> :ok end)
    %{clock: clock}
  end

  defp start_idle_shutdown(clock, opts \\ []) do
    opts =
      Keyword.merge(
        [
          name: IdleShutdown,
          timeout_ms: 30 * @minute,
          check_interval_ms: :manual,
          now: fn -> Agent.get(clock, & &1) end
        ],
        opts
      )

    start_supervised!({IdleShutdown, opts})
  end

  defp advance(clock, ms), do: Agent.update(clock, &(&1 + ms))

  defp check(pid) do
    send(pid, :check)
    :sys.get_state(pid)
    :ok
  end

  defp expect_shutdown do
    test_pid = self()
    Mimic.expect(SystemWrapper, :stop, fn 0 -> send(test_pid, :system_stopped) end)
  end

  describe "idle checks" do
    test "with no activity for the timeout, logs a clear message and stops the system", %{
      clock: clock
    } do
      test_pid = self()

      Mimic.stub(Puts, :on_new_line, fn msg, _style ->
        send(test_pid, {:puts, msg})
        :ok
      end)

      expect_shutdown()
      pid = start_idle_shutdown(clock)

      advance(clock, 30 * @minute)
      check(pid)

      assert_received :system_stopped
      assert_received {:puts, "[idle-shutdown] no MCP tool calls or file changes" <> _ = msg}
      assert msg =~ "30 min"
      assert msg =~ "shutting down"
    end

    test "does not shut down before the timeout", %{clock: clock} do
      Mimic.reject(SystemWrapper, :stop, 1)
      pid = start_idle_shutdown(clock)

      advance(clock, 30 * @minute - 1)
      check(pid)

      refute_received :system_stopped
    end

    test "touch resets the idle clock", %{clock: clock} do
      Mimic.reject(SystemWrapper, :stop, 1)
      pid = start_idle_shutdown(clock)

      advance(clock, 20 * @minute)
      IdleShutdown.touch()
      advance(clock, 20 * @minute)
      check(pid)
    end

    test "never shuts down while tracked work is in flight, then times out from when it finished",
         %{clock: clock} do
      expect_shutdown()
      pid = start_idle_shutdown(clock)
      test_pid = self()

      worker =
        spawn(fn ->
          IdleShutdown.track(fn ->
            send(test_pid, :working)

            receive do
              :finish -> :ok
            end
          end)

          send(test_pid, :worker_done)
        end)

      assert_receive :working
      :sys.get_state(pid)

      advance(clock, 120 * @minute)
      check(pid)
      refute_received :system_stopped

      send(worker, :finish)
      assert_receive :worker_done
      :sys.get_state(pid)

      advance(clock, 30 * @minute - 1)
      check(pid)
      refute_received :system_stopped

      advance(clock, 1)
      check(pid)
      assert_received :system_stopped
    end

    test "tracked work whose process dies no longer blocks shutdown", %{clock: clock} do
      pid = start_idle_shutdown(clock)
      test_pid = self()

      worker =
        spawn(fn ->
          IdleShutdown.track(fn ->
            send(test_pid, :working)
            Process.sleep(:infinity)
          end)
        end)

      assert_receive :working
      :sys.get_state(pid)

      worker_ref = Process.monitor(worker)
      Process.exit(worker, :kill)
      assert_receive {:DOWN, ^worker_ref, :process, _, :killed}
      :sys.get_state(pid)

      advance(clock, 30 * @minute)
      expect_shutdown()
      check(pid)

      assert_received :system_stopped
    end

    test "track returns the function's result" do
      assert :result == IdleShutdown.track(fn -> :result end)
    end

    test "touch and track are no-ops when idle shutdown isn't running" do
      assert :ok == IdleShutdown.touch()
      assert 1 == IdleShutdown.track(fn -> 1 end)
    end
  end

  describe "children/0" do
    test "is empty when the env var is unset" do
      Mimic.expect(SystemWrapper, :get_env, fn "POLYGLOT_WATCHER_IDLE_SHUTDOWN_MINUTES" -> nil end)
      assert [] == IdleShutdown.children()
    end

    test "builds a child with the timeout in ms, accepting whole or fractional minutes" do
      Mimic.expect(SystemWrapper, :get_env, fn "POLYGLOT_WATCHER_IDLE_SHUTDOWN_MINUTES" -> "30" end)
      assert [{IdleShutdown, [timeout_ms: 1_800_000]}] == IdleShutdown.children()

      Mimic.expect(SystemWrapper, :get_env, fn "POLYGLOT_WATCHER_IDLE_SHUTDOWN_MINUTES" -> "0.05" end)
      assert [{IdleShutdown, [timeout_ms: 3_000]}] == IdleShutdown.children()
    end

    test "warns and disables idle shutdown when the env var is invalid" do
      for bad <- ["abc", "0", "-5", ""] do
        Mimic.expect(SystemWrapper, :get_env, fn "POLYGLOT_WATCHER_IDLE_SHUTDOWN_MINUTES" -> bad end)
        Mimic.expect(Puts, :on_new_line, fn msg, :yellow -> assert msg =~ "ignoring" end)
        assert [] == IdleShutdown.children()
      end
    end
  end

  describe "init" do
    test "announces that idle shutdown is enabled", %{clock: clock} do
      test_pid = self()

      Mimic.stub(Puts, :on_new_line, fn msg, _style ->
        send(test_pid, {:puts, msg})
        :ok
      end)

      start_idle_shutdown(clock, timeout_ms: 3_000)

      assert_received {:puts, msg}
      assert msg =~ "[idle-shutdown] enabled"
      assert msg =~ "0.05 min"
    end
  end

  describe "activity sources" do
    test "an MCP tools/call counts as activity", %{clock: clock} do
      Mimic.reject(SystemWrapper, :stop, 1)
      Mimic.stub(PolyglotWatcherV2.ActionsExecutor, :execute, fn _ -> :ok end)

      Mimic.stub(Cache, :get_known_failures, fn ->
        %{failures: [], total_failing_test_files: 0, total_failing_lines: 0}
      end)

      pid = start_idle_shutdown(clock)
      advance(clock, 20 * @minute)

      Handler.handle_message(%{
        "method" => "tools/call",
        "id" => 1,
        "params" => %{"name" => "mix_test_known_failures", "arguments" => %{}}
      })

      advance(clock, 20 * @minute)
      check(pid)
    end

    test "an MCP ping does not count as activity", %{clock: clock} do
      pid = start_idle_shutdown(clock)
      advance(clock, 20 * @minute)

      Handler.handle_message(%{"method" => "ping", "id" => 1})

      advance(clock, 10 * @minute)
      expect_shutdown()
      check(pid)
      assert_received :system_stopped
    end
  end
end
