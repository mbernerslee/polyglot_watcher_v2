defmodule PolyglotWatcherV2.IdleShutdown do
  @moduledoc """
  Stops the whole watcher after a period with no activity (MCP tool calls or
  file changes). Only enabled when POLYGLOT_WATCHER_IDLE_SHUTDOWN_MINUTES is set,
  which mcp_stdio_proxy does when it spawns a watcher detached — so watchers the
  AI auto-started don't pile up forever. Watchers started from the command line
  (or in a visible tmux split) never get the env var, so never idle-shutdown.

  The proxy auto-starts a fresh watcher on the next tool call, so shutting down
  early only costs a reboot and the in-memory failure cache.
  """
  use GenServer

  alias PolyglotWatcherV2.{Puts, SystemWrapper}
  alias PolyglotWatcherV2.MCP.Startup, as: MCPStartup

  @env_var "POLYGLOT_WATCHER_IDLE_SHUTDOWN_MINUTES"
  @minute_ms 60_000

  def children do
    case SystemWrapper.get_env(@env_var) do
      nil ->
        []

      value ->
        case parse_minutes(value) do
          {:ok, minutes} ->
            [{__MODULE__, [timeout_ms: round(minutes * @minute_ms)]}]

          :error ->
            Puts.on_new_line(
              "[idle-shutdown] ignoring invalid #{@env_var}=#{inspect(value)} " <>
                "(expected a positive number of minutes) — idle shutdown disabled",
              :yellow
            )

            []
        end
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Records activity now. A no-op when idle shutdown isn't running."
  def touch, do: GenServer.cast(__MODULE__, :touch)

  @doc """
  Runs `fun`, counting as busy for its whole duration (so a long test run is
  never cut off mid-way), and as activity when it finishes.
  """
  def track(fun) do
    ref = make_ref()
    GenServer.cast(__MODULE__, {:busy, self(), ref})

    try do
      fun.()
    after
      GenServer.cast(__MODULE__, {:done, ref})
    end
  end

  @impl GenServer
  def init(opts) do
    timeout_ms = Keyword.fetch!(opts, :timeout_ms)
    now = Keyword.get(opts, :now, fn -> System.monotonic_time(:millisecond) end)

    check_interval_ms =
      Keyword.get(opts, :check_interval_ms, timeout_ms |> div(10) |> max(1_000) |> min(@minute_ms))

    Puts.on_new_line(
      "[idle-shutdown] enabled — this watcher will exit after #{format_minutes(timeout_ms)} " <>
        "with no MCP tool calls or file changes (it was started detached by the MCP proxy, " <>
        "which restarts it on demand)",
      :cyan
    )

    state = %{
      timeout_ms: timeout_ms,
      check_interval_ms: check_interval_ms,
      now: now,
      last_activity: now.(),
      busy: %{}
    }

    schedule_check(state)
    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:touch, state) do
    {:noreply, %{state | last_activity: state.now.()}}
  end

  def handle_cast({:busy, pid, ref}, state) do
    monitor_ref = Process.monitor(pid)
    {:noreply, %{state | busy: Map.put(state.busy, ref, monitor_ref)}}
  end

  def handle_cast({:done, ref}, state) do
    {monitor_ref, busy} = Map.pop(state.busy, ref)
    if monitor_ref, do: Process.demonitor(monitor_ref, [:flush])
    {:noreply, %{state | busy: busy, last_activity: state.now.()}}
  end

  @impl GenServer
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    busy = state.busy |> Enum.reject(fn {_ref, m} -> m == monitor_ref end) |> Map.new()
    {:noreply, %{state | busy: busy, last_activity: state.now.()}}
  end

  def handle_info(:check, state) do
    idle_ms = state.now.() - state.last_activity

    if map_size(state.busy) == 0 and idle_ms >= state.timeout_ms do
      shutdown(state)
    else
      schedule_check(state)
    end

    {:noreply, state}
  end

  defp shutdown(state) do
    Puts.on_new_line(
      "[idle-shutdown] no MCP tool calls or file changes for #{format_minutes(state.timeout_ms)} " <>
        "— shutting down (this watcher was started detached by the MCP proxy, " <>
        "which will start a new one on the next tool call)",
      :yellow
    )

    # Close the door before leaving: delete config.json and stop the HTTP
    # listener first, so a request racing with shutdown gets a clean connection
    # refusal (which the proxy answers by starting a new watcher) rather than
    # landing on a half-dead VM.
    MCPStartup.stop()
    SystemWrapper.stop(0)
  end

  defp schedule_check(%{check_interval_ms: :manual}), do: :ok

  defp schedule_check(%{check_interval_ms: interval}),
    do: Process.send_after(self(), :check, interval)

  defp parse_minutes(value) do
    case Float.parse(value) do
      {minutes, ""} when minutes > 0 -> {:ok, minutes}
      _ -> :error
    end
  end

  defp format_minutes(ms) do
    minutes = ms / @minute_ms

    if minutes == trunc(minutes),
      do: "#{trunc(minutes)} min",
      else: "#{Float.round(minutes, 2)} min"
  end
end
