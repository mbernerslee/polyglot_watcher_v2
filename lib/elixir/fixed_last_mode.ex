defmodule PolyglotWatcherV2.Elixir.FixedLastMode do
  alias PolyglotWatcherV2.Action

  def determine_actions(%{elixir: %{failures: [test_path | _]}} = server_state) do
    test_path = parse_test_path(test_path)

    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_intent_msg
         },
         put_intent_msg: %Action{
           runnable:
             {:puts, :magenta,
              "Running the most recent test case failure that I remember...\nRunning mix test #{test_path}"},
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: {:mix_test, test_path},
           next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end

  def determine_actions(%{elixir: %{failures: []}} = server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_intent_msg
         },
         put_intent_msg: %Action{
           runnable:
             {:puts, :magenta,
              "You asked me to run the latest, most recently failed test case\nbut my memory of failed test cases is empty...\nSo everything is fine (probably, maybe?)"},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp parse_test_path({test_path, line_number}), do: test_path <> ":" <> to_string(line_number)
end
