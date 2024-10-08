defmodule PolyglotWatcherV2.StartupMessageTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{Action, ServerStateBuilder, StartupMessage}

  describe "put_default_if_empty/1" do
    test "given no action, puts the startup message" do
      server_state = ServerStateBuilder.build()

      assert {%{
                entry_point: :clear_screen,
                actions_tree: %{
                  clear_screen: %Action{
                    runnable: :clear_screen,
                    next_action: :put_startup_msg
                  },
                  put_startup_msg: %Action{
                    runnable: {:puts, :magenta, "Watching for file saves..."},
                    next_action: :exit
                  }
                }
              }, server_state} == StartupMessage.put_default_if_empty({:none, server_state})
    end

    test "given some non 'none' actions and server state, makes no changes and returns it" do
      actions_and_server_state =
        {%{
           entry_point: :say_hi,
           actions_tree: %{
             say_hi: %Action{
               runnable: {:puts, "hi"},
               next_action: :quit_the_program
             }
           }
         }, ServerStateBuilder.build()}

      assert actions_and_server_state ==
               StartupMessage.put_default_if_empty(actions_and_server_state)
    end
  end
end
