defmodule PolyglotWatcherV2 do
  alias PolyglotWatcherV2.Server
  alias PolyglotWatcherV2.Elixir.Cache, as: ElixirCache

  def main(command_line_args \\ []) do
    run(command_line_args)
    :timer.sleep(:infinity)
  end

  defp run(command_line_args) do
    children = [Server.child_spec(command_line_args), ElixirCache.child_spec()]
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
