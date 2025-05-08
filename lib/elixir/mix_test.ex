defmodule PolyglotWatcherV2.Elixir.MixTest do
  alias PolyglotWatcherV2.ShellCommandRunner
  alias PolyglotWatcherV2.Elixir.Cache

  def run(test_path, server_state) do
    {mix_test_output, exit_code} =
      case test_path do
        :all -> ShellCommandRunner.run("mix test --color")
        path -> ShellCommandRunner.run("mix test #{path} --color")
      end

    Cache.update(test_path, mix_test_output, exit_code)

    server_state =
      server_state
      # |> put_in([:elixir, :failures], failures)
      # TODO delete once we've sorted out claude_ai modes to use the cache
      |> put_in([:elixir, :mix_test_output], mix_test_output)

    {exit_code, server_state}
  end
end
