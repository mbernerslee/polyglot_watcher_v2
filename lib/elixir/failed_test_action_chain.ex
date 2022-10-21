defmodule PolyglotWatcherV2.Elixir.FailedTestActionChain do
  alias PolyglotWatcherV2.Action

  def build([], _fail_action, next_action) do
    %{{:mix_test_puts, 0} => %Action{runnable: :noop, next_action: next_action}}
  end

  def build(failures, fail_action, next_action) do
    tests = generate_test_plan(failures)
    build(%{}, 0, tests, fail_action, next_action)
  end

  defp build(test_actions, index, [test], _fail_action, next_action) do
    test_actions
    |> Map.merge(puts(index, test))
    |> Map.merge(mix_test(index, test, next_action))
  end

  defp build(test_actions, index, [test | rest], fail_action, next_action) do
    next_index = index + 1

    test_actions =
      test_actions
      |> Map.merge(puts(index, test))
      |> Map.merge(
        mix_test(index, test, %{
          0 => {:mix_test_puts, next_index},
          :fallback => fail_action
        })
      )

    build(test_actions, next_index, rest, fail_action, next_action)
  end

  defp generate_test_plan(failures) do
    {first_file, rest} = sort_and_split_by_first_file(failures)

    first_file_test_plan(first_file) ++ subsequent_files_test_plan(rest)
  end

  defp subsequent_files_test_plan([]), do: []
  defp subsequent_files_test_plan([{file, _line}]), do: [file]

  defp subsequent_files_test_plan(failures) do
    failures = Enum.map(failures, fn {file, _line} -> file end)

    0
    |> subsequent_files_test_plan(Enum.count(failures), failures, [])
    |> Enum.reverse()
  end

  defp subsequent_files_test_plan(batch_number, max, rest, plan) do
    batch_size = trunc(:math.pow(2, batch_number))

    if batch_size >= max do
      plan
    else
      {batch, rest} = Enum.split(rest, batch_size)
      plan = [Enum.join(batch, " ") | plan]
      subsequent_files_test_plan(batch_number + 1, max, rest, plan)
    end
  end

  defp first_file_test_plan([]) do
    []
  end

  defp first_file_test_plan([{file, _line}]) do
    [file]
  end

  defp first_file_test_plan([{file, line} | _] = failures) do
    failures_count = Enum.count(failures)

    first_file_test_plan(failures_count, file, line)
  end

  defp first_file_test_plan(1, file, _line) do
    [file]
  end

  defp first_file_test_plan(failures_count, file, line) do
    IO.inspect(failures_count)
    IO.inspect(file)

    1..(failures_count - 1)
    |> Enum.reduce_while(["#{file}:#{line}"], fn count, acc ->
      max_cases = trunc(:math.pow(2, count))

      IO.inspect({failures_count, max_cases})

      if failures_count <= max_cases do
        {:halt, [file | acc]}
      else
        {:cont, ["#{file} --failed --max-cases #{max_cases} --max-failures 1" | acc]}
      end
    end)
    |> Enum.reverse()
  end

  defp sort_and_split_by_first_file([]) do
    {[], []}
  end

  defp sort_and_split_by_first_file([{first_file, _} | _] = failures) do
    failures
    |> Enum.sort(fn
      {^first_file, _}, {_file_2, _} ->
        true

      {_file_1, _}, {^first_file, _} ->
        false

      {file_1, _}, {file_2, _} ->
        file_1 <= file_2
    end)
    |> Enum.split_with(fn {file, _line} -> file == first_file end)
  end

  defp puts(index, test) do
    %{
      {:mix_test_puts, index} => %Action{
        runnable: {:puts, :magenta, "Running mix test #{test}"},
        next_action: {:mix_test, index}
      }
    }
  end

  defp mix_test(index, test, next_action) do
    %{
      {:mix_test, index} => %Action{
        runnable: {:mix_test, test},
        next_action: next_action
      }
    }
  end
end
