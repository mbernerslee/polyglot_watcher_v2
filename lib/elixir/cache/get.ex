defmodule PolyglotWatcherV2.Elixir.Cache.Get do
  alias PolyglotWatcherV2.Elixir.Cache.CacheItem
  alias PolyglotWatcherV2.FileSystem

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

  def files(test_path, cache_items) do
    cache_items
    |> Map.get(test_path)
    |> ensure_cache_ok_for_file_reading()
    |> read_files()
  end

  defp read_files({:ok, {test_path, lib_path, mix_test_output}}) do
    with {:ok, test_contents} <- FileSystem.read(test_path),
         {:ok, lib_contents} <- FileSystem.read(lib_path) do
      {:ok,
       %{
         test: %{path: test_path, contents: test_contents},
         lib: %{path: lib_path, contents: lib_contents},
         mix_test_output: mix_test_output
       }}
    else
      _ ->
        {:error, :file_not_found}
    end
  end

  defp read_files(error) do
    error
  end

  defp ensure_cache_ok_for_file_reading(%CacheItem{
         test_path: test_path,
         lib_path: lib_path,
         mix_test_output: mix_test_output
       })
       when not is_nil(lib_path) and not is_nil(mix_test_output) do
    {:ok, {test_path, lib_path, mix_test_output}}
  end

  defp ensure_cache_ok_for_file_reading(nil) do
    {:error, :not_found}
  end

  defp ensure_cache_ok_for_file_reading(_) do
    {:error, :cache_incomplete}
  end
end
