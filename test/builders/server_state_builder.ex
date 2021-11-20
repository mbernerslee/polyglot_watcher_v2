defmodule PolyglotWatcherV2.ServerStateBuilder do
  def build do
    %{
      port: nil,
      ignore_file_changes: false,
      starting_dir: nil,
      elixir: %{mode: :default}
    }
  end
end
