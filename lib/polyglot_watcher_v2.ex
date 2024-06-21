defmodule PolyglotWatcherV2 do
  alias PolyglotWatcherV2.Server

  def main(command_line_args \\ []) do
    run(command_line_args)
    :timer.sleep(:infinity)
  end

  def start(_type, command_line_args \\ []) do
    run(command_line_args)
  end

  defp run(command_line_args) do
    IO.puts("Starting PolyglotWatcherV2")
    children = [Server.child_spec(command_line_args)]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
