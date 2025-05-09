defmodule PolyglotWatcherV2.Elixir.Cache.FixedTestsTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.Elixir.Cache.FixedTests
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  describe "determine/2" do
    test "given some mix test args & mix test exit code, determines which tests were fixed" do
      assert FixedTests.determine(%MixTestArgs{path: "test/a_test.exs"}, 0) ==
               {"test/a_test.exs", :all}
    end

    test "with line numbers, only returns the line number" do
      assert FixedTests.determine(%MixTestArgs{path: {"test/a_test.exs", 10}}, 0) ==
               {"test/a_test.exs", 10}

      assert FixedTests.determine(%MixTestArgs{path: {"test/b_test.exs", 20}}, 0) ==
               {"test/b_test.exs", 20}

      assert FixedTests.determine(%MixTestArgs{path: {"apps/a/test/c_test.exs", 30}}, 0) ==
               {"apps/a/test/c_test.exs", 30}
    end

    test "with --max-failures N" do
      assert FixedTests.determine(%MixTestArgs{path: "test/a_test.exs", max_failures: 1}, 0) ==
               {"test/a_test.exs", :all}

      assert FixedTests.determine(
               %MixTestArgs{path: "apps/a/test/c_test.exs", max_failures: 1},
               0
             ) == {"apps/a/test/c_test.exs", :all}

      assert FixedTests.determine(
               %MixTestArgs{path: {"test/a_test.exs", 10}, max_failures: 1},
               0
             ) == {"test/a_test.exs", 10}
    end

    test "with all returns all" do
      assert FixedTests.determine(%MixTestArgs{path: :all}, 0) == :all
    end

    test "with a non-zero exit code always return nil" do
      assert FixedTests.determine(%MixTestArgs{path: "test/a_test.exs"}, 1) == nil
      assert FixedTests.determine(%MixTestArgs{path: "test/b_test.exs"}, 1) == nil
      assert FixedTests.determine(%MixTestArgs{path: {"test/a_test.exs", 10}}, 1) == nil
      assert FixedTests.determine(%MixTestArgs{path: {"test/b_test.exs", 20}}, 1) == nil

      assert FixedTests.determine(%MixTestArgs{path: {"apps/child_app/test/c_test.exs", 30}}, 1) ==
               nil

      assert FixedTests.determine(%MixTestArgs{path: "test/a_test.exs", max_failures: 1}, 1) ==
               nil

      assert FixedTests.determine(
               %MixTestArgs{path: "apps/child_app/test/c_test.exs", max_failures: 1},
               1
             ) == nil

      assert FixedTests.determine(%MixTestArgs{path: :all}, 1) == nil
    end
  end
end
