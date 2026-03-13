defmodule PolyglotWatcherV2 do
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.Server
  alias PolyglotWatcherV2.Elixir.Cache, as: ElixirCache

  @mcp_default_port 4848

  # TODO do a strict analysis of lib files changed and ensure sufficient test coverage to be confident it worked
  # TODO update README with setup instructions

  # deferred
  # TODO [future] reconsider the ports problem. take a hash of the cwd to get a port, and increase its number til you find one thats free? or sth? need to be able to run at least 1 watcher from different dirs without conflict.
  # TODO [future] let the watcher tell claude what tests have run & passed (server side events?)

  def main(command_line_args \\ []) do
    run(command_line_args)
    :timer.sleep(:infinity)
  end

  def run(command_line_args) do
    # order is important. Server sometimes waits for ElixirCache to be up, so ElixirCache must be first
    {mcp_children, mcp_error} = mcp_children()

    children =
      [ElixirCache.child_spec(), Server.child_spec(command_line_args)] ++ mcp_children

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)

    if mcp_error, do: Puts.on_new_line(mcp_error, :red)
  end

  defp mcp_children do
    if Application.get_env(:polyglot_watcher_v2, :start_mcp, true) do
      port = Application.get_env(:polyglot_watcher_v2, :mcp_port, @mcp_default_port)

      case port_available?(port) do
        :ok ->
          Application.ensure_all_started(:bandit)

          {[
             {Bandit,
              plug: PolyglotWatcherV2.MCP.PlugRouter,
              port: port,
              startup_log: false,
              thousand_island_options: [num_acceptors: 1]}
           ], nil}

        {:error, :eaddrinuse} ->
          {[],
           "MCP server failed to start: port #{port} is already in use. " <>
             "Is another watcher instance running? \n" <>
             "File watching still works, but MCP clients (like Claude Code) won't be able to connect."}

        {:error, reason} ->
          {[],
           "MCP server failed to start: port #{port} error: #{inspect(reason)}. \n" <>
             "File watching still works, but MCP clients (like Claude Code) won't be able to connect."}
      end
    else
      {[], nil}
    end
  end

  defp port_available?(port) do
    case :gen_tcp.listen(port, [:binary, reuseaddr: true]) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
