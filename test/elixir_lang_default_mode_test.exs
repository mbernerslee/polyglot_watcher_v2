defmodule PolyglotWatcherV2.ElixirLangDefaultModeTest do
  use ExUnit.Case, async: true

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    ActionsTreeValidator,
    ElixirLangDeterminer,
    ElixirLangDefaultMode,
    FilePath,
    ServerStateBuilder
  }

  @ex ElixirLangDeterminer.ex()
  @exs ElixirLangDeterminer.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool", extension: @exs}

  describe "determine_actions/2 - in normal mode" do
    test "given an ex file from a lib dir, returns the expected actions_tree & entry point" do
      {tree, @server_state_normal_mode} =
        ElixirLangDefaultMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

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
      assert ActionsTreeValidator.validate(tree)
    end

    test "given an exs file from a test dir, returns the expected valid actions tree" do
      {tree, @server_state_normal_mode} =
        ElixirLangDefaultMode.determine_actions(
          %FilePath{path: "test/cool", extension: @ex},
          @server_state_normal_mode
        )

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :cannot_find_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      assert ActionsTreeValidator.validate(tree)
    end

    test "given an ex file from a test dir, it says it doesn't know what to run" do
      {tree, @server_state_normal_mode} =
        ElixirLangDefaultMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)

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
  end
end
