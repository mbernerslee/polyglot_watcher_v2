defmodule PolyglotWatcherV2.Elixir.FixAllModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.ActionsTreeValidator
  alias PolyglotWatcherV2.Elixir.FixAllMode
  alias PolyglotWatcherV2.Elixir.MixTestArgs
  alias PolyglotWatcherV2.ServerStateBuilder

  describe "determine_actions/1" do
    test "returns the expected actions" do
      raise "no"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:fix_all)

      assert {tree, ^server_state} = FixAllMode.determine_actions(server_state)

      assert %{
               actions_tree: %{
                 clear_screen: %Action{
                   next_action: :mix_test_latest_line,
                   runnable: :clear_screen
                 },
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
                   runnable: {:puts, :magenta, "Running mix test --color"}
                 },
                 mix_test_all: %Action{
                   next_action: %{
                     0 => :put_sarcastic_success,
                     1 => :put_mix_test_error,
                     2 => :mix_test_latest_line,
                     :fallback => :put_mix_test_error
                   },
                   runnable: {:mix_test, %MixTestArgs{path: :all}}
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
               },
               entry_point: :clear_screen
             } == tree

      ActionsTreeValidator.validate(tree)
    end
  end

  describe "switch/1" do
    test "returns the expected actions with a switch mode message" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:fix_all)

      assert {tree, ^server_state} = FixAllMode.switch(server_state)

      assert %{
               actions_tree: %{
                 clear_screen: %Action{
                   next_action: :put_switch_mode_msg,
                   runnable: :clear_screen
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
                   next_action: :mix_test_latest_line,
                   runnable: {:switch_mode, :elixir, :fix_all}
                 },
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
                   runnable: {:puts, :magenta, "Running mix test --color"}
                 },
                 mix_test_all: %Action{
                   next_action: %{
                     0 => :put_sarcastic_success,
                     1 => :put_mix_test_error,
                     2 => :mix_test_latest_line,
                     :fallback => :put_mix_test_error
                   },
                   runnable: {:mix_test, %MixTestArgs{path: :all}}
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
               },
               entry_point: :clear_screen
             } == tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
