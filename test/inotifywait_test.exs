defmodule PolyglotWatcherV2.InotifywaitTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{FilePath, Inotifywait}

  describe "parse_std_out/1" do
    test "can dedupe & return a file path" do
      # std_out = "./lib/ CLOSE_WRITE,CLOSE 4913\n"
      std_out = "./lib/ CLOSE_WRITE,CLOSE server.ex\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} ==
               Inotifywait.parse_std_out(std_out, working_dir)
    end
  end
end
