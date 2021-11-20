defmodule PolyglotWatcherV2.Server do
  use GenServer
  alias PolyglotWatcherV2.{TraverseActionsTree, Determine, FSWatch, Inotifywait, Puts}

  @process_name :server

  @default_options [name: @process_name]

  @initial_state %{
    port: nil,
    ignore_file_changes: false,
    starting_dir: nil,
    elixir: %{mode: :default}
  }

  @supported_oss %{
    {:unix, :darwin} => :mac,
    {:unix, :linux} => :linux
  }

  @os_watchers %{linux: Inotifywait, mac: FSWatch}

  @zombie_killer "#{:code.priv_dir(:polyglot_watcher_v2)}/zombie_killer"

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
    case determine_os() do
      {:stop, reason} -> {:stop, reason}
      os -> init_for_os(os)
    end
  end

  defp init_for_os(os) do
    watcher = Map.fetch!(@os_watchers, os)
    Puts.on_new_line(watcher.startup_message, :magenta)
    port = Port.open({:spawn_executable, @zombie_killer}, args: watcher.startup_command)
    state_additions = %{os: os, port: port, starting_dir: File.cwd!(), watcher: watcher}
    {:ok, Map.merge(@initial_state, state_additions)}
  end

  @impl true
  def handle_info({_port, {:data, std_out}}, %{ignore_file_changes: false} = state) do
    set_ignore_file_changes(true)

    state =
      std_out
      |> to_string()
      |> state.watcher.parse_std_out(state.starting_dir)
      |> Determine.actions()
      |> TraverseActionsTree.execute_all(state)

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

  defp determine_os do
    os = :os.type()

    case Map.get(@supported_oss, os) do
      nil -> {:stop, "I don't support your operating system '#{inspect(os)}', so I'm exiting"}
      supported_os -> supported_os
    end
  end

  defp set_ignore_file_changes(true_or_false) do
    pid = self()
    spawn_link(fn -> GenServer.cast(pid, {:ignore_file_changes, true_or_false}) end)
  end
end
