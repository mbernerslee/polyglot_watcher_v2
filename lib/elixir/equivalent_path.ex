defmodule PolyglotWatcherV2.Elixir.EquivalentPath do
  alias PolyglotWatcherV2.FilePath
  alias PolyglotWatcherV2.Elixir.Determiner

  @ex Determiner.ex()
  @exs Determiner.exs()

  def determine(%FilePath{path: "lib/" <> rest, extension: @ex}) do
    test_path = "test/#{rest}_test.#{@exs}"
    {:ok, test_path}
  end

  def determine(%FilePath{path: "test/" <> rest, extension: @exs}) do
    lib_path = "lib/#{String.replace_suffix(rest, "_test", "")}.#{@ex}"
    {:ok, lib_path}
  end

  def determine(_) do
    :error
  end
end
