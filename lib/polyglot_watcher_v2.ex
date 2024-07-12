defmodule PolyglotWatcherV2 do
  alias PolyglotWatcherV2.Server

  def start(_type, _command_line_args \\ []) do
    children = [Server.child_spec()]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
