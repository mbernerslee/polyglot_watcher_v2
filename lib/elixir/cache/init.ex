defmodule PolyglotWatcherV2.Elixir.Cache.Init do
  @moduledoc """
  Loads:
  - failures from the manifest file created by `mix test`
  - associated code files *.ex
  - associated test files *.exs
  - the line numbers of which tests have failed

  Into memory
  """

  alias PolyglotWatcherV2.{ExUnitFailuresManifest, SystemWrapper}
  alias PolyglotWatcherV2.Elixir.EquivalentPath
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.Elixir.Cache.CacheItem
  alias PolyglotWatcherV2.Elixir.Cache.TestFileASTParser

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
    case SystemWrapper.cmd("find", [".", "-name", ".mix_test_failures"]) do
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
    {cache, _next_rank} =
      Enum.reduce(manifest, {%{}, 1}, fn {test_path, tests}, {cache, next_rank} ->
        cache_from_files(cache, test_path, next_rank, tests)
      end)

    cache
  end

  defp cache_from_files(cache, test_path, next_rank, tests) do
    case read_test_file(test_path) do
      {:ok, test_contents} ->
        lib_path = equivalent_lib_path(test_path)

        cache_item =
          %CacheItem{
            test_path: test_path,
            failed_line_numbers: failed_line_numbers(test_contents, tests),
            lib_path: lib_path,
            mix_test_output: nil,
            rank: next_rank
          }

        {Map.put(cache, test_path, cache_item), next_rank + 1}

      {:error, :no_test_file} ->
        {cache, next_rank}
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

  defp failed_line_numbers(test_contents, tests) do
    failures = TestFileASTParser.run(test_contents)

    tests
    |> Enum.reduce([], fn test, acc ->
      case Map.get(failures, test) do
        nil -> acc
        line -> [line | acc]
      end
    end)
    |> Enum.sort()
  end
end
