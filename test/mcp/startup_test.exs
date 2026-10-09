defmodule PolyglotWatcherV2.MCP.StartupTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.Startup
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.Puts

  describe "init/1" do
    test "starts Bandit on port 0, writes config file" do
      fake_bandit_pid = spawn(fn -> Process.sleep(:infinity) end)

      Mimic.expect(FileWrapper, :read, fn _ -> {:error, :enoent} end)
      Mimic.expect(Bandit, :start_link, fn opts ->
        assert opts[:port] == 0
        {:ok, fake_bandit_pid}
      end)
      Mimic.expect(ThousandIsland, :listener_info, fn ^fake_bandit_pid ->
        {:ok, {{127, 0, 0, 1}, 9876}}
      end)
      Mimic.expect(FileWrapper, :mkdir_p, fn _ -> :ok end)
      Mimic.expect(FileWrapper, :write, fn _, content ->
        decoded = Jason.decode!(content)
        assert decoded["mcp_tcp_port"] == 9876
        assert is_integer(decoded["pid"])
        :ok
      end)
      Mimic.expect(FileWrapper, :rename, fn _, _ -> :ok end)
      Mimic.reject(Puts, :on_new_line, 2)

      {:ok, state} = Startup.init([])

      assert state.port == 9876
      assert state.bandit_pid == fake_bandit_pid

      Process.exit(fake_bandit_pid, :kill)
    end

    test "returns :ignore when another instance is alive" do
      Mimic.expect(FileWrapper, :read, fn _ ->
        {:ok, ~s({"mcp_tcp_port": 5555, "pid": 12345})}
      end)
      Mimic.expect(PolyglotWatcherV2.ShellCommandRunner, :run, fn "kill -0 12345 2>/dev/null" -> {"", 0} end)
      Mimic.expect(Req, :post, fn _, _ ->
        {:ok, %{status: 200, body: %{"jsonrpc" => "2.0", "result" => %{}}}}
      end)
      Mimic.expect(Puts, :on_new_line, fn msg, :yellow ->
        assert msg =~ "another instance already active"
        :ok
      end)

      assert :ignore = Startup.init([])
    end

    test "starts fresh when config exists but instance is dead" do
      fake_bandit_pid = spawn(fn -> Process.sleep(:infinity) end)

      Mimic.expect(FileWrapper, :read, fn _ ->
        {:ok, ~s({"mcp_tcp_port": 5555, "pid": 99999})}
      end)
      Mimic.expect(PolyglotWatcherV2.ShellCommandRunner, :run, fn "kill -0 99999 2>/dev/null" ->
        {"No such process", 1}
      end)
      Mimic.expect(Bandit, :start_link, fn _ -> {:ok, fake_bandit_pid} end)
      Mimic.expect(ThousandIsland, :listener_info, fn ^fake_bandit_pid ->
        {:ok, {{127, 0, 0, 1}, 7777}}
      end)
      Mimic.expect(FileWrapper, :mkdir_p, fn _ -> :ok end)
      Mimic.expect(FileWrapper, :write, fn _, _ -> :ok end)
      Mimic.expect(FileWrapper, :rename, fn _, _ -> :ok end)
      Mimic.reject(Puts, :on_new_line, 2)

      {:ok, state} = Startup.init([])
      assert state.port == 7777

      Process.exit(fake_bandit_pid, :kill)
    end
  end

  describe "terminate/2" do
    test "deletes config file" do
      Mimic.expect(FileWrapper, :rm_rf, fn ".polyglot_watcher_v2/config.json.tmp" -> {:ok, []} end)
      Mimic.expect(FileWrapper, :rm_rf, fn ".polyglot_watcher_v2/config.json" -> {:ok, []} end)

      assert :ok = Startup.terminate(:shutdown, %{})
    end

    test "stops the HTTP listener so no new requests are accepted" do
      Mimic.stub(FileWrapper, :rm_rf, fn _ -> {:ok, []} end)
      {:ok, bandit_pid} = Agent.start(fn -> nil end)

      assert :ok = Startup.terminate(:normal, %{bandit_pid: bandit_pid, port: 1234})

      refute Process.alive?(bandit_pid)
    end
  end

  describe "handle_info/2 - EXIT" do
    test "stops when the HTTP listener exits" do
      bandit_pid = spawn(fn -> :ok end)
      state = %{bandit_pid: bandit_pid, port: 1234}

      assert {:stop, :boom, ^state} = Startup.handle_info({:EXIT, bandit_pid, :boom}, state)
    end

    test "ignores exits from anything else, e.g. the port InstanceChecker's `kill -0` ran in" do
      state = %{bandit_pid: spawn(fn -> :ok end), port: 1234}
      other_port = Port.open({:spawn, "true"}, [])

      assert {:noreply, ^state} = Startup.handle_info({:EXIT, other_port, :normal}, state)
    end
  end

  describe "child_spec/1" do
    test "is transient, so a deliberate stop (idle shutdown) isn't undone by a restart" do
      assert %{restart: :transient} = Startup.child_spec([])
    end
  end

  describe "stop/0" do
    test "is a no-op when the MCP server isn't running" do
      assert :ok = Startup.stop()
    end
  end
end
