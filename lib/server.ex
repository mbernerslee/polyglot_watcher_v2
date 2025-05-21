defmodule PolyglotWatcherV2.Server do
  use GenServer
  require Logger

  alias PolyglotWatcherV2.{
    TraverseActionsTree,
    Determine,
    UserInput,
    ServerState,
    StartupMessage
  }

  alias PolyglotWatcherV2.FileSystemWatchers.{Inotifywait, FSWatch}

  @process_name :server

  @default_options [name: @process_name]

  @initial_state %{
    port: nil,
    ignore_file_changes: false,
    starting_dir: nil,
    elixir: %{mode: :default},
    claude_ai: %{},
    rust: %{mode: :default},
    env_vars: %{},
    files: %{},
    stored_actions: nil,
    action_error: nil,
    file_patches: nil
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
  def init(command_line_args) do
    case determine_os() do
      {:stop, reason} -> {:stop, reason}
      os -> init_for_os(os, command_line_args)
    end
  end

  defp init_for_os(os, command_line_args) do
    watcher = Map.fetch!(@os_watchers, os)

    Logger.debug(watcher.startup_message())

    port = Port.open({:spawn_executable, @zombie_killer}, args: watcher.startup_command())

    server_state =
      Map.merge(
        @initial_state,
        %{os: os, port: port, starting_dir: File.cwd!(), watcher: watcher}
      )

    server_state = struct!(ServerState, server_state)

    server_state =
      command_line_args
      |> Enum.join(" ")
      |> UserInput.determine_actions(server_state)
      |> StartupMessage.put_default_if_empty()
      |> TraverseActionsTree.execute_all()

    listen_for_user_input()
    {:ok, server_state}
  end

  @impl true
  def handle_info({_port, {:data, std_out}}, %{ignore_file_changes: false} = state) do
    set_ignore_file_changes(true)

    state =
      std_out
      |> to_string()
      |> state.watcher.parse_std_out(state.starting_dir)
      |> Determine.actions(state)
      |> TraverseActionsTree.execute_all()

    set_ignore_file_changes(state.ignore_file_changes)

    if state.ignore_file_changes == true do
      Logger.debug("#{__MODULE__} Setting ignore_file_changes: true")
    end

    {:noreply, state}
  end

  def handle_info(_ignored, %{ignore_file_changes: true} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:user_input, user_input}, _from, state) do
    state =
      user_input
      |> UserInput.determine_actions(state)
      |> TraverseActionsTree.execute_all()

    listen_for_user_input()
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

  defp listen_for_user_input do
    if should_listen_for_user_input?() do
      pid = self()

      spawn_link(fn ->
        user_input = IO.gets("")
        GenServer.call(pid, {:user_input, user_input}, :infinity)
      end)
    end
  end

  defp should_listen_for_user_input? do
    Application.get_env(:polyglot_watcher_v2, :listen_for_user_input, true)
  end
end
