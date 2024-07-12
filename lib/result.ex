defmodule PolyglotWatcherV2.Result do
  # TODO test me
  def and_then({:ok, result}, fun), do: fun.(result)
  def and_then(other, _), do: other
end
