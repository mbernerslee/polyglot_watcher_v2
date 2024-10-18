defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ReplaceBlock do
  @keys [:search, :replace, :explanation]
  @enforce_keys @keys
  defstruct @keys
end

defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ReplaceBlocks do
  @keys [:pre, :post, :blocks]
  @enforce_keys @keys
  defstruct @keys
end
