defmodule PolyglotWatcherV2.FilePathTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.FilePath

  describe "build/2" do
    test "works with legit looking file paths with extensions and a relative path" do
      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} ==
               FilePath.build("lib/server.ex")
    end

    test "works with legit absolute paths paths" do
      assert {:ok, %FilePath{path: "/home/berners/src/cool/lib/server", extension: "ex"}} ==
               FilePath.build("/home/berners/src/cool/lib/server.ex")
    end

    test "ignores paths without a file extension" do
      assert :ignore == FilePath.build("lib/no_extension")
    end

    test "trims trailing tildas ~" do
      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} ==
               FilePath.build("lib/server.ex~")
    end

    test "handles paths with multiple ." do
      assert {:ok, %FilePath{path: ".lib/server", extension: "ex"}} ==
               FilePath.build(".lib/server.ex")
    end
  end
end
