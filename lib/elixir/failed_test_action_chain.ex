defmodule PolyglotWatcherV2.Elixir.FailedTestActionChain do
  alias PolyglotWatcherV2.Action

  def build([], _fail_action, next_action) do
    %{{:mix_test_puts, 0} => %Action{runnable: :noop, next_action: next_action}}
  end

  def build(failures, fail_action, next_action) do
    build(%{}, 0, failures, fail_action, next_action)
  end

  defp build(test_actions, index, [{test_path, line_number}], _fail_action, next_action) do
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
