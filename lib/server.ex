defmodule PolyglotWatcherV2.Server do
  use GenServer

  alias PolyglotWatcherV2.{
    CommandLineArguments,
    EnvironmentVariables,
    TraverseActionsTree,
    Determine,
    FSWatch,
    Inotifywait,
    Puts,
    UserInput,
    Result,
    StartupMessage
  }

  @process_name :server

  @default_options [name: @process_name]

  @initial_state %{
    port: nil,
    ignore_file_changes: false,
    starting_dir: nil,
    elixir: %{mode: :default, failures: []},
    rust: %{mode: :default}
  }

  @supported_oss %{
    {:unix, :darwin} => :mac,
    {:unix, :linux} => :linux
  }

  @os_watchers %{linux: Inotifywait, mac: FSWatch}

  @zombie_killer "#{:code.priv_dir(:polyglot_watcher_v2)}/zombie_killer"

  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [@default_options]}
    }
  end

  def start_link(genserver_options \\ @default_options) do
    GenServer.start_link(__MODULE__, nil, genserver_options)
  end

  @impl true
  def init(_ignored_init_arg \\ nil) do
    {:ok, %{}}
    |> Result.and_then(&determine_os/1)
    |> Result.and_then(&read_env_vars/1)
    |> Result.and_then(&parse_cli_args/1)
    |> case do
      {:ok, setup} ->
        init_with_setup(setup)

      {:error, error} ->
        Puts.on_new_line(error, :red)
        {:stop, error}
    end
  end

  defp read_env_vars(acc) do
    case EnvironmentVariables.read() do
      {:ok, env_vars} ->
        {:ok, Map.merge(acc, env_vars)}

      error ->
        error
    end
  end

  defp parse_cli_args(acc) do
    case CommandLineArguments.parse(acc.cli_args) do
      {:ok, cli_args} ->
        {:ok, Map.replace(acc, :cli_args, cli_args)}

      error ->
        error
    end
  end

  defp init_with_setup(%{os: os, path: path, cli_args: cli_args}) do
    watcher = Map.fetch!(@os_watchers, os)

    if Application.get_env(:polyglot_watcher_v2, :put_watcher_startup_message) do
      Puts.on_new_line(watcher.startup_message(), :magenta)
    end

    EnvironmentVariables.put("PATH", path)

    port = Port.open({:spawn_executable, @zombie_killer}, args: watcher.startup_command())

    server_state =
      Map.merge(
        @initial_state,
        %{os: os, port: port, starting_dir: File.cwd!(), watcher: watcher}
      )

    server_state =
      cli_args
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

  @impl true
  def handle_call({:user_input, user_input}, _from, state) do
    state =
      user_input
      |> UserInput.determine_actions(state)
      |> TraverseActionsTree.execute_all()

    listen_for_user_input()
    {:noreply, state}
  end

  defp determine_os(acc) do
    os = :os.type()

    case Map.get(@supported_oss, os) do
      nil -> {:error, "I don't support your operating system '#{inspect(os)}', so I'm exiting"}
      supported_os -> {:ok, Map.put(acc, :os, supported_os)}
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
