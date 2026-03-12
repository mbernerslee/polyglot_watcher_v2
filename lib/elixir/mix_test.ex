defmodule PolyglotWatcherV2.Elixir.MixTest do
  alias PolyglotWatcherV2.ShellCommandRunner
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def run(%MixTestArgs{} = mix_test_args) do
    case Cache.await_or_run(mix_test_args) do
      {:ok, result} ->
        result

      :not_running ->
        execute(mix_test_args)
    end
  end

  def run(%MixTestArgs{} = mix_test_args, server_state) do
    case Cache.await_or_run(mix_test_args) do
      {:ok, {_output, exit_code}} ->
        {exit_code, server_state}

      :not_running ->
        {_output, exit_code} = execute(mix_test_args)
        {exit_code, server_state}
    end
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
end
