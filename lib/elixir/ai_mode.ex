defmodule PolyglotWatcherV2.Elixir.AIMode do
  alias PolyglotWatcherV2.Action
  def determine_actions(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree:
       %{
        clear_screen: %Action{
          runnable: :clear_screen,
          next_action: :put_mix_test_msg
        },
        put_mix_test_msg: %Action{
          runnable: {:puts, :magenta, "Running AI generated mix test"},
          next_action: :mix_test_ai
        },
        mix_test_ai: %Action{
          runnable: :mix_test_ai,
          next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
        },
        put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
        put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
      }
     }, server_state}
  end

  # def determine_actions(%FilePath{extension: @exs} = file_path, server_state) do
  #   test_path = FilePath.stringify(file_path)

  #   {%{
  #      entry_point: :clear_screen,
  #      actions_tree: %{
        #  clear_screen: %Action{
        #    runnable: :clear_screen,
        #    next_action: :put_intent_msg
        #  },
        #  put_intent_msg: %Action{
        #    runnable: {:puts, :magenta, "Running mix test #{test_path}"},
        #    next_action: :mix_test
        #  },
  #        mix_test: %Action{
  #          runnable: {:mix_test, test_path},
  #          next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
  #        },
  #        put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
  #        put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
  #      }
  #    }, server_state}
  # end

end
