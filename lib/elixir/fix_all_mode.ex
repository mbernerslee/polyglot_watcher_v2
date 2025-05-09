defmodule PolyglotWatcherV2.Elixir.FixAllMode do
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def determine_actions(server_state) do
    actions_tree =
      Map.merge(fix_all_actions_loop(), %{
        clear_screen: %Action{
          next_action: :mix_test_latest_line,
          runnable: :clear_screen
        }
      })

    {%{entry_point: :clear_screen, actions_tree: actions_tree}, server_state}
  end

  def switch(server_state) do
    actions_tree =
      Map.merge(fix_all_actions_loop(), %{
        clear_screen: %Action{
          runnable: :clear_screen,
          next_action: :put_switch_mode_msg
        },
        put_switch_mode_msg: %Action{
          runnable:
            {:puts,
             [
               {[:magenta], "Switching to "},
               {[:magenta, :italic], "Fix All "},
               {[:magenta], "mode..."}
             ]},
          next_action: :switch_mode
        },
        switch_mode: %Action{
          runnable: {:switch_mode, :elixir, :fix_all},
          next_action: :mix_test_latest_line
        }
      })

    {%{entry_point: :clear_screen, actions_tree: actions_tree}, server_state}
  end

  defp fix_all_actions_loop do
    mix_test_args = %MixTestArgs{path: :all}
    mix_test_msg = "Running #{MixTestArgs.to_shell_command(mix_test_args)}"

    %{
      mix_test_latest_line: %Action{
        next_action: %{
          {:mix_test, :passed} => :mix_test_latest_max_failures_1,
          {:mix_test, :failed} => :exit,
          {:mix_test, :error} => :put_mix_test_error,
          {:cache, :miss} => :put_mix_test_all_msg,
          :fallback => :put_mix_test_error
        },
        runnable: :mix_test_latest_line
      },
      mix_test_latest_max_failures_1: %Action{
        runnable: :mix_test_latest_max_failures_1,
        next_action: %{
          {:mix_test, :passed} => :mix_test_latest_line,
          {:mix_test, :failed} => :exit,
          {:mix_test, :error} => :put_mix_test_error,
          {:cache, :miss} => :put_mix_test_all_msg,
          :fallback => :put_mix_test_error
        }
      },
      put_mix_test_all_msg: %Action{
        next_action: :mix_test_all,
        runnable: {:puts, :magenta, mix_test_msg}
      },
      mix_test_all: %Action{
        next_action: %{
          0 => :put_sarcastic_success,
          1 => :put_mix_test_error,
          2 => :mix_test_latest_line,
          :fallback => :put_mix_test_error
        },
        runnable: {:mix_test, mix_test_args}
      },
      put_mix_test_error: %Action{
        next_action: :exit,
        runnable: {
          :puts,
          :red,
          "Something went wrong running `mix test`. It errored (as opposed to running successfully with tests failing)"
        }
      },
      put_sarcastic_success: %Action{
        next_action: :exit,
        runnable: :put_sarcastic_success
      }
    }
  end
end
