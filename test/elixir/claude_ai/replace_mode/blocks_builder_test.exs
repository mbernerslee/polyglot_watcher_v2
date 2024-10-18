defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.BlocksBuilderTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.ServerStateBuilder

  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.{
    BlocksBuilder,
    ReplaceBlock,
    ReplaceBlocks
  }

  describe "parse/1" do
    test "given expected input with pre and 1 block, it works (single string variant)" do
      blocks = %{
        "BLOCKS" => [
          %{
            "EXPLANATION" =>
              "We need to implement the Fib module with the sequence/1 function. This implementation handles the base cases for 0 and 1, and uses Enum.reduce to efficiently generate the Fibonacci sequence for n > 1.",
            "REPLACE" =>
              "defmodule Fib do\n  def sequence(0), do: []\n  def sequence(1), do: [1]\n  def sequence(n) when n > 1 do\n    Enum.reduce(2..n, [1, 1], fn _, [b, a | rest] ->\n      [a + b, b, a | rest]\n    end)\n    |> Enum.reverse()\n  end\nend\n",
            "SEARCH" => ""
          }
        ]
      }

      raw_response =
        """
        Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change using the *SEARCH/REPLACE/EXPLANATION BLOCKS* format:

        **********
        #{Jason.encode!(blocks)}
        **********

        This implementation will fix the test by providing the required `Fib.sequence/1` function. It handles all the test cases, including generating an empty list for 0, a single-element list for 1, and the correct Fibonacci sequence for any positive integer n.

        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, new_server_state} = BlocksBuilder.parse(server_state)

      expected_search = ""

      expected_replace =
        """
        defmodule Fib do
          def sequence(0), do: []
          def sequence(1), do: [1]
          def sequence(n) when n > 1 do
            Enum.reduce(2..n, [1, 1], fn _, [b, a | rest] ->
              [a + b, b, a | rest]
            end)
            |> Enum.reverse()
          end
        end
        """

      expected_explanation =
        "We need to implement the Fib module with the sequence/1 function. This implementation handles the base cases for 0 and 1, and uses Enum.reduce to efficiently generate the Fibonacci sequence for n > 1."

      expected_pre =
        "Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change using the *SEARCH/REPLACE/EXPLANATION BLOCKS* format:"

      assert {:ok,
              {:replace,
               %ReplaceBlocks{
                 pre: actual_pre,
                 blocks: [block]
               }}} = new_server_state[:claude_ai][:response]

      assert %ReplaceBlock{
               search: actual_search,
               replace: actual_replace,
               explanation: actual_explanation
             } = block

      assert actual_pre == expected_pre
      assert actual_search == expected_search
      assert actual_replace == expected_replace
      assert actual_explanation == expected_explanation
    end

    test "with multiple blocks" do
      blocks = %{
        "BLOCKS" => [
          %{
            "EXPLANATION" => "explanation 1 cool",
            "REPLACE" => "replace 1 cool",
            "SEARCH" => "search 1 cool"
          },
          %{
            "EXPLANATION" => "explanation 2 cool",
            "REPLACE" => "replace 2 cool",
            "SEARCH" => "search 2 cool"
          }
        ]
      }

      raw_response =
        """
        Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change:

        **********
        #{Jason.encode!(blocks)}
        **********

        Some kinda post msg
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, new_server_state} = BlocksBuilder.parse(server_state)

      expected =
        {:ok,
         {:replace,
          %ReplaceBlocks{
            pre:
              "Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change:",
            post: "Some kinda post msg",
            blocks: [
              %ReplaceBlock{
                search: "search 1 cool",
                replace: "replace 1 cool",
                explanation: "explanation 1 cool"
              },
              %ReplaceBlock{
                search: "search 2 cool",
                replace: "replace 2 cool",
                explanation: "explanation 2 cool"
              }
            ]
          }}}

      assert new_server_state[:claude_ai][:response] == expected
    end

    test "with invalid JSON return error" do
      raw_response =
        """
        Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change:

        **********
        {
         "BLOCKS": [
           {
             "SEARCH": "search",
             "REPLACE": "replace",
             "EXPLANATION": "explanation"
        **********
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {1, new_server_state} = BlocksBuilder.parse(server_state)

      assert {:error, {:replace, error}} = new_server_state[:claude_ai][:response]

      assert error =~ "Failed to decode JSON.\nThe decoding error was:"
      assert error =~ "%Jason.DecodeError{"
      assert error =~ "The raw response was:"
    end

    test "when the JSON doesn't have BLOCKS as the root, return error" do
      raw_response =
        """
        Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change:

        **********
        {
         "FAIL": [
           {
             "SEARCH": "search",
             "REPLACE": "replace",
             "EXPLANATION": "explanation"
           }
          ]
        }
        **********
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {1, new_server_state} = BlocksBuilder.parse(server_state)

      assert {:error, {:replace, error}} = new_server_state[:claude_ai][:response]

      assert error =~ "Failed to parse JSON."
      assert error =~ "The root element was not \"BLOCKS\""
    end

    test "when the the blocks have keys missing, return error" do
      raw_response =
        """
        Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change:

        **********
        {
         "BLOCKS": [
           {
             "SEARCH": "search",
             "REPLACE": "replace"
           }
          ]
        }
        **********
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {1, new_server_state} = BlocksBuilder.parse(server_state)

      assert {:error, {:replace, error}} = new_server_state[:claude_ai][:response]

      assert error =~ "Failed to parse JSON."
      assert error =~ "At least one of the \"BLOCKS\" was missing a mandatory key."
    end

    test "mid way } don't spuriously count as the end of the JSON" do
      raw_response =
        """
        Based on the provided Elixir Test and Mix Test Output, it's clear that we need to implement the `Fib.sequence/1` function in the Elixir Code file. Here's the proposed change:

        **********
        {
           "BLOCKS": [
             {
               "SEARCH": "search",
               "REPLACE": "replace",
               "EXPLANATION": "explanation"
             }
           ]
         }
         **********
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, _} = BlocksBuilder.parse(server_state)
    end

    test "error case from the terminal" do
      raw_response =
        """
          **********
        {
        "BLOCKS": [
        {
          "SEARCH": "  defp parse_json(json) do
        ",
          "REPLACE": "",
          "EXPLANATION": ""
        },
        {
          "SEARCH": "",
          "REPLACE": "",
          "EXPLANATION": ""
        }
        ]
        }
          **********
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, _} = BlocksBuilder.parse(server_state)
    end

    test "handle newline characters being in the SEARCH body" do
      raw_response =
        """
        pre 1\npre 2
        **********
        {
          "BLOCKS": [
            {
              "SEARCH": "hello\nmother",
              "REPLACE": "",
              "EXPLANATION": ""
            }
          ]
        }
        **********
        post 1
        post 2
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, new_server_state} = BlocksBuilder.parse(server_state)

      assert {:ok, {:replace, %{pre: pre, post: post, blocks: [%{search: search}]}}} =
               new_server_state[:claude_ai][:response]

      assert pre == "pre 1\npre 2"
      assert post == "post 1\npost 2"
      assert search == "hello\nmother"
    end

    test "when there's no pre(amble) but valid JSON, its ok" do
      raw_response =
        """
        **********
        {
          "BLOCKS": [
            {
              "SEARCH": "search",
              "REPLACE": "replace",
              "EXPLANATION": "explanation"
            }
          ]
        }
        **********
        post
        """

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, new_server_state} = BlocksBuilder.parse(server_state)

      assert {:ok,
              {:replace,
               %{
                 pre: pre,
                 post: post,
                 blocks: [%{search: search, replace: replace, explanation: explanation}]
               }}} =
               new_server_state[:claude_ai][:response]

      assert pre == ""
      assert post == "post"
      assert search == "search"
      assert replace == "replace"
      assert explanation == "explanation"
    end

    test "when there's no post(amble) but valid JSON, its ok" do
      raw_response =
        """
        pre
        **********
        {
          "BLOCKS": [
            {
              "SEARCH": "search",
              "REPLACE": "replace",
              "EXPLANATION": "explanation"
            }
          ]
        }
        **********
        """
        |> String.trim_trailing()

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, new_server_state} = BlocksBuilder.parse(server_state)

      assert {:ok,
              {:replace,
               %{
                 pre: pre,
                 post: post,
                 blocks: [%{search: search, replace: replace, explanation: explanation}]
               }}} =
               new_server_state[:claude_ai][:response]

      assert pre == "pre"
      assert post == ""
      assert search == "search"
      assert replace == "replace"
      assert explanation == "explanation"
    end

    test "when *'s are missing, return error" do
      raw_response =
        """
        pre
        {
          "BLOCKS": [
            {
              "SEARCH": "search",
              "REPLACE": "replace",
              "EXPLANATION": "explanation"
            }
          ]
        }
        post
        """
        |> String.trim_trailing()

      response = {:ok, {:parsed, raw_response}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {1, new_server_state} = BlocksBuilder.parse(server_state)

      assert {:error, {:replace, error}} =
               new_server_state[:claude_ai][:response]

      assert error =~ "Failed to decode the Claude response"
      assert error =~ "My regex capture to grab JSON between two lines of asterisks didn't work."
    end

    # TODO check there's a test for *'s missing
  end
end
