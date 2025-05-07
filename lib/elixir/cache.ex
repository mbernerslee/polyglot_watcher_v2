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

  alias PolyglotWatcherV2.Elixir.Cache.{File, Init, TestFile, Update}

  @process_name :elixir_cache
  @default_options [name: @process_name]

  # TODO take care about running out of memory. Do cleanup? max MB limit? If you ran mix test on a massive repo and all tests failed this could be enormous.
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
    debug_log("update")

    if wait_until_alive(pid) == :ok do
      GenServer.call(pid, {:update, mix_test_args, mix_test_output, exit_code})
    else
      debug_log("update - failed because I'm not running")
      :ok
    end
  end

  def get(pid \\ @process_name, test_path) do
    debug_log("get")

    if wait_until_alive(pid) == :ok do
      GenServer.call(pid, {:get, test_path})
    else
      debug_log("get - failed because I'm not running")
      {:error, :not_found}
    end
  end

  # Callbacks

  @impl GenServer
  def init(_) do
    debug_log("starting up")
    {:ok, %{status: :loading, files: %{}}, {:continue, :load}}
  end

  @impl GenServer
  def handle_continue(:load, state) do
    debug_log("init")

    state =
      state
      |> Map.replace!(:status, :loaded)
      |> Map.put(:files, Init.run())

    debug_log_stats(state.files)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:update, mix_test_args, mix_test_output, exit_code}, _from, state) do
    files = Update.run(state.files, mix_test_args, mix_test_output, exit_code)
    debug_log_stats(files)
    {:reply, :ok, %{state | files: files}}
  end

  @impl GenServer
  def handle_call({:get, test_path}, _from, state) do
    case Map.get(state.files, test_path) do
      %File{test: %TestFile{failed_line_numbers: [line_number | _]}} ->
        debug_log("get - OK")
        {:reply, {:ok, {test_path, line_number}}, state}

      _ ->
        debug_log("get - failed")
        {:reply, {:error, :not_found}, state}
    end
  end

  # Private

  defp debug_log(msg), do: Logger.debug("#{__MODULE__} #{msg}")
  defp alive?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp alive?(name) when is_atom(name), do: name |> Process.whereis() |> is_pid()

  defp wait_until_alive(pid), do: wait_until_alive(pid, 1, 4)

  defp wait_until_alive(_pid, max_attempts, max_attempts) do
    :error
  end

  defp wait_until_alive(pid, attempt, max_attempts) do
    if alive?(pid) do
      :ok
    else
      :timer.sleep(1)
      wait_until_alive(pid, attempt + 1, max_attempts)
    end
  end

  defp debug_log_stats(files) do
    if Logger.level() == :debug do
      %{
        test_file_count: test_file_count,
        failing_tests: failing_tests,
        in_memory_file_count: in_memory_file_count
      } =
        Enum.reduce(
          files,
          %{test_file_count: 0, failing_tests: 0, in_memory_file_count: 0},
          fn {_file_path, file}, acc ->
            %{
              test: %{contents: test_contents, failed_line_numbers: failed_line_numbers},
              lib: %{contents: lib_contents}
            } = file

            acc
            |> Map.update!(:test_file_count, &(&1 + 1))
            |> Map.update!(:failing_tests, &(&1 + length(failed_line_numbers)))
            |> Map.update!(
              :in_memory_file_count,
              &(&1 + file_load_count(test_contents) + file_load_count(lib_contents))
            )
          end
        )

      {:memory, memory_usage_in_bytes} = Process.info(self(), :memory)

      Logger.debug("""

      **************************
      #{__MODULE__} Stats:
      **************************
      #{failing_tests} failing test(s)
      #{test_file_count} test file(s)
      #{in_memory_file_count} file(s) held in memory
      #{inspect(memory_usage_in_bytes)} [bytes] memory used =~ #{memory_usage_magnitude(memory_usage_in_bytes)}
      **************************
      """)
    end
  end

  defp file_load_count(nil), do: 0
  defp file_load_count(_), do: 1

  defp memory_usage_magnitude(memory_usage_in_bytes) do
    magnitude = :math.log10(memory_usage_in_bytes)

    cond do
      magnitude >= 10 -> "10's of GB or more!!"
      magnitude >= 9 -> "few GB!!"
      magnitude >= 8 -> "100's of MB"
      magnitude >= 7 -> "10's of MB"
      magnitude >= 6 -> "few MB"
      magnitude >= 5 -> "100's of kB"
      magnitude >= 4 -> "10's of kB"
      magnitude >= 3 -> "few kB"
      true -> "few bytes (peanuts)"
    end
  end
end
