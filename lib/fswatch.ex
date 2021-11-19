defmodule PolyglotWatcherV2.FSWatch do
  alias PolyglotWatcherV2.FilePath

  def parse_std_out(std_out, working_dir) do
    std_out
    |> String.split("\n", trim: true)
    |> Enum.reduce_while(:ignore, fn file_path, _acc ->
      case FilePath.build(file_path, working_dir) do
        {:ok, parsed_file_path} -> {:halt, {:ok, parsed_file_path}}
        _ -> {:cont, :ignore}
      end
    end)
  end
end
