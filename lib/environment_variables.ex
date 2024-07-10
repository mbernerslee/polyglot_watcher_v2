defmodule PolyglotWatcherV2.EnvironmentVariables.Constants do
  @cli_args "POLYGLOT_WATCHER_V2_CLI_ARGS"
  @path "POLYGLOT_WATCHER_V2_PATH"

  def cli_args, do: @cli_args
  def path, do: @path
end

defmodule PolyglotWatcherV2.EnvironmentVariables.Real do
  alias PolyglotWatcherV2.EnvironmentVariables.Constants

  @cli_args Constants.cli_args()
  @path Constants.path()

  def read do
    %{cli_args: System.get_env(@cli_args), path: System.get_env(@path)}
  end

  def put(key, value), do: System.put_env(key, value)
end

defmodule PolyglotWatcherV2.EnvironmentVariables.Mock do
  def read do
    %{cli_args: "start polyglot_watcher_v2_seperator_arg", path: "/usr/local/go/bin"}
  end

  def put(_key, _value), do: :ok
end

defmodule PolyglotWatcherV2.EnvironmentVariables do
  @no_path_error "POLYGLOT_WATCHER_V2_PATH environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

  @no_cli_args_error "POLYGLOT_WATCHER_V2_CLI_ARGS environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

  @both_missing_error "both POLYGLOT_WATCHER_V2_CLI_ARGS and POLYGLOT_WATCHER_V2_PATH environment variables are not set. They should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."

  def read do
    case module().read() do
      %{cli_args: nil, path: nil} -> raise @both_missing_error
      %{path: nil} -> raise @no_path_error
      %{cli_args: nil} -> raise @no_cli_args_error
      env_vars -> env_vars
    end
  end

  def put(key, value), do: module().put(key, value)

  defp module do
    Application.get_env(:polyglot_watcher_v2, :environment_variables_module)
  end
end
