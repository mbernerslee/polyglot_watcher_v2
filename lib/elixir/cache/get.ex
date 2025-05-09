defmodule PolyglotWatcherV2.Elixir.Cache.Get do
  alias PolyglotWatcherV2.Elixir.Cache.CacheItem

  def test_failure(:latest, cache_items) do
    cache_items
    |> Enum.sort_by(fn {_test_path, cache_item} -> cache_item.rank end)
    |> Enum.reduce_while({:error, :not_found}, fn
      {test_path, %CacheItem{failed_line_numbers: [line_number | _]}}, _ ->
        {:halt, {:ok, {test_path, line_number}}}

      _, error ->
        {:cont, error}
    end)
  end

  def test_failure(test_path, cache_items) do
    case Map.get(cache_items, test_path) do
      %CacheItem{failed_line_numbers: [line_number | _]} ->
        {:ok, {test_path, line_number}}

      _ ->
        {:error, :not_found}
    end
  end
end
