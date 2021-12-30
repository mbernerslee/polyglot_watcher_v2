defmodule PolyglotWatcherV2.Elixir.FixAllMode do
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.FailedTestActionChain

  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switching to fix_all mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :fix_all},
           next_action: :mix_test_msg
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

  def determine_actions(server_state) do
    failed_test_action_chain =
      FailedTestActionChain.build(
        server_state.elixir.failures,
        :put_failure_msg,
        %{0 => :mix_test_msg, :fallback => :put_failure_msg}
      )

    actions = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: {:mix_test_puts, 0}
      },
      mix_test_msg: %Action{
        runnable: {:puts, :magenta, "Running mix test"},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: :mix_test,
        next_action: %{0 => :put_sarcastic_success, :fallback => :put_failure_msg}
      },
      put_sarcastic_success: %Action{
        runnable: :put_sarcastic_success,
        next_action: :exit
      },
      put_failure_msg: %Action{
        runnable:
          {:puts, :red,
           "The above test is busted. I'll run it exclusively until you fix it... (unless you break another one in the process)"},
        next_action: :exit
      }
    }

    {
      %{
        entry_point: :clear_screen,
        actions_tree: Map.merge(actions, failed_test_action_chain)
      },
      server_state
    }
  end
end
