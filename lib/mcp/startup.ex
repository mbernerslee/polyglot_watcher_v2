defmodule PolyglotWatcherV2.MCP.Startup do
  # transient: a deliberate stop (idle shutdown) must not be undone by a restart
  use GenServer, restart: :transient

  alias PolyglotWatcherV2.MCP.{ConfigFile, InstanceChecker}
  alias PolyglotWatcherV2.Puts

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Stops the MCP server (deleting config.json and closing the listener). No-op if not running."
  def stop do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end

  @impl GenServer
  def init(_opts) do
    Process.flag(:trap_exit, true)
    Application.ensure_all_started(:req)
    Application.ensure_all_started(:bandit)

    case check_and_start() do
      {:ok, state} -> {:ok, state}
      :skip -> :ignore
    end
  end

  @impl GenServer
  def handle_info({:EXIT, bandit_pid, reason}, %{bandit_pid: bandit_pid} = state) do
    {:stop, reason, state}
  end

  # Other linked things exiting (e.g. the port InstanceChecker's `kill -0` ran
  # in) are no reason to stop. This used to be masked by a :permanent restart.
  def handle_info({:EXIT, _other, _reason}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    ConfigFile.delete()
    stop_listener(state)
    :ok
  end

  defp stop_listener(%{bandit_pid: bandit_pid}) do
    GenServer.stop(bandit_pid, :normal)
  catch
    :exit, _ -> :ok
  end

  defp stop_listener(_state), do: :ok

  defp check_and_start do
    case ConfigFile.read() do
      {:ok, %{"pid" => pid, "mcp_tcp_port" => port}} ->
        if InstanceChecker.alive?(pid, port) do
          Puts.on_new_line(
            "MCP server not started — another instance already active " <>
              "for PID #{pid} on port #{port}",
            :yellow
          )

          :skip
        else
          do_start()
        end

      _ ->
        do_start()
    end
  end

  defp do_start do
    # Bandit is linked (not supervised separately) so that if it crashes,
    # this GenServer stops, cleans up the config file, and the supervisor
    # restarts both together.
    with {:ok, bandit_pid} <-
           Bandit.start_link(
             plug: PolyglotWatcherV2.MCP.PlugRouter,
             port: 0,
             startup_log: false,
             thousand_island_options: [num_acceptors: 1]
           ),
         {:ok, {_addr, port}} <- ThousandIsland.listener_info(bandit_pid) do
      os_pid = System.pid() |> String.to_integer()

      case ConfigFile.write(port, os_pid) do
        :ok -> :ok
        error -> Puts.on_new_line("Warning: failed to write MCP config file: #{inspect(error)}", :yellow)
      end

      {:ok, %{bandit_pid: bandit_pid, port: port}}
    else
      error ->
        Puts.on_new_line(
          "MCP server failed to start: #{inspect(error)}. " <>
            "File watching still works, but MCP clients won't be able to connect.",
          :red
        )

        :skip
    end
  end
end
