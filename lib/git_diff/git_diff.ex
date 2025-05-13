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

    rm_rf_tmp_files()
    result
  end

  defp run_one(key, contents, search_replace) do
    # TODO figure this out. test it. do we need this??
    key = key |> to_string() |> String.replace("/", "_")
    old = @old <> "_#{key}"
    new = @new <> "_#{key}"

    result =
      with {:ok, new_file_contents} <- new_file_contents(contents, search_replace),
           :ok <- write_tmp_file(old, contents),
           :ok <- write_tmp_file(new, new_file_contents),
           {:ok, git_diff} <- run_git_diff(old, new) do
        {:ok, git_diff}
      else
        {:error, {:failed_to_write_tmp_file, file_path, error}} ->
          {:error, {:failed_to_write_tmp_file, file_path, error}}

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

  # TODO test handling nil
  defp search_and_replace(contents, search, nil) do
    search_and_replace(contents, search, "")
  end

  defp search_and_replace(contents, search, replace) do
    proposed = String.replace(contents, search, replace, global: false)

    if contents == proposed do
      {:error, :search_failed}
    else
      {:ok, proposed}
    end

    # single_match = String.replace(contents, search, replace, global: false)
    # multi_match = String.replace(contents, search, replace, global: true)

    # cond do
    #  multi_match == contents ->
    #   {:error, :search_failed}

    #  single_match == multi_match ->
    #    {:ok, single_match}

    #  true ->
    #    {:error, :search_multiple_matches}
    # end
  end

  defp write_tmp_file(file_path, contents) do
    case FileSystem.write(file_path, contents) do
      :ok -> :ok
      {:error, error} -> {:error, {:failed_to_write_tmp_file, file_path, error}}
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

# TODO - stop it recursing. its still doing it
# TODO - fix this shit in GitDiff Parser
# ────────────────────────
# Lines: 18 - 24
# ────────────────────────
#       lib_contents = "lib contents OLD LIB"
#       mix_test_output = "mix test output"
#
# -      raise "no"
# +
#
#       test_file = %{path: test_path, contents: test_contents}
#       lib_file = %{path: lib_path, contents: lib_contents}
# @@ -121,8 +121,16 @@ defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICallTest do
#                }
#              } == file_updates
#
# -      # Remove the raise statement
# -      # Add assertions to verify the structure of file_updates
# +      # Assert the structure of file_updates
# +      assert is_map(file_updates)
# +      assert Map.has_key?(file_updates, lib_path)
# +      assert Map.has_key?(file_updates, test_path)
# +
# +      assert %{patches: [lib_patch]} = file_updates[lib_path]
# +      assert %{search: "OLD LIB", replace: "NEW LIB", explanation: "some lib code was awful"} = lib_patch
# +
# +      assert %{patches: [test_patch]} = file_updates[test_path]
# +      assert %{search: "OLD TEST", replace: "NEW TEST", explanation: "some test code was awful"} = test_patch
#     end
#
#     test "when reading the cache returns error, return error" do
