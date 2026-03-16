defmodule PolyglotWatcherV2.MCP.ConfigFile do
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @dir ".polyglot_watcher_v2"
  @filename "config.json"
  @tmp_filename "config.json.tmp"

  def path, do: Path.join(@dir, @filename)
  defp tmp_path, do: Path.join(@dir, @tmp_filename)

  def write(port, pid) do
    content = Jason.encode!(%{"mcp_tcp_port" => port, "pid" => pid})

    with :ok <- FileWrapper.mkdir_p(@dir),
         :ok <- FileWrapper.write(tmp_path(), content),
         :ok <- FileWrapper.rename(tmp_path(), path()) do
      :ok
    end
  end

  def read do
    with {:ok, content} <- FileWrapper.read(path()),
         {:ok, decoded} <- Jason.decode(content) do
      {:ok, decoded}
    else
      _ -> :error
    end
  end

  def delete do
    FileWrapper.rm_rf(tmp_path())
    FileWrapper.rm_rf(path())
  end
end
