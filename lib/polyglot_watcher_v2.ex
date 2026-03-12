defmodule PolyglotWatcherV2 do
  require Logger

  alias PolyglotWatcherV2.Server
  alias PolyglotWatcherV2.Elixir.Cache, as: ElixirCache

  @mcp_default_port 4848

  # TODO check CLAUDE.md addition doesn't wreck claude when PolyglotWatcherV2 MCP server is not connected. it should fall back to regular `mix test` commands
  # TODO bundle the common mix test actions run by ActionExecutor into one thing, so that they can be run with similar output wrapping regardless of if it happened from a file change or direct claude instruction. magenta text and sarcastic message and so on...
  # TODO do a strict analysis of lib files changed and ensure sufficient test coverage to be confident it worked
  # TODO update README with setup instructions
  # TODO [future] let the watcher tell claude what tests have run & passed

  def main(command_line_args \\ []) do
    run(command_line_args)
    :timer.sleep(:infinity)
  end

  def run(command_line_args) do
    # order is important. Server sometimes waits for ElixirCache to be up, so ElixirCache must be first
    children =
      [ElixirCache.child_spec(), Server.child_spec(command_line_args)] ++ mcp_children()

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp mcp_children do
    if Application.get_env(:polyglot_watcher_v2, :start_mcp, true) do
      Application.ensure_all_started(:bandit)
      port = Application.get_env(:polyglot_watcher_v2, :mcp_port, @mcp_default_port)

      [
        {Bandit,
         plug: PolyglotWatcherV2.MCP.PlugRouter,
         port: port,
         startup_log: false,
         thousand_island_options: [num_acceptors: 1]}
      ]
    else
      []
    end
  end
end
