defmodule PolyglotWatcherV2.Elixir.FixedFileMode do
  alias PolyglotWatcherV2.Action

  def switch(server_state, test_path) do
    test_path = parse_test_path(test_path)

    run_actions_tree = run_actions_tree_without_clear_screen(test_path.with_line_number)

    switch_mode_actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :check_file_exists
      },
      check_file_exists: %Action{
        runnable: {:file_exists, test_path.without_line_number},
        next_action: %{true => :switch_mode, :fallback => :put_no_file_msg}
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:fixed_file, test_path.with_line_number}},
        next_action: :put_switch_success_msg
      },
      put_no_file_msg: %Action{
        runnable:
          {:puts, :red,
           "I couldn't find a file at #{test_path.without_line_number}, so I failed to switch mode"},
        next_action: :exit
      },
      put_switch_success_msg: %Action{
        runnable:
          {:puts, :magenta, "Switching Elixir to fixed_file #{test_path.with_line_number} mode"},
        next_action: :put_intent_msg
      }
    }

    {%{
       entry_point: :clear_screen,
       actions_tree: Map.merge(switch_mode_actions_tree, run_actions_tree)
     }, server_state}
  end

  def switch(server_state) do
    %{elixir: %{failures: failures}} = server_state

    case failures do
      [{test_path, line_number} | _] ->
        path = "#{test_path}:#{line_number}"
        switch_without_path_exists_check(server_state, path)

      [] ->
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %Action{
               runnable: :clear_screen,
               next_action: :put_switch_mode_failure_msg
             },
             put_switch_mode_failure_msg: %Action{
               runnable:
                 {:puts, :red,
                  "I can't switch to fixed_file mode because you didn't specify which test path I should be fixed to AND my memory of test failures is empty, so I can't switch to the most recent test failure either :-("},
               next_action: :exit
             }
           }
         }, server_state}
    end
  end

  defp switch_without_path_exists_check(server_state, path) do
    run_actions_tree = run_actions_tree_without_clear_screen(path)

    switch_mode_actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :put_switch_mode_msg
      },
      put_switch_mode_msg: %Action{
        runnable:
          {:puts, :magenta, "Switching to Elixir fxied_file mode for the last known test failure"},
        next_action: :switch_mode
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:fixed_file, path}},
        next_action: :put_intent_msg
      }
    }

    {%{
       entry_point: :clear_screen,
       actions_tree: Map.merge(switch_mode_actions_tree, run_actions_tree)
     }, server_state}
  end

  def determine_actions(%{elixir: %{mode: {:fixed_file, test_path}}} = server_state) do
    actions_tree =
      test_path
      |> run_actions_tree_without_clear_screen()
      |> Map.put(:clear_screen, %Action{runnable: :clear_screen, next_action: :put_intent_msg})

    {%{entry_point: :clear_screen, actions_tree: actions_tree}, server_state}
  end

  defp run_actions_tree_without_clear_screen(test_path) do
    %{
      put_intent_msg: %Action{
        runnable: {:puts, :magenta, "Running mix test #{test_path}"},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: {:mix_test, test_path},
        next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
      },
      put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
      put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
    }
  end

  defp parse_test_path(file_path) do
    case String.split(file_path, ":") do
      [result] -> %{with_line_number: result, without_line_number: result}
      [result, _line_number] -> %{with_line_number: file_path, without_line_number: result}
      _ -> %{with_line_number: file_path, without_line_number: file_path}
    end
  end
end
