defmodule PolyglotWatcherV2.Elixir.DanMode do
  alias PolyglotWatcherV2.{Action, FilePath}
  alias PolyglotWatcherV2.Elixir.{Determiner, Failures}

  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
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
         },
         mix_test_msg: %Action{
           runnable: {:puts, :magenta, "Running mix test"},
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: :mix_test,
           next_action: %{0 => :put_success_msg, :fallback => :switch_to_next_file_mode}
         },
         switch_to_next_file_mode: %Action{
           runnable: {:switch_mode, :elixir, {:dan, :next_file}},
           next_action: :put_failure_msg
         },
         put_success_msg: %Action{
           runnable: :put_sarcastic_success,
           next_action: :exit
         },
         put_failure_msg: %Action{
           runnable: :put_insult,
           next_action: :exit
         }
       }
     }, server_state}
  end

  def determine_actions(server_state) do
    case server_state.elixir.mode do
      {:dan, :mix_test} ->
        mix_test_actions(server_state)

      {:dan, :next_file} ->
        next_file_actions(server_state)
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
              "#{failures_for_file_count - 1} test failures (at most) left in #{file}"},
           next_action: :put_success_msg
         },
         put_test_failed_count_msg: %Action{
           runnable:
             {:puts, :cyan, "#{failures_for_file_count} test failures (at most) left in #{file}"},
           next_action: :put_failure_msg
         },
         put_success_msg: %Action{
           runnable: :put_sarcastic_success,
           next_action: :exit
         },
         put_failure_msg: %Action{
           runnable: :put_insult,
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
           next_action: %{0 => :put_success_msg, :fallback => :switch_to_next_file_mode}
         },
         switch_to_next_file_mode: %Action{
           runnable: {:switch_mode, :elixir, {:dan, :next_file}},
           next_action: :put_failure_msg
         },
         put_success_msg: %Action{
           runnable: :put_sarcastic_success,
           next_action: :exit
         },
         put_failure_msg: %Action{
           runnable: :put_insult,
           next_action: :exit
         }
       }
     }, server_state}
  end
end
