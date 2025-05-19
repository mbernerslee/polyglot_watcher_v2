defmodule PolyglotWatcherV2.FileSystemWatchers.Behaviour do
  @callback startup_command() :: [String.t()]
  @callback startup_message() :: String.t()
  @callback parse_std_out(std_out :: String.t(), working_dir :: String.t()) ::
              {:ok, String.t()} | :ignore
end
