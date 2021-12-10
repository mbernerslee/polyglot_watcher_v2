defmodule PolyglotWatcherV2.ElixirLangFixedLastModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator
  alias PolyglotWatcherV2.{ActionsTreeValidator, ElixirLangFixedLastMode, ServerStateBuilder}

  describe "determine_actions/1" do
    test "returns actions to fun the most recently failed test" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:fixed_last)
        |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 100}])

      {tree, _server_state} = ElixirLangFixedLastMode.determine_actions(server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      assert ActionsTreeValidator.validate(tree)
    end

    test "when there're no test failures in memory, return a msg to say that" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:fixed_last)
        |> ServerStateBuilder.with_elixir_failures([])

      {tree, _server_state} = ElixirLangFixedLastMode.determine_actions(server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      assert ActionsTreeValidator.validate(tree)
    end
  end
end
