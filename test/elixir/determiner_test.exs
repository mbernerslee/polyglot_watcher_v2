defmodule PolyglotWatcherV2.Elixir.DeterminerTest do
  use ExUnit.Case, async: true
  use Mimic

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Cache, Determiner}
  alias PolyglotWatcherV2.FilePatch
  alias PolyglotWatcherV2.Patch

  @ex Determiner.ex()
  @ex_file_path %FilePath{path: "lib/cool", extension: @ex}

  describe "determine_actions/2" do
    test "can find the expected normal mode actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

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
      ActionsTreeValidator.validate(tree)
    end

    test "returns the run_all actions when in that mode" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:run_all)

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_mix_test_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end

    test "returns the fix_all actions when in that state" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:fix_all)

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      ActionsTreeValidator.validate(tree)
    end

    test "returns the fix_all_for_file_actions when in that state" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fix_all_for_file, "test/x_test.exs"})

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :mix_test_latest_line,
        :put_sarcastic_success,
        :put_mix_test_error,
        :put_insult,
        :put_mix_test_all_for_file_msg,
        :mix_test_all_for_file,
        :mix_test_max_failures_1,
        :put_mix_test_max_failures_1_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end

    test "returns the AI Default Mode actions when in that state" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_default)
        |> ServerStateBuilder.with_anthropic_api_key("SECRET")

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      ActionsTreeValidator.validate(tree)
    end

    test "returns the AI Replace Mode actions when in that state" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_anthropic_api_key("SECRET")

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      ActionsTreeValidator.validate(tree)
    end
  end

  describe "user_input_actions/2" do
    test "switching to default mode returns the expected functioning actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = Determiner.user_input_actions("ex d", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end

    test "switching to fixed_file mode works" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               Determiner.user_input_actions("ex f test/cool_test.exs", server_state)

      assert %{entry_point: :clear_screen} = tree

      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, {:fixed_file, "test/cool_test.exs"}}} =
               tree.actions_tree.switch_mode
    end

    test "switching to fixed_file, specifying a line number works" do
      server_state = ServerStateBuilder.build()

      assert {tree, _server_state} =
               Determiner.user_input_actions(
                 "ex f test/cool_test.exs:100",
                 server_state
               )

      assert %Action{
               runnable: {:switch_mode, :elixir, {:fixed_file, {"test/cool_test.exs", 100}}}
             } =
               tree.actions_tree.switch_mode

      ActionsTreeValidator.validate(tree)
    end

    test "switching to fixed_file, giving a nonsense test path fails" do
      server_state = ServerStateBuilder.build()

      assert {:none, ^server_state} =
               Determiner.user_input_actions(
                 "ex f test/cool_test.exs:not_a_line_number",
                 server_state
               )
    end

    test "switching to fixed_file mode without a path argument works and fixes it to the most recent test failure" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Cache, :get_test_failure, fn :latest ->
        {:ok, {"test/path_test.exs", 1}}
      end)

      assert {tree, _server_state} = Determiner.user_input_actions("ex f", server_state)

      ActionsTreeValidator.validate(tree)
    end

    test "switching to run_all mode returns the expected functioning actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = Determiner.user_input_actions("ex ra", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :switch_mode,
        :put_switch_mode_msg,
        :put_mix_test_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :run_all}} = tree.actions_tree.switch_mode
    end

    test "switching to fix_all mode works, and returns the expected actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = Determiner.user_input_actions("ex fa", server_state)

      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :fix_all}} = tree.actions_tree.switch_mode
    end

    test "switching to fix_all_for_file mode, returns the expected actions tree" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"

      assert {tree, ^server_state} =
               Determiner.user_input_actions("ex faff #{test_path}", server_state)

      assert %{entry_point: :clear_screen} = tree

      ActionsTreeValidator.assert_exact_keys(
        tree,
        [
          :clear_screen,
          :mix_test_latest_line,
          :put_sarcastic_success,
          :put_mix_test_error,
          :put_insult,
          :switch_mode,
          :put_mode_switch_msg,
          :put_mix_test_all_for_file_msg,
          :mix_test_all_for_file,
          :mix_test_max_failures_1,
          :put_mix_test_max_failures_1_msg
        ]
      )

      ActionsTreeValidator.validate(tree)
    end

    test "switching to fix_all_for_file mode, giving a nonsense test path fails" do
      server_state = ServerStateBuilder.build()

      assert {:none, ^server_state} =
               Determiner.user_input_actions(
                 "ex faff test/cool_test.exs:not_a_line_number",
                 server_state
               )
    end

    test "switching to fix_all_for_file mode works (tested more thoroughly lower in the stack)" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"
      line_number = 10

      Mimic.expect(Cache, :get_test_failure, fn :latest ->
        {:ok, {test_path, line_number}}
      end)

      assert {tree, ^server_state} = Determiner.user_input_actions("ex faff", server_state)

      assert %{entry_point: :clear_screen} = tree

      ActionsTreeValidator.assert_exact_keys(
        tree,
        [
          :clear_screen,
          :mix_test_latest_line,
          :put_sarcastic_success,
          :put_mix_test_error,
          :put_insult,
          :put_mix_test_all_for_file_msg,
          :mix_test_all_for_file,
          :mix_test_max_failures_1,
          :put_mix_test_max_failures_1_msg,
          :switch_mode,
          :put_mode_switch_msg
        ]
      )

      ActionsTreeValidator.validate(tree)
    end

    test "switching to ai default mode" do
      server_state = ServerStateBuilder.build()
      assert {tree, ^server_state} = Determiner.user_input_actions("ex ai", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode,
        :persist_api_key,
        :no_api_key_fail_msg,
        :put_awaiting_file_save_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :ai_default}} =
               tree.actions_tree.switch_mode
    end

    test "switching to ai replace mode" do
      server_state = ServerStateBuilder.build()
      assert {tree, ^server_state} = Determiner.user_input_actions("ex air", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode,
        :persist_api_key,
        :no_api_key_fail_msg,
        :put_awaiting_file_save_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :ai_replace}} =
               tree.actions_tree.switch_mode
    end

    test "given nonsense user input, doesn't do anything" do
      server_state = ServerStateBuilder.build()

      assert {:none, ^server_state} = Determiner.user_input_actions("ex xxxxx", server_state)
    end

    test "if in replace mode, awaiting user response, accept y" do
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

      assert {tree, _server_state} = Determiner.user_input_actions("y\n", server_state)
      assert %{} = tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
