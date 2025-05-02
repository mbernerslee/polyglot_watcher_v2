defmodule PolyglotWatcherV2.Elixir.Cache.MixTestOutputParser do
  def run(mix_test_output) do
    lines =
      mix_test_output
      |> String.split("\n")
      |> Enum.reverse()

    %{tests: %{}, path: nil, unclaimed_lines: [], rank: 1}
    |> run(lines)
    |> format_result()
  end

  defp format_result(%{tests: tests}) do
    Map.new(tests, fn {path, %{rank: rank, raw: raw, failure_line_numbers: failure_line_numbers}} ->
      raw = Enum.join(raw, "\n")
      failure_line_numbers = Enum.reverse(failure_line_numbers)
      {path, %{rank: rank, raw: raw, failure_line_numbers: failure_line_numbers}}
    end)
  end

  defp run(%{path: path} = acc, [line, next | rest]) do
    case {path, test_with_colon_then_line_number_parser(line)} do
      {path, {path, n}} ->
        %{unclaimed_lines: unclaimed_lines} = acc

        acc
        |> update_in([:tests, path, :raw], fn lines -> unclaimed_lines ++ lines end)
        |> update_in([:tests, path, :raw], fn lines -> [next, line | lines] end)
        |> update_in([:tests, path, :failure_line_numbers], fn fails -> [n | fails] end)
        |> Map.put(:unclaimed_lines, [])
        |> run(rest)

      {_old_path, {path, n}} ->
        %{unclaimed_lines: unclaimed_lines, rank: rank} = acc

        test = %{rank: rank, raw: [next, line | unclaimed_lines], failure_line_numbers: [n]}

        acc
        |> put_in([:tests, path], test)
        |> Map.put(:path, path)
        |> Map.put(:rank, rank + 1)
        |> Map.put(:unclaimed_lines, [])
        |> run(rest)

      {_path, nil} ->
        acc
        |> update_in([:unclaimed_lines], fn unclaimed_lines -> [line | unclaimed_lines] end)
        |> run([next | rest])
    end
  end

  defp run(acc, _) do
    acc
  end

  defp test_with_colon_then_line_number_parser(test) do
    case Regex.named_captures(~r|^(?<test>.*test/.+):(?<line>[0-9]+)$|, test) do
      %{"test" => path, "line" => line} ->
        {String.trim(path), String.to_integer(line)}

      _ ->
        nil
    end
  end
end
