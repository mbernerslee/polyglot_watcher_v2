defmodule PolyglotWatcherV2.Elixir.FixedFileAIMode do
  alias PolyglotWatcherV2.Action

  def switch(server_state, test_path) do
    test_path = parse_test_path(test_path)

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
        runnable: {:switch_mode, :elixir, {:fixed_file_ai, test_path.with_line_number}},
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
          {:puts, :magenta, "Switching Elixir to fixed_file #{test_path.without_line_number} AI mode"},
        next_action: :put_intent_msg
      },
      put_intent_msg: %Action{
        runnable: {:puts, :magenta, "Running mix test #{test_path.with_line_number}"},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: {:mix_test, "#{test_path.with_line_number}"},
        next_action: %{0 => :put_success_msg, :fallback => :put_insult}
      },
      put_insult: %Action{
        runnable: :put_insult,
        next_action: :call_chat_gpt
      },
      call_chat_gpt: %Action{
        runnable: :elixir_call_chat_gpt,
        next_action: %{0 => :exit, :fallback => :put_chat_gpt_failure_msg}
      },
      put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
      put_chat_gpt_failure_msg: %Action{
        runnable: {:puts, :red, "I failed to call Chat GPT, so I'm giving up for now!"},
        next_action: :exit
      },
    }
    {%{entry_point: :clear_screen, actions_tree: switch_mode_actions_tree }, server_state}
  end


  def determine_actions(%{elixir: %{mode: {:fixed_file_ai, test_path}}} = server_state) do
    test_path = parse_test_path(test_path)

    actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :put_intent_msg
      },
      put_intent_msg: %Action{
        runnable: {:puts, :magenta, "Running mix test #{test_path.with_line_number}"},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: {:mix_test, "#{test_path.with_line_number}"},
        next_action: %{0 => :put_success_msg, :fallback => :put_insult}
      },
      put_insult: %Action{
        runnable: :put_insult,
        next_action: :call_chat_gpt
      },
      call_chat_gpt: %Action{
        runnable: :elixir_call_chat_gpt,
        next_action: %{0 => :exit, :fallback => :put_chat_gpt_failure_msg}
      },
      put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
      put_chat_gpt_failure_msg: %Action{
        runnable: {:puts, :red, "I failed to call Chat GPT, so I'm giving up for now!"},
        next_action: :exit
      },
    }
    {%{entry_point: :clear_screen, actions_tree: actions_tree }, server_state}
  end

  defp parse_test_path(file_path) do
    case String.split(file_path, ":") do
      [result] -> %{with_line_number: result, without_line_number: result}
      [result, _line_number] -> %{with_line_number: file_path, without_line_number: result}
      _ -> %{with_line_number: file_path, without_line_number: file_path}
    end
  end
end
