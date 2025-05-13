defmodule PolyglotWatcherV2.GitDiff.ParserTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.GitDiff.Parser

  describe "parse/1" do
    test "given a valid git diff output with 1 hunk in it, the expected output is returned" do
      raw =
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

      expected =
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

      assert {:ok, expected} == Parser.parse(raw)
    end

    test "when the last line is not a newline its ok" do
      raw =
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
        |> String.trim_trailing()

      expected =
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

      assert {:ok, expected} == Parser.parse(raw)
    end

    # apparently this is possible. see link
    # https://stackoverflow.com/questions/2529441/how-to-read-the-output-from-git-diff
    test "when there's no number of lines, it means there's only 1" do
      raw =
        """
        diff --git a/tmp/polyglot_watcher_v2_old b/tmp/polyglot_watcher_v2_new
        index 53fea5a..ed29468 100644
        --- a/tmp/polyglot_watcher_v2_old
        +++ b/tmp/polyglot_watcher_v2_new
        @@ -1 +1 @@
        -      text
        +      "cool " <> text
        """

      expected =
        """
        ────────────────────────
        Line: 1
        ────────────────────────
        -      text
        +      "cool " <> text
        ────────────────────────
        """

      assert {:ok, expected} == Parser.parse(raw)
    end

    test "can handle diffs that aren't at the top of the file" do
      raw =
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

      expected =
        """
        ────────────────────────
        Lines: 11 - 17
        ────────────────────────
                                                                      {:none, server_state} ->
               case language_module.determine_actions(file_path, server_state) do
                 {:none, server_state} -> {:cont, {:none, server_state}}
        -        {actions, server_state} -> cool replacement
        +        {actions, server_state} -> {:halt, {actions, server_state}}
               end
             end)
           end
        ────────────────────────
        """

      assert {:ok, expected} == Parser.parse(raw)
    end

    test "can parse multiple hunks" do
      raw =
        """
        \e[1mdiff --git a/tmp/polyglot_watcher_v2_old_test_elixir_claude_ai_replace_mode_api_call_test.exs b/tmp/polyglot_watcher_v2_new_test_elixir_claude_ai_replace_mode_api_call_test.exs\e[m
        \e[1mindex 76db925..61a95d5 100644\e[m
        \e[1m--- a/tmp/polyglot_watcher_v2_old_test_elixir_claude_ai_replace_mode_api_call_test.exs\e[m
        \e[1m+++ b/tmp/polyglot_watcher_v2_new_test_elixir_claude_ai_replace_mode_api_call_test.exs\e[m
        \e[36m@@ -18,7 +18,7 @@\e[m \e[mdefmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICallTest do\e[m
               lib_contents = \"lib contents OLD LIB\"\e[m
               mix_test_output = \"mix test output\"\e[m
         \e[m
        \e[31m-      raise \"no\"\e[m
        \e[32m+\e[m\e[41m      \e[m
         \e[m
               test_file = %{path: test_path, contents: test_contents}\e[m
               lib_file = %{path: lib_path, contents: lib_contents}\e[m
        \e[36m@@ -370,7 +370,7 @@\e[m \e[mdefmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICallTest do\e[m
         \e[m
               assert {1, new_server_state} = APICall.perform(test_path, server_state)\e[m
         \e[m
        \e[31m-      expected_error = \"Git Diff error: :git_diff_parsing_error\"\e[m
        \e[32m+\e[m\e[32m      expected_error = \"Git Diff error: \\\"im blowing up\\\"\"\e[m
               assert new_server_state.action_error == expected_error\e[m
               assert %{server_state | action_error: expected_error} == new_server_state\e[m
             end\e[m
        """

      expected =
        """
        ────────────────────────
        Lines: 18 - 24
        ────────────────────────
               lib_contents = \"lib contents OLD LIB\"\e[m
               mix_test_output = \"mix test output\"\e[m
         \e[m
        \e[31m-      raise \"no\"\e[m
        \e[32m+\e[m\e[41m      \e[m
         \e[m
               test_file = %{path: test_path, contents: test_contents}\e[m
               lib_file = %{path: lib_path, contents: lib_contents}\e[m
        ────────────────────────
        Lines: 370 - 376
        ────────────────────────
         \e[m
               assert {1, new_server_state} = APICall.perform(test_path, server_state)\e[m
         \e[m
        \e[31m-      expected_error = \"Git Diff error: :git_diff_parsing_error\"\e[m
        \e[32m+\e[m\e[32m      expected_error = \"Git Diff error: \\\"im blowing up\\\"\"\e[m
               assert new_server_state.action_error == expected_error\e[m
               assert %{server_state | action_error: expected_error} == new_server_state\e[m
             end\e[m
        ────────────────────────
        """

      assert {:ok, expected} == Parser.parse(raw)
    end
  end
end

#TODO fix parsing fail:
#────────────────────────
#Lines: 429 - 439
#────────────────────────
#                })
#     end
#
#-    test "if the read file contents contains the search text twice, replace them all (scary)" do
#+    test "if the read file contents contains the search text twice, replace them all" do
#       old_contents = "Some content that matches twice. Some content that matches twice."
#       search_replace = [%{search: "Some content that matches twice", replace: "New text"}]
#
#-      raise "write me"
#+      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)
#+
#+      Mimic.expect(SystemCall, :cmd, fn "git", _ ->
#+        {
#+          """
#+          diff --git a/old b/new
#+          index 1234567..abcdefg 100644
#+          --- a/old
#+          +++ b/new
#────────────────────────
#Line: 1
#────────────────────────
#+          -Some content that matches twice. Some content that matches twice.
#+          +New text. New text.
#+          """,
#+          0
#+        }
#+      end)
#+
#+      Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)
#+
#+      expected_diff = """
#+      ────────────────────────
#+      Lines: 1 - 1
#+      ────────────────────────
#+      -Some content that matches twice. Some content that matches twice.
#+      +New text. New text.
#+      ────────────────────────
#+      """
#+
#+      assert {:ok, %{"example" => actual_diff}} =
#+               GitDiff.run(%{
#+                 "example" => %{contents: old_contents, search_replace: search_replace}
#+               })
#+
#+      assert expected_diff == actual_diff
#     end
#
#     test "when the git diff is not in a format that we can parse, return an error" do
#────────────────────────
