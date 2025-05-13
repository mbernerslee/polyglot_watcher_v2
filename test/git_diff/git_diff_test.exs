defmodule PolyglotWatcherV2.GitDiffTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{GitDiff, SystemCall}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  describe "run/3" do
    test "similarly to run/4, but accepts a list of search/replace strings instead" do
      old_contents_lib = """
      defmodule Lib do
        def hello, do: "world"
        def goodbye, do: "farewell"
      end
      """

      search_replace_lib = [
        %{
          search: "def hello, do: \"world\"",
          replace: "def hello, do: \"universe\""
        },
        %{
          search: "def goodbye, do: \"farewell\"",
          replace: "def goodbye, do: \"see you later\""
        }
      ]

      old_contents_test = """
      defmodule Test do
        def some, do: "test"
        def other, do: "test thing"
      end
      """

      search_replace_test = [
        %{
          search: "def some, do: \"test\"",
          replace: "def some_new, do: \"thingey\""
        },
        %{
          search: "def other, do: \"test thing\"",
          replace: "def other_new, do: \"other new thingey\""
        }
      ]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemCall, :cmd, 2, fn
        "git",
        [
          "diff",
          "--no-index",
          "--color",
          "/tmp/polyglot_watcher_v2_old_lib",
          "/tmp/polyglot_watcher_v2_new_lib"
        ] ->
          {
            """
            diff --git a/old b/new
            index 1234567..abcdefg 100644
            --- a/old
            +++ b/new
            @@ -1,4 +1,4 @@
             defmodule Lib do
            -  def hello, do: "world"
            -  def goodbye, do: "farewell"
            +  def hello, do: "universe"
            +  def goodbye, do: "see you later"
             end
            """,
            1
          }

        "git",
        [
          "diff",
          "--no-index",
          "--color",
          "/tmp/polyglot_watcher_v2_old_test",
          "/tmp/polyglot_watcher_v2_new_test"
        ] ->
          {
            """
            diff --git a/old b/new
            index 1234567..abcdefg 100644
            --- a/old
            +++ b/new
            @@ -1,4 +1,4 @@
             defmodule Lib do
            -  def some, do: "test"
            -  def other, do: "test thing"
            +  def some_new, do: "thingey"
            +  def other_new, do: "other new thingey"
             end
            """,
            1
          }
      end)

      expected_diff_lib =
        """
        ────────────────────────
        Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def hello, do: \"world\"
        -  def goodbye, do: \"farewell\"
        +  def hello, do: \"universe\"
        +  def goodbye, do: \"see you later\"
         end
        ────────────────────────
        """

      expected_diff_test =
        """
        ────────────────────────
        Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def some, do: \"test\"
        -  def other, do: \"test thing\"
        +  def some_new, do: \"thingey\"
        +  def other_new, do: \"other new thingey\"
         end
        ────────────────────────
        """

      Mimic.expect(FileWrapper, :rm_rf, 4, fn
        "/tmp/polyglot_watcher_v2_old_lib" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_new_lib" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_old_test" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_new_test" = path ->
          {:ok, [path]}
      end)

      assert {:ok, %{lib: actual_lib_diff, test: actual_test_diff}} =
               GitDiff.run(%{
                 lib: %{contents: old_contents_lib, search_replace: search_replace_lib},
                 test: %{contents: old_contents_test, search_replace: search_replace_test}
               })

      assert expected_diff_lib == actual_lib_diff
      assert expected_diff_test == actual_test_diff
    end

    test "when we're not searching for the entire file, we produce the diff we expect" do
      old_contents = """
      defmodule Example do
        def hello do
          IO.puts("Hello, world!")
        end

        def goodbye do
          IO.puts("Goodbye!")
        end
      end
      """

      search_replace = [
        %{
          search: "def hello do\n    IO.puts(\"Hello, world!\")\n  end",
          replace: "def hello do\n    IO.puts(\"Hello, universe!\")\n  end"
        }
      ]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemCall, :cmd, fn "git",
                                        [
                                          "diff",
                                          "--no-index",
                                          "--color",
                                          "/tmp/polyglot_watcher_v2_old_example",
                                          "/tmp/polyglot_watcher_v2_new_example"
                                        ] ->
        {
          """
          diff --git a/old b/new
          index 1234567..abcdefg 100644
          --- a/old
          +++ b/new
          @@ -1,6 +1,6 @@
           defmodule Example do
             def hello do
          -    IO.puts("Hello, world!")
          +    IO.puts("Hello, universe!")
             end

             def goodbye do
          """,
          0
        }
      end)

      Mimic.expect(FileWrapper, :rm_rf, 2, fn path -> {:ok, [path]} end)

      expected_diff = """
      ────────────────────────
      Lines: 1 - 6
      ────────────────────────
       defmodule Example do
         def hello do
      -    IO.puts(\"Hello, world!\")
      +    IO.puts(\"Hello, universe!\")
         end

         def goodbye do
      ────────────────────────
      """

      assert {:ok, %{example: actual_diff}} =
               GitDiff.run(%{
                 example: %{contents: old_contents, search_replace: search_replace}
               })

      assert expected_diff == actual_diff
    end

    test "if writing the 'old' file fails, return an error" do
      old_contents = "Some content"
      search_replace = [%{search: "Some", replace: "New"}]

      Mimic.expect(FileWrapper, :write, 1, fn
        "/tmp/polyglot_watcher_v2_old_example", _contents ->
          {:error, :eacces}
      end)

      Mimic.reject(&SystemCall.cmd/2)

      Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)

      assert {:error, {:failed_to_write_tmp_file, _, :eacces}} =
               GitDiff.run(%{
                 example: %{contents: old_contents, search_replace: search_replace}
               })
    end

    test "if writing the 'new' file fails, return an error" do
      old_contents = "Some content"
      search_replace = [%{search: "Some", replace: "New"}]

      Mimic.expect(FileWrapper, :write, 2, fn
        "/tmp/polyglot_watcher_v2_new_example", _contents ->
          {:error, :eacces}

        "/tmp/polyglot_watcher_v2_old_example", _contents ->
          :ok
      end)

      Mimic.reject(&SystemCall.cmd/2)

      Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)

      assert {:error, {:failed_to_write_tmp_file, _, :eacces}} =
               GitDiff.run(%{
                 example: %{contents: old_contents, search_replace: search_replace}
               })
    end

    test "if the git diff returns some error output, then return an error" do
      old_contents = "Some content"
      search_replace = [%{search: "Some", replace: "New"}]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemCall, :cmd, fn "git", _ ->
        {"fatal: error occurred", 1}
      end)

      Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)

      assert {:error, :git_diff_parsing_error} ==
               GitDiff.run(%{
                 example: %{contents: old_contents, search_replace: search_replace}
               })
    end

    test "if the read file contents does not contain the search text, then return error" do
      old_contents = "Some content that doesn't match"
      search_replace = [%{search: "Non-existent text", replace: "New text"}]

      Mimic.reject(&FileWrapper.write/2)

      Mimic.reject(&SystemCall.cmd/2)

      Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)

      assert {:error, {:search_failed, "Non-existent text", "New text"}} ==
               GitDiff.run(%{
                 example: %{contents: old_contents, search_replace: search_replace}
               })
    end

    # TODO consider if this is wise to remove
    # test "if the read file contents contains the search text twice, then return error" do
    #  old_contents = "Some content that matches twice. Some content that matches twice."
    #  search_replace = [%{search: "Some content that matches twice", replace: "New text"}]

    #  Mimic.reject(&FileWrapper.write/2)
    #  Mimic.reject(&SystemCall.cmd/2)

    #  Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)

    #  assert {:error, {:search_multiple_matches, "Some content that matches twice", "New text"}} ==
    #           GitDiff.run(%{
    #             example: %{contents: old_contents, search_replace: search_replace}
    #           })
    # end

    test "when the git diff is not in a format that we can parse, return an error" do
      old_contents = "Some content"
      search_replace = [%{search: "Some", replace: "New"}]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemCall, :cmd, fn "git", _ ->
        {"This is not a valid git diff format", 0}
      end)

      Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)

      assert {:error, :git_diff_parsing_error} ==
               GitDiff.run(%{
                 example: %{contents: old_contents, search_replace: search_replace}
               })
    end
  end
end
