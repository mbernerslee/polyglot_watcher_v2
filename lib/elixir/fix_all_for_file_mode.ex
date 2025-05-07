defmodule PolyglotWatcherV2.Elixir.FixAllForFileMode do
  alias PolyglotWatcherV2.Action

  # TODO continue here tomorrow
  # TODO update switching behaviour to read the cache etc
  def switch(server_state) do
    case server_state.elixir.failures do
      [{test_path, _} | _] ->
        switch_mode_actions_tree = %{
          clear_screen: %Action{
            runnable: :clear_screen,
            next_action: :switch_mode
          },
          switch_mode: %Action{
            runnable: {:switch_mode, :elixir, {:fix_all_for_file, test_path}},
            next_action: :put_switch_success_msg
          },
          put_switch_success_msg: %Action{
            runnable:
              {:puts, :magenta,
               "Switching Elixir to fix_all_for_file #{test_path} mode\nRunning mix test #{test_path}..."},
            next_action: :mix_test
          },
          mix_test: %Action{
            runnable: {:mix_test, test_path},
            next_action: %{
              0 => :put_sarcastic_success,
              :fallback => :put_running_latest_failure_msg
            }
          },
          put_running_latest_failure_msg: %Action{
            runnable:
              {:puts, :red,
               "We'll run only the above failing test until it passes, then the next one until all #{test_path} tests pass"},
            next_action: :exit
          },
          put_sarcastic_success: %Action{
            runnable: :put_sarcastic_success,
            next_action: :exit
          }
        }

        {%{entry_point: :clear_screen, actions_tree: switch_mode_actions_tree}, server_state}

      [] ->
        switch_mode_actions_tree = %{
          clear_screen: %Action{
            runnable: :clear_screen,
            next_action: :put_failed_to_switch_msg
          },
          put_failed_to_switch_msg: %Action{
            runnable:
              {:puts, :magenta,
               "You asked me to switch to fix all for file mode, without specifying which file. I normally use the file from the most recent failure in my memory, but my memory of test failures is empty, so I'm in a bit of a bind and can't work out what you want from me :-("},
            next_action: :exit
          }
        }

        {%{entry_point: :clear_screen, actions_tree: switch_mode_actions_tree}, server_state}
    end
  end

  def switch(server_state, test_path) do
    switch_mode_actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :check_file_exists
      },
      check_file_exists: %Action{
        runnable: {:file_exists, test_path},
        next_action: %{true => :switch_mode, :fallback => :put_no_file_msg}
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:fix_all_for_file, test_path}},
        next_action: :put_switch_success_msg
      },
      put_no_file_msg: %Action{
        runnable:
          {:puts, :red, "I couldn't find a file at #{test_path}, so I failed to switch mode"},
        next_action: :exit
      },
      put_switch_success_msg: %Action{
        runnable:
          {:puts, :magenta,
           "Switching Elixir to fix_all_for_file #{test_path} mode\nRunning mix test #{test_path}..."},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: {:mix_test, test_path},
        next_action: %{0 => :put_sarcastic_success, :fallback => :put_running_latest_failure_msg}
      },
      put_running_latest_failure_msg: %Action{
        runnable:
          {:puts, :red,
           "We'll run only the above failing test until it passes, then the next one until all #{test_path} tests pass"},
        next_action: :exit
      },
      put_sarcastic_success: %Action{
        runnable: :put_sarcastic_success,
        next_action: :exit
      }
    }

    {%{entry_point: :clear_screen, actions_tree: switch_mode_actions_tree}, server_state}
  end

  def determine_actions(%{elixir: %{mode: {:fix_all_for_file, test_path}}} = server_state) do
    {%{
       actions_tree: %{
         :clear_screen => %Action{
           next_action: :mix_test_next,
           runnable: :clear_screen
         },
         :mix_test_next => %Action{
           runnable: {:mix_test_next, test_path},
           next_action: %{
             {:cache, :miss} => :put_mix_test_all_for_file_msg,
             {:mix_test, :passed} => :mix_test_next,
             {:mix_test, :failed} => :exit,
             {:mix_test, :error} => :put_mix_test_all_for_file_msg,
             :fallback => :put_mix_test_all_for_file_msg
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
             2 => :mix_test_next,
             1 => :put_mix_test_error,
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
         }
       },
       entry_point: :clear_screen
     }, server_state}
  end
end
