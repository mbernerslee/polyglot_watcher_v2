defmodule PolyglotWatcherV2.Elixir.Cache.FixedTests do
  def determine(:all, 0) do
    :all
  end

  def determine(mix_test_args, 0) do
    Enum.reduce_while(test_path_parsers(), nil, fn parser, _acc ->
      case parser.(mix_test_args) do
        nil -> {:cont, nil}
        result -> {:halt, result}
      end
    end)
  end

  def determine(_mix_test_args, _non_zero_exit_code) do
    nil
  end

  # TODO this is brittle if we run `mix test` with different args in future.. maybe sanatise the input to what we can handle & write a doc?
  defp test_path_parsers do
    [
      &test_without_color_parser/1,
      &test_with_colon_then_line_number_parser/1,
      &max_failures_for_file_parser/1,
      &max_failures_all_parser/1
    ]
  end

  defp test_with_colon_then_line_number_parser(mix_test_args) do
    case Regex.named_captures(~r|^(?<test>.*test/.+):(?<line>[0-9]+)$|, mix_test_args) do
      %{"test" => test_path, "line" => line} -> {test_path, String.to_integer(line)}
      _ -> nil
    end
  end

  defp test_without_color_parser(test) do
    case Regex.named_captures(~r|^.*(?<test>test/[^ :]+)$|, test) do
      %{"test" => test_path} -> {test_path, :all}
      _ -> nil
    end
  end

  defp max_failures_for_file_parser(test) do
    case Regex.named_captures(~r|^(?<test>.*test/.+) --max-failures [0-9]+$|, test) do
      %{"test" => test_path} -> {test_path, :all}
      _ -> nil
    end
  end

  defp max_failures_all_parser(test) do
    if Regex.match?(~r|[^test] --max-failures [0-9]+$|, test) do
      :all
    else
      nil
    end
  end
end
