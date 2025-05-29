defmodule PolyglotWatcherV2.GitDiff.Parser do
  @ansi_sequence "(?:\x1b\[[0-9;]*[a-zA-Z])"
  @line_count_regex ~r|^#{@ansi_sequence}*@@ \-(?<line_number>[0-9]+),(?<line_count>[0-9]+)\s\+[0-9]+,[0-9]+ @@|
  @one_line_regex ~r|^#{@ansi_sequence}*@@ \-(?<line_number>[0-9]+)\s\+[0-9]+ @@|

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
    result =
      acc
      |> Enum.map(fn hunk ->
        %{hunk | diff: ["" | hunk.diff] |> Enum.reverse() |> Enum.join("\n")}
      end)
      |> Enum.reverse()

    {:ok, result}
  end

  defp do_parse([], true, acc, _index) do
    result =
      acc
      |> Enum.map(fn hunk ->
        %{hunk | diff: ["" | hunk.diff] |> Enum.reverse() |> Enum.join("\n")}
      end)
      |> Enum.reverse()

    {:ok, result}
  end

  defp do_parse([line | rest], found?, acc, index) do
    case {capture_hunk_line(line), found?} do
      {{:ok, start_line, line_count}, _} ->
        last_line = start_line + line_count - 1
        hunk = %{start_line: start_line, end_line: last_line, diff: []}
        do_parse(rest, true, [hunk | acc], index)

      {{:ok, start_line}, _} ->
        hunk = %{start_line: start_line, end_line: start_line, diff: []}
        do_parse(rest, true, [hunk | acc], index)

      {:error, true} ->
        [%{diff: diff} = hunk | acc_rest] = acc
        hunk = %{hunk | diff: [String.trim_trailing(line) | diff]}
        acc = [hunk | acc_rest]
        do_parse(rest, true, acc, index)

      {:error, false} ->
        do_parse(rest, false, acc, index)
    end
  end

  defp capture_hunk_line(line) do
    Enum.reduce_while([@line_count_regex, @one_line_regex], :error, fn regex, _ ->
      case Regex.named_captures(regex, line, capture: :all_but_first) do
        %{"line_number" => line_number, "line_count" => line_count} ->
          {:halt, {:ok, String.to_integer(line_number), String.to_integer(line_count)}}

        %{"line_number" => line_number} ->
          {:halt, {:ok, String.to_integer(line_number)}}

        _ ->
          {:cont, :error}
      end
    end)
  end
end
