defmodule PolyglotWatcherV2.UserInput do
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.Determiner, as: ElixirDeterminer

  @languages [ElixirDeterminer]
  @helps ["help\n", "help"]
  @help_and_quits ["help_and_quit\n", "help_and_quit"]

  def determine_actions(user_input, server_state) do
    @languages
    |> Enum.reduce_while({:none, server_state}, fn language_module, {:none, server_state} ->
      case language_module.user_input_actions(user_input, server_state) do
        {:none, server_state} -> {:cont, {:none, server_state}}
        {actions, server_state} -> {:halt, {actions, server_state}}
      end
    end)
    |> put_default_usage(user_input)
  end

  defp put_default_usage({_, server_state}, help) when help in @helps do
    {%{
       entry_point: :put_usage,
       actions_tree: %{
         put_usage: %Action{
           runnable: {:puts, general_usage_puts() ++ languages_usage_puts()},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp put_default_usage({_, server_state}, help_and_quit)
       when help_and_quit in @help_and_quits do
    {%{
       entry_point: :put_usage,
       actions_tree: %{
         put_usage: %Action{
           runnable: {:puts, general_usage_puts() ++ languages_usage_puts()},
           next_action: :quit_the_program
         }
       }
     }, server_state}
  end

  defp put_default_usage({:none, server_state}, "\n") do
    {:none, server_state}
  end

  defp put_default_usage({:none, server_state}, user_input) when user_input != "" do
    {%{
       entry_point: :put_help_command,
       actions_tree: %{
         put_help_command: %Action{
           runnable:
             {:puts, :magenta,
              "I didn't understand what you just entered. Type 'help' to find out what I do understand..."},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp put_default_usage({actions, server_state}, _user_input) do
    {actions, server_state}
  end

  # keep this up to date with README.md!
  defp general_usage_puts do
    [
      {:magenta, "\nGeneral usage\n"},
      {:white, "  Switch between watcher modes per langage using the commands listed below.\n"},
      {:white, "  This can be done by on the fly by typing them in as I run...\n"},
      {:white,
       "  Equally you can pass them in on the command line arguments on startup, to initialise in the desired mode\n\n"},
      {:magenta, "General Commands\n"},
      {:light_magenta, "help\n"},
      {:white, "  see this message\n"},
      {:light_magenta, "help_and_quit\n"},
      {:white, "  see this message and quit\n\n"}
    ]
  end

  # keep this up to date with README.md!
  defp languages_usage_puts do
    Enum.flat_map(@languages, fn language -> language.usage_puts end)
  end
end
