defmodule PolyglotWatcherV2.Elixir.MixTest do
  alias PolyglotWatcherV2.ShellCommandRunner
  alias PolyglotWatcherV2.Elixir.Failures
  alias PolyglotWatcherV2.Elixir.Cache

  def run(test_path, server_state) do
    IO.inspect(test_path)

    {mix_test_output, exit_code} =
      case test_path do
        :all -> ShellCommandRunner.run("mix test --color")
        path -> ShellCommandRunner.run("mix test #{path} --color")
      end

    failures =
      Failures.update(
        server_state.elixir.failures,
        test_path,
        mix_test_output,
        exit_code
      )

    # TODO should it be a sync or async thing? race conditions could happen if async maybe? Too slow if sync (probably not). So sync?
    # sync call
    # TODO test this gets called
    Cache.update(test_path, mix_test_output, exit_code)

    server_state =
      server_state
      |> put_in([:elixir, :failures], failures)
      |> put_in([:elixir, :mix_test_exit_code], exit_code)
      |> put_in([:elixir, :mix_test_output], mix_test_output)

    {exit_code, server_state}
  end
end
