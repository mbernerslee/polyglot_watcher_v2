defmodule PolyglotWatcherV2.Elixir.FailedTestActionChain do
  alias PolyglotWatcherV2.Action

  def build([], _fail_action, next_action) do
    %{{:mix_test_puts, 0} => %Action{runnable: :noop, next_action: next_action}}
  end

  def build([{first_file, _} | _] = failures, fail_action, next_action) do
    failures = generate_test_plan(failures)
    build({%{}, first_file}, 0, failures, fail_action, next_action)
  end

  defp build({test_actions, _}, index, [{test_path, line_number}], _fail_action, next_action) do
    test_actions
    |> Map.merge(puts(index, test_path, line_number))
    |> Map.merge(mix_test(index, test_path, line_number, next_action))
  end

  defp build(test_actions, index, [{test_path, line_number} | rest], fail_action, next_action) do
    next_index = index + 1

    test_actions =
      test_actions
      |> Map.merge(puts(index, test_path, line_number))
      |> Map.merge(
        mix_test(index, test_path, line_number, %{
          0 => {:mix_test_puts, next_index},
          :fallback => fail_action
        })
      )

    build(test_actions, next_index, rest, fail_action, next_action)
  end

  defp generate_test_plan([]) do
    []
  end

  defp generate_test_plan([first | rest] = failures) do
    sorted_failures = sort_by_first(first, rest)

    generate_first_file_test_plan(first, sorted_failures)

    raise "oops"
  end

  defp generate_first_file_test_plan({file, line}, sorted_failures) do
    count = Enum.count(sorted_failures, fn {this_file, _} -> this_file == file end)

    case count do
      1 -> ["#{file}:#{line_number}"]
      _ -> ["#{file}:#{line_number}" | do_generate_first_file_test_plan(count - 1, file)]
    end
  end

  defp do_generate_first_file_test_plan(count, file) do
    do_generate_first_file_test_plan([], count, file)
  end

  defp do_generate_first_file_test_plan(count, file) do
  end

  defp sort_by_first({first_file, _} = first, rest) do
    Enum.sort([first | rest], fn
      {^first_file, _}, {_file_2, _} ->
        true

      {_file_1, _}, {^first_file, _} ->
        false

      {file_1, _}, {file_2, _} ->
        file_1 <= file_2
    end)
  end

  defp puts(index, test_path, line_number) do
    %{
      {:mix_test_puts, index} => %Action{
        runnable: {:puts, :magenta, "Running mix test #{test_path}:#{line_number}"},
        next_action: {:mix_test, index}
      }
    }
  end

  defp mix_test(index, test_path, line_number, next_action) do
    %{
      {:mix_test, index} => %Action{
        runnable: {:mix_test, "#{test_path}:#{line_number}"},
        next_action: next_action
      }
    }
  end
end
