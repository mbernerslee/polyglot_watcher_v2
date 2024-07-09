defmodule PolyglotWatcherV2 do
  alias PolyglotWatcherV2.Server

  def main(command_line_args \\ []) do
    run(command_line_args)
    :timer.sleep(:infinity)
  end

  def start(_type, command_line_args \\ []) do
    # TODO test this
    # TODO e2e test that release works
    if path = System.get_env("POLYGLOT_WATCHER_V2_PATH") do
      System.put_env("PATH", path)
    else
      IO.puts(
        "I need the environment variable POLYGLOT_WATCHER_V2_PATH to be set, and it wasn't, so I'm givng up. This shouldn't happen :-("
      )

      System.halt(1)
    end

    run(command_line_args)
  end

  defp run(command_line_args) do
    children = [Server.child_spec(command_line_args)]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
