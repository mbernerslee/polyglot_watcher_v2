defmodule PolyglotWatcherV2.ShellCommandRunner do
  use GenServer

  def run(command) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, %{command: command, caller_pid: self()})

    receive do
      {:exit, {command_output, exit_code}} -> {command_output, exit_code}
    end
  end

  @impl true
  def init(%{command: command, caller_pid: caller_pid}) do
    port = Port.open({:spawn, command}, [:exit_status])

    {:ok, %{port: port, command_output: "", caller_pid: caller_pid}}
  end

  @impl true
  def handle_info({_port, {:data, command_output}}, state) do
    # this line looks weird and pointless, but it solves elm make output from being wrong
    # and outputting "Main âââ>", instead of "Main ───>"
    # https://elixirforum.com/t/converting-a-list-of-bytes-from-utf-8-or-iso-8859-1-to-elixir-string/20032/2
    command_output = :unicode.characters_to_binary(:erlang.list_to_binary(command_output))

    IO.write(command_output)
    {:noreply, Map.update!(state, :command_output, &(&1 <> command_output))}
  end

  def handle_info({_port, {:exit_status, exit_status}}, state) do
    send(state.caller_pid, {:exit, {state.command_output, exit_status}})
    {:stop, :normal, state}
  end
end
