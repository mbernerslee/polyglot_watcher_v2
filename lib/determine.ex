defmodule PolyglotWatcherV2.Determine do
  alias PolyglotWatcherV2.ElixirLangDeterminer

  defp languages do
    [ElixirLangDeterminer]
  end

  def actions({:ok, file_path}) do
    Enum.reduce_while(languages(), :none, fn language_module, _acc ->
      case language_module.determine_actions(file_path) do
        :none -> {:cont, :none}
        actions -> {:halt, actions}
      end
    end)
  end

  def actions(:ignore) do
    :none
  end
end
