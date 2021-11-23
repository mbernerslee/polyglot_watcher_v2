defmodule PolyglotWatcherV2.ElixirLangDeterminer do
  alias PolyglotWatcherV2.{ElixirLangDefaultMode, FilePath}
  @ex "ex"
  @exs "exs"
  @extensions [@ex, @exs]

  def ex, do: @ex
  def exs, do: @exs

  def determine_actions(%FilePath{} = file_path, server_state) do
    if file_path.extension in @extensions do
      by_mode(file_path, server_state)
    else
      {:none, server_state}
    end
  end

  def user_input_actions(user_input, server_state) do
    ex_space = "#{@ex} "

    if String.starts_with?(user_input, ex_space) do
      user_input
      |> String.trim()
      |> String.trim_leading(ex_space)
      |> map_user_input_to_actions(server_state)
    else
      {:none, server_state}
    end
  end

  defp input_to_actions_mapping do
    %{
      "d" => &switch_mode(&1, :default)
    }
  end

  defp map_user_input_to_actions(user_input, server_state) do
    case Map.get(input_to_actions_mapping(), user_input) do
      nil -> dont_undstand_user_input(user_input, server_state)
      actions_fun -> actions_fun.(server_state)
    end
  end

  defp switch_mode(server_state, mode) do
    IO.inspect("switch mode to #{inspect(mode)}")
    {:none, server_state}
  end

  defp dont_undstand_user_input(mode, server_state) do
    IO.inspect("wtf does this mean? #{mode}????")
    {:none, server_state}
  end

  defp by_mode(file_path, server_state) do
    case server_state.elixir.mode do
      :default -> ElixirLangDefaultMode.determine_actions(file_path, server_state)
    end
  end
end
