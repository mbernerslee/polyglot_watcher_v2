defmodule PolyglotWatcherV2.Elixir.FixAllModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.Elixir.{Cache, FixAllMode}
  alias PolyglotWatcherV2.ServerStateBuilder

  #TODO continue from here
  describe "determine_actions/1" do
    test "returns the expected actions" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:fix_all)

      assert {tree, ^server_state} = FixAllMode.determine_actions(server_state)

      assert %{
               actions_tree: %{
                 clear_screen: %PolyglotWatcherV2.Action{
                   next_action: :mix_test_next,
                   runnable: :clear_screen
                 },
                 mix_test_next: %PolyglotWatcherV2.Action{
                   next_action: %{
                     {:mix_test, :passed} => :mix_test_max_failures_1,
                     {:mix_test, :failed} => :exit,
                     {:mix_test, :error} => :put_mix_test_error,
                     {:cache, :miss} => :put_mix_test_all_msg,
                     :fallback => :put_mix_test_error
                   },
                   runnable: {:mix_test_next, "test/x_test.exs"}
                 },
                 mix_test_max_failures_1: %PolyglotWatcherV2.Action{
                   runnable: :mix_test_next,
                   next_action: %{
                     {:mix_test, :passed} => :mix_test_next,
                     {:mix_test, :failed} => :exit,
                     {:mix_test, :error} => :put_mix_test_error,
                     {:cache, :miss} => :put_mix_test_all_msg,
                     :fallback => :put_mix_test_error
                   }
                 },
                 put_mix_test_all_msg: %PolyglotWatcherV2.Action{
                   next_action: :mix_test_all,
                   runnable: {:puts, :magenta, "Running mix test"}
                 },
                 mix_test_all: %PolyglotWatcherV2.Action{
                   next_action: %{
                     0 => :put_sarcastic_success,
                     1 => :put_mix_test_error,
                     2 => :mix_test_next,
                     :fallback => :put_mix_test_error
                   },
                   runnable: :mix_test
                 },
                 put_mix_test_error: %PolyglotWatcherV2.Action{
                   next_action: :exit,
                   runnable: {
                     :puts,
                     :red,
                     "Something went wrong running `mix test`. It errored (as opposed to running successfully with tests failing)"
                   }
                 },
                 put_sarcastic_success: %PolyglotWatcherV2.Action{
                   next_action: :exit,
                   runnable: :put_sarcastic_success
                 },
                 put_insult: %PolyglotWatcherV2.Action{runnable: :put_insult, next_action: :exit}
               },
               entry_point: :clear_screen
             } == tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
