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

  alias PolyglotWatcherV2.Elixir.Cache.{Get, Init, Update}
  alias PolyglotWatcherV2.Elixir.MixTestArgs

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

  def get_test_failure(pid \\ @process_name, test_path) do
    GenServer.call(pid, {:get_test_failure, test_path})
  end

  def get_files(pid \\ @process_name, test_path) do
    GenServer.call(pid, {:get_files, test_path})
  end

  def mark_running(pid \\ @process_name, %MixTestArgs{} = mix_test_args) do
    GenServer.call(pid, {:mark_running, mix_test_args})
  end

  def await_or_run(pid \\ @process_name, %MixTestArgs{} = mix_test_args) do
    GenServer.call(pid, {:await_or_run, mix_test_args}, :infinity)
  end

  # Callbacks

  @impl GenServer
  def init(_) do
    debug_log("starting up")
    {:ok, %{status: :loading, cache_items: %{}, running: %{}}, {:continue, :load}}
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

    key = normalize_key(mix_test_args)
    result = {mix_test_output, exit_code}

    running =
      case Map.get(state.running, key) do
        %{waiters: waiters} ->
          for from <- waiters, do: GenServer.reply(from, {:ok, result})
          Map.delete(state.running, key)

        nil ->
          state.running
      end

    state = %{state | cache_items: cache_items, running: running}
    debug_log_cache(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:get_test_failure, test_path}, _from, state) do
    {:reply, Get.test_failure(test_path, state.cache_items), state}
  end

  @impl GenServer
  def handle_call({:get_files, test_path}, _from, state) do
    {:reply, Get.files(test_path, state.cache_items), state}
  end

  @impl GenServer
  def handle_call({:mark_running, mix_test_args}, _from, state) do
    key = normalize_key(mix_test_args)
    debug_log("mark_running: #{key}")
    running = Map.put(state.running, key, %{waiters: []})
    {:reply, :ok, %{state | running: running}}
  end

  @impl GenServer
  def handle_call({:await_or_run, mix_test_args}, from, state) do
    key = normalize_key(mix_test_args)

    case Map.get(state.running, key) do
      %{waiters: waiters} ->
        debug_log("await_or_run: #{key} is running, adding waiter")
        running = Map.put(state.running, key, %{waiters: [from | waiters]})
        {:noreply, %{state | running: running}}

      nil ->
        {:reply, :not_running, state}
    end
  end

  # Private

  defp normalize_key(%MixTestArgs{path: {test_path, _line}}), do: test_path
  defp normalize_key(%MixTestArgs{path: path}), do: path

  defp debug_log(msg), do: Logger.debug("#{__MODULE__} #{msg}")

  defp debug_log_cache(state) do
    if Logger.level() == :debug do
      Logger.debug("#{__MODULE__} cache_items: #{inspect(state.cache_items, pretty: true)}")
    end
  end
end
