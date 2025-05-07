defmodule PolyglotWatcherV2.Elixir.FailedTestActionChain do
  alias PolyglotWatcherV2.Action

  # TODO delete
  def build(failures, fail_action, next_action, mode \\ :all)

  def build([], _fail_action, next_action, _mode) do
    %{{:mix_test_puts, 0} => %Action{runnable: :noop, next_action: next_action}}
  end

  def build(failures, fail_action, next_action, mode) do
    tests = generate_test_plan(failures)
    build(%{}, 0, tests, fail_action, next_action, mode)
  end

  defp build(test_actions, index, [test], _fail_action, next_action, mode) do
    test_actions
    |> Map.merge(puts(index, test))
    |> Map.merge(mix_test(index, test))
    |> Map.merge(put_elixir_failures_count(index, mode, next_action))
  end

  defp build(test_actions, index, [test | rest], fail_action, next_action, mode) do
    next_index = index + 1

    test_actions =
      test_actions
      |> Map.merge(puts(index, test))
      |> Map.merge(mix_test(index, test))
      |> Map.merge(
        put_elixir_failures_count(index, mode, %{
          0 => {:mix_test_puts, next_index},
          :fallback => fail_action
        })
      )

    build(test_actions, next_index, rest, fail_action, next_action, mode)
  end

  defp generate_test_plan(failures) do
    {first_file, rest} = sort_and_split_by_first_file(failures)

    first_file
    |> first_file_test_plan()
    |> prepend_subsequent_files_test_plan(rest)
    |> Enum.reverse()
  end

  defp prepend_subsequent_files_test_plan(plan, []) do
    plan
  end

  defp prepend_subsequent_files_test_plan(plan, _rest) do
    ["--failed --max-failures 1" | plan]
  end

  defp first_file_test_plan([]) do
    []
  end

  defp first_file_test_plan([{file, line} | _]) do
    ["#{file} --max-failures 1", "#{file}:#{line}"]
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

  defp put_elixir_failures_count(index, mode, next_action) do
    %{
      {:put_elixir_failures_count, index} => %Action{
        runnable: {:put_elixir_failures_count, mode},
        next_action: next_action
      }
    }
  end

  defp mix_test(index, test) do
    %{
      {:mix_test, index} => %Action{
        runnable: {:mix_test, test},
        next_action: {:put_elixir_failures_count, index}
      }
    }
  end
end
