defmodule PolyglotWatcherV2.ServerStateBuilder do
  alias PolyglotWatcherV2.Inotifywait

  def build do
    %{
      port: nil,
      ignore_file_changes: false,
      elixir: %{mode: :default, failures: []},
      os: :linux,
      watcher: Inotifywait,
      starting_dir: "./"
    }
  end

  def with_elixir_mode(server_state, mode) do
    put_in(server_state, [:elixir, :mode], mode)
  end

  def with_elixir_failures(server_state, failures) do
    put_in(server_state, [:elixir, :failures], failures)
  end
end
