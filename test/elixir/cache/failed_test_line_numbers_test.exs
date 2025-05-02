defmodule PolyglotWatcherV2.Elixir.Cache.FailedTestLineNumbersTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.Cache.FailedTestLineNumbers

  describe "update/2" do
    test "simple cases" do
      assert FailedTestLineNumbers.update([], []) == []
      assert FailedTestLineNumbers.update([1], []) == [1]
      assert FailedTestLineNumbers.update([], [1]) == [1]
    end

    test "newer failures come first" do
      assert FailedTestLineNumbers.update([1, 2, 3], [4, 5]) == [4, 5, 1, 2, 3]
      assert FailedTestLineNumbers.update([], [4, 5]) == [4, 5]
    end

    test "duplicate failures are removed" do
      assert FailedTestLineNumbers.update([1], [1]) == [1]
      assert FailedTestLineNumbers.update([1, 2, 3], [1, 2, 3, 4, 5]) == [1, 2, 3, 4, 5]
      assert FailedTestLineNumbers.update([5], [4, 5]) == [4, 5]
    end
  end
end
