defmodule PolyglotWatcherV2.ElixirLangFixAllForFileMode do
  alias PolyglotWatcherV2.{Action, ElixirLangMixTest}

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

  def determine_actions(
        %{elixir: %{failures: failures, mode: {:fix_all_for_file, test_path}}} = server_state
      ) do
    failures
    |> ElixirLangMixTest.failures_for_file(test_path)
    |> determine_actions_with_failures(server_state, test_path)
  end

  defp determine_actions_with_failures([], server_state, test_path) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: {:mix_test, test_path},
           next_action: %{0 => :put_sarcastic_success, :fallback => :put_failure_msg}
         },
         put_sarcastic_success: %Action{
           runnable: :put_sarcastic_success,
           next_action: :exit
         },
         put_failure_msg: %Action{
           runnable:
             {:puts, :red,
              "At least one test in #{test_path} is busted. I'll run only one failure at a time"},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp determine_actions_with_failures(failures, server_state, test_path) do
    tests_by_line = tests_by_line(failures)

    actions = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: {:mix_test, 0}
      },
      mix_test: %Action{
        runnable: :mix_test,
        next_action: %{0 => :put_sarcastic_success, :fallback => :put_failure_msg}
      },
      put_sarcastic_success: %Action{
        runnable: :put_sarcastic_success,
        next_action: :exit
      },
      put_failure_msg: %Action{
        runnable:
          {:puts, :red,
           "At least one test in #{test_path} is busted. I'll run only one failure at a time"},
        next_action: :exit
      }
    }

    {%{entry_point: :clear_screen, actions_tree: Map.merge(actions, tests_by_line)}, server_state}
  end

  defp tests_by_line(failures), do: tests_by_line(%{}, 0, failures)

  defp tests_by_line(test_actions, index, [{test_path, line_number}]) do
    action = %Action{
      runnable: {:mix_test, "#{test_path}:#{line_number}"},
      next_action: %{0 => :mix_test, :fallback => :put_failure_msg}
    }

    Map.put(test_actions, {:mix_test, index}, action)
  end

  defp tests_by_line(test_actions, index, [{test_path, line_number} | rest]) do
    next_index = index + 1

    action = %Action{
      runnable: {:mix_test, "#{test_path}:#{line_number}"},
      next_action: %{0 => {:mix_test, next_index}, :fallback => :put_failure_msg}
    }

    test_actions = Map.put(test_actions, {:mix_test, index}, action)
    tests_by_line(test_actions, next_index, rest)
  end
end
