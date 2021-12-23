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
        next_action: %{0 => :all_fixed, :fallback => :put_running_latest_failure_msg}
      },
      put_running_latest_failure_msg: %Action{
        runnable:
          {:puts, :red,
           "We'll run only the above failing test until it passes, then the next one until all #{test_path} test pass"},
        next_action: :exit
      },
      all_fixed: %Action{
        runnable: {:puts, :green, "Wow, all #{test_path} test passed"},
        next_action: :put_sarcastic_success
      },
      put_sarcastic_success: %Action{
        runnable: :put_sarcastic_success,
        next_action: :exit
      }
    }

    {%{entry_point: :clear_screen, actions_tree: switch_mode_actions_tree}, server_state}
  end

  # TODO make the mix test history delete all historical failures in test/x_test.exs if we ran "mix test test/x_test.exs" or "mix test"
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
           next_action: :put_success_msg
         },
         put_success_msg: %Action{
           runnable: {:puts, :green, "Wow, all the #{test_path} tests passed"},
           next_action: :put_sarcastic_success
         },
         put_sarcastic_success: %Action{
           runnable: :put_sarcastic_success,
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp determine_actions_with_failures(failures, server_state, test_path) do
    build_test_actions(failures, test_path)
    # {%{entry_point: :clear_screen, actions_tree: %{
    #  clear_screen: %Action{
    #    runnable: :clear_screen,
    #    next_action: :put_success_msg
    #  },
    #  put_success_msg: %Action{
    #    runnable: {:puts, :green, "Wow, all the #{test_path} tests passed"}
    #    next_action: :put_sarcastic_success
    #  },
    #  put_sarcastic_success: %Action{
    #    runnable: :put_sarcastic_success,
    #    next_action: :exit
    #  }
    # }}, server_state}
  end

  defp build_test_actions(failures, test_path) do
    failures
    |> Enum.with_index()
    |> Enum.map(fn {{_, line_number}, index} ->
      %{
        {:run_test, index} => %Action{runnable: raise("ass")}
      }
    end)
  end
end
