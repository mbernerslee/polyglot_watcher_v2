defmodule PolyglotWatcherV2.FSWatch do
  alias PolyglotWatcherV2.FilePath

  def startup_command, do: "fswatch ."
  def startup_message, do: "Starting fswatch..."

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
