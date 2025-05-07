defmodule PolyglotWatcherV2 do
  alias PolyglotWatcherV2.Server
  alias PolyglotWatcherV2.Elixir.Cache, as: ElixirCache

  def main(command_line_args \\ []) do
    run(command_line_args)
    :timer.sleep(:infinity)
  end

  def run(command_line_args) do
    # order is important. Server sometimes waits for ElixirCache to be up, so ElixirCache must be first
    children = [ElixirCache.child_spec(), Server.child_spec(command_line_args)]
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
