defmodule PolyglotWatcherV2.Rust.DeterminerTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.{Action, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Rust.Determiner

  describe "determine_actions/1" do
    test "when in default mode, returns the default mode actions" do
      server_state = ServerStateBuilder.build()
      file_path = %FilePath{path: "cool", extension: Determiner.rs()}

      assert {%{
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
              }, server_state} == Determiner.determine_actions(file_path, server_state)
    end

    test "when in default mode, but no rs file was saved, returns :none" do
      server_state = ServerStateBuilder.build()
      file_path = %FilePath{path: "cool", extension: "nope"}

      assert {:none, server_state} == Determiner.determine_actions(file_path, server_state)
    end
  end
end
