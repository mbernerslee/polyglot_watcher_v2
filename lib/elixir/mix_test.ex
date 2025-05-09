defmodule PolyglotWatcherV2.Elixir.MixTest do
  alias PolyglotWatcherV2.ShellCommandRunner
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def run(%MixTestArgs{} = mix_test_args, server_state) do
    {mix_test_output, exit_code} =
      mix_test_args
      |> MixTestArgs.to_shell_command()
      |> ShellCommandRunner.run()

    Cache.update(mix_test_args, mix_test_output, exit_code)

    {exit_code, server_state}
  end
end
