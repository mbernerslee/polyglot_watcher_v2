defmodule PolyglotWatcherV2.Elixir.Failures do
  alias PolyglotWatcherV2.Elixir.FailureMerger

  def update(_failures, :all, _mix_test_output, _exit_code = 0) do
    []
  end

  def update(failures, test_path, _mix_test_output, _exit_code = 0) do
    {test_path, line_number} = parse_test_path(test_path)

    Enum.reject(failures, fn {failure_test_path, failure_test_line_number} ->
      (failure_test_path == test_path || test_path == :all) &&
        (failure_test_line_number == line_number || line_number == :all)
    end)
  end

  def update(_failures, :all, mix_test_output, _exit_code) do
    accumulate_failing_tests(mix_test_output)
  end

  def update(failures, _test_path, mix_test_output, _exit_code) do
    new_failures = accumulate_failing_tests(mix_test_output)

    FailureMerger.merge(failures, new_failures)
  end

  # TODO delete
  def for_file(failures, file_path) do
    Enum.filter(failures, &is_file_path?(&1, file_path))
  end

  def count(failures, :all) do
    Enum.count(failures)
  end

  def count(failures, file_path) do
    Enum.count(failures, &is_file_path?(&1, file_path))
  end

  def count_message(0), do: wrap_in_dashes({[:green, :italic], "0 failing tests remain!"})
  def count_message(1), do: wrap_in_dashes({[:cyan, :italic], "1 failing test remains"})

  def count_message(count) do
    wrap_in_dashes({[:cyan, :italic], "#{count} failing tests remain"})
  end

  defp wrap_in_dashes({styles, message}) do
    [
      {styles, "--------------------------------------"},
      {styles, " #{message} "},
      {styles, "--------------------------------------"}
    ]
  end

  defp is_file_path?({file_path, _}, file_path), do: true
  defp is_file_path?(_, _), do: false

  defp test_path_parsers do
    [
      &test_without_color_parser/1,
      &test_with_colon_then_line_number_parser/1,
      &max_failures_for_file_parser/1,
      &max_failures_all_parser/1
    ]
  end

  defp parse_test_path(test_path) do
    Enum.reduce_while(test_path_parsers(), nil, fn parser, _acc ->
      case parser.(test_path) do
        {:ok, result} -> {:halt, result}
        _ -> {:cont, nil}
      end
    end)
  end

  defp test_without_color_parser(test) do
    case Regex.named_captures(~r|^.*(?<test>test/[^ :]+)$|, test) do
      %{"test" => test_path} ->
        {:ok, {test_path, :all}}

      _ ->
        :error
    end
  end

  defp max_failures_for_file_parser(test) do
    case Regex.named_captures(~r|^.*(?<test>test/.+) --max-failures [0-9]+$|, test) do
      %{"test" => test_path} ->
        {:ok, {test_path, :all}}

      _ ->
        :error
    end
  end

  defp max_failures_all_parser(test) do
    if Regex.match?(~r|[^test] --max-failures [0-9]+$|, test) do
      {:ok, {:all, :all}}
    else
      :error
    end
  end

  defp test_with_colon_then_line_number_parser(test) do
    case Regex.named_captures(~r|^.*(?<test>test/.+):(?<line>[0-9]+).*|, test) do
      %{"test" => test_path, "line" => line} ->
        {:ok, {test_path, String.to_integer(line)}}

      _ ->
        :error
    end
  end

  defp accumulate_failing_tests(mix_test_output) do
    mix_test_output = String.split(mix_test_output, "\n")
    accumulate_failing_tests([], nil, mix_test_output)
  end

  defp accumulate_failing_tests(acc, _, []), do: acc

  defp accumulate_failing_tests(acc, :add_next_line, [line | rest]) do
    acc =
      case test_with_colon_then_line_number_parser(line) do
        {:ok, {test_path, line_number}} ->
          [{test_path, line_number} | acc]

        _ ->
          acc
      end

    accumulate_failing_tests(acc, nil, rest)
  end

  defp accumulate_failing_tests(acc, nil, [line | rest]) do
    if Regex.match?(~r|^\s+[0-9]+\)\stest|, line) do
      accumulate_failing_tests(acc, :add_next_line, rest)
    else
      accumulate_failing_tests(acc, nil, rest)
    end
  end
end
