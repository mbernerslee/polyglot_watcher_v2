defmodule PolyglotWatcherV2.ServerStateBuilder do
  alias PolyglotWatcherV2.Inotifywait

  def build do
    %{
      port: nil,
      ignore_file_changes: false,
      elixir: %{mode: :default},
      os: :linux,
      watcher: Inotifywait,
      starting_dir: "./"
    }
  end
end
