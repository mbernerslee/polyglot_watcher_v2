defmodule PolyglotWatcherV2.Determine do
  alias PolyglotWatcherV2.ElixirLangDeterminer

  defp languages do
    [ElixirLangDeterminer]
  end

  def actions({:ok, file_path}, server_state) do
    languages()
    |> Enum.reduce_while(:none, fn language_module, _acc ->
      case language_module.determine_actions(file_path, server_state) do
        :none -> {:cont, :none}
        {actions, server_state} -> {:halt, {actions, server_state}}
      end
    end)
    |> case do
      :none -> {%{}, server_state}
      {actions, server_state} -> {actions, server_state}
    end
  end
end

