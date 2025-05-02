defmodule PolyglotWatcherV2.Elixir.EquivalentPathTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.FilePath
  alias PolyglotWatcherV2.Elixir.{Determiner, EquivalentPath}

  @ex Determiner.ex()
  @exs Determiner.exs()

  describe "determine/1" do
    test "given a string rather than a %FilePath{}, it still works" do
      assert EquivalentPath.determine("lib/cool.ex") == {:ok, "test/cool_test.exs"}
    end

    test "given a nonsense string returns error" do
      assert EquivalentPath.determine("total_bs") == :error
    end
  end

  describe "determine/1 - aboslute lib and test paths" do
    test "absolute test paths returns the lib path" do
      assert EquivalentPath.determine(%FilePath{
               path: "/home/berners/src/fib/test/another_test",
               extension: @exs
             }) == {:ok, "/home/berners/src/fib/lib/another.ex"}
    end

    test "absolute lib paths returns the test path" do
      assert EquivalentPath.determine(%FilePath{
               path: "/home/berners/src/fib/lib/another",
               extension: @ex
             }) == {:ok, "/home/berners/src/fib/test/another_test.exs"}
    end
  end

  describe "determine/1 - umbrella app lib and test paths" do
    test "umbrella app test paths returns the lib path" do
      assert EquivalentPath.determine(%FilePath{
               path: "apps/cool_app/test/another_test",
               extension: @exs
             }) == {:ok, "apps/cool_app/lib/another.ex"}
    end

    test "umbrella app lib paths returns the test path" do
      assert EquivalentPath.determine(%FilePath{
               path: "apps/cool_app/lib/another",
               extension: @ex
             }) == {:ok, "apps/cool_app/test/another_test.exs"}
    end
  end

  describe "determine/1 - relative paths starting in lib or test" do
    test "given a lib path, returns the test path" do
      assert EquivalentPath.determine(%FilePath{path: "lib/cool", extension: @ex}) ==
               {:ok, "test/cool_test.exs"}

      assert EquivalentPath.determine(%FilePath{path: "lib/nested/whatever/cool", extension: @ex}) ==
               {:ok, "test/nested/whatever/cool_test.exs"}
    end

    test "given a test path, returns the lib path" do
      assert EquivalentPath.determine(%FilePath{path: "test/cool_test", extension: @exs}) ==
               {:ok, "lib/cool.ex"}

      assert EquivalentPath.determine(%FilePath{
               path: "test/nested/coolness/oh-yeah/boi/cool",
               extension: @exs
             }) == {:ok, "lib/nested/coolness/oh-yeah/boi/cool.ex"}
    end

    test "given a test path with extra '_test' in the file path, it's ok " do
      assert EquivalentPath.determine(%FilePath{path: "test/a_test/b_test/cool", extension: @exs}) ==
               {:ok, "lib/a_test/b_test/cool.ex"}
    end

    test "given a lib file, but in an invalid format, return error" do
      assert EquivalentPath.determine(%FilePath{path: "not_lib/not_cool", extension: @ex}) ==
               :error
    end

    test "given a test file, but in an invalid format, return error" do
      assert EquivalentPath.determine(%FilePath{path: "not_test/not_cool", extension: @exs}) ==
               :error
    end
  end
end
