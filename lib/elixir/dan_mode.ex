defmodule PolyglotWatcherV2.Elixir.DanMode do
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.Failures

  def switch(server_state) do
    {%{actions_tree: mix_test_actions}, _server_state} = mix_test_actions(server_state)

    switch_actions = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :put_switch_mode_msg
      },
      put_switch_mode_msg: %Action{
        runnable: {:puts, :magenta, "Switching to dan mode"},
        next_action: :switch_mode
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:dan, :mix_test}},
        next_action: :mix_test_msg
      }
    }

    {%{
       entry_point: :clear_screen,
       actions_tree: Map.merge(mix_test_actions, switch_actions)
     }, server_state}
  end

  def determine_actions(server_state) do
    case server_state.elixir.mode do
      {:dan, :mix_test} ->
        mix_test_actions(server_state)

      {:dan, :next_file} ->
        next_file_actions(server_state)

      {:dan, {:fixed_file, file}} ->
        fixed_file_actions(server_state, file)
    end
  end

  defp fixed_file_actions(server_state, file) do
    failures = server_state.elixir.failures
    failures_for_file = Failures.for_file(failures, file)
    failures_for_file_count = length(failures_for_file)

    case failures_for_file do
      [{file, line_number}] ->
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %Action{
               runnable: :clear_screen,
               next_action: :mix_test_msg
             },
             mix_test_msg: %Action{
               runnable: :clear_screen,
               next_action: :mix_test
             },
             mix_test: %Action{
               runnable: {:mix_test, "#{file}:#{line_number}"},
               next_action: %{
                 0 => :put_all_tests_in_file_probably_fixed_msg,
                 :fallback => :put_test_failed_count_msg
               }
             },
             put_all_tests_in_file_probably_fixed_msg: %Action{
               runnable:
                 {:puts,
                  [
                    {:green, "Looks like all tests in #{file} pass now!\n"},
                    {:magenta, "Running mix test #{file} to be sure..."}
                  ]},
               next_action: :mix_test_for_file
             },
             mix_test_for_file: %Action{
               runnable: {:mix_test, file},
               next_action: %{
                 0 => :put_switch_mode_to_next_file_msg,
                 :fallback => :put_test_failed_count_msg
               }
             },
             put_switch_mode_to_next_file_msg: %Action{
               runnable:
                 {:puts,
                  [
                    {:green, "All tests in #{file} have passed for real!\n"},
                    {:magenta, "Moving onto the next test file...\n"},
                    {:magenta, "Save an arbitrary file to trigger the next test"}
                  ]},
               next_action: :switch_mode_to_next_file
             },
             switch_mode_to_next_file: %Action{
               runnable: {:switch_mode, :elixir, {:dan, :next_file}},
               next_action: :exit
             },
             put_test_failed_count_msg: %Action{
               runnable:
                 {:puts, :cyan,
                  "We're currently running tests in #{file} until they all pass...\n #{failures_for_file_count} test failure(s) left ... (ish)"},
               next_action: :exit
             }
           }
         }, server_state}

      [{file, line_number}, {_file, next_line_number} | _] ->
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %Action{
               runnable: :clear_screen,
               next_action: :mix_test_msg
             },
             mix_test_msg: %Action{
               runnable: {:puts, :magenta, "Running mix test #{file}:#{line_number}"},
               next_action: :mix_test
             },
             mix_test: %Action{
               runnable: {:mix_test, "#{file}:#{line_number}"},
               next_action: %{
                 0 => :put_test_passed_count_msg,
                 :fallback => :put_test_failed_count_msg
               }
             },
             put_test_passed_count_msg: %Action{
               runnable:
                 {:puts, :cyan,
                  "We're currently running tests in #{file} until they all pass...\n #{failures_for_file_count - 1} test failure(s) left ... (ish)"},
               next_action: :next_line_number
             },
             next_line_number: %Action{
               runnable: {:switch_mode, :elixir, {:dan, {:fixed_file, file}}},
               next_action: :exit
             },
             put_test_failed_count_msg: %Action{
               runnable:
                 {:puts, :cyan,
                  "We're currently running tests in #{file} until they all pass...\n #{failures_for_file_count} test failure(s) left ... (ish)"},
               next_action: :exit
             }
           }
         }, server_state}
    end
  end

  defp next_file_actions(server_state) do
    failures = server_state.elixir.failures

    case failures do
      [] -> mix_test_actions(server_state)
      [{file, line_number} | _] -> next_file_actions(server_state, file, line_number)
    end
  end

  defp next_file_actions(server_state, file, line_number) do
    failures = server_state.elixir.failures
    failures_for_file_count = failures |> Failures.for_file(file) |> length()

    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :switch_to_fixed_file_mode
         },
         switch_to_fixed_file_mode: %Action{
           runnable: {:switch_mode, :elixir, {:dan, {:fixed_file, file}}},
           next_action: :mix_test_msg
         },
         mix_test_msg: %Action{
           runnable: {:puts, :magenta, "Running mix test #{file}:#{line_number}"},
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: {:mix_test, "#{file}:#{line_number}"},
           next_action: %{
             0 => :put_test_passed_count_msg,
             :fallback => :put_test_failed_count_msg
           }
         },
         put_test_passed_count_msg: %Action{
           runnable:
             {:puts, :cyan,
              "We're currently running tests in #{file} until they all pass...\n #{failures_for_file_count - 1} test failure(s) left ... (ish)"},
           next_action: :exit
         },
         put_test_failed_count_msg: %Action{
           runnable:
             {:puts, :cyan,
              "We're currently running tests in #{file} until they all pass...\n #{failures_for_file_count} test failure(s) left ... (ish)"},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp mix_test_actions(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :mix_test_msg
         },
         mix_test_msg: %Action{
           runnable: {:puts, :magenta, "Running mix test"},
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: :mix_test,
           next_action: %{0 => :exit, :fallback => :put_mix_test_summary}
         },
         put_mix_test_summary: %Action{
           runnable: :put_mix_test_summary,
           next_action: :switch_to_next_file_mode
         },
         switch_to_next_file_mode: %Action{
           runnable: {:switch_mode, :elixir, {:dan, :next_file}},
           next_action: :exit
         }
       }
     }, server_state}
  end
end
