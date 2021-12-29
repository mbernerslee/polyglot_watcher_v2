defmodule PolyglotWatcherV2.ElixirLangFixAllForFileModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    ActionsTreeValidator,
    ElixirLangDeterminer,
    FilePath,
    ServerStateBuilder
  }

  @ex ElixirLangDeterminer.ex()
  @ex_file_path %FilePath{path: "lib/cool", extension: @ex}

  describe "determine_actions/1" do
    test "with no failures for the fixed file, runs all the tests" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fix_all_for_file, "test/x_test.exs"})
        |> ServerStateBuilder.with_elixir_failures([{"test/other_file_test.exs", 1}])

      assert {tree, _} = ElixirLangDeterminer.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :mix_test,
        :put_sarcastic_success,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end
  end
end
