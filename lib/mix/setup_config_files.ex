defmodule Mix.Tasks.PolyglotWatcherV2.SetupConfigFiles do
  @moduledoc "Sets up PolyglotWatcherV2 config files"
  @shortdoc "Sets up PolyglotWatcherV2 config files"

  use Mix.Task

  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.FileSystem

  @impl Mix.Task
  def run(_args \\ []) do
    with :ok <- create_config_dir(),
         :ok <-
           write_file(
             Const.config_file_path(),
             Const.default_config_contents(),
             "config",
             false
           ),
         :ok <-
           write_file(
             Const.config_backup_file_path(),
             Const.default_config_contents(),
             "backup config",
             true
           ),
         :ok <-
           write_file(
             Const.prompt_file_path(),
             Const.default_prompt(),
             "prompt",
             false
           ),
         :ok <-
           write_file(
             Const.prompt_backup_file_path(),
             Const.default_prompt(),
             "backup prompt",
             true
           ) do
      :ok
      exit(:normal)
    else
      {:error, error} ->
        Puts.on_new_line(error, :red)
        exit(1)
    end
  end

  defp write_file(path, contents, description, _overwrite = false) do
    if FileSystem.exists?(path) do
      Puts.on_new_line("Already exists #{path} OK", :green)
      :ok
    else
      write_file(path, contents, description, _overwrite = true)
    end
  end

  defp write_file(path, contents, description, _overwrite = true) do
    case FileSystem.write(path, contents) do
      :ok ->
        Puts.on_new_line("Written #{path} OK", :green)
        :ok

      {:error, error} ->
        {:error,
         "Failed to write PolyglotWatcherV2 #{description} file to #{path}. The error was #{inspect(error)}"}
    end
  end

  defp create_config_dir do
    dir = Const.config_dir_path()

    case FileSystem.mkdir_p(dir) do
      :ok ->
        :ok

      {:error, error} ->
        {:error,
         "Failed to create PolyglotWatcherV2 config directory #{dir}. The error was #{inspect(error)}"}
    end
  end
end
