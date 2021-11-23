defmodule PolyglotWatcherV2.ElixirLangDeterminerTest do
  use ExUnit.Case, async: true

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    ActionsTreeValidator,
    ElixirLangDeterminer,
    FilePath,
    ServerStateBuilder
  }

  @ex ElixirLangDeterminer.ex()

  describe "determine_actions/2" do
    test "can find the expected normal mode actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               ElixirLangDeterminer.determine_actions(
                 %FilePath{path: "lib/cool", extension: @ex},
                 server_state
               )

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :check_file_exists,
        :put_intent_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg,
        :no_test_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
    end
  end
end
