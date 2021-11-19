defmodule PolyglotWatcherV2.Server do
  use GenServer
  alias PolyglotWatcherV2.{Determine, FSWatch, Puts}

  @process_name :server

  @default_options [name: @process_name]

  @initial_state %{
    port: nil,
    ignore_file_changes: false,
    starting_dir: nil,
    elixir: %{mode: :default}
  }

  @supported_operating_systems %{{:unix, :darwin} => :mac}

  def child_spec(command_line_args \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [command_line_args, @default_options]}
    }
  end

  def start_link(command_line_args \\ [], genserver_options \\ @default_options) do
    GenServer.start_link(__MODULE__, command_line_args, genserver_options)
  end

  @impl true
  def init(_command_line_args) do
    case determine_operating_system() do
      :mac -> init_mac()
    end
  end

  defp init_mac do
    Puts.on_new_line("Starting fswatch...", :magenta)
    port = Port.open({:spawn, "fswatch ."}, [:binary, :exit_status])
    state_additions = %{os: :mac, port: port, starting_dir: File.cwd!()}
    {:ok, Map.merge(@initial_state, state_additions)}
  end

  @impl true
  def handle_info({_port, {:data, std_out}}, %{ignore_file_changes: false} = state) do
    set_ignore_file_changes(true)

    std_out
    |> FSWatch.parse_std_out(state.starting_dir)
    |> Determine.actions(state)

    set_ignore_file_changes(false)
    {:noreply, state}
  end

  def handle_info(_, %{ignore_file_changes: true} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:ignore_file_changes, ignore_file_changes?}, state) do
    {:noreply, %{state | ignore_file_changes: ignore_file_changes?}}
  end

  defp determine_operating_system do
    os = :os.type()

    case Map.get(@supported_operating_systems, os) do
      nil ->
        IO.inspect("I don't support your operating system '#{os}', so I'm exiting")
        System.stop(1)

      supported_os ->
        supported_os
    end
  end

  defp set_ignore_file_changes(true_or_false) do
    pid = self()
    spawn_link(fn -> GenServer.cast(pid, {:ignore_file_changes, true_or_false}) end)
  end
end
