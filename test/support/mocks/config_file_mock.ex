defmodule PolyglotWatcherV2.Support.Mocks.ConfigFileMock do
  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.ConfigFile

  @path Const.config_file_path()

  def read_valid do
    Mimic.expect(FileWrapper, :read, 1, fn @path ->
      {:ok, ConfigFile.valid_example()}
    end)
  end

  def read_failed do
    Mimic.expect(FileWrapper, :read, 1, fn @path ->
      {:error, :enoent}
    end)
  end
end
