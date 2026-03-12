defmodule PolyglotWatcherV2.Elixir.MixTest do
  alias PolyglotWatcherV2.ActionsExecutor
  alias PolyglotWatcherV2.ShellCommandRunner
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def run(%MixTestArgs{} = mix_test_args) do
    put_running_message(mix_test_args)

    {output, exit_code} =
      case Cache.await_or_run(mix_test_args) do
        {:ok, result} ->
          result

        :not_running ->
          execute(mix_test_args)
      end

    put_result_message(exit_code)
    {output, exit_code}
  end

  def run(%MixTestArgs{} = mix_test_args, server_state) do
    {_output, exit_code} = run(mix_test_args)
    {exit_code, server_state}
  end

  defp execute(mix_test_args) do
    Cache.mark_running(mix_test_args)

    {mix_test_output, exit_code} =
      mix_test_args
      |> MixTestArgs.to_shell_command()
      |> ShellCommandRunner.run()

    Cache.update(mix_test_args, mix_test_output, exit_code)

    {mix_test_output, exit_code}
  end

  defp put_running_message(mix_test_args) do
    ActionsExecutor.execute({:puts, :magenta, "Running #{MixTestArgs.to_shell_command(mix_test_args)}"})
  end

  defp put_result_message(0), do: ActionsExecutor.execute(:put_sarcastic_success)
  defp put_result_message(_), do: ActionsExecutor.execute(:put_insult)
end
