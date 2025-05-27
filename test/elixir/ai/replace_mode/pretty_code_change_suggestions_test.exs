defmodule PolyglotWatcherV2.Elixir.AI.ReplaceMode.PrettyCodeChangeSuggestionsTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.AI.ReplaceMode.PrettyCodeChangeSuggestions

  describe "generate/1" do
    test "given some suggestions, returns a pretty string" do
      input = [
        %{
          index: 1,
          path: "lib/fib.ex",
          git_diff: [
            %{
              diff: """
                defmodule Fib do
                 - def sequence(0), do: [0]
                 + def sequence(0), do: []
                   def sequence(1), do: [-1]
              """,
              start_line: 1,
              end_line: 5
            }
          ],
          explanation: "Fixed the case for 0 items to return empty list"
        },
        %{
          index: 2,
          path: "lib/fib.ex",
          git_diff: [
            %{
              diff: """
                defmodule Fib do
                  def sequence(0), do: [0]
                -  def sequence(1), do: [-1]
                +  def sequence(1), do: [1]

                  def sequence(n) when n > 1 do
                    Enum.reduce(3..n, [2, 1], fn _, [a, b | _] = acc ->
              """,
              start_line: 1,
              end_line: 6
            }
          ],
          explanation: "Fixed the base case for 1 to return [1] instead of [-1]."
        },
        %{
          index: 3,
          path: "lib/string_fun.ex",
          git_diff: [
            %{
              diff: """
                defmodule X do
                  def cool(0), do: "zero"
                -  def cool(1), do: "fail"
                +  def cool(1), do: "one"

              """,
              start_line: 11,
              end_line: 16
            },
            %{
              diff: """
                  def yikes, do: "yikes"
                -  def yikes(1), do: "yikes fail"
                +  def yikes(1), do: "yikes one"

              """,
              start_line: 21,
              end_line: 23
            }
          ],
          explanation: "stop failing"
        }
      ]

      output =
        """
        ────────────────────────────────────────────────────────────
        🤖 AI Suggestions
        ────────────────────────────────────────────────────────────

        1) 📁 lib/fib.ex

        Lines 1 - 5
          defmodule Fib do
           - def sequence(0), do: [0]
           + def sequence(0), do: []
             def sequence(1), do: [-1]

        🔎 Fixed the case for 0 items to return empty list

        ────────────────────────────────────────────────────────────

        2) 📁 lib/fib.ex

        Lines 1 - 6
          defmodule Fib do
            def sequence(0), do: [0]
          -  def sequence(1), do: [-1]
          +  def sequence(1), do: [1]

            def sequence(n) when n > 1 do
              Enum.reduce(3..n, [2, 1], fn _, [a, b | _] = acc ->

        🔎 Fixed the base case for 1 to return [1] instead of [-1].

        ────────────────────────────────────────────────────────────

        3) 📁 lib/string_fun.ex

        Lines 11 - 16
          defmodule X do
            def cool(0), do: "zero"
          -  def cool(1), do: "fail"
          +  def cool(1), do: "one"

        Lines 21 - 23
            def yikes, do: "yikes"
          -  def yikes(1), do: "yikes fail"
          +  def yikes(1), do: "yikes one"

        🔎 stop failing

        ────────────────────────────────────────────────────────────
        🎯 Choose your action:
           y          Apply all suggestions
           n          Skip all suggestions
           1,2,3      Apply specific suggestions (comma-separated)
        ────────────────────────────────────────────────────────────
        """

      assert output ==
               input |> PrettyCodeChangeSuggestions.generate() |> remove_ansi_escape_sequences()
    end
  end

  defp remove_ansi_escape_sequences(text) do
    Regex.replace(~r/\e\[[0-9;]*[a-zA-Z]/, text, "")
  end
end
