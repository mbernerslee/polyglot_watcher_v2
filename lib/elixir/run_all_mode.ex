defmodule PolyglotWatcherV2.Elixir.RunAllMode do
  alias PolyglotWatcherV2.Action

  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree:
         Map.merge(shared_actions(), %{
           clear_screen: %Action{
             runnable: :clear_screen,
             next_action: :switch_mode
           },
           switch_mode: %Action{
             runnable: {:switch_mode, :elixir, :run_all},
             next_action: :put_switch_mode_msg
           },
           put_switch_mode_msg: %Action{
             runnable: {:puts, :magenta, "Switching to Elixir run_all mode"},
             next_action: :put_mix_test_msg
           }
         })
     }, server_state}
  end

  def determine_actions(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree:
         Map.merge(shared_actions(), %{
           clear_screen: %Action{
             runnable: :clear_screen,
             next_action: :put_mix_test_msg
           }
         })
     }, server_state}
  end

  defp shared_actions do
    %{
      put_mix_test_msg: %Action{
        runnable: {:puts, :magenta, "Running mix test"},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: :mix_test,
        next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
      },
      put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
      put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
    }
  end
end
