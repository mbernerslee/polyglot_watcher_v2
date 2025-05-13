defmodule PolyglotWatcherV2.TraverseActionsTreeTest do
  use ExUnit.Case, async: true
  use Mimic

  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    Action,
    ActionsExecutor,
    ActionsTreeValidator,
    ServerStateBuilder,
    TraverseActionsTree
  }

  describe "execute_all/1" do
    test "given an action tree, entry point and server state, with only 1 action that succeeds, we run it and return the server_state" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %Action{runnable: :clear_screen, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == :clear_screen
        {0, server_state}
      end)

      assert server_state == TraverseActionsTree.execute_all(input)
    end

    test "when 1 action is run which changes the server_state, we return the new server_state" do
      server_state = ServerStateBuilder.build()
      new_server_state = ServerStateBuilder.with_env_var(server_state, "KEY", "VALUE")

      input =
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %Action{runnable: :put_env, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, _server_state ->
        assert runnable == :put_env
        {0, new_server_state}
      end)

      assert new_server_state == TraverseActionsTree.execute_all(input)
    end

    test "when there is a chain of several actions that work, they get run in the order defined in the tree" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{runnable: {:puts, "one"}, next_action: :two},
             two: %Action{runnable: {:puts, "two"}, next_action: :three},
             three: %Action{runnable: {:puts, "three"}, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "one"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "two"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "three"}
        {0, server_state}
      end)

      assert server_state == TraverseActionsTree.execute_all(input)
    end

    test "given many steps, with next_action always atoms, but one in the middle fails, the rest are run regardless" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{runnable: {:puts, "one"}, next_action: :two},
             two: %Action{runnable: {:puts, "two"}, next_action: :three},
             three: %Action{runnable: {:puts, "three"}, next_action: :four},
             four: %Action{runnable: {:puts, "four"}, next_action: :five},
             five: %Action{runnable: {:puts, "five"}, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "one"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "two"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "three"}
        {1, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "four"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "five"}
        {0, server_state}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      assert server_state == TraverseActionsTree.execute_all(input)
    end

    test "given many steps, with next_actions as containing a fallback, the result of the previous action determines the next action, unless we have no match in which case we fallback to the fallback action" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{
               runnable: {:puts, "one"},
               next_action: %{0 => :two, :fallback => :three}
             },
             two: %Action{
               runnable: {:puts, "two"},
               next_action: %{0 => :three, :fallback => :four}
             },
             three: %Action{
               runnable: {:puts, "three"},
               next_action: %{0 => :four, 1 => :five, :fallback => :exit}
             },
             four: %Action{runnable: {:puts, "four"}, next_action: :five},
             five: %Action{runnable: {:puts, "five"}, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "one"}
        {1, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "three"}

        # there is no exit code of 2 defined in the next_actions for action :three, so fallback to the fallback = exit
        {2, server_state}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      assert server_state == TraverseActionsTree.execute_all(input)
    end

    test "if the next action name is :execute_stored_actions, then we give up on our action_tree, and use the one stored in memory in the server_state instead" do
      stored_actions =
        %{
          entry_point: :stored_one,
          actions_tree: %{
            stored_one: %Action{runnable: {:puts, "stored_one"}, next_action: :stored_two},
            stored_two: %Action{runnable: {:puts, "stored_two"}, next_action: :stored_three},
            stored_three: %Action{runnable: {:puts, "stored_three"}, next_action: :exit}
          }
        }

      assert ActionsTreeValidator.validate(stored_actions)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_stored_actions(stored_actions)

      input =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{
               runnable: {:puts, "one"},
               next_action: %{0 => :two, :fallback => :three}
             },
             two: %Action{
               runnable: {:puts, "two"},
               next_action: %{0 => :three, :fallback => :four}
             },
             three: %Action{
               runnable: {:puts, "three"},
               next_action: %{0 => :execute_stored_actions, :fallback => :four}
             },
             four: %Action{runnable: {:puts, "four"}, next_action: :five},
             five: %Action{runnable: {:puts, "five"}, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "one"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "two"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "three"}
        {0, server_state}
      end)

      # four and five are skipped because we're executing the stored actions now

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "stored_one"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "stored_two"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "stored_three"}
        {0, server_state}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      new_server_state = TraverseActionsTree.execute_all(input)

      assert %{server_state | stored_actions: nil} == new_server_state
    end

    test "if an action puts a :action_error into the server_state, then we puts that on the screen and exit, ignoring the other actions. We are then careful to delete the :action_error from the server_state" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{runnable: {:puts, "one"}, next_action: :two},
             two: %Action{runnable: {:puts, "two"}, next_action: :three},
             three: %Action{runnable: {:puts, "three"}, next_action: :four},
             four: %Action{runnable: {:puts, "four"}, next_action: :five},
             five: %Action{runnable: {:puts, "five"}, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "one"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "two"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "three"}
        {0, %{server_state | action_error: "three errored!"}}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, :red, "three errored!"}
        {0, server_state}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      assert server_state == TraverseActionsTree.execute_all(input)

      assert server_state.action_error == nil
    end

    test "if the first action errors, putting at action error, then we put the error & quit" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{runnable: {:puts, "one"}, next_action: :two},
             two: %Action{runnable: {:puts, "two"}, next_action: :three},
             three: %Action{runnable: {:puts, "three"}, next_action: :four},
             four: %Action{runnable: {:puts, "four"}, next_action: :five},
             five: %Action{runnable: {:puts, "five"}, next_action: :exit}
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "one"}
        {0, %{server_state | action_error: "one errored!"}}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, :red, "one errored!"}
        {0, server_state}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      assert server_state == TraverseActionsTree.execute_all(input)

      assert server_state.action_error == nil
    end

    test "given a complex tree with branching paths, the route taken is as expected given the exit codes and next_action maps as defined in the tree" do
      server_state = ServerStateBuilder.build()

      tree =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{
               runnable: {:puts, "one"},
               next_action: %{0 => :two, 1 => :three, :fallback => :four}
             },
             two: %Action{
               runnable: {:puts, "two"},
               next_action: %{0 => :three, 1 => :four, :fallback => :five}
             },
             three: %Action{
               runnable: {:puts, "three"},
               next_action: %{0 => :four, 1 => :five, :fallback => :six}
             },
             four: %Action{
               runnable: {:puts, "four"},
               next_action: %{0 => :five, 1 => :six, 2 => :seven, :fallback => :exit}
             },
             five: %Action{
               runnable: {:puts, "five"},
               next_action: %{0 => :six, 1 => :seven, 2 => :three, :fallback => :exit}
             },
             six: %Action{
               runnable: {:puts, "six"},
               next_action: %{0 => :six, 1 => :seven, 2 => :eight, :fallback => :exit}
             },
             seven: %Action{
               runnable: {:puts, "seven"},
               next_action: %{0 => :six, 1 => :seven, 2 => :exit, :fallback => :eight}
             },
             eight: %Action{
               runnable: {:puts, "eight"},
               next_action: :exit
             }
           }
         }, server_state}

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "one"}
        {1, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "three"}
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "four"}
        {2, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "seven"}
        # 3 doesn't exist in :seven's next_actions, so we use its fallback = eight
        {3, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == {:puts, "eight"}
        {0, server_state}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      assert server_state == TraverseActionsTree.execute_all(tree)
    end

    #    test "when an action is executed, but execute_one returns a new state with an action_error, we respect it and put the error text" do
    #      server_state = ServerStateBuilder.build()
    #
    #      input =
    #        {%{
    #           entry_point: :one,
    #           actions_tree: %{
    #             one: %Action{runnable: {:puts, "one"}, next_action: %{0 => :two, :fallack => :exit}},
    #             two: %Action{runnable: {:puts, "two"}, next_action: :exit}
    #           }
    #         }, server_state}
    #
    #      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
    #        assert runnable == {:puts, "one"}
    #        {0, %{server_state | action_error: "Error in action one"}}
    #      end)
    #
    #      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
    #        assert runnable == {:puts, :red, "Error in action one"}
    #        {0, %{server_state | action_error: nil}}
    #      end)
    #
    #      Mimic.reject(&ActionsExecutor.execute/2)
    #
    #      new_server_state = TraverseActionsTree.execute_all(input)
    #      assert new_server_state.action_error == nil
    #    end

    test "when an action sets action_error but execute_next continues to next action anyway" do
      server_state = ServerStateBuilder.build()

      tree = %{
        entry_point: :clear_screen,
        actions_tree: %{
          clear_screen: %PolyglotWatcherV2.Action{
            runnable: :clear_screen,
            next_action: :put_intent_msg
          },
          put_intent_msg: %PolyglotWatcherV2.Action{
            runnable: {:puts, :magenta, "Z"},
            next_action: :mix_test
          },
          mix_test: %PolyglotWatcherV2.Action{
            runnable:
              {:mix_test, %PolyglotWatcherV2.Elixir.MixTestArgs{path: "path", max_failures: nil}},
            next_action: %{0 => :put_success_msg, :fallback => :put_calling_claude_msg}
          },
          perform_api_call: %PolyglotWatcherV2.Action{
            runnable: {:perform_claude_replace_api_call, "path"},
            next_action: %{0 => :put_awaiting_input_msg, :fallback => :exit}
          },
          put_awaiting_input_msg: %PolyglotWatcherV2.Action{
            runnable: {:puts, :magenta, "X"},
            next_action: :exit
          },
          put_calling_claude_msg: %PolyglotWatcherV2.Action{
            runnable: {:puts, :magenta, "Y"},
            next_action: :perform_api_call
          },
          put_success_msg: %PolyglotWatcherV2.Action{
            runnable: :put_sarcastic_success,
            next_action: :exit
          }
        }
      }

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert runnable == :clear_screen
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert {:puts, :magenta, "Z"} = runnable
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert {:mix_test, _} = runnable
        {2, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert {:puts, :magenta, "Y"} = runnable
        {0, server_state}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert {:perform_claude_replace_api_call, _} = runnable
        {1, %{server_state | action_error: "action error!"}}
      end)

      Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
        assert {:puts, :red, "action error!"} = runnable
        {0, server_state}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      TraverseActionsTree.execute_all({tree, server_state})

      #  Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
      #    assert runnable == {:puts, :magenta, "X"
      #    {0, server_state}
      #  end)

      #  Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
      #    assert runnable == {:puts, "two"}
      #    {0, %{server_state | action_error: "Error in action two"}}
      #  end)

      #  Mimic.expect(ActionsExecutor, :execute, fn runnable, server_state ->
      #    assert runnable == {:puts, :red, "Error in action two"}
      #    {0, server_state}
      #  end)

      #  Mimic.reject(&ActionsExecutor.execute/2)

      # new_server_state = TraverseActionsTree.execute_all(input)
      # assert new_server_state.action_error == nil
    end
  end
end
