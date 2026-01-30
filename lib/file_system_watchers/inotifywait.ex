defmodule PolyglotWatcherV2.FileSystemWatchers.Inotifywait do
  @behaviour PolyglotWatcherV2.FileSystemWatchers.Behaviour
  alias PolyglotWatcherV2.FilePath

  @source_extensions ["ex", "exs", "rs"]

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_command, do: ["inotifywait", ".", "-rmqe", "close_write"]

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_message, do: "Starting inotifywait..."

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def parse_std_out(std_out, _working_dir) do
    std_out
    |> String.split("\n")
    |> Enum.reduce({:ignore, :ignore}, fn line, {source_file, fallback_file} ->
      case attempt_to_build_file_path(line) do
        {:ok, parsed} when parsed.extension in @source_extensions ->
          {source_file_or(source_file, parsed), fallback_file}

        {:ok, parsed} ->
          {source_file, fallback_file_or(fallback_file, parsed)}

        :ignore ->
          {source_file, fallback_file}
      end
    end)
    |> pick_best_file()
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

  defp source_file_or(:ignore, parsed), do: {:ok, parsed}
  defp source_file_or(existing, _parsed), do: existing

  defp fallback_file_or(:ignore, parsed), do: {:ok, parsed}
  defp fallback_file_or(existing, _parsed), do: existing

  defp pick_best_file({{:ok, _} = source, _fallback}), do: source
  defp pick_best_file({:ignore, fallback}), do: fallback
end
