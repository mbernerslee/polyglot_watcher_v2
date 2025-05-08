defmodule PolyglotWatcherV2.Elixir.Cache do
  @moduledoc """
  Holds an in-memory cache of elixir:
  - code files *.ex
  - test files *.exs
  - the line numbers of which tests have failed
  - mix test failure output

  We want them available to us for actions such as
  - spicing them into an AI prompt
  - rerunning the most recent test that failed

  Designed to be updated every time `mix test` is run via the ActionsExecutor

  Also loads the mix test failures from the manifest file that ExUnit writes to.
  """
  use GenServer
  require Logger

  alias PolyglotWatcherV2.Elixir.Cache.{CacheItem, Init, Update}

  @process_name :elixir_cache
  @default_options [name: @process_name]

  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [@default_options]}
    }
  end

  def start_link(genserver_options \\ @default_options) do
    GenServer.start_link(__MODULE__, [], genserver_options)
  end

  def update(pid \\ @process_name, mix_test_args, mix_test_output, exit_code) do
    GenServer.call(pid, {:update, mix_test_args, mix_test_output, exit_code})
  end

  def get(pid \\ @process_name, test_path) do
    GenServer.call(pid, {:get, test_path})
  end

  # Callbacks

  @impl GenServer
  def init(_) do
    debug_log("starting up")
    {:ok, %{status: :loading, cache_items: %{}}, {:continue, :load}}
  end

  @impl GenServer
  def handle_continue(:load, state) do
    debug_log("init")

    state =
      state
      |> Map.replace!(:status, :loaded)
      |> Map.put(:cache_items, Init.run())

    debug_log_cache(state)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:update, mix_test_args, mix_test_output, exit_code}, _from, state) do
    cache_items = Update.run(state.cache_items, mix_test_args, mix_test_output, exit_code)
    state = %{state | cache_items: cache_items}
    debug_log_cache(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:get, :latest}, _from, state) do
    state.cache_items
    |> lowest_rank_test_path()
    |> get_latest_failure(state.cache_items)
    |> case do
      {:ok, {test_path, line_number}} -> {:reply, {:ok, {test_path, line_number}}, state}
      {:error, :not_found} -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:get, test_path}, _from, state) do
    case get_latest_failure({:ok, test_path}, state.cache_items) do
      {:ok, {test_path, line_number}} -> {:reply, {:ok, {test_path, line_number}}, state}
      {:error, :not_found} -> {:reply, {:error, :not_found}, state}
    end
  end

  # Private

  # TODO change this & get_latest_failure to handle failed_line_numbers == [], and skipping to the next rank if so
  # TODO wire in oustading modes:
  # - ex cl
  # - ex clr
  defp lowest_rank_test_path(cache_items) do
    cache_items
    |> Enum.min_by(fn {_test_path, file} -> file.rank end, &<=/2, fn -> {:error, :not_found} end)
    |> case do
      {:error, :not_found} -> {:error, :not_found}
      {test_path, _file} -> {:ok, test_path}
    end
  end

  defp get_latest_failure({:ok, test_path}, cache_items) do
    case Map.get(cache_items, test_path) do
      %CacheItem{failed_line_numbers: [line_number | _]} ->
        {:ok, {test_path, line_number}}

      _ ->
        {:error, :not_found}
    end
  end

  defp get_latest_failure(error, _cache_items) do
    error
  end

  defp debug_log(msg), do: Logger.debug("#{__MODULE__} #{msg}")

  defp debug_log_cache(state) do
    if Logger.level() == :debug do
      Logger.debug("#{__MODULE__} cache_items: #{inspect(state.cache_items, pretty: true)}")
    end
  end
end
