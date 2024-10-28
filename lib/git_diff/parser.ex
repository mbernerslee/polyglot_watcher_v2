defmodule PolyglotWatcherV2.GitDiff.Parser do
  # TODO write tests at this level
  # TODO what if multple hunks? parse many? write tests for that??

  @line_count_regex ~r|@@ \-(?<line_number>[0-9]+),(?<line_count>[0-9]+)\s\+[0-9]+,[0-9]+ @@|
  @one_line_regex ~r|@@ \-(?<line_number>[0-9]+)\s\+[0-9]+ @@|

  @bar_line "────────────────────────"

  def parse(git_diff_output) do
    git_diff_output
    |> String.split("\n")
    |> do_parse(false, [])
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, :no_hunk_start} ->
        {:error, no_hunk_start_error(git_diff_output)}
    end
  end

  defp do_parse([], false, _acc) do
    {:error, :no_hunk_start}
  end

  defp do_parse([""], true, acc) do
    result = ["", @bar_line | acc] |> Enum.reverse() |> Enum.join("\n")
    {:ok, result}
  end

  defp do_parse([], true, acc) do
    result = ["", @bar_line | acc] |> Enum.reverse() |> Enum.join("\n")
    {:ok, result}
  end

  defp do_parse([line | rest], true, acc) do
    do_parse(rest, true, [line | acc])
  end

  defp do_parse([line | rest], false, acc) do
    case capture_hunk_line(line) do
      {:ok, line_number, line_count} ->
        last_line = String.to_integer(line_number) + String.to_integer(line_count) - 1
        lines_line = "Lines: #{line_number} - #{last_line}"
        do_parse(rest, true, [@bar_line, lines_line, @bar_line | acc])

      {:ok, line_number} ->
        lines_line = "Line: #{line_number}"
        do_parse(rest, true, [@bar_line, lines_line, @bar_line | acc])

      :error ->
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

  defp no_hunk_start_error(raw) do
    """
    I failed to find the start of a hunk in the format:
    @@ -1,5 +1,5 @@

    The raw output from git diff was:
    #{raw}

    This is terminal to the Claude AI operation I'm afraid so I'm giving up.
    """
  end
end
