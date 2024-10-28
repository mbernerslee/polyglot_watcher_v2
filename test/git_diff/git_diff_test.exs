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
                 ────────────────────────
                 Lines: 1 - 5
                 ────────────────────────
                    defmodule Cool do
                      def cool(text) do
                 -      text
                 +      "cool " <> text
                      end
                    end
                 ────────────────────────
                 """

        :ok
      end)

      mimic_expect_files_rm_rf()

      assert {0, _new_server_state} = GitDiff.run(file_path, search, replace, server_state)
    end

    test "when we're not searching for the entire file, we produce the diff we expect" do
      file_path = "lib/cool.ex"

      old_file_contents =
        """
        defmodule PolyglotWatcherV2.Determine do
          alias PolyglotWatcherV2.Elixir.Determiner, as: ElixirDeterminer
          alias PolyglotWatcherV2.Rust.Determiner, as: RustDeterminer

          defp languages do
            [ElixirDeterminer, RustDeterminer]
          end

          def actions({:ok, file_path}, server_state) do
            Enum.reduce_while(languages(), {:none, server_state}, fn language_module,
                                                                     {:none, server_state} ->
              case language_module.determine_actions(file_path, server_state) do
                {:none, server_state} -> {:cont, {:none, server_state}}
                {actions, server_state} -> {:halt, {actions, server_state}}
              end
            end)
          end

          def actions(:ignore, server_state) do
            {:none, server_state}
          end
        end

        """

      new_file_contents =
        """
        defmodule PolyglotWatcherV2.Determine do
          alias PolyglotWatcherV2.Elixir.Determiner, as: ElixirDeterminer
          alias PolyglotWatcherV2.Rust.Determiner, as: RustDeterminer

          defp languages do
            [ElixirDeterminer, RustDeterminer]
          end

          def actions({:ok, file_path}, server_state) do
            Enum.reduce_while(languages(), {:none, server_state}, fn language_module,
                                                                     {:none, server_state} ->
              case language_module.determine_actions(file_path, server_state) do
                {:none, server_state} -> {:cont, {:none, server_state}}
                {actions, server_state} -> {:cont, {actions, server_state}}
              end
            end)
          end

          def actions(:ignore, server_state) do
            {:none, server_state}
          end
        end

        """

      search =
        """
                {actions, server_state} -> {:halt, {actions, server_state}}
        """

      replace =
        """
                {actions, server_state} -> {:cont, {actions, server_state}}
        """

      server_state = ServerStateBuilder.build()

      Mimic.expect(FileWrapper, :read, fn this_path ->
        assert file_path == this_path
        {:ok, old_file_contents}
      end)

      Mimic.expect(FileWrapper, :write, fn old_path, content ->
        assert old_path == "/tmp/polyglot_watcher_v2_old"
        assert content == old_file_contents
        :ok
      end)

      Mimic.expect(FileWrapper, :write, fn new_path, content ->
        assert new_path == "/tmp/polyglot_watcher_v2_new"
        assert content == new_file_contents
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
          diff --git a/cool2 b/cool
          index ff69c28..dbaf1b0 100644
          --- a/cool2
          +++ b/cool
          @@ -11,7 +11,7 @@ defmodule PolyglotWatcherV2.Determine do
                                                                        {:none, server_state} ->
                 case language_module.determine_actions(file_path, server_state) do
                   {:none, server_state} -> {:cont, {:none, server_state}}
          -        {actions, server_state} -> cool replacement
          +        {actions, server_state} -> {:halt, {actions, server_state}}
                 end
               end)
             end
          """

        {std_out, 1}
      end)

      Mimic.expect(Puts, :on_new_line_unstyled, fn output ->
        assert output =~ "{:none, server_state}"
        :ok
      end)

      mimic_expect_files_rm_rf()

      assert {0, _new_server_state} = GitDiff.run(file_path, search, replace, server_state)
    end

    test "if writing the 'old' file fails, return an error" do
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

      Mimic.expect(FileWrapper, :read, fn _ ->
        {:ok, "some content"}
      end)

      Mimic.expect(FileWrapper, :write, fn _path, _content ->
        {:error, :eacces}
      end)

      Mimic.reject(&FileWrapper.write/2)
      Mimic.reject(&SystemCall.cmd/2)
      Mimic.reject(&Puts.on_new_line_unstyled/1)

      mimic_expect_files_rm_rf()

      assert {1, new_server_state} = GitDiff.run(file_path, search, replace, server_state)

      expected_error =
        """
        I failed to write to a temporary file, in order to generate a git diff to show you the Claude AI code suggestion.
        Maybe I'm not allowed to write files to /tmp, or it doesn't exist?

        The error was {:error, :eacces}.

        This is terminal to the Claude AI operation I'm afraid so I'm giving up.
        """

      assert Map.put(server_state, :action_error, expected_error) == new_server_state
    end

    test "if writing the 'new' file fails, return an error" do
      file_path = "lib/cool.ex"

      search = """
        defmodule Cool do
          def cool(text) do
            text
          end
        end
      """

      file_contents = search

      replace = """
        defmodule Cool do
          def cool(text) do
            "cool " <> text
          end
        end
      """

      server_state = ServerStateBuilder.build()

      Mimic.expect(FileWrapper, :read, fn _ ->
        {:ok, file_contents}
      end)

      Mimic.expect(FileWrapper, :write, fn _path, _content ->
        :ok
      end)

      Mimic.expect(FileWrapper, :write, fn _path, _content ->
        {:error, :eacces}
      end)

      Mimic.reject(&SystemCall.cmd/2)
      Mimic.reject(&Puts.on_new_line_unstyled/1)

      mimic_expect_files_rm_rf()

      assert {1, new_server_state} = GitDiff.run(file_path, search, replace, server_state)

      expected_error =
        """
        I failed to write to a temporary file, in order to generate a git diff to show you the Claude AI code suggestion.
        Maybe I'm not allowed to write files to /tmp, or it doesn't exist?

        The error was {:error, :eacces}.

        This is terminal to the Claude AI operation I'm afraid so I'm giving up.
        """

      assert Map.put(server_state, :action_error, expected_error) == new_server_state
    end

    test "if writing the reading the file fails, return an error" do
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

      Mimic.expect(FileWrapper, :read, fn _ ->
        {:error, :enoent}
      end)

      Mimic.reject(&FileWrapper.write/2)
      Mimic.reject(&SystemCall.cmd/2)
      Mimic.reject(&Puts.on_new_line_unstyled/1)

      mimic_expect_files_rm_rf()

      assert {1, new_server_state} = GitDiff.run(file_path, search, replace, server_state)

      expected_error =
        """
        I failed to read a file that I was previously lead to believe exists.
        It was lib/cool.ex.

        The error was {:error, :enoent}.

        This is terminal to the Claude AI operation I'm afraid so I'm giving up.
        """

      assert Map.put(server_state, :action_error, expected_error) == new_server_state
    end
  end

  test "if the git diff returns some error output, then put an action error into the state" do
    file_path = "lib/cool.ex"
    search = "old content"
    replace = "new content"
    server_state = ServerStateBuilder.build()

    Mimic.expect(FileWrapper, :read, fn _ -> {:ok, search} end)
    Mimic.expect(FileWrapper, :write, fn _, _ -> :ok end)
    Mimic.expect(FileWrapper, :write, fn _, _ -> :ok end)

    Mimic.expect(SystemCall, :cmd, fn _, _ ->
      {"fatal: git diff error", 1}
    end)

    Mimic.reject(&Puts.on_new_line_unstyled/1)

    mimic_expect_files_rm_rf()

    assert {1, new_server_state} = GitDiff.run(file_path, search, replace, server_state)

    expected_error =
      """
      I failed to find the start of a hunk in the format:
      @@ -1,5 +1,5 @@

      The raw output from git diff was:
      fatal: git diff error

      This is terminal to the Claude AI operation I'm afraid so I'm giving up.
      """

    assert Map.get(new_server_state, :action_error) == expected_error
  end

  defp mimic_expect_files_rm_rf do
    Mimic.expect(FileWrapper, :rm_rf, fn path ->
      assert path == "/tmp/polyglot_watcher_v2_old"
      {:ok, [path]}
    end)

    Mimic.expect(FileWrapper, :rm_rf, fn path ->
      assert path == "/tmp/polyglot_watcher_v2_new"
      {:ok, [path]}
    end)
  end
end
