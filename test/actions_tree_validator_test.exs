defmodule PolyglotWatcherV2.ActionsTreeValidatorTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{ActionsTreeValidator, Action, InvalidActionsTreeError}

  describe "validate/1 - valid" do
    test "when the entry point exists in the tree" do
      tree = %{
        entry_point: :start,
        actions_tree: %{start: %Action{runnable: :clear_screen, next_action: :exit}}
      }

      assert ActionsTreeValidator.validate(tree) == true
    end

    test "when there's a next_action of exit within a next_action conditional map" do
      tree = %{
        entry_point: :start,
        actions_tree: %{
          start: %Action{
            runnable: :clear_screen,
            next_action: %{0 => :other_action, :fallback => :exit}
          },
          other_action: %Action{
            runnable: :clear_screen,
            next_action: :exit
          }
        }
      }

      assert ActionsTreeValidator.validate(tree) == true
    end
  end

  describe "validate/1 - invalid" do
    test "when the entry point does not exist in the tree" do
      actions_tree = %{not_start: %Action{runnable: :clear_screen, next_action: :exit}}

      tree = %{entry_point: :start, actions_tree: actions_tree}

      msg =
        "I require the entry_point to exist in the action_tree, but 'start' was not found in #{inspect(actions_tree)}"

      assert_raise InvalidActionsTreeError, msg, fn -> ActionsTreeValidator.validate(tree) end
    end

    test "when any of the actions in the tree are not an action struct" do
      actions_tree = %{start: %{runnable: :clear_screen, next_action: :exit}}

      tree = %{entry_point: :start, actions_tree: actions_tree}

      msg =
        "I require all actions in the tree to be %Action{} structs, but at least one wasn't in #{inspect(actions_tree)}"

      assert_raise InvalidActionsTreeError, msg, fn -> ActionsTreeValidator.validate(tree) end
    end

    test "when no actions have a next_action of exit" do
      actions_tree = %{start: %Action{runnable: :clear_screen, next_action: :clear_screen}}
      tree = %{entry_point: :start, actions_tree: actions_tree}

      msg =
        "I require at least one exit point from the actions tree, but found none in #{inspect(actions_tree)}"

      assert_raise InvalidActionsTreeError, msg, fn -> ActionsTreeValidator.validate(tree) end
    end

    test "when no actions have a next_action of exit, including within next_action maps" do
      actions_tree = %{
        start: %Action{
          runnable: :clear_screen,
          next_action: %{0 => :clear_screen, :fallback => :clear_screen}
        }
      }

      tree = %{entry_point: :start, actions_tree: actions_tree}

      msg =
        "I require at least one exit point from the actions tree, but found none in #{inspect(actions_tree)}"

      assert_raise InvalidActionsTreeError, msg, fn -> ActionsTreeValidator.validate(tree) end
    end

    test "when next_actions don't exist in the tree" do
      actions_tree = %{
        start: %Action{
          runnable: :clear_screen,
          next_action: %{0 => :non_existant, :fallback => :exit}
        }
      }

      tree = %{entry_point: :start, actions_tree: actions_tree}

      assert_raise InvalidActionsTreeError, fn -> ActionsTreeValidator.validate(tree) end
    end

    test "if any actions have a next_action that's a map, but doesn't specify a fallback, then it's invalid" do
      tree =
        %{
          entry_point: :one,
          actions_tree: %{
            one: %Action{
              runnable: {:puts, "one"},
              next_action: %{0 => :two, :fallback => :three}
            },
            two: %Action{
              runnable: {:puts, "two"},
              # fallback is missing here
              next_action: %{0 => :three}
            },
            three: %Action{
              runnable: {:puts, "three"},
              next_action: :exit
            }
          }
        }

      msg =
        """
        I require next_actions to be either:

        - an atom
            Signifying that no matter what happened, run the action with this key
        - a map
            Which MUST contain the :fallback key, signifying what to do if there is no matching exit_code found in the next_actions map

        And sadly I found a map which did not contain :fallback as a next action in the tree!

        The bad next_action was %{0 => :three}
        """

      assert_raise InvalidActionsTreeError, msg, fn -> ActionsTreeValidator.validate(tree) end
    end
  end
end
