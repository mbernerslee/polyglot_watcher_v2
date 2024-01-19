defmodule PolyglotWatcherV2.Elixir.DeterminerTest do
  use ExUnit.Case, async: true

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.Determiner

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

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        {:mix_test, 0},
        {:mix_test_puts, 0},
        {:put_elixir_failures_count, 0},
        {:mix_test, 1},
        {:mix_test_puts, 1},
        {:put_elixir_failures_count, 1},
        :mix_test_msg,
        :mix_test,
        :put_sarcastic_success,
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

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        {:mix_test, 0},
        {:mix_test_puts, 0},
        {:put_elixir_failures_count, 0},
        {:mix_test, 1},
        {:mix_test_puts, 1},
        {:put_elixir_failures_count, 1},
        :put_mix_test_msg,
        :mix_test,
        :put_sarcastic_success,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end
    test "returns the fixed_file_ai_mode_actions when in that state" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fixed_file_ai, "test/x_test.exs"})
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

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree
      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_insult,
        :call_chat_gpt,
        :put_success_msg,
        :put_chat_gpt_failure_msg,
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
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

    test "switching to fixed_file mode returns the expected functioning actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               Determiner.user_input_actions("ex f test/cool_test.exs", server_state)

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
               Determiner.user_input_actions(
                 "ex f test/cool_test.exs:100",
                 server_state
               )

      assert %Action{runnable: {:file_exists, "test/cool_test.exs"}} =
               tree.actions_tree.check_file_exists

      assert %Action{runnable: {:switch_mode, :elixir, {:fixed_file, "test/cool_test.exs:100"}}} =
               tree.actions_tree.switch_mode
    end

    test "switching to fixed_file mode without a path argument works and fixes it to the most recent test failure" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 100}])

      assert {tree, _server_state} = Determiner.user_input_actions("ex f", server_state)

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode,
        :put_intent_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
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

    test "switching to fixed_last mode returns the expected functioning actions tree" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 100}])

      assert {tree, ^server_state} = Determiner.user_input_actions("ex fl", server_state)

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

    test "switching to fix_all mode works, and returns the expected actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = Determiner.user_input_actions("ex fa", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode,
        :mix_test_msg,
        :mix_test,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)

      assert %Action{runnable: {:switch_mode, :elixir, :fix_all}} = tree.actions_tree.switch_mode
    end

    test "switching to fix_all_for_file mode, returns the expected actions tree" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               Determiner.user_input_actions("ex faff test/x_test.exs", server_state)

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

    test "switching to fix_all_for_file mode uses the last failure file if no path is provided" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 1}])

      assert {tree, ^server_state} = Determiner.user_input_actions("ex faff", server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :switch_mode,
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

      assert {:none, ^server_state} = Determiner.user_input_actions("ex xxxxx", server_state)
    end

    test "given ex fai, switches to fixed ai mode" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} = Determiner.user_input_actions("ex fai test/x_test.exs:12", server_state)

      expected_action_tree_keys = [:call_chat_gpt, :check_file_exists, :clear_screen, :mix_test, :put_chat_gpt_failure_msg, :put_insult, :put_intent_msg, :put_no_file_msg, :put_success_msg, :put_switch_success_msg, :switch_mode]
      assert %{entry_point: :clear_screen} = tree

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end
  end
end
