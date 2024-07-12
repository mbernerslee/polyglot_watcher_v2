defmodule PolyglotWatcherV2.EnvironmentVariablesTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.EnvironmentVariables
  alias PolyglotWatcherV2.EnvironmentVariables.{Stub, Constants}

  @cli_args Constants.cli_args()
  @path Constants.path()

  describe "read/0" do
    test "returns the environment variables if they exist" do
      cli_args = "start ex d"
      path = "/some/path"

      env_vars = Stub.read()

      Mimic.expect(Stub, :read, fn -> %{env_vars | cli_args: cli_args, path: path} end)

      assert {:ok, %{cli_args: cli_args, path: path}} == EnvironmentVariables.read()
    end

    test "raises if POLYGLOT_WATCHER_V2_PATH is not set" do
      env_vars = Stub.read()

      Mimic.expect(Stub, :read, fn -> %{env_vars | path: nil} end)

      expected_error =
        "POLYGLOT_WATCHER_V2_PATH environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

      assert {:error, expected_error} == EnvironmentVariables.read()
    end

    test "returns an error if POLYGLOT_WATCHER_V2_CLI_ARGS is not set" do
      env_vars = Stub.read()

      Mimic.expect(Stub, :read, fn -> %{env_vars | cli_args: nil} end)

      expected_error =
        "POLYGLOT_WATCHER_V2_CLI_ARGS environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

      assert {:error, expected_error} == EnvironmentVariables.read()
    end

    test "raises if both POLYGLOT_WATCHER_V2_PATH and POLYGLOT_WATCHER_V2_CLI_ARGS are not set" do
      env_vars = Stub.read()

      Mimic.expect(Stub, :read, fn -> %{env_vars | cli_args: nil, path: nil} end)

      expected_error =
        "both POLYGLOT_WATCHER_V2_CLI_ARGS and POLYGLOT_WATCHER_V2_PATH environment variables are not set. They should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

      assert {:error, expected_error} == EnvironmentVariables.read()
    end
  end

  describe "put/2" do
    test "given a key and value, sets an environment variable" do
      path = "/some/path"
      cli_args = "start polyglot_watcher_v2_seperator_arg ex d"

      Mimic.expect(Stub, :put, fn @path, this_path ->
        assert this_path == path
        :ok
      end)

      Mimic.expect(Stub, :put, fn @cli_args, these_cli_args ->
        assert these_cli_args == cli_args
        :ok
      end)

      assert :ok == EnvironmentVariables.put(@path, path)
      assert :ok == EnvironmentVariables.put(@cli_args, cli_args)
    end
  end
end
