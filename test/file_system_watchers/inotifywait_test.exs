defmodule PolyglotWatcherV2.FileSystemWatchers.InotifywaitTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.FilePath
  alias PolyglotWatcherV2.FileSystemWatchers.Inotifywait

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

    test "prefers .ex file over temp file reported first (Claude Code atomic write pattern)" do
      std_out =
        "./lib/ CLOSE_WRITE,CLOSE server.ex.tmp.75322.1769781659081\n./lib/ CLOSE_WRITE,CLOSE server.ex\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end

    test "prefers .exs file over temp file reported first" do
      std_out =
        "./test/ CLOSE_WRITE,CLOSE server_test.exs.tmp.12345.9999999\n./test/ CLOSE_WRITE,CLOSE server_test.exs\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "test/server_test", extension: "exs"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end

    test "prefers .rs file over temp file reported first" do
      std_out =
        "./src/ CLOSE_WRITE,CLOSE main.rs.tmp.11111.22222\n./src/ CLOSE_WRITE,CLOSE main.rs\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "src/main", extension: "rs"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end

    test "returns source file even when temp file has valid-looking extension" do
      std_out =
        "./lib/ CLOSE_WRITE,CLOSE .server.ex.swp\n./lib/ CLOSE_WRITE,CLOSE server.ex\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end

    test "falls back to first valid file when no source extensions present" do
      std_out =
        "./lib/ CLOSE_WRITE,CLOSE 4913\n./docs/ CLOSE_WRITE,CLOSE readme.md\n./config/ CLOSE_WRITE,CLOSE settings.json\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "docs/readme", extension: "md"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end
  end
end
