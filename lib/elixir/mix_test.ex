defmodule PolyglotWatcherV2.Elixir.MixTest do
  alias PolyglotWatcherV2.ActionsExecutor
  alias PolyglotWatcherV2.ShellCommandRunner
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def run(%MixTestArgs{} = mix_test_args, opts \\ []) do
    use_cache = Keyword.get(opts, :use_cache, :no_cache)
    server_state = Keyword.get(opts, :server_state)
    pre_message = Keyword.get(opts, :pre_message)
    source = Keyword.get(opts, :source)

    {output, exit_code, from_cache?} =
      cond do
        mix_test_args.extra_args != [] ->
          # Skip Cache.get_cached_result and Cache.await_or_run: a cached/in-flight
          # result was produced by a different command line and would mismatch the
          # requested flags. Note this means an MCP run with extra_args can execute
          # concurrently with a watcher run on the same project — be cautious with
          # flags that touch shared state (e.g. --cover writes to cover/coverdata).
          {output, exit_code} = execute(mix_test_args, pre_message)
          {output, exit_code, false}

        use_cache == :cached ->
          case Cache.get_cached_result(mix_test_args) do
            {:hit, output, exit_code} ->
              if source == :mcp,
                do:
                  ActionsExecutor.execute(
                    {:puts, :cyan,
                     "MCP cache hit: #{MixTestArgs.to_shell_command(mix_test_args)}"}
                  )

              {output, exit_code, true}

            :miss ->
              run_tests(mix_test_args, pre_message)
          end

        true ->
          run_tests(mix_test_args, pre_message)
      end

    unless from_cache?, do: put_result_message(exit_code)

    if server_state do
      {exit_code, server_state}
    else
      {output, exit_code}
    end
  end

  defp run_tests(mix_test_args, pre_message) do
    {output, exit_code} =
      case Cache.await_or_run(mix_test_args) do
        {:ok, result} -> result
        :not_running -> execute(mix_test_args, pre_message)
      end

    {output, exit_code, false}
  end

  defp execute(mix_test_args, pre_message) do
    ActionsExecutor.execute(:clear_screen)
    if pre_message, do: ActionsExecutor.execute({:puts, :cyan, pre_message})
    put_running_message(mix_test_args)

    {mix_test_output, exit_code} =
      mix_test_args
      |> MixTestArgs.to_shell_command()
      |> ShellCommandRunner.run()

    Cache.update(mix_test_args, mix_test_output, exit_code)

    {mix_test_output, exit_code}
  end

  defp put_running_message(mix_test_args) do
    ActionsExecutor.execute(
      {:puts, :magenta, "Running #{MixTestArgs.to_shell_command(mix_test_args)}"}
    )
  end

  defp put_result_message(0), do: ActionsExecutor.execute(:put_sarcastic_success)
  defp put_result_message(_), do: ActionsExecutor.execute(:put_insult)
end
