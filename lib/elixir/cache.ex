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

  def await_or_run(pid \\ @process_name, %MixTestArgs{} = mix_test_args) do
    GenServer.call(pid, {:await_or_run, mix_test_args}, :infinity)
  end

  # Callbacks

  @impl GenServer
  def init(_) do
    debug_log("starting up")

    {:ok,
     %{
       status: :loading,
       cache_items: %{},
       running_key: nil,
       same_key_waiters: [],
       queue: []
     }, {:continue, :load}}
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

    result = {mix_test_output, exit_code}

    # Reply to all same-key waiters with the result
    for from <- state.same_key_waiters, do: GenServer.reply(from, {:ok, result})

    # Drain the queue: pop next item
    state =
      case state.queue do
        [] ->
          %{state | cache_items: cache_items, running_key: nil, same_key_waiters: [], queue: []}

        [{next_from, next_args} | rest] ->
          next_key = normalize_key(next_args)

          # Collect any remaining queue entries with the same key as same_key_waiters
          {same_key_entries, remaining_queue} =
            Enum.split_with(rest, fn {_from, args} -> normalize_key(args) == next_key end)

          new_same_key_waiters = Enum.map(same_key_entries, fn {from, _args} -> from end)

          # Tell the next caller to run
          GenServer.reply(next_from, :not_running)

          %{
            state
            | cache_items: cache_items,
              running_key: next_key,
              same_key_waiters: new_same_key_waiters,
              queue: remaining_queue
          }
      end

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
  def handle_call({:await_or_run, mix_test_args}, from, state) do
    key = normalize_key(mix_test_args)

    case state.running_key do
      nil ->
        # Nothing running — caller gets the lock
        debug_log("await_or_run: #{key} — acquired lock")
        {:reply, :not_running, %{state | running_key: key}}

      ^key ->
        # Same test running — wait for its result
        debug_log("await_or_run: #{key} is running, adding same-key waiter")
        {:noreply, %{state | same_key_waiters: [from | state.same_key_waiters]}}

      other_key ->
        # Different test running — queue up
        debug_log("await_or_run: #{key} queued behind #{other_key}")
        {:noreply, %{state | queue: state.queue ++ [{from, mix_test_args}]}}
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
