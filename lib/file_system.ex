defmodule PolyglotWatcherV2.FileSystem.FileWrapper do
  def read(path), do: File.read(path)
end

defmodule PolyglotWatcherV2.FileSystem do
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  def read_and_persist(path, key, server_state) do
    case FileWrapper.read(path) do
      {:ok, contents} ->
        {0, persist_file(server_state, key, contents, path)}

      error ->
        {error, server_state}
    end
  end

  def read(path), do: FileWrapper.read(path)

  defp persist_file(server_state, key, contents, path) do
    Map.update!(server_state, :files, fn files ->
      Map.put(files, key, %{contents: contents, path: path})
    end)
  end
end
