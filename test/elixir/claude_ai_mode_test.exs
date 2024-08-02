defmodule PolyglotWatcherV2.Elixir.ClaudeAIModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Determiner, ClaudeAIMode}
  alias HTTPoison.Request

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool", extension: @exs}

  describe "switch/1" do
    test "given a valid server state, switches to ClaudeAI mode" do
      assert {tree, @server_state_normal_mode} = ClaudeAIMode.switch(@server_state_normal_mode)

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
        ClaudeAIMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_claude_init_msg,
        :persist_lib_file,
        :persist_test_file,
        :build_claude_api_request,
        :perform_claude_api_request,
        :put_claude_api_response,
        :find_claude_api_diff,
        :write_claude_api_diff_to_file,
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
        ClaudeAIMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      assert actions_tree.persist_test_file.runnable ==
               {:persist_file, "test/cool_test.exs", :test}
    end

    test "given a test file, puts the correct lib file path" do
      {%{actions_tree: actions_tree}, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)

      assert actions_tree.persist_lib_file.runnable == {:persist_file, "lib/cool.ex", :lib}
    end

    test "given a test file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_claude_init_msg,
        :persist_lib_file,
        :persist_test_file,
        :build_claude_api_request,
        :perform_claude_api_request,
        :put_claude_api_response,
        :find_claude_api_diff,
        :write_claude_api_diff_to_file,
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
        ClaudeAIMode.determine_actions(
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
        ClaudeAIMode.determine_actions(
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

  describe "build_api_request/2" do
    test "given server_state that contains the required info to build the API call, then it is built and stored in the server_state" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      assert {0, new_server_state} = ClaudeAIMode.build_api_request(server_state)

      assert %{elixir: %{claude_api_request: api_request}} = new_server_state

      assert put_in(server_state, [:elixir, :claude_api_request], api_request) == new_server_state

      assert %Request{
               method: :post,
               url: "https://api.anthropic.com/v1/messages",
               headers: [
                 {"x-api-key", ^api_key},
                 {"anthropic-version", "2023-06-01"},
                 {"content-type", "application/json"}
               ],
               body: body,
               options: [recv_timeout: 30_000]
             } = api_request

      assert %{
               "max_tokens" => 2048,
               "model" => "claude-3-5-sonnet-20240620",
               "messages" => [%{"role" => "user", "content" => _}]
             } = Jason.decode!(body)
    end

    test "given server_state that is missing any of the required info to build the API call, then we return exit_code 1 and leave the server_state unchanged" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      assert {0, _} = ClaudeAIMode.build_api_request(server_state)

      bad_server_states = [
        ServerStateBuilder.with_file(server_state, :lib, nil),
        ServerStateBuilder.with_file(server_state, :test, nil),
        ServerStateBuilder.with_mix_test_output(server_state, nil),
        ServerStateBuilder.with_env_var(server_state, "ANTHROPIC_API_KEY", nil)
      ]

      Enum.each(bad_server_states, fn bad_server_state ->
        assert {1, bad_server_state} == ClaudeAIMode.build_api_request(bad_server_state)
      end)
    end
  end

  # TODO don't try to run mix test in claude mode if the file doesn't exist

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
