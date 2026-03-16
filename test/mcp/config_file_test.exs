defmodule PolyglotWatcherV2.MCP.ConfigFileTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.ConfigFile
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  describe "write/2" do
    test "creates directory, writes tmp file, renames atomically" do
      Mimic.expect(FileWrapper, :mkdir_p, fn ".polyglot_watcher_v2" -> :ok end)

      Mimic.expect(FileWrapper, :write, fn ".polyglot_watcher_v2/config.json.tmp", content ->
        decoded = Jason.decode!(content)
        assert decoded == %{"mcp_tcp_port" => 5123, "pid" => 12345}
        :ok
      end)

      Mimic.expect(FileWrapper, :rename, fn
        ".polyglot_watcher_v2/config.json.tmp", ".polyglot_watcher_v2/config.json" -> :ok
      end)

      assert :ok = ConfigFile.write(5123, 12345)
    end
  end

  describe "read/0" do
    test "reads and parses config file" do
      Mimic.expect(FileWrapper, :read, fn ".polyglot_watcher_v2/config.json" ->
        {:ok, ~s({"mcp_tcp_port": 5123, "pid": 12345})}
      end)

      assert {:ok, %{"mcp_tcp_port" => 5123, "pid" => 12345}} = ConfigFile.read()
    end

    test "returns :error when file doesn't exist" do
      Mimic.expect(FileWrapper, :read, fn ".polyglot_watcher_v2/config.json" ->
        {:error, :enoent}
      end)

      assert :error = ConfigFile.read()
    end

    test "returns :error when file contains invalid JSON" do
      Mimic.expect(FileWrapper, :read, fn ".polyglot_watcher_v2/config.json" ->
        {:ok, "not valid json"}
      end)

      assert :error = ConfigFile.read()
    end
  end

  describe "delete/0" do
    test "removes tmp file and config file" do
      Mimic.expect(FileWrapper, :rm_rf, fn ".polyglot_watcher_v2/config.json.tmp" -> {:ok, []} end)
      Mimic.expect(FileWrapper, :rm_rf, fn ".polyglot_watcher_v2/config.json" -> {:ok, []} end)

      assert ConfigFile.delete()
    end
  end
end
