defmodule PolyglotWatcherV2.Elixir.MixTestArgsTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  describe "to_shell_command/1" do
    test "for :all & no test failures, returns mix test --color" do
      args = %MixTestArgs{path: :all, max_failures: nil}
      result = MixTestArgs.to_shell_command(args)
      assert result == "mix test --color"
    end

    test "for specific file path, returns mix test path/to/file.exs --color" do
      args = %MixTestArgs{path: "test/some_test.exs", max_failures: nil}
      result = MixTestArgs.to_shell_command(args)
      assert result == "mix test test/some_test.exs --color"
    end

    test "for specific file path and line number, returns mix test path/to/file.exs:line --color" do
      args = %MixTestArgs{path: {"test/some_test.exs", 42}, max_failures: nil}
      result = MixTestArgs.to_shell_command(args)
      assert result == "mix test test/some_test.exs:42 --color"
    end

    test "for :all with max failures, returns mix test --max-failures count --color" do
      args = %MixTestArgs{path: :all, max_failures: 5}
      result = MixTestArgs.to_shell_command(args)
      assert result == "mix test --max-failures 5 --color"
    end

    test "for specific file path with max failures, returns mix test path/to/file.exs --max-failures count --color" do
      args = %MixTestArgs{path: "test/some_test.exs", max_failures: 3}
      result = MixTestArgs.to_shell_command(args)
      assert result == "mix test test/some_test.exs --max-failures 3 --color"
    end

    test "for specific file path and line number with max failures, returns mix test path/to/file.exs:line --max-failures count --color" do
      args = %MixTestArgs{path: {"test/some_test.exs", 10}, max_failures: 2}
      result = MixTestArgs.to_shell_command(args)
      assert result == "mix test test/some_test.exs:10 --max-failures 2 --color"
    end

    test "raise if instead of using the typle format, path is a string in the format <path>:<line>" do
      args = %MixTestArgs{path: "test/some_test.exs:42", max_failures: nil}

      assert_raise ArgumentError,
                   "Invalid path format of \"test/some_test.exs:42\". Use a tuple {file, line} instead",
                   fn -> MixTestArgs.to_shell_command(args) end
    end
  end

  describe "to_shell_command/1 with extra_args" do
    test "empty extra_args is unchanged" do
      args = %MixTestArgs{path: :all, extra_args: []}
      assert MixTestArgs.to_shell_command(args) == "mix test --color"
    end

    test "appends extra_args after path" do
      args = %MixTestArgs{path: "test/some_test.exs", extra_args: ["--trace"]}
      assert MixTestArgs.to_shell_command(args) == "mix test test/some_test.exs --trace --color"
    end

    test "appends multiple extra_args tokens preserving order" do
      args = %MixTestArgs{path: :all, extra_args: ["--slowest", "5", "--seed", "42"]}
      assert MixTestArgs.to_shell_command(args) == "mix test --slowest 5 --seed 42 --color"
    end

    test "appends extra_args after max_failures" do
      args = %MixTestArgs{path: "test/a_test.exs", max_failures: 3, extra_args: ["--trace"]}

      assert MixTestArgs.to_shell_command(args) ==
               "mix test test/a_test.exs --max-failures 3 --trace --color"
    end

    test "appends extra_args with path + line tuple" do
      args = %MixTestArgs{path: {"test/a_test.exs", 10}, extra_args: ["--slowest", "5"]}

      assert MixTestArgs.to_shell_command(args) ==
               "mix test test/a_test.exs:10 --slowest 5 --color"
    end
  end

  describe "category/1" do
    test "returns :safe for empty extra_args" do
      assert MixTestArgs.category(%MixTestArgs{path: :all}) == :safe
      assert MixTestArgs.category(%MixTestArgs{path: "test/a_test.exs", extra_args: []}) == :safe
    end

    test "returns :safe for each safe-allowlist flag individually" do
      for flag <- [
            "--trace",
            "--slowest",
            "--slowest-modules",
            "--color",
            "--no-color",
            "--formatter",
            "--preload-modules",
            "--max-requires",
            "--seed",
            "--cover"
          ] do
        assert MixTestArgs.category(%MixTestArgs{path: :all, extra_args: [flag]}) == :safe,
               "expected #{flag} to be :safe"
      end
    end

    test "returns :safe for safe flags in --flag=value form" do
      assert MixTestArgs.category(%MixTestArgs{path: :all, extra_args: ["--slowest=5"]}) == :safe
      assert MixTestArgs.category(%MixTestArgs{path: :all, extra_args: ["--seed=42"]}) == :safe
    end

    test "returns :safe for multiple safe flags with value tokens interleaved" do
      assert MixTestArgs.category(%MixTestArgs{
               path: :all,
               extra_args: ["--slowest", "5", "--seed", "42", "--trace"]
             }) == :safe
    end

    test "returns :paranoid for each explicitly-paranoid flag" do
      for flag <- [
            "--failed",
            "--stale",
            "--only",
            "--exclude",
            "--include",
            "--timeout",
            "--raise",
            "--warnings-as-errors",
            "--exit-status",
            "--repeat-until-failure",
            "--partitions",
            "--partitions-total",
            "--breakpoints",
            "--max-failures"
          ] do
        assert MixTestArgs.category(%MixTestArgs{path: :all, extra_args: [flag]}) == :paranoid,
               "expected #{flag} to be :paranoid"
      end
    end

    test "returns :paranoid for an unknown flag" do
      assert MixTestArgs.category(%MixTestArgs{path: :all, extra_args: ["--made-up-flag"]}) ==
               :paranoid
    end

    test "returns :paranoid when a safe flag and a paranoid flag are mixed" do
      assert MixTestArgs.category(%MixTestArgs{
               path: :all,
               extra_args: ["--trace", "--failed"]
             }) == :paranoid

      assert MixTestArgs.category(%MixTestArgs{
               path: :all,
               extra_args: ["--failed", "--trace"]
             }) == :paranoid
    end

    test "non-double-dash tokens alone don't flip the category" do
      assert MixTestArgs.category(%MixTestArgs{path: :all, extra_args: ["5"]}) == :safe
      assert MixTestArgs.category(%MixTestArgs{path: :all, extra_args: ["integration"]}) == :safe
    end

    test "paranoid wins even when the =value form is used" do
      assert MixTestArgs.category(%MixTestArgs{
               path: :all,
               extra_args: ["--only=integration"]
             }) == :paranoid
    end
  end

  describe "to_path/1" do
    test "returns {:ok, path} for a valid path without line number" do
      result = MixTestArgs.to_path("test/some_test.exs")
      assert result == {:ok, "test/some_test.exs"}
    end

    test "returns {:ok, {path, line}} for a valid path with line number" do
      result = MixTestArgs.to_path("test/some_test.exs:42")
      assert result == {:ok, {"test/some_test.exs", 42}}
    end

    test "returns :error for an invalid path format" do
      result = MixTestArgs.to_path("test/some_test.exs:not_a_number")
      assert result == :error
    end

    test "returns :error given many :'s" do
      result = MixTestArgs.to_path("test/some_test.exs:1:2:3")
      assert result == :error
    end

    test "padding is dealt with" do
      result = MixTestArgs.to_path(" test/some_test.exs ")
      assert result == {:ok, "test/some_test.exs"}
    end

    test "returns error for multiple tests" do
      result = MixTestArgs.to_path("test/a_test.exs test/b_test.exs")
      assert result == :error

      result = MixTestArgs.to_path("test/a_test.exs:1 test/b_test.exs")
      assert result == :error

      result = MixTestArgs.to_path("test/a_test.exs test/b_test.exs:1")
      assert result == :error

      result = MixTestArgs.to_path("test/a_test.exs:1 test/b_test.exs:1")
      assert result == :error
    end

    test "returns :error for a path with multiple colons" do
      result = MixTestArgs.to_path("test/some_test.exs:42:extra")
      assert result == :error
    end
  end
end
