defmodule PolyglotWatcherV2.FileSystemWatchers.FSWatchTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{FilePath, FSWatch}
  alias PolyglotWatcherV2.FileSystemWatchers.FSWatch

  describe "parse_std_out/1" do
    test "can dedupe & return a file path" do
      std_out =
        "/Users/bernersiscool/src/polyglot_watcher_v2/lib/4913\n/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex\n/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex~\n/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end

    test "returns the first legit looking file path" do
      std_out =
        "/Users/bernersiscool/src/polyglot_watcher_v2/lib/4913\n/Users/bernersiscool/src/polyglot_watcher_v2/first/legit.txt\n/Users/bernersiscool/src/polyglot_watcher_v2/second/legit.txt\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "first/legit", extension: "txt"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end

    test "returns ignore if no legit looking file paths" do
      std_out = "/Users/bernersiscool/src/polyglot_watcher_v2/lib/4913\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert :ignore == FSWatch.parse_std_out(std_out, working_dir)
    end

    test "finds paths relative to the working_dir" do
      std_out = "/first/second/third/fourth/fifth/file_name.txt\n"

      working_dir = "/first/second/third/fourth"

      assert {:ok, %FilePath{path: "fifth/file_name", extension: "txt"}} ==
               FSWatch.parse_std_out(std_out, working_dir)

      working_dir = "/first"

      assert {:ok, %FilePath{path: "second/third/fourth/fifth/file_name", extension: "txt"}} ==
               FSWatch.parse_std_out(std_out, working_dir)
    end
  end
end
