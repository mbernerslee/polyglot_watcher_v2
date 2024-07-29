defmodule PolyglotWatcherV2.Elixir.ClaudeAIModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Determiner, ClaudeAIMode}

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool", extension: @exs}

  describe "determine_actions/1" do
    test "given a lib file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_claude_init_msg,
        :persist_lib_file,
        :persist_test_file,
        :build_claude_api_call,
        :perform_claude_api_request,
        :put_claude_api_response,
        :find_claude_api_diff,
        :write_claude_api_diff_to_file,
        :missing_file_msg,
        :put_claude_noop_msg,
        :fallback_placeholder_error,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end
  end

  describe "find_diff/2" do
    test "given a response with a diff in it, returns the diff" do
      assert {:ok, diff_contents() <> "\n"} ==
               ClaudeAIMode.find_diff(api_response_text_with_diff())
    end

    test "x" do
      assert {:error, :no_diff} == ClaudeAIMode.find_diff("no diff here")
    end
  end

  defp api_response_text_with_diff do
    """
    Based on the test output and the code, it appears that the test is failing because there's an extra key `:bollocks` in the actual action tree that is not expected. Here's a diff to fix this issue:

    #{diff()}

    This diff removes the `:bollocks` key from the actions tree. This extra key was causing the test to fail because it wasn't included in the list of expected action tree keys in the test.

    After applying this change, the actual action tree keys should match the expected keys in the test, and the test should pass.
    """
  end

  defp diff do
    """
    ```diff
    #{diff_contents()}
    ```
    """
  end

  defp diff_contents do
    """
    --- a/lib/elixir/claude_ai_mode.ex
    +++ b/lib/elixir/claude_ai_mode.ex
    @@ -143,7 +143,6 @@ defmodule PolyglotWatcherV2.Elixir.ClaudeAIMode do
                next_action: :put_failure_msg
              },
              put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
    -         bollocks: %Action{runnable: :put_sarcastic_success, next_action: :exit},
              put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
            }
          }, server_state}
    """
  end
end
