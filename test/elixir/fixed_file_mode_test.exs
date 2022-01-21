defmodule PolyglotWatcherV2.Elixir.FixedFileModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator
  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.FixedFileMode

  describe "switch/0" do
    test "works if there's at least 1 test failure in the history" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 100}])

      assert {tree, _server_state} = FixedFileMode.switch(server_state)

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode,
        :put_intent_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      assert %Action{runnable: {:switch_mode, :elixir, {:fixed_file, "test/x_test.exs:100"}}} =
               tree.actions_tree.switch_mode

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end

    test "fails if there're no test failures in the history" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_failures([])

      assert {tree, _server_state} = FixedFileMode.switch(server_state)

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end
  end
end
