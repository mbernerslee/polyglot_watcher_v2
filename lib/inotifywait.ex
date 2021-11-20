defmodule PolyglotWatcherV2.Inotifywait do
  alias PolyglotWatcherV2.FilePath

  def startup_command, do: "inotifywait . -rmqe close_write"
  def startup_message, do: "Starting inotifywait..."

  def parse_std_out(std_out, _working_dir) do
    case String.split(std_out, " ") do
      [path, _file_operations, name] ->
        relative_path = String.trim(path, "./") <> String.trim(name)
        FilePath.build(relative_path)

      _ ->
        :ignore
    end
  end
end
