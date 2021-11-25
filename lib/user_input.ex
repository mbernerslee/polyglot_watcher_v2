defmodule PolyglotWatcherV2.UserInput do
  alias PolyglotWatcherV2.{ElixirLangDeterminer}

  @languages [ElixirLangDeterminer]

  def determine_actions(user_input, server_state) do
    Enum.reduce_while(@languages, {:none, server_state}, fn language_module,
                                                            {:none, server_state} ->
      case language_module.user_input_actions(user_input, server_state) do
        {:none, server_state} -> {:cont, {:none, server_state}}
        {actions, server_state} -> {:halt, {actions, server_state}}
      end
    end)
  end
end
