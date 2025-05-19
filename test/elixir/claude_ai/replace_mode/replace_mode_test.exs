defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.Determiner
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool_test", extension: @exs}
  @yes "y\n"
  @no "n\n"

  describe "user_input_actions/2" do
    test "when waiting for user input to determine if we should write Claude-proposed file changes, then make them given 'y'" do
      file_updates = %{
        "lib/cool.ex" => %{
          contents: "AAA\nCCC",
          patches: [
            %{
              search: "AAA",
              replace: "BBB"
            },
            %{
              search: "CCC",
              replace: "DDD"
            }
          ]
        },
        "lib/cool_test.exs" => %{
          contents: "EEE\nGGG",
          patches: [
            %{
              search: "EEE",
              replace: "FFF"
            },
            %{
              search: "GGG",
              replace: "HHH"
            }
          ]
        }
      }

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_claude_ai_file_updates(file_updates)

      assert {tree, server_state} = ReplaceMode.user_input_actions(@yes, server_state)

      assert server_state.claude_ai == %{}

      assert %{
               actions_tree: %{
                 patch_files: %Action{
                   runnable: {:patch_files, file_updates},
                   next_action: :exit
                 }
               },
               entry_point: :patch_files
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "works given 'no'" do
      file_updates = %{
        "lib/cool.ex" => %{
          contents: "AAA\nCCC",
          patches: [
            %{
              search: "AAA",
              replace: "BBB"
            },
            %{
              search: "CCC",
              replace: "DDD"
            }
          ]
        },
        "lib/cool_test.exs" => %{
          contents: "EEE\nGGG",
          patches: [
            %{
              search: "EEE",
              replace: "FFF"
            },
            %{
              search: "GGG",
              replace: "HHH"
            }
          ]
        }
      }

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_claude_ai_file_updates(file_updates)

      assert {tree, server_state} = ReplaceMode.user_input_actions(@no, server_state)

      assert server_state.claude_ai == %{}

      assert %{
               actions_tree: %{
                 put_msg: %Action{
                   runnable: {:puts, :magenta, "Ok, ignoring suggestion..."},
                   next_action: :exit
                 }
               },
               entry_point: :put_msg
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "given state we're not meant to deal with, return false" do
      server_state = ServerStateBuilder.build()

      assert {false, _} = ReplaceMode.user_input_actions("y", server_state)
      assert {false, _} = ReplaceMode.user_input_actions("n", server_state)
      assert {false, _} = ReplaceMode.user_input_actions("invalid", server_state)
    end

    test "when no action is matched, we still remove the claude_ai" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_claude_ai_file_updates(%{})

      assert {false, server_state} = ReplaceMode.user_input_actions("invalid", server_state)

      assert server_state.claude_ai == %{}
    end
  end

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
        :put_calling_claude_msg,
        :perform_api_call,
        :put_awaiting_input_msg,
        :put_success_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a test file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        ReplaceMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_calling_claude_msg,
        :perform_api_call,
        :put_awaiting_input_msg,
        :put_success_msg
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
  end
end
