defmodule PolyglotWatcherV2.Elixir.Cache.FixedTestsTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.Elixir.Cache.FixedTests

  describe "determine/2" do
    test "given some mix test ares & mix test exist code, determines which tests were fixed" do
      assert FixedTests.determine("test/a_test.exs", 0) == {"test/a_test.exs", :all}
      assert FixedTests.determine("test/b_test.exs", 0) == {"test/b_test.exs", :all}
    end

    test "with line numbers, only returns the line number" do
      assert FixedTests.determine("test/a_test.exs:10", 0) == {"test/a_test.exs", 10}
      assert FixedTests.determine("test/b_test.exs:20", 0) == {"test/b_test.exs", 20}

      assert FixedTests.determine("apps/child_app/test/c_test.exs:30", 0) ==
               {"apps/child_app/test/c_test.exs", 30}
    end

    test "with --max-failures N" do
      assert FixedTests.determine("test/a_test.exs --max-failures 1", 0) ==
               {"test/a_test.exs", :all}

      assert FixedTests.determine("apps/child_app/test/c_test.exs --max-failures 1", 0) ==
               {"apps/child_app/test/c_test.exs", :all}
    end

    test "with all returns all" do
      assert FixedTests.determine(:all, 0) == :all
    end

    test "with a non-zero exit code always return nil" do
      assert FixedTests.determine("test/a_test.exs", 1) == nil
      assert FixedTests.determine("test/b_test.exs", 1) == nil
      assert FixedTests.determine("test/a_test.exs:10", 1) == nil
      assert FixedTests.determine("test/b_test.exs:20", 1) == nil
      assert FixedTests.determine("apps/child_app/test/c_test.exs:30", 1) == nil
      assert FixedTests.determine("test/a_test.exs --max-failures 1", 1) == nil
      assert FixedTests.determine("apps/child_app/test/c_test.exs --max-failures 1", 1) == nil
      assert FixedTests.determine(:all, 1) == nil
    end
  end
end
