defmodule PolyglotWatcherV2.FileSystemWatchers.FSWatch do
  @behaviour PolyglotWatcherV2.FileSystemWatchers.Behaviour
  alias PolyglotWatcherV2.{FileExtensions, FilePath}

  @source_extensions FileExtensions.all()

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_command, do: ["fswatch", "."]

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def startup_message, do: "Starting fswatch..."

  @impl PolyglotWatcherV2.FileSystemWatchers.Behaviour
  def parse_std_out(std_out, working_dir) do
    std_out
    |> String.split("\n", trim: true)
    |> Enum.reduce({:ignore, :ignore}, fn file_path, {source_file, fallback_file} ->
      relative_path = Path.relative_to(file_path, working_dir)

      case FilePath.build(relative_path) do
        {:ok, parsed} when parsed.extension in @source_extensions ->
          {source_file_or(source_file, parsed), fallback_file}

        {:ok, parsed} ->
          {source_file, fallback_file_or(fallback_file, parsed)}

        _ ->
          {source_file, fallback_file}
      end
    end)
    |> pick_best_file()
  end

  defp source_file_or(:ignore, parsed), do: {:ok, parsed}
  defp source_file_or(existing, _parsed), do: existing

  defp fallback_file_or(:ignore, parsed), do: {:ok, parsed}
  defp fallback_file_or(existing, _parsed), do: existing

  defp pick_best_file({{:ok, _} = source, _fallback}), do: source
  defp pick_best_file({:ignore, fallback}), do: fallback
end
