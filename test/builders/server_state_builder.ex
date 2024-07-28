defmodule PolyglotWatcherV2.ServerStateBuilder do
  alias PolyglotWatcherV2.Inotifywait

  def build do
    %{
      port: nil,
      ignore_file_changes: false,
      elixir: %{mode: :default, failures: []},
      rust: %{mode: :default},
      os: :linux,
      watcher: Inotifywait,
      starting_dir: "./",
      files: %{}
    }
  end

  def with_elixir_mode(server_state, mode) do
    put_in(server_state, [:elixir, :mode], mode)
  end

  def with_elixir_failures(server_state, failures) do
    put_in(server_state, [:elixir, :failures], failures)
  end

  def with_rust_mode(server_state, mode) do
    put_in(server_state, [:rust, :mode], mode)
  end

  def with_claude_api_key(server_state, claude_api_key) do
    put_in(server_state, [:claude_api_key], claude_api_key)
  end
end
