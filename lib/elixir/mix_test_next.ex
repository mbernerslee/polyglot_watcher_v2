defmodule PolyglotWatcherV2.Elixir.MixTestNext do
  @moduledoc """
  Finds the next failing test in the Cache and runs it.

  Designed to be run recursively to fix all failing tests

  `mix test` exit codes:
    0 -> tests passed
    1 -> error (e.g. test file does not exist)
    2 -> tests failed
  """
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.ActionsExecutor

  def run(test_path, server_state) do
    test_path
    |> get_next_from_cache(server_state)
    |> run_mix_test()
  end

  defp run_mix_test({:ok, {test_path, line_number, server_state}}) do
    mix_test_args = "#{test_path}:#{line_number}"
    ActionsExecutor.execute({:puts, :magenta, "Running mix test #{mix_test_args}"}, server_state)

    case ActionsExecutor.execute({:mix_test, mix_test_args}, server_state) do
      {0, server_state} ->
        ActionsExecutor.execute(:put_sarcastic_success, server_state)
        {{:mix_test, :passed}, server_state}

      {2, server_state} ->
        ActionsExecutor.execute(:put_insult, server_state)
        {{:mix_test, :failed}, server_state}

      {_, server_state} ->
        {{:mix_test, :error}, server_state}
    end
  end

  defp run_mix_test(error) do
    error
  end

  defp get_next_from_cache(test_path, server_state) do
    case Cache.get(test_path) do
      {:ok, {test_path, line_number}} -> {:ok, {test_path, line_number, server_state}}
      {:error, :not_found} -> {{:cache, :miss}, server_state}
    end
  end
end
