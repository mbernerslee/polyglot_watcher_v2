defmodule PolyglotWatcherV2.Elm.DeterminerTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator
  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elm.Determiner

  @elm Determiner.elm()

  describe "determine_actions/2" do
    test "given a file that isn't .elm, returns none" do
      server_state = ServerStateBuilder.build()

      assert {:none, ^server_state} =
               Determiner.determine_actions(
                 %FilePath{path: "Cool", extension: ".notelm"},
                 server_state
               )
    end

    test "given a .elm file, returns some actual actions" do
      server_state = ServerStateBuilder.build()

      assert {tree, ^server_state} =
               Determiner.determine_actions(
                 %FilePath{path: "Cool", extension: @elm},
                 server_state
               )

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :find_elm_json,
        :no_elm_json,
        :put_finding_main_msg,
        :find_elm_main,
        :no_elm_main,
        :elm_make,
        :put_success_msg,
        :put_failure_msg
      ]

      assert %Action{runnable: {:puts, :magenta, "Searching for Main.elm for Cool.elm"}} =
               tree.actions_tree.put_finding_main_msg

      assert %Action{
               runnable:
                 {:puts, :red,
                  "I couldn't find a corresponding Main.elm for Cool.elm, so I'm giving up :-("}
             } = tree.actions_tree.no_elm_main

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end
  end
end
