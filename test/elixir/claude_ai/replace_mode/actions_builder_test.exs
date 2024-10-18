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
    test "x" do
      lib_contents =
        """
        defmodule CoolDude do
          def make_cool(dude) do
            dude
          end
        end
        """

      test_contents =
        """
        defmodule CoolDudeTest do
          use ExUnit.Case, async: true

          describe "make_cool/1" do
            test "prepends 'cool'" do
              assert CoolDude.make_cool("dave") == "cool dave"
            end
          end
        end
        """

      lib_file = %{path: "lib/cool.ex", contents: lib_contents}
      test_file = %{path: "test/cool_test.exs", contents: test_contents}

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

      blocks = {:ok, {:replace, %ReplaceBlocks{pre: "pre", blocks: [block], post: "post"}}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_claude_ai_response(blocks)

      assert {0, new_server_state} = ActionsBuilder.build(server_state)

      tree = new_server_state[:stored_actions]

      assert %{
               entry_point: :block_puts_1,
               actions_tree: %{
                 block_puts_1: %Action{
                   runnable: {:puts, _block_puts_1},
                   next_action: :exit
                 }
               }
             } = tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
