defmodule PolyglotWatcherV2.Elixir.Cache.TestFileASTParser do
  @moduledoc """
  This is wild stuff.
  ClaudeAI wrote this code.
  Credit to any humans who could write AST parsing code.
  I'm not one of them.
  Read the tests to get a better idea of what this is doing
  """

  def run(string) do
    case Code.string_to_quoted(string) do
      {:ok, ast} -> parse(ast)
      _ -> %{}
    end
  end

  def parse(ast) do
    case ast do
      {:__block__, _, modules} ->
        Enum.reduce(modules, %{}, fn module, acc ->
          case module do
            {:defmodule, _, [_, [do: block]]} ->
              Map.merge(acc, parse(block, nil, %{}))

            _ ->
              acc
          end
        end)

      {:defmodule, _, [_, [do: block]]} ->
        parse(block, nil, %{})

      _ ->
        %{}
    end
  end

  defp parse(
         {:__block__, _, expressions},
         describe_name,
         acc
       ) do
    Enum.reduce(expressions, acc, fn expr, tests ->
      parse(expr, describe_name, tests)
    end)
  end

  defp parse(
         {:describe, _, [describe_name, [do: block]]},
         _current_describe,
         acc
       ) do
    parse(block, describe_name, acc)
  end

  defp parse(
         {:test, meta, [test_name, _options, _block]},
         describe_name,
         acc
       ) do
    line_number = Keyword.get(meta, :line)
    test_key = format_test_key(describe_name, test_name)
    Map.put(acc, test_key, line_number)
  end

  defp parse(
         {:test, meta, [test_name, [do: _block]]},
         describe_name,
         acc
       ) do
    line_number = Keyword.get(meta, :line)
    test_key = format_test_key(describe_name, test_name)
    Map.put(acc, test_key, line_number)
  end

  # Catch-all for any other AST nodes with potential children
  defp parse(node, describe_name, acc)
       when is_tuple(node) do
    case Tuple.to_list(node) do
      [_head | rest] when is_list(rest) ->
        Enum.reduce(rest, acc, fn elem, tests ->
          if is_tuple(elem) or is_list(elem) do
            parse(elem, describe_name, tests)
          else
            tests
          end
        end)

      _ ->
        acc
    end
  end

  defp parse(nodes, describe_name, acc)
       when is_list(nodes) do
    Enum.reduce(nodes, acc, fn node, tests ->
      parse(node, describe_name, tests)
    end)
  end

  defp parse(_, _describe_name, acc) do
    acc
  end

  defp format_test_key(nil, test_name) do
    :"test #{test_name}"
  end

  defp format_test_key(describe_name, test_name) do
    :"test #{describe_name} #{test_name}"
  end
end
