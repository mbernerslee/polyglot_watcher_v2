defmodule PolyglotWatcherV2.Elixir.Cache.FixedTests do
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def determine(%MixTestArgs{path: :all}, 0) do
    :all
  end

  def determine(%MixTestArgs{path: {path, line}}, 0) do
    {path, line}
  end

  def determine(%MixTestArgs{path: path}, 0) do
    {path, :all}
  end

  def determine(_, _non_zero_exit_code) do
    nil
  end
end
