defmodule PolyglotWatcherV2.Elixir.AI.ReplaceModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    Action,
    ActionsTreeValidator,
    FilePatch,
    FilePath,
    Patch,
    ServerStateBuilder
  }

  alias PolyglotWatcherV2.Elixir.Determiner
  alias PolyglotWatcherV2.Elixir.AI.ReplaceMode

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool_test", extension: @exs}
  @yes "y\n"

  describe "user_input_actions/2" do
    test "when waiting for user input to determine if we should write AI-proposed file changes, then make them given 'y'" do
      file_patches = [
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

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_ai_state_phase(:waiting)
        |> ServerStateBuilder.with_ignore_file_changes(true)
        |> ServerStateBuilder.with_file_patches(file_patches)

      assert {tree, new_server_state} = ReplaceMode.user_input_actions(@yes, server_state)

      assert new_server_state == %{server_state | ai_state: %{}, ignore_file_changes: false}

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
  end

  describe "switch/1" do
    test "given a valid server state, switches to AI replace mode" do
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
        :put_calling_ai_msg,
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
        :put_calling_ai_msg,
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
