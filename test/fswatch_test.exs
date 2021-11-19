defmodule PolyglotWatcherV2.FSWatchTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{FilePath, FSWatch}

  describe "parse_std_out/1" do
    test "can dedupe & return a file path" do
      std_out =
        "/Users/bernersiscool/src/polyglot_watcher_v2/lib/4913\n/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex\n/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex~\n/Users/bernersiscool/src/polyglot_watcher_v2/lib/server.ex\n"

      working_dir = "/Users/bernersiscool/src/polyglot_watcher_v2"

      assert {:ok, %FilePath{path: "lib/server", extension: "ex"}} =
               FSWatch.parse_std_out(std_out, working_dir)
    end
  end
end
