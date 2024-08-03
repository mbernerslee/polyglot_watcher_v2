defmodule PolyglotWatcherV2.Elixir.EquivalentPathTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.FilePath
  alias PolyglotWatcherV2.Elixir.{Determiner, EquivalentPath}

  @ex Determiner.ex()
  @exs Determiner.exs()

  describe "determine/1" do
    test "given a lib path, returns the test path" do
      assert EquivalentPath.determine(%FilePath{path: "lib/cool", extension: @ex}) ==
               {:ok, "test/cool_test.exs"}

      assert EquivalentPath.determine(%FilePath{path: "lib/nested/whatever/cool", extension: @ex}) ==
               {:ok, "test/nested/whatever/cool_test.exs"}
    end

    test "given a test path, returns the lib path" do
      assert EquivalentPath.determine(%FilePath{path: "test/cool", extension: @exs}) ==
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
