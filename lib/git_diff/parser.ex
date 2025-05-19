defmodule PolyglotWatcherV2.GitDiff.Parser do
  @ansi_sequence "(?:\x1b\[[0-9;]*[a-zA-Z])"
  @line_count_regex ~r|^#{@ansi_sequence}*@@ \-(?<line_number>[0-9]+),(?<line_count>[0-9]+)\s\+[0-9]+,[0-9]+ @@|
  @one_line_regex ~r|^#{@ansi_sequence}*@@ \-(?<line_number>[0-9]+)\s\+[0-9]+ @@|

  @bar_line "────────────────────────"

  def parse(git_diff_output, index) do
    git_diff_output
    |> String.split("\n")
    |> do_parse(false, [], index)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, {:git_diff_parse, :no_hunk_start}} ->
        {:error, {:git_diff_parse, :no_hunk_start}}
    end
  end

  defp do_parse([], false, _acc, _index) do
    {:error, {:git_diff_parse, :no_hunk_start}}
  end

  defp do_parse([""], true, acc, _index) do
    result = ["", @bar_line | acc] |> Enum.reverse() |> Enum.join("\n")
    {:ok, result}
  end

  defp do_parse([], true, acc, _index) do
    result = ["", @bar_line | acc] |> Enum.reverse() |> Enum.join("\n")
    {:ok, result}
  end

  defp do_parse([line | rest], found?, acc, index) do
    case {capture_hunk_line(line), found?} do
      {{:ok, line_number, line_count}, _} ->
        last_line = String.to_integer(line_number) + String.to_integer(line_count) - 1
        lines_line = "#{index}) Lines: #{line_number} - #{last_line}"
        do_parse(rest, true, [@bar_line, lines_line, @bar_line | acc], index)

      {{:ok, line_number}, _} ->
        lines_line = "#{index}) Line: #{line_number}"
        do_parse(rest, true, [@bar_line, lines_line, @bar_line | acc], index)

      {:error, true} ->
        do_parse(rest, true, [String.trim_trailing(line) | acc], index)

      {:error, false} ->
        do_parse(rest, false, acc, index)
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
