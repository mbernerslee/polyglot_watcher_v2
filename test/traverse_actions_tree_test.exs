defmodule PolyglotWatcherV2.TraverseActionsTreeTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{Action, ActionsExecutor, ServerStateBuilder, TraverseActionsTree}

  describe "execute_all/1" do
    test "given an action tree, entry point and server state, with only 1 action that succeeds, we run it and return the server_state" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %Action{
               runnable: :clear_screen,
               next_action: :exit
             }
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

    test "given many steps, but one in the middle fails, the rest are not run" do
      server_state = ServerStateBuilder.build()

      input =
        {%{
           entry_point: :one,
           actions_tree: %{
             one: %Action{runnable: {:puts, "one"}, next_action: :two},
             two: %Action{runnable: {:puts, "two"}, next_action: :three},
             three: %Action{runnable: {:puts, "three"}, next_action: :four},
             four: %Action{runnable: {:puts, "four"}, next_action: :five},
             five: %Action{runnable: {:puts, "three"}, next_action: :exit}
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

      #TODO continue here with tests !!
      # Mimic.reject(&ActionsExecutor.execute/2)

      assert server_state == TraverseActionsTree.execute_all(input)
    end
  end

  #    {%{
  #       entry_point: :clear_screen,
  #       actions_tree: %{
  #         clear_screen: %Action{
  #           runnable: :clear_screen,
  #           next_action: :put_intent_msg
  #         },
  #         put_intent_msg: %Action{
  #           runnable: {:puts, :magenta, "Running mix test #{test_path}"},
  #           next_action: :mix_test
  #         },
  #         mix_test: %Action{
  #           runnable: {:mix_test, test_path},
  #           next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
  #         },
  #         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
  #         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
  #       }
  #     }, server_state}
end
