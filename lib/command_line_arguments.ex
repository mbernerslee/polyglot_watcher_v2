defmodule PolyglotWatcherV2.CommandLineArguments do
  alias PolyglotWatcherV2.EnvironmentVariables.Constants
  # see rel/overlays/bin/polyglot_watcher_v2_wrapper

  @start "start"
  @separator "polyglot_watcher_v2_seperator_arg"
  @env_var Constants.cli_args()

  # TODO add tests
  def parse(raw_cli_args) do
    raw_cli_args
    |> String.split()
    |> case do
      [@start, @separator | rest] ->
        {:ok, Enum.join(rest, " ")}

      _ ->
        {:error,
         "#{@env_var} environment variable not set properly. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."}
    end
  end
end
