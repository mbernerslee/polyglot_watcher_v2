defmodule PolyglotWatcherV2.Elixir.Cache.Init do
  @moduledoc """
  Loads:
  - failures from the manifest file created by `mix test`
  - associated code files *.ex
  - associated test files *.exs
  - the line numbers of which tests have failed

  Into memory
  """

  alias PolyglotWatcherV2.{ExUnitFailuresManifest, SystemCall}
  alias PolyglotWatcherV2.Elixir.EquivalentPath
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.Elixir.Cache.{File, LibFile, TestFile}

  def run do
    case find_manifest_file() do
      {:ok, path} ->
        path
        |> String.trim()
        |> ExUnitFailuresManifest.read()
        |> group_manifest_by_relative_test_path()
        |> read_manifest_files()

      _ ->
        %{}
    end
  end

  defp find_manifest_file do
    case SystemCall.cmd("find", [".", "-name", ".mix_test_failures"]) do
      {path, 0} -> {:ok, path}
      _error -> :error
    end
  end

  defp group_manifest_by_relative_test_path(manifest) do
    cwd = FileWrapper.cwd!()

    Enum.reduce(manifest, %{}, fn {{_module, test}, test_path}, acc ->
      Map.update(acc, Path.relative_to(test_path, cwd), [test], fn tests -> [test | tests] end)
    end)
  end

  defp read_manifest_files(manifest) do
    {files, _next_rank} =
      Enum.reduce(manifest, {%{}, 1}, fn {test_path, tests}, {files, next_rank} ->
        read_test_and_lib_files(files, test_path, next_rank, tests)
      end)

    files
  end

  defp read_test_and_lib_files(files, test_path, next_rank, tests) do
    case read_test_file(test_path) do
      {:ok, test_contents} ->
        lib_path = equivalent_lib_path(test_path)
        lib_contents = read_lib_file(lib_path)

        file =
          %File{
            test: %TestFile{
              path: test_path,
              contents: test_contents,
              failed_line_numbers: failed_line_numbers(test_contents, tests)
            },
            lib: %LibFile{path: lib_path, contents: lib_contents},
            mix_test_output: nil,
            rank: next_rank
          }

        {Map.put(files, test_path, file), next_rank + 1}

      {:error, :no_test_file} ->
        {files, next_rank}
    end
  end

  defp equivalent_lib_path(test_path) do
    case EquivalentPath.determine(test_path) do
      {:ok, lib_path} -> lib_path
      :error -> nil
    end
  end

  defp read_test_file(path) do
    case FileWrapper.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, _error} -> {:error, :no_test_file}
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

  defp failed_line_numbers(test_contents, tests) do
    test_lines =
      test_contents
      |> String.split("\n")
      |> Enum.with_index(1)

    tests
    |> Enum.reduce([], fn test, acc ->
      test
      |> to_string()
      |> String.trim_leading("test ")
      |> find_line_numbers(test_lines)
      |> Kernel.++(acc)
    end)
    |> Enum.sort()
    |> Enum.uniq()
  end

  # handling with and without the describe blocking being in the manifest:
  # a test of the same name being in / not in a describe block called "sequence/0":
  # :"test sequence/0 can generate 0 items of the Fibonacci sequence"
  # :"test can generate 0 items of the Fibonacci sequence"
  # crudly trimming the 2nd word in the string to get both
  defp find_line_numbers(test, test_lines) do
    trimmed_test = trim_leading_word(test)

    Enum.reduce(test_lines, [], fn {line, line_number}, acc ->
      regex_1 = ~r|^\s+test\s\"#{test}\"|
      regex_2 = ~r|^\s+test\s\"#{trimmed_test}\"|

      if Regex.match?(regex_1, line) || Regex.match?(regex_2, line) do
        [line_number | acc]
      else
        acc
      end
    end)
  end

  defp trim_leading_word(string) do
    string
    |> String.split(" ")
    |> case do
      [_leading_word | rest] -> rest
      other -> other
    end
    |> Enum.join(" ")
  end
end
