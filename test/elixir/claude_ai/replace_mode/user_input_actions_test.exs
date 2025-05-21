defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.UserInputActionsTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    Action,
    ActionsTreeValidator,
    FilePatch,
    Patch,
    ServerStateBuilder
  }

  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.UserInputActions

  @yes "y\n"
  @no "n\n"
  @file_patches [
    {"lib/cool.ex",
     %FilePatch{
       contents: "AAA\nCCC",
       patches: [
         %Patch{
           search: "AAA",
           replace: "BBB",
           index: 1
         },
         %Patch{
           search: "CCC",
           replace: "DDD",
           index: 2
         }
       ]
     }},
    {"lib/cool_test.exs",
     %FilePatch{
       contents: "EEE\nGGG",
       patches: [
         %Patch{
           search: "EEE",
           replace: "FFF",
           index: 3
         },
         %Patch{
           search: "GGG",
           replace: "HHH",
           index: 4
         }
       ]
     }}
  ]

  describe "determine/2" do
    test "when waiting for user input to determine if we should write Claude-proposed file changes, then make them given 'y'" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches(@file_patches)

      assert {tree, new_server_state} = UserInputActions.determine(@yes, server_state)

      assert new_server_state == %{server_state | claude_ai: %{}, ignore_file_changes: false}

      assert %{
               actions_tree: %{
                 patch_files: %Action{
                   runnable: {:patch_files, :all},
                   next_action: :exit
                 }
               },
               entry_point: :patch_files
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "works given 'no'" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches(@file_patches)

      expected_server_state = %{
        server_state
        | file_patches: nil,
          claude_ai: %{},
          ignore_file_changes: false
      }

      assert {tree, ^expected_server_state} = UserInputActions.determine(@no, server_state)

      assert %{
               actions_tree: %{
                 put_msg: %Action{
                   runnable: {:puts, :magenta, "Ok, ignoring the rest of the suggestion(s)..."},
                   next_action: :exit
                 }
               },
               entry_point: :put_msg
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "works given an single valid patch index" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches(@file_patches)

      assert {tree, ^server_state} = UserInputActions.determine("1\n", server_state)

      expected_actions = [
        :patch_files,
        :put_cont_msg,
        :put_done_msg,
        :reset_server_state
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_actions)
      ActionsTreeValidator.validate(tree)
    end

    test "works given multiple valid patch indices" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches(@file_patches)

      assert {tree, ^server_state} = UserInputActions.determine("1,2,3,4\n", server_state)

      expected_actions = [
        :patch_files,
        :put_cont_msg,
        :put_done_msg,
        :reset_server_state
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_actions)
      ActionsTreeValidator.validate(tree)
    end

    test "given any patch indices which do not exist in the file patches, return error" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches(@file_patches)

      assert {tree, ^server_state} = UserInputActions.determine("1,2,1000,3,4\n", server_state)

      ActionsTreeValidator.assert_exact_keys(tree, [:put_bad_patch_index_error])
      ActionsTreeValidator.validate(tree)
    end

    test "given some jank user input, returns error" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches(@file_patches)

      assert {tree, ^server_state} = UserInputActions.determine("jank\n", server_state)

      ActionsTreeValidator.assert_exact_keys(tree, [:put_error_msg])
      ActionsTreeValidator.validate(tree)
    end

    test "when no action is matched, we still remove the claude_ai" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_ai_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches([])

      assert {tree, ^server_state} = UserInputActions.determine("invalid", server_state)

      ActionsTreeValidator.validate(tree)
    end

    test "given state we're not meant to deal with, return false" do
      server_state = ServerStateBuilder.build()

      assert {false, _} = UserInputActions.determine("y", server_state)
      assert {false, _} = UserInputActions.determine("n", server_state)
      assert {false, _} = UserInputActions.determine("invalid", server_state)
    end
  end
end
