defmodule PolyglotWatcherV2.Elixir.Cache.FailedTestLineNumbers do
  def update(old, new) do
    new
    |> Enum.reverse()
    |> Enum.reduce(old, fn new, acc -> [new | acc] end)
    |> Enum.uniq()
  end
end
