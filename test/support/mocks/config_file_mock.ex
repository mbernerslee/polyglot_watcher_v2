defmodule PolyglotWatcherV2.Support.Mocks.ConfigFileMock do
  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @path Const.config_file_path()
  @default_config_contents Const.default_config_contents()

  def read_valid do
    path = Path.expand(@path)

    Mimic.expect(FileWrapper, :read, 1, fn ^path ->
      {:ok, @default_config_contents}
    end)
  end

  def read_failed do
    path = Path.expand(@path)

    Mimic.expect(FileWrapper, :read, 1, fn ^path ->
      {:error, :enoent}
    end)
  end
end
