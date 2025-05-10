defmodule PolyglotWatcherV2.GitDiff do
  alias PolyglotWatcherV2.{FileSystem, Puts, SystemCall}
  alias PolyglotWatcherV2.GitDiff.Parser

  @old "/tmp/polyglot_watcher_v2_old"
  @new "/tmp/polyglot_watcher_v2_new"

  # TODO update error messages
  def run(contents, search, replace, server_state) do
    run(contents, [%{search: search, replace: replace}], server_state)
  end

  def run(contents, search_replace, server_state) do
    result =
      with {:ok, new_file_contents} <- new_file_contents(contents, search_replace),
           :ok <- write_tmp_file(@old, contents),
           :ok <- write_tmp_file(@new, new_file_contents),
           {:ok, git_diff} <- run_git_diff() do
        Puts.on_new_line_unstyled(git_diff)
        {0, server_state}
      else
        {:error, :write_tmp, error} ->
          action_error =
            """
            I failed to write to a temporary file, in order to generate a git diff to show you the Claude AI code suggestion.
            Maybe I'm not allowed to write files to /tmp, or it doesn't exist?

            The error was {:error, #{inspect(error)}}.

            This is terminal to the Claude AI operation I'm afraid so I'm giving up.
            """

          {1, Map.put(server_state, :action_error, action_error)}

        {:error, :search_failed, search, replace} ->
          action_error =
            """
            I tried to find some existing code and replace it with some that might be better,
            but the code it tried to search for didn't exist.

            Here's what it tried to find:

            ```
            #{search}
            ```

            And here's what it tried to replace it with:

            ```
            #{replace}
            ```
            """

          {1, Map.put(server_state, :action_error, action_error)}

        {:error, :search_multiple_matches, search, replace} ->
          action_error =
            """
            Claude tried to find some existing code and replace it with some code it thought was better,
            but the search text it tried to find contained more than 1 match, making it unclear what Claude's intentions were!

            I guess Claude failed us this time :-(

            Here's what it tried to find:

            ```
            #{search}
            ```

            And here's what it tried to replace it with:

            ```
            #{replace}
            ```
            """

          {1, Map.put(server_state, :action_error, action_error)}

        {:error, :parse, action_error} ->
          {1, Map.put(server_state, :action_error, action_error)}
      end

    rm_rf_tmp_files()
    result
  end

  defp new_file_contents(contents, search_replace) do
    Enum.reduce_while(search_replace, {:ok, contents}, fn %{search: search, replace: replace},
                                                          {:ok, contents} ->
      case search_and_replace(contents, search, replace) do
        {:ok, new_contents} -> {:cont, {:ok, new_contents}}
        {:error, error} -> {:halt, {:error, error, search, replace}}
      end
    end)
  end

  defp search_and_replace(contents, search, replace) do
    single_match = String.replace(contents, search, replace, global: false)
    multi_match = String.replace(contents, search, replace, global: true)

    cond do
      multi_match == contents ->
        {:error, :search_failed}

      single_match == multi_match ->
        {:ok, single_match}

      true ->
        {:error, :search_multiple_matches}
    end
  end

  defp write_tmp_file(file_path, contents) do
    case FileSystem.write(file_path, contents) do
      :ok -> :ok
      {:error, error} -> {:error, :write_tmp, error}
    end
  end

  defp rm_rf_tmp_files do
    FileSystem.rm_rf(@old)
    FileSystem.rm_rf(@new)
  end

  defp run_git_diff do
    {std_out, _exit_code} =
      SystemCall.cmd("git", ["diff", "--no-index", "--color", @old, @new])

    case Parser.parse(std_out) do
      {:ok, git_diff} -> {:ok, git_diff}
      {:error, error} -> {:error, :parse, error}
    end
  end
end
