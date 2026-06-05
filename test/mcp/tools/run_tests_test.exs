defmodule PolyglotWatcherV2.MCP.Tools.RunTestsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.Tools.RunTests
  alias PolyglotWatcherV2.Elixir.{Cache, MixTestArgs}
  alias PolyglotWatcherV2.ShellCommandRunner

  describe "call/1" do
    test "runs test for given test_path" do
      args = %MixTestArgs{path: "test/cool_test.exs"}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs --color" ->
        {"1 test, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "1 test, 0 failures", 0 -> :ok end)

      result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
      decoded = Jason.decode!(result)

      assert decoded["exit_code"] == 0
      assert decoded["output"] == "1 test, 0 failures"
      assert decoded["test_path"] == "test/cool_test.exs"
      assert decoded["command"] == "mix test test/cool_test.exs --color"
    end

    test "runs test with line_number" do
      args = %MixTestArgs{path: {"test/cool_test.exs", 42}}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs:42 --color" ->
        {"1 test, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "1 test, 0 failures", 0 -> :ok end)

      result = RunTests.call(%{"test_path" => "test/cool_test.exs", "line_number" => 42})
      decoded = Jason.decode!(result)

      assert decoded["test_path"] == "test/cool_test.exs:42"
    end

    test "runs test when test_path includes embedded line number" do
      args = %MixTestArgs{path: {"test/cool_test.exs", 42}}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs:42 --color" ->
        {"1 test, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "1 test, 0 failures", 0 -> :ok end)

      result = RunTests.call(%{"test_path" => "test/cool_test.exs:42"})
      decoded = Jason.decode!(result)

      assert decoded["exit_code"] == 0
      assert decoded["test_path"] == "test/cool_test.exs:42"
      assert decoded["command"] == "mix test test/cool_test.exs:42 --color"
    end

    test "runs all tests when no test_path given" do
      args = %MixTestArgs{path: :all}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test --color" ->
        {"10 tests, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "10 tests, 0 failures", 0 -> :ok end)

      result = RunTests.call(%{})
      decoded = Jason.decode!(result)

      assert decoded["exit_code"] == 0
      assert decoded["test_path"] == "all"
    end

    test "returns cached result when cache hit" do
      args = %MixTestArgs{path: "test/cool_test.exs"}

      Mimic.expect(Cache, :get_cached_result, fn ^args ->
        {:hit, "1 test, 0 failures", 0}
      end)

      result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
      decoded = Jason.decode!(result)

      assert decoded["exit_code"] == 0
      assert decoded["output"] == "1 test, 0 failures"
      assert decoded["test_path"] == "test/cool_test.exs"
    end

    test "returns awaited result when test is already running" do
      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn %MixTestArgs{path: "test/cool_test.exs"} ->
        {:ok, {"1 test, 1 failure", 2}}
      end)

      result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
      decoded = Jason.decode!(result)

      assert decoded["exit_code"] == 2
      assert decoded["output"] == "1 test, 1 failure"
    end
  end

  describe "call/1 with extra_args" do
    test "appends extra_args to the shell command and passes them through to Cache.update" do
      args = %MixTestArgs{
        path: "test/cool_test.exs",
        extra_args: ["--slowest", "5"]
      }

      Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs --slowest 5 --color" ->
        {"1 test, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "1 test, 0 failures", 0 -> :ok end)

      result =
        RunTests.call(%{
          "test_path" => "test/cool_test.exs",
          "extra_args" => ["--slowest", "5"]
        })

      decoded = Jason.decode!(result)
      assert decoded["exit_code"] == 0
      assert decoded["command"] == "mix test test/cool_test.exs --slowest 5 --color"
    end

    test "bypasses cache read when extra_args is non-empty" do
      Mimic.reject(Cache, :get_cached_result, 1)

      Mimic.expect(ShellCommandRunner, :run, fn _ -> {"1 test, 0 failures", 0} end)
      Mimic.expect(Cache, :update, fn _, _, _ -> :ok end)

      result =
        RunTests.call(%{
          "test_path" => "test/cool_test.exs",
          "extra_args" => ["--trace"]
        })

      decoded = Jason.decode!(result)
      assert decoded["exit_code"] == 0
    end

    test "bypasses in-flight dedup (await_or_run) when extra_args is non-empty" do
      Mimic.reject(Cache, :await_or_run, 1)

      Mimic.expect(ShellCommandRunner, :run, fn _ -> {"1 test, 0 failures", 0} end)
      Mimic.expect(Cache, :update, fn _, _, _ -> :ok end)

      result =
        RunTests.call(%{
          "test_path" => "test/cool_test.exs",
          "extra_args" => ["--only", "integration"]
        })

      decoded = Jason.decode!(result)
      assert decoded["exit_code"] == 0
    end
  end

  describe "definition/0" do
    test "returns valid tool definition" do
      defn = RunTests.definition()

      assert defn["name"] == "mix_test"
      assert is_binary(defn["description"])
      assert defn["inputSchema"]["type"] == "object"
      assert Map.has_key?(defn["inputSchema"]["properties"], "test_path")
      assert Map.has_key?(defn["inputSchema"]["properties"], "line_number")
      assert Map.has_key?(defn["inputSchema"]["properties"], "extra_args")
    end
  end
end
