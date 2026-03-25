defmodule PolyglotWatcherV2.Elixir.MixTestOutputTruncator do
  @moduledoc """
  Truncates mix test output before returning it via MCP to save context window tokens.

  MCP tool responses aren't automatically truncated like shell output, so large test
  failures (e.g. 10 failures each dumping a full Ecto struct) can consume thousands
  of tokens. This module splits output by double-newline (which separates individual
  test failures) and keeps as many complete failure blocks as fit within the line limit,
  always preserving the first block (seed/header) and last block (summary).
  """

  @max_lines 100

  def truncate(text) do
    if line_count(text) <= @max_lines do
      text
    else
      blocks = String.split(text, "\n\n")
      first_block = List.first(blocks)
      last_block = List.last(blocks)
      middle_blocks = blocks |> Enum.drop(1) |> Enum.drop(-1)
      reserved_lines = line_count(first_block) + line_count(last_block)

      {kept, _total_lines} =
        Enum.reduce_while(middle_blocks, {[], reserved_lines}, fn block, {acc, lines_so_far} ->
          new_total = lines_so_far + line_count(block)

          if new_total <= @max_lines do
            {:cont, {acc ++ [block], new_total}}
          else
            {:halt, {acc, lines_so_far}}
          end
        end)

      omitted_count = length(middle_blocks) - length(kept)
      total_failures = parse_failure_count(last_block)
      kept_failures = Enum.count(kept, &failure_block?/1)

      truncation_msg =
        case total_failures do
          n when is_integer(n) and n > kept_failures ->
            "... (#{n} tests failed, showing #{kept_failures} failure outputs) ..."

          _ ->
            "... (#{omitted_count} blocks omitted) ..."
        end

      ([first_block] ++ kept ++ [truncation_msg, last_block])
      |> Enum.join("\n\n")
    end
  end

  defp line_count(text), do: text |> String.split("\n") |> length()

  defp failure_block?(block), do: Regex.match?(~r/^\s+\d+\) test /, block)

  defp parse_failure_count(block) do
    case Regex.run(~r/(\d+) failures?/, block) do
      [_, count] -> String.to_integer(count)
      _ -> nil
    end
  end
end
