defmodule PolyglotWatcherV2.Support.Mocks.ConfigFileMock do
  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @default_config_contents Const.default_config_contents()

  def read_valid do
    Mimic.expect(
      FileWrapper,
      :read,
      1,
      fn "/home/default_mocked_expand_path/.config/polyglot_watcher_v2/config.yml" ->
        {:ok, @default_config_contents}
      end
    )
  end

  def read_failed do
    Mimic.expect(
      FileWrapper,
      :read,
      1,
      fn "/home/default_mocked_expand_path/.config/polyglot_watcher_v2/config.yml" ->
        {:error, :enoent}
      end
    )
  end
end
