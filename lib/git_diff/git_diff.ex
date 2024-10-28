defmodule PolyglotWatcherV2.GitDiff do
  alias PolyglotWatcherV2.{FileSystem, Puts, SystemCall}
  alias PolyglotWatcherV2.GitDiff.Parser

  @old "/tmp/polyglot_watcher_v2_old"
  @new "/tmp/polyglot_watcher_v2_new"

  # TODO write this
  # Plan is that this will
  # - read the file
  # - search it
  # - generate replacement contents (replace "search" with "replace")
  # - write original & replacement to separate tmp files
  # - run git diff --no-index to generate a diff
  # - write the diff to the terminal
  # - rm -rf the /tmp/polyglot_watcher_v2 dir at the end and recreate it at the start as the real step one (so that every time we execute this we clean up after ourselves)

  def run(file_path, search, replace, server_state) do
    with {:ok, contents} <- read_file(file_path),
         :ok <- write_tmp_file(@old, contents),
         {:ok, new_file_contents} <- new_file_contents(contents, search, replace),
         :ok <- write_tmp_file(@new, new_file_contents),
         {:ok, git_diff} <- run_git_diff() do
      Puts.on_new_line_unstyled(git_diff)
      rm_rf_tmp_files()
      {0, server_state}
    else
      {:error, :read_file, error} ->
        action_error =
          """
          I failed to read a file that I was previously lead to believe exists.
          It was #{file_path}.

          The error was {:error, #{inspect(error)}}.

          This is terminal to the Claude AI operation I'm afraid so I'm giving up.
          """

        rm_rf_tmp_files()
        {1, Map.put(server_state, :action_error, action_error)}

      {:error, :write_tmp, error} ->
        action_error =
          """
          I failed to write to a temporary file, in order to generate a git diff to show you the Claude AI code suggestion.
          Maybe I'm not allowed to write files to /tmp, or it doesn't exist?

          The error was {:error, #{inspect(error)}}.

          This is terminal to the Claude AI operation I'm afraid so I'm giving up.
          """

        rm_rf_tmp_files()
        {1, Map.put(server_state, :action_error, action_error)}

      {:error, :parse, action_error} ->
        rm_rf_tmp_files()
        {1, Map.put(server_state, :action_error, action_error)}

      _ ->
        rm_rf_tmp_files()
        {1, server_state}
    end
  end

  defp new_file_contents(contents, search, replace) do
    result = String.replace(contents, search, replace, global: false)

    if result == contents do
      # TODO test this path
      # TODO handle it in the else block of the with
      {:error, :search_failed}
    else
      {:ok, result}
    end
  end

  defp write_tmp_file(file_path, contents) do
    case FileSystem.write(file_path, contents) do
      :ok -> :ok
      {:error, error} -> {:error, :write_tmp, error}
    end
  end

  defp read_file(file_path) do
    case FileSystem.read(file_path) do
      {:ok, contents} -> {:ok, contents}
      {:error, error} -> {:error, :read_file, error}
    end
  end

  defp rm_rf_tmp_files do
    FileSystem.rm_rf(@old)
    FileSystem.rm_rf(@new)
  end

  defp run_git_diff do
    # exit_code = 1 when there's a diff, otherwise 0. makes error handling tricky...
    {std_out, _exit_code} =
      SystemCall.cmd("git", ["diff", "--no-index", "--color", @old, @new])

    case Parser.parse(std_out) do
      {:ok, git_diff} -> {:ok, git_diff}
      {:error, error} -> {:error, :parse, error}
    end
  end
end
