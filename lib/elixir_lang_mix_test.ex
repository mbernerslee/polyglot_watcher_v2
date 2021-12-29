defmodule PolyglotWatcherV2.ElixirLangMixTest do
  def update_failures(_failures, :all, _mix_test_output, _exit_code = 0) do
    []
  end

  def update_failures(failures, test_path, _mix_test_output, _exit_code = 0) do
    {test_path, line_number} = parse_test_path(test_path)

    Enum.reject(failures, fn {failure_test_path, failure_test_line_number} ->
      failure_test_path == test_path &&
        (failure_test_line_number == line_number || line_number == :all)
    end)
  end

  def update_failures(_failures, :all, mix_test_output, _exit_code) do
    accumulate_failing_tests(mix_test_output)
  end

  def update_failures(failures, _test_path, mix_test_output, _exit_code) do
    new_failures = accumulate_failing_tests(mix_test_output)

    add_new_failures(failures, new_failures)
  end

  def failures_for_file(failures, file_path) do
    Enum.filter(failures, fn {path, _} -> path == file_path end)
  end

  defp parse_test_path(test_path) do
    case String.split(test_path, ":") do
      [test_path] -> {test_path, :all}
      [test_path, line_number] -> {test_path, String.to_integer(line_number)}
    end
  end

  defp add_new_failures(failures, new_failures) do
    new_failures
    |> Enum.reverse()
    |> Enum.reduce(failures, fn new_failure, acc ->
      if Enum.member?(acc, new_failure) do
        acc
      else
        [new_failure | acc]
      end
    end)
  end

  defp accumulate_failing_tests(mix_test_output) do
    mix_test_output = String.split(mix_test_output, "\n")
    accumulate_failing_tests([], nil, mix_test_output)
  end

  defp accumulate_failing_tests(acc, _, []), do: acc

  defp accumulate_failing_tests(acc, :add_next_line, [line | rest]) do
    acc =
      case Regex.named_captures(~r|^.*(?<test>test/.+):(?<line>[0-9]+).*|, line) do
        %{"test" => test_path, "line" => line} ->
          [{test_path, String.to_integer(line)} | acc]

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
