defmodule PolyglotWatcherV2.FileSystemWatchers.FSWatchTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.FilePath
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

    test "prefers .ex file over temp file reported first (Claude Code atomic write pattern)" do
      # Claude Code writes to file.ex.tmp.PID.TIMESTAMP then renames to file.ex
      # fswatch reports the temp file first, then the actual file
      std_out =
        "/Users/berners/src/project/lib/server.ex.tmp.75322.1769781659081\n/Users/berners/src/project/lib/server.ex\n"

      working_dir = "/Users/berners/src/project"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end

    test "prefers .exs file over temp file reported first" do
      std_out =
        "/Users/berners/src/project/test/server_test.exs.tmp.12345.9999999\n/Users/berners/src/project/test/server_test.exs\n"

      working_dir = "/Users/berners/src/project"

      assert {:ok, %FilePath{path: "test/server_test", extension: "exs"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end

    test "prefers .rs file over temp file reported first" do
      std_out =
        "/Users/berners/src/project/src/main.rs.tmp.11111.22222\n/Users/berners/src/project/src/main.rs\n"

      working_dir = "/Users/berners/src/project"

      assert {:ok, %FilePath{path: "src/main", extension: "rs"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end

    test "returns source file even when temp file has valid-looking extension" do
      # Edge case: temp file before source file, both parseable
      std_out =
        "/Users/berners/src/project/lib/.server.ex.swp\n/Users/berners/src/project/lib/server.ex\n"

      working_dir = "/Users/berners/src/project"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end

    test "falls back to first valid file when no source extensions present" do
      std_out =
        "/Users/berners/src/project/lib/4913\n/Users/berners/src/project/docs/readme.md\n/Users/berners/src/project/config/settings.json\n"

      working_dir = "/Users/berners/src/project"

      assert {:ok, %FilePath{path: "docs/readme", extension: "md"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end
  end
end
