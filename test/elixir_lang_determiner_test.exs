defmodule PolyglotWatcherV2.ElixirLangDeterminerTest do
  use ExUnit.Case, async: true

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    Action,
    ActionsTreeValidator,
    ElixirLangDeterminer,
    FilePath,
    ServerStateBuilder
  }

  @ex ElixirLangDeterminer.ex()
  @ex_file_path %FilePath{path: "lib/cool", extension: @ex}

  describe "determine_actions/2" do
    test "can find the expected normal mode actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               ElixirLangDeterminer.determine_actions(@ex_file_path, server_state)

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

      assert {tree, ^server_state} =
               ElixirLangDeterminer.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end

    test "returns the fix_all_for_file_actions when in that state" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fix_all_for_file, "test/x_test.exs"})
        |> ServerStateBuilder.with_elixir_failures([
          {"test/x_test.exs", 1},
          {"test/x_test.exs", 2},
          {"test/x_test.exs", 3},
          {"test/x_test.exs", 4},
          {"test/x_test.exs", 5},
          {"test/x_test.exs", 6},
          {"test/x_test.exs", 7},
          {"test/x_test.exs", 8}
        ])

      assert {tree, ^server_state} =
               ElixirLangDeterminer.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        {:mix_test, 0},
        {:mix_test, 1},
        {:mix_test, 2},
        {:mix_test, 3},
        {:mix_test, 4},
        {:mix_test, 5},
        {:mix_test, 6},
        {:mix_test, 7},
        :mix_test,
        :put_sarcastic_success,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end
  end

  describe "user_input_actions/2" do
    test "switching to default mode returns the expected functioning actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = ElixirLangDeterminer.user_input_actions("ex d", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end

    test "switching to fixed_file mode returns the expected functioning actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               ElixirLangDeterminer.user_input_actions("ex f test/cool_test.exs", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :check_file_exists,
        :switch_mode,
        :put_no_file_msg,
        :put_switch_success_msg,
        :put_intent_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, {:fixed_file, "test/cool_test.exs"}}} =
               tree.actions_tree.switch_mode
    end

    test "switching to fixed_file, specifying a line number works" do
      server_state = ServerStateBuilder.build()

      assert {tree, _server_state} =
               ElixirLangDeterminer.user_input_actions(
                 "ex f test/cool_test.exs:100",
                 server_state
               )

      assert %Action{runnable: {:file_exists, "test/cool_test.exs"}} =
               tree.actions_tree.check_file_exists

      assert %Action{runnable: {:switch_mode, :elixir, {:fixed_file, "test/cool_test.exs:100"}}} =
               tree.actions_tree.switch_mode
    end

    test "switching to run_all mode returns the expected functioning actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               ElixirLangDeterminer.user_input_actions("ex ra", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :switch_mode,
        :put_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :run_all}} = tree.actions_tree.switch_mode
    end

    test "switching to fixed_last mode returns the expected functioning actions tree" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 100}])

      assert {tree, ^server_state} =
               ElixirLangDeterminer.user_input_actions("ex fl", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :switch_mode,
        :put_switch_msg,
        :put_intent_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :fixed_last}} =
               tree.actions_tree.switch_mode
    end

    test "switching to fix_all_for_file mode, returns the expected actions tree" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               ElixirLangDeterminer.user_input_actions("ex faff test/x_test.exs", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :check_file_exists,
        :switch_mode,
        :put_no_file_msg,
        :put_switch_success_msg,
        :mix_test,
        :put_running_latest_failure_msg,
        :put_sarcastic_success
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, {:fix_all_for_file, "test/x_test.exs"}}} =
               tree.actions_tree.switch_mode
    end

    test "given nonsense user input, doesn't do anything" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 100}])

      assert {:none, ^server_state} =
               ElixirLangDeterminer.user_input_actions("ex xxxxx", server_state)
    end
  end
end
