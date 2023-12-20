defmodule PolyglotWatcherV2.Determine do
  alias PolyglotWatcherV2.Elixir.Determiner, as: ElixirDeterminer
  alias PolyglotWatcherV2.Rust.Determiner, as: RustDeterminer

  defp languages do
    [ElixirDeterminer, RustDeterminer]
  end

  def actions({:ok, file_path}, server_state) do
    Enum.reduce_while(languages(), {:none, server_state}, fn language_module,
                                                             {:none, server_state} ->
      case language_module.determine_actions(file_path, server_state) do
        {:none, server_state} -> {:cont, {:none, server_state}}
        {actions, server_state} -> {:halt, {actions, server_state}}
      end
    end)
  end

  def actions(:ignore, server_state) do
    {:none, server_state}
  end
end
