defmodule PolyglotWatcherV2.GitDiff.Parser do
  @ansi_sequence "(?:\x1b\[[0-9;]*[a-zA-Z])"
  @line_count_regex ~r|^#{@ansi_sequence}*@@ \-(?<line_number>[0-9]+),(?<line_count>[0-9]+)\s\+[0-9]+,[0-9]+ @@|
  @one_line_regex ~r|^#{@ansi_sequence}*@@ \-(?<line_number>[0-9]+)\s\+[0-9]+ @@|

  @bar_line "────────────────────────"

  def parse(git_diff_output) do
    git_diff_output
    |> String.split("\n")
    |> do_parse(false, [])
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, {:git_diff_parse, :no_hunk_start}} ->
        {:error, {:git_diff_parse, :no_hunk_start}}
    end
  end

  defp do_parse([], false, _acc) do
    {:error, {:git_diff_parse, :no_hunk_start}}
  end

  defp do_parse([""], true, acc) do
    result = ["", @bar_line | acc] |> Enum.reverse() |> Enum.join("\n")
    {:ok, result}
  end

  defp do_parse([], true, acc) do
    result = ["", @bar_line | acc] |> Enum.reverse() |> Enum.join("\n")
    {:ok, result}
  end

  defp do_parse([line | rest], found?, acc) do
    case {capture_hunk_line(line), found?} do
      {{:ok, line_number, line_count}, _} ->
        last_line = String.to_integer(line_number) + String.to_integer(line_count) - 1
        lines_line = "Lines: #{line_number} - #{last_line}"
        do_parse(rest, true, [@bar_line, lines_line, @bar_line | acc])

      {{:ok, line_number}, _} ->
        lines_line = "Line: #{line_number}"
        do_parse(rest, true, [@bar_line, lines_line, @bar_line | acc])

      {:error, true} ->
        do_parse(rest, true, [String.trim_trailing(line) | acc])

      {:error, false} ->
        do_parse(rest, false, acc)
    end
  end

  defp capture_hunk_line(line) do
    Enum.reduce_while([@line_count_regex, @one_line_regex], :error, fn regex, _ ->
      case Regex.named_captures(regex, line, capture: :all_but_first) do
        %{"line_number" => line_number, "line_count" => line_count} ->
          {:halt, {:ok, line_number, line_count}}

        %{"line_number" => line_number} ->
          {:halt, {:ok, line_number}}

        _ ->
          {:cont, :error}
      end
    end)
  end
end
