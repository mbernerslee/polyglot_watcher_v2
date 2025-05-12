defmodule PolyglotWatcherV2.GitDiff do
  alias PolyglotWatcherV2.{FileSystem, SystemCall}
  alias PolyglotWatcherV2.GitDiff.Parser

  @old "/tmp/polyglot_watcher_v2_old"
  @new "/tmp/polyglot_watcher_v2_new"

  def run(request) do
    result =
      Enum.reduce_while(request, {:ok, %{}}, fn {key,
                                                 %{
                                                   contents: contents,
                                                   search_replace: search_replace
                                                 }},
                                                {:ok, acc} ->
        case run_one(key, contents, search_replace) do
          {:ok, git_diff} ->
            {:cont, {:ok, Map.put(acc, key, git_diff)}}

          {:error, :failed_to_write_tmp_file} ->
            {:halt, {:error, :failed_to_write_tmp_file}}

          {:error, :git_diff_parsing_error} ->
            {:halt, {:error, :git_diff_parsing_error}}

          {:error, :search_failed, search, replace} ->
            {:halt, {:error, {:search_failed, search, replace}}}

          {:error, :search_multiple_matches, search, replace} ->
            {:halt, {:error, {:search_multiple_matches, search, replace}}}
        end
      end)

    rm_rf_tmp_files()
    result
  end

  defp run_one(key, contents, search_replace) do
    old = @old <> "_#{key}"
    new = @new <> "_#{key}"

    result =
      with {:ok, new_file_contents} <- new_file_contents(contents, search_replace),
           :ok <- write_tmp_file(old, contents),
           :ok <- write_tmp_file(new, new_file_contents),
           {:ok, git_diff} <- run_git_diff(old, new) do
        {:ok, git_diff}
      else
        {:error, :failed_to_write_tmp_file} ->
          {:error, :failed_to_write_tmp_file}

        {:error, :git_diff_parsing_error} ->
          {:error, :git_diff_parsing_error}

        {:error, :search_failed, search, replace} ->
          {:error, :search_failed, search, replace}

        {:error, :search_multiple_matches, search, replace} ->
          {:error, :search_multiple_matches, search, replace}
      end

    FileSystem.rm_rf(old)
    FileSystem.rm_rf(new)

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
      {:error, _error} -> {:error, :failed_to_write_tmp_file}
    end
  end

  defp rm_rf_tmp_files do
    FileSystem.rm_rf(@old)
    FileSystem.rm_rf(@new)
  end

  defp run_git_diff(old, new) do
    {std_out, _exit_code} =
      SystemCall.cmd("git", ["diff", "--no-index", "--color", old, new])

    case Parser.parse(std_out) do
      {:ok, git_diff} -> {:ok, git_diff}
      {:error, _error} -> {:error, :git_diff_parsing_error}
    end
  end
end
