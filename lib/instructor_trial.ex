defmodule PolyglotWatcherV2.CodeFileUpdate do
  use Ecto.Schema
  use InstructorLite.Instruction

  @primary_key false
  embedded_schema do
    field(:file_path, :string)
    field(:explanation, :string)
    field(:search, :string)
    field(:replace, :string)
  end
end

defmodule PolyglotWatcherV2.CodeFileUpdates do
  use Ecto.Schema
  use InstructorLite.Instruction

  alias PolyglotWatcherV2.CodeFileUpdate

  @primary_key false
  embedded_schema do
    embeds_many(:updates, CodeFileUpdate)
  end
end

defmodule InstructorTrial do
  def run do
    InstructorLite.instruct(
      %{
        messages: [
          %{role: "user", content: prompt()}
        ]
      },
      response_model: PolyglotWatcherV2.CodeFileUpdates,
      adapter: InstructorLite.Adapters.Anthropic,
      adapter_context: [api_key: System.get_env("ANTHROPIC_API_KEY")]
    )
  end

  defp prompt do
    """
    Given the following -

    Test file:
    #{inspect(test_file(), pretty: true)}

    Lib file:
    #{inspect(lib_file(), pretty: true)}

    Mix Test Output:
    #{inspect(mix_test_output(), pretty: true)}

    Can you please provide a list of updates to fix the issues?
    """
  end

  defp test_file do
    #    contents =
    #      """
    #      defmodule FibTest do
    #        use ExUnit.Case
    #        doctest Fib
    #
    #        # 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89,144,233,377,610,987, 1597, 2584, 4181
    #
    #        test "can generate 0 items of the Fibonacci sequence" do
    #          assert Fib.sequence(0) == []
    #        end
    #
    #        test "can generate 1 item of the Fibonacci sequence" do
    #          assert Fib.sequence(1) == [1]
    #        end
    #
    #        test "can generate 2 items of the Fibonacci sequence" do
    #          assert Fib.sequence(2) == [1, 1]
    #        end
    #
    #        test "can generate many items of the Fibonacci sequence" do
    #          assert Fib.sequence(3) == [1, 1, 2]
    #          assert Fib.sequence(4) == [1, 1, 2, 3]
    #          assert Fib.sequence(5) == [1, 1, 2, 3, 5]
    #          assert Fib.sequence(6) == [1, 1, 2, 3, 5, 8]
    #          assert Fib.sequence(7) == [1, 1, 2, 3, 5, 8, 13]
    #
    #          assert Fib.sequence(19) == [
    #                   1,
    #                   1,
    #                   2,
    #                   3,
    #                   5,
    #                   8,
    #                   13,
    #                   21,
    #                   34,
    #                   55,
    #                   89,
    #                   144,
    #                   233,
    #                   377,
    #                   610,
    #                   987,
    #                   1597,
    #                   2584,
    #                   4181
    #                 ]
    #          end
    #      end
    #      """

    path = "../fib/test/fib_test.exs"
    %{path: path, contents: File.read!(path)}
  end

  defp lib_file do
    # contents =
    #  """
    #  defmodule Fib do
    #    def sequence(0), do: [0]
    #    def sequence(1), do: []
    #    def sequence(2), do: [1, 2]

    #    def sequence(n) when n > 2 do
    #    Enum.reduce(3..n, [1, 2], fn _, [a, b | _] = acc ->
    #      [a + b | acc]
    #    end)
    #    |> Enum.reverse()
    #    end
    #  end
    #  """

    path = "../fib/lib/fib.ex"
    %{path: path, contents: File.read!(path)}
  end

  defp mix_test_output do
    """
      1) test can generate 1 item of the Fibonacci sequence (FibTest)
         test/fib_test.exs:11
         Assertion with == failed
         code:  assert Fib.sequence(1) == [1]
         left:  []
         right: [1]
         stacktrace:
           test/fib_test.exs:12: (test)



      2) test can generate 0 items of the Fibonacci sequence (FibTest)
         test/fib_test.exs:7
         Assertion with == failed
         code:  assert Fib.sequence(0) == []
         left:  [0]
         right: []
         stacktrace:
           test/fib_test.exs:8: (test)



      3) test can generate many items of the Fibonacci sequence (FibTest)
         test/fib_test.exs:19
         Assertion with == failed
         code:  assert Fib.sequence(3) == [1, 1, 2]
         left:  [2, 1, 3]
         right: [1, 1, 2]
         stacktrace:
           test/fib_test.exs:20: (test)



      4) test can generate 2 items of the Fibonacci sequence (FibTest)
         test/fib_test.exs:15
         Assertion with == failed
         code:  assert Fib.sequence(2) == [1, 1]
         left:  [1, 2]
         right: [1, 1]
         stacktrace:
           test/fib_test.exs:16: (test)

    """
  end

  defp response do
    # the response "run" gave
    {:ok,
     %PolyglotWatcherV2.CodeFileUpdates{
       updates: [
         %PolyglotWatcherV2.CodeFileUpdate{
           file_path: "../fib/lib/fib.ex",
           explanation:
             "Fixed the base cases for 0, 1, and 2 items in the sequence. Also updated the initial accumulator in the reduce function to start with [1, 1] instead of [1, 2].",
           search:
             "def sequence(0), do: [0]\n  def sequence(1), do: []\n  def sequence(2), do: [1, 2]\n\n  def sequence(n) when n > 2 do\n    Enum.reduce(3..n, [1, 2], fn _, [a, b | _] = acc ->\n      [a + b | acc]\n    end)\n    |> Enum.reverse()\n  end",
           replace:
             "def sequence(0), do: []\n  def sequence(1), do: [1]\n  def sequence(2), do: [1, 1]\n\n  def sequence(n) when n > 2 do\n    Enum.reduce(3..n, [1, 1], fn _, [a, b | _] = acc ->\n      [a + b | acc]\n    end)\n    |> Enum.reverse()\n  end"
         }
       ]
     }}
  end

  def check do
    {:ok, %{updates: [update]}} = response()

    %{file_path: file_path, explanation: _explanation, search: search, replace: replace} = update

    %{path: path, contents: contents} = lib_file()

    (path == file_path) |> IO.inspect()

    String.contains?(contents, search)
    |> IO.inspect()

    PolyglotWatcherV2.GitDiff.run(file_path, search, replace, %{})
    |> IO.inspect()

    # the response it actually gave fixed the tests with the search / replace
  end
end
