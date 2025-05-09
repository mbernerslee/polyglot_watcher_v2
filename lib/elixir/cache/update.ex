defmodule PolyglotWatcherV2.Elixir.Cache.Update do
  alias PolyglotWatcherV2.Elixir.Cache.{
    FailedTestLineNumbers,
    CacheItem,
    MixTestOutputParser,
    FixedTests
  }

  alias PolyglotWatcherV2.Elixir.EquivalentPath
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def run(cache, %MixTestArgs{} = mix_test_args, mix_test_output, exit_code) do
    mix_test_output
    |> MixTestOutputParser.run()
    |> combine(cache)
    |> handle_fixed_tests(mix_test_args, exit_code)
  end

  defp handle_fixed_tests(cache, mix_test_args, exit_code) do
    case FixedTests.determine(mix_test_args, exit_code) do
      nil ->
        cache

      :all ->
        %{}

      {test_path, :all} ->
        Map.delete(cache, test_path)

      {test_path, line} ->
        handle_fixed_test(cache, test_path, line)
    end
  end

  defp handle_fixed_test(cache, test_path, line) do
    case cache do
      %{^test_path => cache_item} ->
        cache_item
        |> Map.update!(:failed_line_numbers, fn lines ->
          Enum.reject(lines, fn n -> n == line end)
        end)
        |> update_or_delete_cache_item_if_no_failing_tests(test_path, cache)

      _ ->
        cache
    end
  end

  defp update_or_delete_cache_item_if_no_failing_tests(cache_item, test_path, cache) do
    case cache_item do
      %{failed_line_numbers: []} ->
        Map.delete(cache, test_path)

      cache_item ->
        Map.put(cache, test_path, cache_item)
    end
  end

  defp combine(mix_test_results, cache) do
    rank_adjustment = map_size(mix_test_results)

    mix_test_results
    |> Enum.reduce(cache, fn {test_path, result}, cache ->
      update_test_path(cache, test_path, result, rank_adjustment)
    end)
    |> adjust_ranks(rank_adjustment)
  end

  defp update_test_path(cache, test_path, mix_test_result, rank_adjustment) do
    %{rank: rank, failure_line_numbers: new_n, raw: file_specific_mix_test_output} =
      mix_test_result

    existing_n = old_failed_test_line_numbers(cache, test_path)
    lib_path = equivalent_lib_path(test_path)

    cache_item =
      %CacheItem{
        test_path: test_path,
        failed_line_numbers: FailedTestLineNumbers.update(existing_n, new_n),
        lib_path: lib_path,
        mix_test_output: file_specific_mix_test_output,
        rank: rank - rank_adjustment
      }

    Map.put(cache, test_path, cache_item)
  end

  defp old_failed_test_line_numbers(cache, test_path) do
    case Map.get(cache, test_path) do
      %CacheItem{failed_line_numbers: failed_line_numbers} -> failed_line_numbers
      nil -> []
    end
  end

  defp adjust_ranks(cache, adjustment) do
    Map.new(cache, fn {test_path, cache_item} ->
      {test_path, Map.update!(cache_item, :rank, &(&1 + adjustment))}
    end)
  end

  defp equivalent_lib_path(test_path) do
    case EquivalentPath.determine(test_path) do
      {:ok, lib_path} -> lib_path
      :error -> nil
    end
  end
end
