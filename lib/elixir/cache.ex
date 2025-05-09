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

  @process_name :elixir_cache
  @default_options [name: @process_name]

  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [@default_options]}
    }
  end

  # TODO wire in oustading modes:
  # - ex cl
  # - ex clr

  def start_link(genserver_options \\ @default_options) do
    GenServer.start_link(__MODULE__, [], genserver_options)
  end

  def update(pid \\ @process_name, mix_test_args, mix_test_output, exit_code) do
    GenServer.call(pid, {:update, mix_test_args, mix_test_output, exit_code})
  end

  def get_test_failure(pid \\ @process_name, test_path) do
    GenServer.call(pid, {:get_test_failure, test_path})
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
  def handle_call({:get_test_failure, test_path}, _from, state) do
    {:reply, Get.test_failure(test_path, state.cache_items), state}
  end

  # Private

  defp debug_log(msg), do: Logger.debug("#{__MODULE__} #{msg}")

  defp debug_log_cache(state) do
    if Logger.level() == :debug do
      Logger.debug("#{__MODULE__} cache_items: #{inspect(state.cache_items, pretty: true)}")
    end
  end
end
