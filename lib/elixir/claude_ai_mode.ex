defmodule PolyglotWatcherV2.Elixir.ClaudeAIMode do
  alias PolyglotWatcherV2.Action

  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switching to Claude AI mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, {:claude_ai, %{}}},
           next_action: :persist_api_key
         },
         persist_api_key: %Action{
           runnable: {:persist_env_var, "CLAUDE_API_KEY", [:claude_api_key]},
           next_action: %{0 => :mix_test_msg, :fallback => :no_api_key_fail_msg}
         },
         no_api_key_fail_msg: %Action{
           runnable:
             {:puts, :red,
              "I read the environment variable 'CLAUDE_API_KEY', but nothing was there, so I'm giving up! Try setting it and running me again..."},
           next_action: :exit
         },
         mix_test_msg: %Action{
           runnable: {:puts, :magenta, "Running mix test"},
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: :mix_test,
           next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
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
