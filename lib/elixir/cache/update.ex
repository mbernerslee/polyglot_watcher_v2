defmodule PolyglotWatcherV2.Elixir.Cache.Update do
  alias PolyglotWatcherV2.Elixir.Cache.{
    FailedTestLineNumbers,
    File,
    LibFile,
    TestFile,
    MixTestOutputParser,
    FixedTests
  }

  alias PolyglotWatcherV2.Elixir.EquivalentPath
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  def run(files, mix_test_args, mix_test_output, exit_code) do
    mix_test_output
    |> MixTestOutputParser.run()
    |> combine(files)
    |> handle_fixed_tests(mix_test_args, exit_code)
  end

  defp handle_fixed_tests(files, mix_test_args, exit_code) do
    case FixedTests.determine(mix_test_args, exit_code) do
      nil ->
        files

      :all ->
        %{}

      {test_path, :all} ->
        Map.delete(files, test_path)

      {test_path, line} ->
        update_in(files, [test_path, :test, :failed_line_numbers], fn lines ->
          Enum.reject(lines, fn n -> n == line end)
        end)
    end
  end

  defp combine(mix_test_results, files) do
    rank_adjustment = map_size(mix_test_results)

    mix_test_results
    |> Enum.reduce(files, fn {test_path, result}, files ->
      update_test_path(files, test_path, result, rank_adjustment)
    end)
    |> adjust_ranks(rank_adjustment)
  end

  defp update_test_path(files, test_path, mix_test_result, rank_adjustment) do
    %{rank: rank, failure_line_numbers: new_n, raw: file_specific_mix_test_output} =
      mix_test_result

    existing_n = old_failed_test_line_numbers(files, test_path)

    case read_test_file(test_path) do
      {:ok, test_contents} ->
        lib_path = equivalent_lib_path(test_path)
        lib_contents = read_lib_file(lib_path)

        file =
          %File{
            test: %TestFile{
              path: test_path,
              contents: test_contents,
              failed_line_numbers: FailedTestLineNumbers.update(existing_n, new_n)
            },
            lib: %LibFile{path: lib_path, contents: lib_contents},
            mix_test_output: file_specific_mix_test_output,
            rank: rank - rank_adjustment
          }

        Map.put(files, test_path, file)

      {:error, :no_test_file} ->
        files
    end
  end

  defp old_failed_test_line_numbers(files, test_path) do
    case Map.get(files, test_path) do
      %{test: %TestFile{failed_line_numbers: failed_line_numbers}} -> failed_line_numbers
      nil -> []
    end
  end

  defp adjust_ranks(files, adjustment) do
    Map.new(files, fn {test_path, file} ->
      {test_path, Map.update!(file, :rank, &(&1 + adjustment))}
    end)
  end

  # TODO continue here - deal with this duplication
  ###############################
  #### copied from init.ex
  ###############################
  defp read_test_file(path) do
    case FileWrapper.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, _error} -> {:error, :no_test_file}
    end
  end

  defp equivalent_lib_path(test_path) do
    case EquivalentPath.determine(test_path) do
      {:ok, lib_path} -> lib_path
      :error -> nil
    end
  end

  defp read_lib_file(nil) do
    nil
  end

  defp read_lib_file(path) do
    case FileWrapper.read(path) do
      {:ok, contents} -> contents
      {:error, _error} -> nil
    end
  end
end
