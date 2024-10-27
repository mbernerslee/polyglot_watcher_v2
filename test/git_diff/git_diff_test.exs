defmodule PolyglotWatcherV2.GitDiffTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{GitDiff, Puts, ServerStateBuilder, SystemCall}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  # TODO continue here! More tests needed!
  # actually generate a proper replacement file.. including the unchanged parts of the time
  describe "run/4" do
    test "given a file path, search and replacement texts and server_state, puts a git diff onto the screen" do
      file_path = "lib/cool.ex"

      search = """
        defmodule Cool do
          def cool(text) do
            text
          end
        end
      """

      replace = """
        defmodule Cool do
          def cool(text) do
            "cool " <> text
          end
        end
      """

      server_state = ServerStateBuilder.build()

      Mimic.expect(FileWrapper, :read, fn this_path ->
        assert file_path == this_path
        {:ok, search}
      end)

      Mimic.expect(FileWrapper, :write, fn old_path, content ->
        assert old_path == "/tmp/polyglot_watcher_v2_old"
        assert content == search
        :ok
      end)

      Mimic.expect(FileWrapper, :write, fn new_path, content ->
        assert new_path == "/tmp/polyglot_watcher_v2_new"
        assert content == replace
        :ok
      end)

      Mimic.expect(SystemCall, :cmd, fn cmd, args ->
        assert cmd == "git"

        assert args == [
                 "diff",
                 "--no-index",
                 "--color",
                 "/tmp/polyglot_watcher_v2_old",
                 "/tmp/polyglot_watcher_v2_new"
               ]

        std_out =
          """
          diff --git a/tmp/polyglot_watcher_v2_old b/tmp/polyglot_watcher_v2_new
          index 53fea5a..ed29468 100644
          --- a/tmp/polyglot_watcher_v2_old
          +++ b/tmp/polyglot_watcher_v2_new
          @@ -1,5 +1,5 @@
             defmodule Cool do
               def cool(text) do
          -      text
          +      "cool " <> text
               end
             end
          """

        {std_out, 1}
      end)

      Mimic.expect(Puts, :on_new_line_unstyled, fn output ->
        assert output ==
                 """
                 diff --git a/tmp/polyglot_watcher_v2_old b/tmp/polyglot_watcher_v2_new
                 index 53fea5a..ed29468 100644
                 --- a/tmp/polyglot_watcher_v2_old
                 +++ b/tmp/polyglot_watcher_v2_new
                 @@ -1,5 +1,5 @@
                    defmodule Cool do
                      def cool(text) do
                 -      text
                 +      "cool " <> text
                      end
                    end
                 """

        :ok
      end)

      Mimic.expect(FileWrapper, :rm_rf, fn path ->
        assert path == "/tmp/polyglot_watcher_v2_old"
        {:ok, [path]}
      end)

      Mimic.expect(FileWrapper, :rm_rf, fn path ->
        assert path == "/tmp/polyglot_watcher_v2_new"
        {:ok, [path]}
      end)

      assert {0, _new_server_state} = GitDiff.run(file_path, search, replace, server_state)
    end
  end
end
