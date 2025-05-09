defmodule PolyglotWatcherV2.FileSystemTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{FilePath, FileSystem, ServerStateBuilder}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  describe "read_and_persist/3" do
    test "given a path which exists on the system & server state, we persist it in the server state" do
      path = "some/path/to/file"
      key = :lib
      contents = "some cool file contents"

      Mimic.expect(FileWrapper, :read, fn this_path ->
        assert this_path == path
        {:ok, contents}
      end)

      server_state = ServerStateBuilder.build()

      assert {0, new_server_state} = FileSystem.read_and_persist(path, key, server_state)

      assert put_in(server_state, [:files, key], %{contents: contents, path: path}) ==
               new_server_state
    end

    test "given a path which DOES NOT exist on the system & server state, we do not persist it in the server state & return exit code 1" do
      path = "some/path/to/file"
      key = :lib

      Mimic.expect(FileWrapper, :read, fn this_path ->
        assert this_path == path
        :error
      end)

      server_state = ServerStateBuilder.build()

      assert {:error, server_state} ==
               FileSystem.read_and_persist(path, key, server_state)
    end

    test "given existing persisted files, we can persist another under a different key" do
      old_path = "some/path/to/old_file"
      old_key = :lib
      old_contents = "some cool old file contents"

      new_path = "new/path/to/new_file"
      new_key = :test
      new_contents = "some cool new file contents"

      Mimic.expect(FileWrapper, :read, fn this_path ->
        assert this_path == new_path
        {:ok, new_contents}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(old_key, %{contents: old_contents, path: old_path})

      assert {0, new_server_state} = FileSystem.read_and_persist(new_path, new_key, server_state)

      assert %{
               server_state
               | files: %{
                   new_key => %{contents: new_contents, path: new_path},
                   old_key => %{contents: old_contents, path: old_path}
                 }
             } ==
               new_server_state
    end
  end

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
