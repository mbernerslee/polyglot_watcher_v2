defmodule PolyglotWatcherV2.Rust.DeterminerTest do
  use ExUnit.Case, async: true

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Rust.Determiner

  describe "determine_actions/1" do
    test "when in default mode, returns the default mode actions" do
      server_state = ServerStateBuilder.build()
      file_path = %FilePath{path: "cool", extension: Determiner.rs()}

      assert {tree, ^server_state} = Determiner.determine_actions(file_path, server_state)

      assert tree == %{
               entry_point: :clear_screen,
               actions_tree: %{
                 clear_screen: %Action{
                   runnable: :clear_screen,
                   next_action: :put_intent_msg
                 },
                 put_intent_msg: %Action{
                   runnable: {:puts, :magenta, "Running cargo build"},
                   next_action: :cargo_build
                 },
                 cargo_build: %Action{
                   runnable: :cargo_build,
                   next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
                 },
                 put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
                 put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
               }
             }

      ActionsTreeValidator.validate(tree)
    end

    test "when in test mode, returns the test mode actions" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_rust_mode(:test)

      file_path = %FilePath{path: "cool", extension: Determiner.rs()}

      assert {tree, ^server_state} = Determiner.determine_actions(file_path, server_state)

      assert tree == %{
               entry_point: :clear_screen,
               actions_tree: %{
                 clear_screen: %Action{
                   runnable: :clear_screen,
                   next_action: :put_intent_msg
                 },
                 put_intent_msg: %Action{
                   runnable: {:puts, :magenta, "Running cargo test"},
                   next_action: :cargo_test
                 },
                 cargo_test: %Action{
                   runnable: :cargo_test,
                   next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
                 },
                 put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
                 put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
               }
             }

      ActionsTreeValidator.validate(tree)
    end

    test "when in default mode, but no rs file was saved, returns :none" do
      server_state = ServerStateBuilder.build()
      file_path = %FilePath{path: "cool", extension: "nope"}

      assert {:none, server_state} == Determiner.determine_actions(file_path, server_state)
    end
  end

  describe "user_input_actions/2" do
    test "switching to default mode with rs d, works" do
      server_state = ServerStateBuilder.build()
      assert {tree, ^server_state} = Determiner.user_input_actions("rs d", server_state)

      assert %{
               entry_point: :clear_screen,
               actions_tree: %{
                 clear_screen: %Action{
                   runnable: :clear_screen,
                   next_action: :put_switch_mode_msg
                 },
                 put_switch_mode_msg: %Action{
                   runnable: {:puts, :magenta, "Switched Rust to default mode"},
                   next_action: :switch_mode
                 },
                 switch_mode: %Action{
                   runnable: {:switch_mode, :rust, :default},
                   next_action: :exit
                 }
               }
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "switching to test mode with rs t, works" do
      server_state = ServerStateBuilder.build()
      assert {tree, ^server_state} = Determiner.user_input_actions("rs t", server_state)

      assert %{
               entry_point: :clear_screen,
               actions_tree: %{
                 clear_screen: %Action{
                   runnable: :clear_screen,
                   next_action: :put_switch_mode_msg
                 },
                 put_switch_mode_msg: %Action{
                   runnable: {:puts, :magenta, "Switched Rust to test mode"},
                   next_action: :switch_mode
                 },
                 switch_mode: %Action{
                   runnable: {:switch_mode, :rust, :test},
                   next_action: :exit
                 }
               }
             } == tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
