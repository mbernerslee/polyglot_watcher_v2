defmodule PolyglotWatcherV2.FileExtensions do
  alias PolyglotWatcherV2.Elixir.Determiner, as: ElixirDeterminer
  alias PolyglotWatcherV2.Rust.Determiner, as: RustDeterminer

  @extensions ElixirDeterminer.extensions() ++ RustDeterminer.extensions()

  def all, do: @extensions
end
