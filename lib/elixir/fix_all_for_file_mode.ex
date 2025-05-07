defmodule PolyglotWatcherV2.Elixir.FixAllForFileMode do
  @moduledoc """
  This module violates the usually sacred rule of "mode switching & actions determining must not have side effects" by checking the Elixir.Cache state.

  This was preferable in a trade-off vs the much more cumbersome alternative
  """
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.Cache

  def switch(server_state) do
    case Cache.get(:latest) do
      {:ok, {test_path, _line_number}} ->
        my_specific_actions_tree = %{
          clear_screen: %Action{
            runnable: :clear_screen,
            next_action: :switch_mode
          },
          switch_mode: %Action{
            runnable: {:switch_mode, :elixir, {:fix_all_for_file, test_path}},
            next_action: :put_mode_switch_msg
          },
          put_mode_switch_msg: %Action{
            runnable:
              {:puts,
               [
                 {[:magenta], "Switching to "},
                 {[:magenta, :italic], "Fix All For File "},
                 {[:magenta], "mode...\n"},
                 {[:magenta], "using the latest failing test in memory..."}
               ]},
            next_action: :mix_test_next
          }
        }

        tree = %{
          entry_point: :clear_screen,
          actions_tree: Map.merge(my_specific_actions_tree, action_loop(test_path))
        }

        {tree, server_state}

      {:error, :not_found} ->
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %Action{
               runnable: :clear_screen,
               next_action: :put_error_msg
             },
             put_error_msg: %Action{
               runnable:
                 {:puts,
                  [
                    {[:red], "Switching to "},
                    {[:red, :italic], "Fix All For File "},
                    {[:red], "mode failed\n"},
                    {[:red], "I wasn't given a test_path "},
                    {[:red, :italic], "and "},
                    {[:red], "my memory of failing tests is empty\n"},
                    {[:red],
                     "Therefore I don't know which file upon which to fixate testing, so I am forced to give up :-("}
                  ]},
               next_action: :exit
             }
           }
         }, server_state}
    end
  end

  def switch(server_state, test_path) do
    my_specific_actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :switch_mode
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:fix_all_for_file, test_path}},
        next_action: :put_mode_switch_msg
      },
      put_mode_switch_msg: %Action{
        runnable:
          {:puts,
           [
             {[:magenta], "Switching to "},
             {[:magenta, :italic], "Fix All For File "},
             {[:magenta], "mode..."}
           ]},
        next_action: :mix_test_next
      }
    }

    tree = %{
      entry_point: :clear_screen,
      actions_tree: Map.merge(my_specific_actions_tree, action_loop(test_path))
    }

    {tree, server_state}
  end

  def determine_actions(%{elixir: %{mode: {:fix_all_for_file, test_path}}} = server_state) do
    my_specific_actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :mix_test_next
      }
    }

    tree = %{
      entry_point: :clear_screen,
      actions_tree: Map.merge(my_specific_actions_tree, action_loop(test_path))
    }

    {tree, server_state}
  end

  defp action_loop(test_path) do
    %{
      :mix_test_next => %Action{
        runnable: {:mix_test_next, test_path},
        next_action: %{
          {:cache, :miss} => :put_mix_test_all_for_file_msg,
          {:mix_test, :passed} => :put_mix_test_max_failures_1_msg,
          {:mix_test, :error} => :put_mix_test_error,
          {:mix_test, :failed} => :exit,
          :fallback => :put_mix_test_error
        }
      },
      :put_mix_test_max_failures_1_msg => %Action{
        runnable: {:puts, :magenta, "Running mix test #{test_path} --max-failures 1"},
        next_action: :mix_test_max_failures_1
      },
      :mix_test_max_failures_1 => %Action{
        runnable: {:mix_test, "#{test_path} --max-failures 1"},
        next_action: %{
          0 => :put_sarcastic_success,
          1 => :put_mix_test_error,
          2 => :put_insult,
          :fallback => :put_mix_test_error
        }
      },
      :put_mix_test_all_for_file_msg => %Action{
        runnable: {:puts, :magenta, "Running mix test #{test_path}"},
        next_action: :mix_test_all_for_file
      },
      :mix_test_all_for_file => %Action{
        runnable: {:mix_test, test_path},
        next_action: %{
          0 => :put_sarcastic_success,
          1 => :put_mix_test_error,
          2 => :mix_test_next,
          :fallback => :put_mix_test_error
        }
      },
      :put_mix_test_error => %Action{
        next_action: :exit,
        runnable:
          {:puts, :red,
           "Something went wrong running `mix test`. It errored (as opposed to running successfully with tests failing)"}
      },
      :put_sarcastic_success => %Action{
        next_action: :exit,
        runnable: :put_sarcastic_success
      },
      put_insult: %Action{runnable: :put_insult, next_action: :exit}
    }
  end
end
