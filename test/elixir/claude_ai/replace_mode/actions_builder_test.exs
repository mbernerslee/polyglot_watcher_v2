defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ActionsBuilderTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, ServerStateBuilder}

  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.{
    ActionsBuilder,
    ReplaceBlock,
    ReplaceBlocks
  }

  describe "build/1" do
    test "with 1 block, returns the expected actions tree" do
      lib_path = "lib/cool.ex"

      lib_file = %{path: lib_path, contents: "irrelevent lib contents"}
      test_file = %{path: "test/cool_test.exs", contents: "irrelevent test contents"}

      search =
        """
          def make_cool(dude) do
            dude
          end
        """

      replace =
        """
          def make_cool(dude) do
            "cool " <> dude
          end
        """

      explanation =
        """
        We need to prepend 'cool ' to the inputted string to make the test pass.
        """

      block = %ReplaceBlock{
        search: search,
        replace: replace,
        explanation: explanation
      }

      pre = "pre"

      blocks =
        {:ok, {:replace, %ReplaceBlocks{pre: pre, blocks: [block], post: "irrelevent post"}}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_claude_ai_response(blocks)

      assert {0, new_server_state} = ActionsBuilder.build(server_state)

      tree = new_server_state[:stored_actions]

      expected_pre =
        """
        *******************************
        ******* Claude Response *******
        *******************************
        #{pre}
        """

      assert %{
               entry_point: :put_pre,
               actions_tree: %{
                 put_pre: %Action{runnable: {:puts, [], expected_pre}, next_action: :git_diff_1},
                 git_diff_1: %Action{
                   runnable: {:git_diff, lib_path, search, replace},
                   next_action: %{0 => :put_explanation_1, :fallback => :exit}
                 },
                 put_explanation_1: %Action{
                   runnable: {:puts, :magenta, explanation},
                   next_action: :exit
                 }
               }
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "with 2 blocks, returns the expected actions tree" do
      lib_path = "lib/cool.ex"

      lib_file = %{path: lib_path, contents: "irrelevent lib contents"}
      test_file = %{path: "test/cool_test.exs", contents: "irrelevent test contents"}

      search_1 =
        """
          def make_cool(dude) do
        """

      replace_1 =
        """
          def make_not_cool(dude) do
        """

      explanation_1 =
        """
        We need to change the function name to be less cool
        """

      block_1 = %ReplaceBlock{
        search: search_1,
        replace: replace_1,
        explanation: explanation_1
      }

      search_2 =
        """
            dude
          end
        """

      replace_2 =
        """
            "uncool " <> dude
          end
        """

      explanation_2 =
        """
        We need to prepend 'uncool ' to the inputted string to make the test pass.
        """

      block_2 = %ReplaceBlock{
        search: search_2,
        replace: replace_2,
        explanation: explanation_2
      }

      pre = "pre"

      expected_pre =
        """
        *******************************
        ******* Claude Response *******
        *******************************
        pre
        """

      blocks =
        {:ok,
         {:replace, %ReplaceBlocks{pre: pre, blocks: [block_1, block_2], post: "irrelevent post"}}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_claude_ai_response(blocks)

      assert {0, new_server_state} = ActionsBuilder.build(server_state)

      tree = new_server_state[:stored_actions]

      assert %{
               entry_point: :put_pre,
               actions_tree: %{
                 put_pre: %Action{
                   runnable: {:puts, [], expected_pre},
                   next_action: :git_diff_1
                 },
                 git_diff_1: %Action{
                   runnable: {:git_diff, lib_path, search_1, replace_1},
                   next_action: %{0 => :put_explanation_1, :fallback => :exit}
                 },
                 put_explanation_1: %Action{
                   runnable: {:puts, :magenta, explanation_1},
                   next_action: :git_diff_2
                 },
                 git_diff_2: %Action{
                   runnable: {:git_diff, lib_path, search_2, replace_2},
                   next_action: %{0 => :put_explanation_2, :fallback => :exit}
                 },
                 put_explanation_2: %Action{
                   runnable: {:puts, :magenta, explanation_2},
                   next_action: :exit
                 }
               }
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "with 0 blocks, put the special 'there're no blocks' action tree in the server_state" do
      lib_file = %{path: "lib/cool.ex", contents: "irrelevent lib contents"}
      test_file = %{path: "test/cool_test.exs", contents: "irrelevent test contents"}

      pre = "pre"

      blocks =
        {:ok, {:replace, %ReplaceBlocks{pre: pre, blocks: [], post: "irrelevent post"}}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_claude_ai_response(blocks)

      assert {0, new_server_state} = ActionsBuilder.build(server_state)

      tree = new_server_state[:stored_actions]

      expected_message =
        """
        Claude offered no code changes, only some words of advice:

        #{pre}
        """

      assert %{
               entry_point: :put_no_blocks_message,
               actions_tree: %{
                 put_no_blocks_message: %Action{
                   runnable: {:puts, :magenta, expected_message},
                   next_action: :exit
                 }
               }
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "when the server state is missing key expected data, put an error into actions error" do
      server_state = ServerStateBuilder.build()

      assert {1, new_server_state} = ActionsBuilder.build(server_state)

      expected_error =
        """
        ClaudeAI ReplaceMode Actions Builder was called with some expected data missing.

        If you see this message it's due to a serious bug in the code and should be reported and fixed.

        Please raise a github issue.
        """

      assert Map.put(server_state, :action_error, expected_error) == new_server_state
    end
  end
end
