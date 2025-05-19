defmodule PolyglotWatcherV2.FileSystemWatchers.FSWatch do
  @behaviour PolyglotWatcherV2.FileSystemWatchers.Behaviour
  alias PolyglotWatcherV2.FilePath

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_command, do: ["fswatch", "."]

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_message, do: "Starting fswatch..."

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def parse_std_out(std_out, working_dir) do
    std_out
    |> String.split("\n", trim: true)
    |> Enum.reduce_while(:ignore, fn file_path, _acc ->
      relative_path = Path.relative_to(file_path, working_dir)

      case FilePath.build(relative_path) do
        {:ok, parsed_file_path} -> {:halt, {:ok, parsed_file_path}}
        _ -> {:cont, :ignore}
      end
    end)
  end
end
