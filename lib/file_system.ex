defmodule PolyglotWatcherV2.FileSystem.FileWrapper.Real do
  def read(path), do: File.read(path)
  def write(path, content), do: File.write(path, content)
  def rm_rf(path), do: File.rm_rf(path)
  def cwd!, do: File.cwd!()
  def mkdir_p(path), do: File.mkdir_p(path)
  def exists?(path), do: File.exists?(path)
end

defmodule PolyglotWatcherV2.FileSystem.FileWrapper.Fake do
  def read(_path), do: {:ok, "default fake mocked file contents"}
  def write(_path, _content), do: :ok
  def rm_rf(_path), do: :ok
  def cwd!, do: "/home/mocked/fake/response"
  def mkdir_p(_path), do: :ok
  def exists?(_path), do: true
end

defmodule PolyglotWatcherV2.FileSystem.FileWrapper do
  def read(path), do: module().read(path)
  def write(path, content), do: module().write(path, content)
  def rm_rf(path), do: module().rm_rf(path)
  def cwd!, do: module().cwd!()
  def mkdir_p(path), do: module().mkdir_p(path)
  def exists?(path), do: module().exists?(path)

  defp module do
    if Application.get_env(:polyglot_watcher_v2, :use_real_file_wrapper_module, true) do
      PolyglotWatcherV2.FileSystem.FileWrapper.Real
    else
      PolyglotWatcherV2.FileSystem.FileWrapper.Fake
    end
  end
end

defmodule PolyglotWatcherV2.FileSystem do
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.FilePath

  def read_and_persist(path, key, server_state) do
    case FileWrapper.read(path) do
      {:ok, contents} ->
        {0, persist_file(server_state, key, contents, path)}

      error ->
        {error, server_state}
    end
  end

  def read(%FilePath{} = file_path), do: file_path |> FilePath.stringify() |> read()
  def read(path), do: FileWrapper.read(path)

  def mkdir_p(path), do: FileWrapper.mkdir_p(path)

  def write(path, content), do: FileWrapper.write(path, content)
  def rm_rf(path), do: FileWrapper.rm_rf(path)
  def exists?(path), do: FileWrapper.exists?(path)

  defp persist_file(server_state, key, contents, path) do
    Map.update!(server_state, :files, fn files ->
      Map.put(files, key, %{contents: contents, path: path})
    end)
  end
end
