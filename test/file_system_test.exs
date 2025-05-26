defmodule PolyglotWatcherV2.FileSystemTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{FilePath, FileSystem}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  describe "read/1" do
    test "calls FileWrapper.read/1" do
      Mimic.expect(FileWrapper, :read, fn "path" ->
        {:ok, "contents"}
      end)

      assert FileSystem.read("path") == {:ok, "contents"}
    end

    test "can handle %FilePath{}s as input" do
      Mimic.expect(FileWrapper, :read, fn "script.sh" ->
        {:ok, "contents"}
      end)

      assert FileSystem.read(%FilePath{path: "script", extension: "sh"}) == {:ok, "contents"}
    end
  end
end
