defmodule PolyglotWatcherV2.FilePathTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.FilePath

  describe "build/2" do
    test "works with legit looking file paths with extensions and a relative path" do
      file_path = "/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex"

      relative_path = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} =
               FilePath.build(file_path, relative_path)
    end

    test "ignores paths without a file extension" do
      file_path = "too/cool/for/a/file/extension"
      relative_path = "doesnt/matter"

      assert :ignore == FilePath.build(file_path, relative_path)
    end

    test "trims trailing tildas ~" do
      file_path = "/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex~"

      relative_path = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} =
               FilePath.build(file_path, relative_path)
    end
  end
end
