defmodule PolyglotWatcherV2.MCP.Tools.RunTestsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.Tools.RunTests
  alias PolyglotWatcherV2.Elixir.{Cache, MixTestArgs}
  alias PolyglotWatcherV2.ShellCommandRunner

  describe "call/1" do
    test "runs test for given test_path" do
      args = %MixTestArgs{path: "test/cool_test.exs", max_failures: 3}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs --max-failures 3 --color" ->
        {"1 test, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "1 test, 0 failures", 0 -> :ok end)

      result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
      decoded = Jason.decode!(result)

      assert decoded["exit_code"] == 0
      assert decoded["output"] == "1 test, 0 failures"
      assert decoded["test_path"] == "test/cool_test.exs"
      assert decoded["command"] == "mix test test/cool_test.exs --max-failures 3 --color"
    end

    test "runs test with line_number" do
      args = %MixTestArgs{path: {"test/cool_test.exs", 42}, max_failures: 3}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs:42 --max-failures 3 --color" ->
        {"1 test, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "1 test, 0 failures", 0 -> :ok end)

      result = RunTests.call(%{"test_path" => "test/cool_test.exs", "line_number" => 42})
      decoded = Jason.decode!(result)

      assert decoded["test_path"] == "test/cool_test.exs:42"
    end

    test "runs all tests when no test_path given" do
      args = %MixTestArgs{path: :all, max_failures: 3}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test --max-failures 3 --color" ->
        {"10 tests, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "10 tests, 0 failures", 0 -> :ok end)

      result = RunTests.call(%{})
      decoded = Jason.decode!(result)

      assert decoded["exit_code"] == 0
      assert decoded["test_path"] == "all"
    end

    test "returns cached result when cache hit" do
      args = %MixTestArgs{path: "test/cool_test.exs", max_failures: 3}

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

  describe "definition/0" do
    test "returns valid tool definition" do
      defn = RunTests.definition()

      assert defn["name"] == "mix_test"
      assert is_binary(defn["description"])
      assert defn["inputSchema"]["type"] == "object"
      assert Map.has_key?(defn["inputSchema"]["properties"], "test_path")
      assert Map.has_key?(defn["inputSchema"]["properties"], "line_number")
    end
  end
end
