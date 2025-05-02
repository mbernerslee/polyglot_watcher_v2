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

  alias PolyglotWatcherV2.Elixir.Cache.{Init, Update}

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

  def update(pid \\ @process_name, test_path, mix_test_output, exit_code) do
    if alive?(pid) do
      GenServer.call(pid, {:update, test_path, mix_test_output, exit_code})
    else
      # TODO consider how to run this in tests...
      # IO.inspect("#{__MODULE__} update was called but I'm not running :-(")
      :ok
    end
  end

  defp debug_log(msg) do
    Logger.debug("#{__MODULE__} #{inspect(msg)}")
  end

  defp alive?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp alive?(name) when is_atom(name), do: name |> Process.whereis() |> is_pid()

  # Callbacks

  @impl GenServer
  def init(_) do
    debug_log("starting up")
    {:ok, %{status: :loading, files: %{}}, {:continue, :load}}
  end

  @impl GenServer
  def handle_continue(:load, state) do
    state =
      state
      |> Map.replace!(:status, :loaded)
      |> Map.put(:files, Init.run())

    debug_log("init. files from manifest count = #{state.files |> Map.keys() |> length()}")

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:update, test_path, mix_test_output, exit_code}, _from, state) do
    {:reply, :ok,
     %{state | files: Update.run(state.files, test_path, mix_test_output, exit_code)}}
  end
end
