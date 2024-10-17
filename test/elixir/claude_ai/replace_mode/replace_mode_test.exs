defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.Determiner
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool_test", extension: @exs}

  describe "switch/1" do
    test "given a valid server state, switches to ClaudeAI mode" do
      assert {tree, @server_state_normal_mode} = ReplaceMode.switch(@server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode,
        :persist_api_key,
        :no_api_key_fail_msg,
        :put_awaiting_file_save_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end
  end

  describe "determine_actions/1" do
    test "given a lib file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        ReplaceMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_claude_init_msg,
        :put_perist_files_msg,
        :persist_lib_file,
        :persist_test_file,
        :build_claude_replace_api_request,
        :put_calling_claude_msg,
        :perform_claude_api_request,
        :initial_parse_claude_api_response,
        :second_parse_claude_api_response,
        :missing_file_msg,
        :fallback_placeholder_error,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a lib file, puts the correct test file path" do
      {%{actions_tree: actions_tree}, @server_state_normal_mode} =
        ReplaceMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      assert actions_tree.persist_test_file.runnable ==
               {:persist_file, "test/cool_test.exs", :test}
    end

    test "given a test file, puts the correct lib file path" do
      {%{actions_tree: actions_tree}, @server_state_normal_mode} =
        ReplaceMode.determine_actions(
          %FilePath{path: "test/elixir/claude_ai_mode_test", extension: @exs},
          @server_state_normal_mode
        )

      assert actions_tree.persist_lib_file.runnable ==
               {:persist_file, "lib/elixir/claude_ai_mode.ex", :lib}
    end

    test "given a test file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        ReplaceMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_claude_init_msg,
        :put_perist_files_msg,
        :persist_lib_file,
        :persist_test_file,
        :build_claude_replace_api_request,
        :put_calling_claude_msg,
        :perform_claude_api_request,
        :initial_parse_claude_api_response,
        :second_parse_claude_api_response,
        :missing_file_msg,
        :fallback_placeholder_error,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a lib file, but in an invalid format, returns an error actions tree" do
      {tree, @server_state_normal_mode} =
        ReplaceMode.determine_actions(
          %FilePath{path: "not_lib/not_cool", extension: @ex},
          @server_state_normal_mode
        )

      expected_action_tree_keys = [
        :clear_screen,
        :cannot_find_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a test file, but in an invalid format, returns an error actions tree" do
      {tree, @server_state_normal_mode} =
        ReplaceMode.determine_actions(
          %FilePath{path: "not_test/not_cool", extension: @exs},
          @server_state_normal_mode
        )

      expected_action_tree_keys = [
        :clear_screen,
        :cannot_find_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end
  end
end
