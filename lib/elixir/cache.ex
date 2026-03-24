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

  def bump_change_epoch(pid \\ @process_name) do
    GenServer.cast(pid, :bump_change_epoch)
  end

  def get_change_epoch(pid \\ @process_name) do
    GenServer.call(pid, :get_change_epoch)
  end

  def get_cached_result(pid \\ @process_name, %MixTestArgs{} = mix_test_args) do
    GenServer.call(pid, {:get_cached_result, mix_test_args})
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
       queue: [],
       change_epoch: 0,
       last_run_results: %{}
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
  def handle_call(:get_change_epoch, _from, state) do
    {:reply, state.change_epoch, state}
  end

  @impl GenServer
  def handle_call({:update, mix_test_args, mix_test_output, exit_code}, _from, state) do
    cache_items = Update.run(state.cache_items, mix_test_args, mix_test_output, exit_code)

    notify_waiters(state.same_key_waiters, mix_test_output, exit_code)

    state =
      state
      |> drain_queue(cache_items)
      |> maybe_store_run_result(mix_test_args, mix_test_output, exit_code)

    debug_log_cache(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:get_cached_result, mix_test_args}, _from, state) do
    key = run_result_key(mix_test_args)

    result =
      case Map.get(state.last_run_results, key) do
        %{epoch: epoch, output: output, exit_code: exit_code}
        when epoch == state.change_epoch ->
          debug_log("cache HIT for #{inspect(key)} at epoch #{epoch}")
          {:hit, output, exit_code}

        %{epoch: stale_epoch} ->
          debug_log(
            "cache MISS for #{inspect(key)} (cached epoch #{stale_epoch}, current epoch #{state.change_epoch})"
          )

          :miss

        nil ->
          debug_log("cache MISS for #{inspect(key)} (no cached result)")
          :miss
      end

    {:reply, result, state}
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
    test_file_path = test_file_path(mix_test_args)

    case state.running_key do
      nil ->
        # Nothing running — caller gets the lock
        debug_log("await_or_run: #{test_file_path} — acquired lock")
        {:reply, :not_running, %{state | running_key: test_file_path}}

      ^test_file_path ->
        # Same test running — wait for its result
        debug_log("await_or_run: #{test_file_path} is running, adding same-key waiter")
        {:noreply, %{state | same_key_waiters: [from | state.same_key_waiters]}}

      other_key ->
        # Different test running — queue up
        debug_log("await_or_run: #{test_file_path} queued behind #{other_key}")
        {:noreply, %{state | queue: state.queue ++ [{from, mix_test_args}]}}
    end
  end

  @impl GenServer
  def handle_cast(:bump_change_epoch, state) do
    new_epoch = state.change_epoch + 1
    debug_log("cache epoch bumped from #{state.change_epoch} to #{new_epoch}")
    {:noreply, %{state | change_epoch: new_epoch}}
  end

  # Private

  defp notify_waiters(waiters, output, exit_code) do
    result = {output, exit_code}
    for from <- waiters, do: GenServer.reply(from, {:ok, result})
  end

  defp drain_queue(state, cache_items) do
    case state.queue do
      [] ->
        %{state | cache_items: cache_items, running_key: nil, same_key_waiters: [], queue: []}

      [{next_from, next_args} | rest] ->
        next_key = test_file_path(next_args)

        {same_key_entries, remaining_queue} =
          Enum.split_with(rest, fn {_from, args} -> test_file_path(args) == next_key end)

        new_same_key_waiters = Enum.map(same_key_entries, fn {from, _args} -> from end)

        GenServer.reply(next_from, :not_running)

        %{
          state
          | cache_items: cache_items,
            running_key: next_key,
            same_key_waiters: new_same_key_waiters,
            queue: remaining_queue
        }
    end
  end

  defp maybe_store_run_result(state, %MixTestArgs{max_failures: nil} = args, output, exit_code) do
    run_result = %{output: output, exit_code: exit_code, epoch: state.change_epoch}
    put_in(state.last_run_results[run_result_key(args)], run_result)
  end

  defp maybe_store_run_result(state, _args, _output, _exit_code), do: state

  defp test_file_path(%MixTestArgs{path: {test_path, _line}}), do: test_path
  defp test_file_path(%MixTestArgs{path: path}), do: path

  defp run_result_key(%MixTestArgs{path: path}), do: path

  defp debug_log(msg), do: Logger.debug("#{__MODULE__} #{msg}")

  defp debug_log_cache(state) do
    if Logger.level() == :debug do
      Logger.debug("#{__MODULE__} cache_items: #{inspect(state.cache_items, pretty: true)}")
    end
  end
end
