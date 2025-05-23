defmodule PolyglotWatcherV2.GitDiff do
  alias PolyglotWatcherV2.{FileSystem, SystemWrapper}
  alias PolyglotWatcherV2.GitDiff.Parser

  @old "/tmp/polyglot_watcher_v2_old"
  @new "/tmp/polyglot_watcher_v2_new"

  def run(request) do
    result =
      Enum.reduce_while(request, {:ok, %{}}, fn {key, file}, {:ok, acc} ->
        %{contents: contents, patches: search_replace} = file

        case run(acc, key, contents, search_replace) do
          {:ok, acc} ->
            {:cont, {:ok, acc}}

          {:error, {:failed_to_write_tmp_file, file_path, error}} ->
            {:halt, {:error, {:failed_to_write_tmp_file, file_path, error}}}

          {:error, :git_diff_parsing_error} ->
            {:halt, {:error, :git_diff_parsing_error}}

          {:error, :search_failed, search, replace} ->
            {:halt, {:error, {:search_failed, search, replace}}}

          {:error, :search_multiple_matches, search, replace} ->
            {:halt, {:error, {:search_multiple_matches, search, replace}}}
        end
      end)

    result
  end

  defp run(acc, _key, _contents, []) do
    {:ok, acc}
  end

  defp run(acc, key, contents, [patch | patches]) do
    %{search: search, replace: replace, index: index} = patch

    key_with_underscores =
      key
      |> to_string()
      |> String.replace("/", "_")
      |> String.replace(".", "_")

    old = @old <> "_#{key_with_underscores}_#{index}"
    new = @new <> "_#{key_with_underscores}_#{index}"

    with {:ok, new_file_contents} <- search_and_replace(contents, search, replace),
         :ok <- write_tmp_file(old, contents),
         :ok <- write_tmp_file(new, new_file_contents),
         {:ok, git_diff} <- run_git_diff(old, new, index) do
      FileSystem.rm_rf(old)
      FileSystem.rm_rf(new)

      acc
      |> Map.put_new(key, %{})
      |> put_in([key, index], git_diff)
      |> run(key, contents, patches)
    else
      {:error, {:failed_to_write_tmp_file, file_path, error}} ->
        {:error, {:failed_to_write_tmp_file, file_path, error}}

      {:error, :git_diff_parsing_error} ->
        {:error, :git_diff_parsing_error}

      {:error, :search_failed} ->
        {:error, :search_failed, search, replace}

      {:error, :search_multiple_matches, search, replace} ->
        {:error, :search_multiple_matches, search, replace}
    end
  end

  defp search_and_replace(contents, search, nil) do
    search_and_replace(contents, search, "")
  end

  defp search_and_replace(contents, search, replace) do
    case :binary.matches(contents, search) do
      [] -> {:error, :search_failed}
      [_] -> {:ok, String.replace(contents, search, replace)}
      [_, _ | _] -> {:ok, String.replace(contents, search, replace, global: true)}
    end
  end

  defp write_tmp_file(file_path, contents) do
    case FileSystem.write(file_path, contents) do
      :ok -> :ok
      {:error, error} -> {:error, {:failed_to_write_tmp_file, file_path, error}}
    end
  end

  defp run_git_diff(old, new, index) do
    IO.inspect(File.read!(old))
    IO.inspect(File.read!(new))

    {std_out, _exit_code} =
      SystemWrapper.cmd("git", ["diff", "--no-index", "--color", old, new])

    IO.inspect(std_out)

    case Parser.parse(std_out, index) do
      {:ok, git_diff} ->
        {:ok, git_diff}

      {:error, error} ->
        IO.inspect(error)
        {:error, :git_diff_parsing_error}
    end
  end
end
