defmodule PolyglotWatcherV2.FileSystemWatchers.Inotifywait do
  @behaviour PolyglotWatcherV2.FileSystemWatchers.Behaviour
  alias PolyglotWatcherV2.FilePath

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_command, do: ["inotifywait", ".", "-rmqe", "close_write"]

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_message, do: "Starting inotifywait..."

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def parse_std_out(std_out, _working_dir) do
    std_out
    |> String.split("\n")
    |> find_file_path()
  end

  defp find_file_path([]) do
    :ignore
  end

  defp find_file_path([line | lines]) do
    case attempt_to_build_file_path(line) do
      {:ok, file_path} -> {:ok, file_path}
      :ignore -> find_file_path(lines)
    end
  end

  defp attempt_to_build_file_path(line) do
    case String.split(line, " ") do
      [path, _file_operations, name] ->
        relative_path = String.trim(path, "./") <> String.trim(name)
        FilePath.build(relative_path)

      _ ->
        :ignore
    end
  end
end
