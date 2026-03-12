defmodule PolyglotWatcherV2.Elixir.RunAllMode do
  @behaviour PolyglotWatcherV2.Mode
  alias PolyglotWatcherV2.Action

  @impl PolyglotWatcherV2.Mode
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
             next_action: :mix_test
           }
         })
     }, server_state}
  end

  @impl PolyglotWatcherV2.Mode
  def determine_actions(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree:
         Map.merge(shared_actions(), %{
           clear_screen: %Action{
             runnable: :clear_screen,
             next_action: :mix_test
           }
         })
     }, server_state}
  end

  defp shared_actions do
    %{
      mix_test: %Action{
        runnable: :mix_test,
        next_action: :exit
      }
    }
  end
end
