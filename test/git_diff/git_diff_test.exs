defmodule PolyglotWatcherV2.GitDiffTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{GitDiff, SystemWrapper}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  describe "run/3" do
    test "given file updates with search/replace strings, returns a diff" do
      old_contents_lib = """
      defmodule Lib do
        def hello, do: "world"
        def goodbye, do: "farewell"
      end
      """

      search_replace_lib = [
        %{
          search: "def hello, do: \"world\"",
          replace: "def hello, do: \"universe\"",
          index: 1
        },
        %{
          search: "def goodbye, do: \"farewell\"",
          replace: "def goodbye, do: \"see you later\"",
          index: 2
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
          replace: "def some_new, do: \"thingey\"",
          index: 3
        },
        %{
          search: "def other, do: \"test thing\"",
          replace: "def other_new, do: \"other new thingey\"",
          index: 4
        }
      ]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemWrapper, :cmd, 4, fn
        "git",
        [
          "diff",
          "--no-index",
          "--color",
          "/tmp/polyglot_watcher_v2_old_lib_1",
          "/tmp/polyglot_watcher_v2_new_lib_1"
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
            +  def hello, do: "universe"
             end
            """,
            1
          }

        "git",
        [
          "diff",
          "--no-index",
          "--color",
          "/tmp/polyglot_watcher_v2_old_lib_2",
          "/tmp/polyglot_watcher_v2_new_lib_2"
        ] ->
          {
            """
            diff --git a/old b/new
            index 1234567..abcdefg 100644
            --- a/old
            +++ b/new
            @@ -1,4 +1,4 @@
             defmodule Lib do
            -  def goodbye, do: "farewell"
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
          "/tmp/polyglot_watcher_v2_old_test_3",
          "/tmp/polyglot_watcher_v2_new_test_3"
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
            +  def some_new, do: "thingey"
             end
            """,
            1
          }

        "git",
        [
          "diff",
          "--no-index",
          "--color",
          "/tmp/polyglot_watcher_v2_old_test_4",
          "/tmp/polyglot_watcher_v2_new_test_4"
        ] ->
          {
            """
            diff --git a/old b/new
            index 1234567..abcdefg 100644
            --- a/old
            +++ b/new
            @@ -1,4 +1,4 @@
             defmodule Lib do
            -  def other, do: "test thing"
            +  def other_new, do: "other new thingey"
             end
            """,
            1
          }
      end)

      expected_diff_lib_1 =
        """
        ────────────────────────
        1) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def hello, do: \"world\"
        +  def hello, do: \"universe\"
         end
        ────────────────────────
        """

      expected_diff_lib_2 =
        """
        ────────────────────────
        2) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def goodbye, do: \"farewell\"
        +  def goodbye, do: \"see you later\"
         end
        ────────────────────────
        """

      expected_diff_test_3 =
        """
        ────────────────────────
        3) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def some, do: \"test\"
        +  def some_new, do: \"thingey\"
         end
        ────────────────────────
        """

      expected_diff_test_4 =
        """
        ────────────────────────
        4) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def other, do: \"test thing\"
        +  def other_new, do: \"other new thingey\"
         end
        ────────────────────────
        """

      Mimic.expect(FileWrapper, :rm_rf, 8, fn
        "/tmp/polyglot_watcher_v2_old_lib_1" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_old_lib_2" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_new_lib_1" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_new_lib_2" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_old_test_3" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_new_test_3" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_old_test_4" = path ->
          {:ok, [path]}

        "/tmp/polyglot_watcher_v2_new_test_4" = path ->
          {:ok, [path]}
      end)

      assert {:ok,
              %{
                "lib" => %{1 => actual_lib_diff_1, 2 => actual_lib_diff_2},
                "test" => %{3 => actual_test_diff_3, 4 => actual_test_diff_4}
              }} =
               GitDiff.run([
                 {"lib", %{contents: old_contents_lib, patches: search_replace_lib}},
                 {"test", %{contents: old_contents_test, patches: search_replace_test}}
               ])

      assert expected_diff_lib_1 == actual_lib_diff_1
      assert expected_diff_lib_2 == actual_lib_diff_2
      assert expected_diff_test_3 == actual_test_diff_3
      assert expected_diff_test_4 == actual_test_diff_4
    end

    test "if replace is nil, delete the search text" do
      old_contents_lib = """
      defmodule Lib do
        def hello, do: "world"
        def goodbye, do: "farewell"
      end
      """

      search_replace_lib = [
        %{
          search: "def hello, do: \"world\"",
          replace: nil,
          index: 1
        },
        %{
          search: "def goodbye, do: \"farewell\"",
          replace: nil,
          index: 2
        }
      ]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemWrapper, :cmd, 2, fn
        "git",
        [
          "diff",
          "--no-index",
          "--color",
          "/tmp/polyglot_watcher_v2_old_lib_1",
          "/tmp/polyglot_watcher_v2_new_lib_1"
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
             end
            """,
            1
          }

        "git",
        [
          "diff",
          "--no-index",
          "--color",
          "/tmp/polyglot_watcher_v2_old_lib_2",
          "/tmp/polyglot_watcher_v2_new_lib_2"
        ] ->
          {
            """
            diff --git a/old b/new
            index 1234567..abcdefg 100644
            --- a/old
            +++ b/new
            @@ -1,4 +1,4 @@
             defmodule Lib do
            -  def goodbye, do: "farewell"
             end
            """,
            1
          }
      end)

      expected_diff_lib_1 =
        """
        ────────────────────────
        1) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def hello, do: \"world\"
         end
        ────────────────────────
        """

      expected_diff_lib_2 =
        """
        ────────────────────────
        2) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def goodbye, do: \"farewell\"
         end
        ────────────────────────
        """

      Mimic.expect(FileWrapper, :rm_rf, 4, fn
        path -> {:ok, [path]}
      end)

      assert {:ok, %{"lib" => %{1 => actual_lib_diff_1, 2 => actual_lib_diff_2}}} =
               GitDiff.run([
                 {"lib", %{contents: old_contents_lib, patches: search_replace_lib}}
               ])

      assert expected_diff_lib_1 == actual_lib_diff_1
      assert expected_diff_lib_2 == actual_lib_diff_2
    end

    test "given file update keys with / in them, they are handled" do
      old_contents_lib = """
      defmodule Lib do
        def hello, do: "world"
        def goodbye, do: "farewell"
      end
      """

      search_replace_lib = [
        %{
          search: "def hello, do: \"world\"",
          replace: "def hello, do: \"universe\"",
          index: 1
        },
        %{
          search: "def goodbye, do: \"farewell\"",
          replace: "def goodbye, do: \"see you later\"",
          index: 2
        }
      ]

      Mimic.expect(FileWrapper, :write, 1, fn _, _ -> :ok end)

      Mimic.expect(SystemWrapper, :cmd, 2, fn
        "git",
        [
          _,
          _,
          _,
          "/tmp/polyglot_watcher_v2_old_lib_some_path_ok_1",
          "/tmp/polyglot_watcher_v2_new_lib_some_path_ok_1"
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
            +  def hello, do: "universe"
             end
            """,
            1
          }

        "git",
        [
          _,
          _,
          _,
          "/tmp/polyglot_watcher_v2_old_lib_some_path_ok_2",
          "/tmp/polyglot_watcher_v2_new_lib_some_path_ok_2"
        ] ->
          {
            """
            diff --git a/old b/new
            index 1234567..abcdefg 100644
            --- a/old
            +++ b/new
            @@ -1,4 +1,4 @@
             defmodule Lib do
            -  def goodbye, do: "farewell"
            +  def goodbye, do: "see you later"
             end
            """,
            1
          }
      end)

      expected_diff_lib_1 =
        """
        ────────────────────────
        1) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def hello, do: \"world\"
        +  def hello, do: \"universe\"
         end
        ────────────────────────
        """

      expected_diff_lib_2 =
        """
        ────────────────────────
        2) Lines: 1 - 4
        ────────────────────────
         defmodule Lib do
        -  def goodbye, do: \"farewell\"
        +  def goodbye, do: \"see you later\"
         end
        ────────────────────────
        """

      Mimic.expect(FileWrapper, :rm_rf, 4, fn
        path -> {:ok, [path]}
      end)

      assert {:ok, %{"lib/some/path/ok" => %{1 => actual_lib_diff_1, 2 => actual_lib_diff_2}}} =
               GitDiff.run([
                 {"lib/some/path/ok",
                  %{
                    contents: old_contents_lib,
                    patches: search_replace_lib
                  }}
               ])

      assert expected_diff_lib_1 == actual_lib_diff_1
      assert expected_diff_lib_2 == actual_lib_diff_2
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

      patches = [
        %{
          search: "def hello do\n    IO.puts(\"Hello, world!\")\n  end",
          replace: "def hello do\n    IO.puts(\"Hello, universe!\")\n  end",
          index: 1
        }
      ]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemWrapper, :cmd, fn "git", _ ->
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
      1) Lines: 1 - 6
      ────────────────────────
       defmodule Example do
         def hello do
      -    IO.puts(\"Hello, world!\")
      +    IO.puts(\"Hello, universe!\")
         end

         def goodbye do
      ────────────────────────
      """

      assert {:ok, %{"example" => %{1 => actual_diff}}} =
               GitDiff.run([
                 {"example", %{contents: old_contents, patches: patches}}
               ])

      assert expected_diff == actual_diff
    end

    test "if writing the 'old' file fails, return an error" do
      old_contents = "Some content"
      patches = [%{search: "Some", replace: "New", index: 1}]

      Mimic.expect(FileWrapper, :write, 1, fn
        "/tmp/polyglot_watcher_v2_old_example_1", _contents ->
          {:error, :eacces}
      end)

      Mimic.reject(&SystemWrapper.cmd/2)

      assert {:error, {:failed_to_write_tmp_file, _, :eacces}} =
               GitDiff.run([
                 {"example", %{contents: old_contents, patches: patches}}
               ])
    end

    test "if writing the 'new' file fails, return an error" do
      old_contents = "Some content"
      patches = [%{search: "Some", replace: "New", index: 1}]

      Mimic.expect(FileWrapper, :write, 2, fn
        "/tmp/polyglot_watcher_v2_new_example_1", _contents ->
          {:error, :eacces}

        "/tmp/polyglot_watcher_v2_old_example_1", _contents ->
          :ok
      end)

      Mimic.reject(&SystemWrapper.cmd/2)
      Mimic.reject(&FileWrapper.rm_rf/1)

      assert {:error, {:failed_to_write_tmp_file, _, :eacces}} =
               GitDiff.run([
                 {
                   "example",
                   %{contents: old_contents, patches: patches}
                 }
               ])
    end

    test "if the git diff returns some error output, then return an error" do
      old_contents = "Some content"
      patches = [%{search: "Some", replace: "New", index: 1}]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemWrapper, :cmd, fn "git", _ ->
        {"fatal: error occurred", 1}
      end)

      assert {:error, :git_diff_parsing_error} ==
               GitDiff.run([
                 {"example", %{contents: old_contents, patches: patches}}
               ])
    end

    test "if the read file contents contains the search text twice, replace them all" do
      old_contents = "Some content that matches twice. Some content that matches twice."
      patches = [%{search: "Some content that matches twice", replace: "New text", index: 1}]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemWrapper, :cmd, fn "git", _ ->
        {
          """
          diff --git a/old b/new
          index 1234567..abcdefg 100644
          --- a/old
          +++ b/new
          @@ -1 +1 @@
          -Some content that matches twice. Some content that matches twice.
          +New text. New text.
          """,
          0
        }
      end)

      Mimic.expect(FileWrapper, :rm_rf, 2, fn _ -> {:ok, []} end)

      expected_diff = """
      ────────────────────────
      1) Line: 1
      ────────────────────────
      -Some content that matches twice. Some content that matches twice.
      +New text. New text.
      ────────────────────────
      """

      assert {:ok, %{"example" => %{1 => actual_diff}}} =
               GitDiff.run([
                 {"example", %{contents: old_contents, patches: patches}}
               ])

      assert expected_diff == actual_diff
    end

    test "when the git diff is not in a format that we can parse, return an error" do
      old_contents = "Some content"
      patches = [%{search: "Some", replace: "New", index: 1}]

      Mimic.expect(FileWrapper, :write, 2, fn _, _ -> :ok end)

      Mimic.expect(SystemWrapper, :cmd, fn "git", _ ->
        {"This is not a valid git diff format", 0}
      end)

      assert {:error, :git_diff_parsing_error} ==
               GitDiff.run([
                 {"example", %{contents: old_contents, patches: patches}}
               ])
    end

    test "when there's a problem with the file system and we fail to write the tmp file, we return an error" do
      old_contents = "Some content"
      patches = [%{search: "Some", replace: "New", index: 1}]

      Mimic.expect(FileWrapper, :write, 1, fn _, _ -> {:error, :eacces} end)

      Mimic.reject(&SystemWrapper.cmd/2)

      assert {:error,
              {:failed_to_write_tmp_file, "/tmp/polyglot_watcher_v2_old_example_1", :eacces}} =
               GitDiff.run([
                 {"example", %{contents: old_contents, patches: patches}}
               ])
    end

    test "when search fails to find a match, return an error" do
      old_contents = "Some content"
      patches = [%{search: "NonExistent", replace: "New", index: 1}]

      Mimic.reject(&FileWrapper.write/2)
      Mimic.reject(&SystemWrapper.cmd/2)

      assert {:error, {:search_failed, "NonExistent", "New"}} ==
               GitDiff.run([
                 {"example", %{contents: old_contents, patches: patches}}
               ])
    end
  end
end
