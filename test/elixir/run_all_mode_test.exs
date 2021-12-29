defmodule PolyglotWatcherV2.Elixir.RunAllModeTest do
  use ExUnit.Case, async: true

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.RunAllMode

  describe "switch/2" do
    test "returns the expected actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = RunAllMode.switch(server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :switch_mode,
        :put_switch_mode_msg,
        :put_mix_test_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :run_all}} = tree.actions_tree.switch_mode
    end
  end

  describe "determine_actions/2" do
    test "returns the valid expected actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = RunAllMode.determine_actions(server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_mix_test_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end
  end
end
