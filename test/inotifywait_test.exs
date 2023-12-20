defmodule PolyglotWatcherV2.InotifywaitTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{FilePath, Inotifywait}

  describe "parse_std_out/1" do
    test "can return a file path" do
      std_out = "./lib/ CLOSE_WRITE,CLOSE server.ex\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end

    test "ignores unexpected janky input" do
      std_out = "some nonesense that I did not expect"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert :ignore == Inotifywait.parse_std_out(std_out, working_dir)
    end

    test "any three space-separated-words are considered legitimate" do
      std_out = "path/ write_operations file.extension"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "path/file", extension: "extension"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end

    test "when there's a output we can't parse to a file, followed by one we can, return the one we can" do
      std_out = "./lib/ CLOSE_WRITE,CLOSE 4913\n./lib/ CLOSE_WRITE,CLOSE server.ex\n"
      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end
  end
end
