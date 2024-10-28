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
  end
end
