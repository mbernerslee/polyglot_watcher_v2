defmodule PolyglotWatcherV2.EnvironmentVariablesTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.EnvironmentVariables
  alias PolyglotWatcherV2.EnvironmentVariables.{Mock, Constants}

  @cli_args Constants.cli_args()
  @path Constants.path()

  describe "read/0" do
    test "returns the environment variables if they exist" do
      cli_args = "start ex d"
      path = "/some/path"

      env_vars = Mock.read()

      Mimic.expect(Mock, :read, fn -> %{env_vars | cli_args: cli_args, path: path} end)

      assert %{cli_args: cli_args, path: path} == EnvironmentVariables.read()
    end

    test "raises if POLYGLOT_WATCHER_V2_PATH is not set" do
      env_vars = Mock.read()

      Mimic.expect(Mock, :read, fn -> %{env_vars | path: nil} end)

      message =
        "POLYGLOT_WATCHER_V2_PATH environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

      assert_raise RuntimeError, message, fn -> EnvironmentVariables.read() end
    end

    test "raises if POLYGLOT_WATCHER_V2_CLI_ARGS is not set" do
      env_vars = Mock.read()

      Mimic.expect(Mock, :read, fn -> %{env_vars | cli_args: nil} end)

      message =
        "POLYGLOT_WATCHER_V2_CLI_ARGS environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

      assert_raise RuntimeError, message, fn -> EnvironmentVariables.read() end
    end

    test "raises if both POLYGLOT_WATCHER_V2_PATH and POLYGLOT_WATCHER_V2_CLI_ARGS are not set" do
      env_vars = Mock.read()

      Mimic.expect(Mock, :read, fn -> %{env_vars | cli_args: nil, path: nil} end)

      message =
        "both POLYGLOT_WATCHER_V2_CLI_ARGS and POLYGLOT_WATCHER_V2_PATH environment variables are not set. They should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

      assert_raise RuntimeError, message, fn -> EnvironmentVariables.read() end
    end
  end

  describe "put/2" do
    test "given a key and value, sets an environment variable" do
      # TODO continue here
      raise "TODO finish me"
      path = "/some/path"

      Mimic.expect(Mock, :put, fn @path, this_value ->
        assert this_key == @path
        assert this_value == path
        :ok
      end)

      assert :ok == EnvironmentVariables.put_path(@path, path)
    end
  end
end
