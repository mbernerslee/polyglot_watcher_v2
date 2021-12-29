defmodule PolyglotWatcherV2.Elixir.FailureMergerTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.FailureMerger

  describe "merge/2" do
    test "puts failures in a new file first" do
      old = [{"a", 1}, {"b", 2}, {"c", 3}]

      new = [{"d", 4}]

      expected = [{"d", 4}, {"a", 1}, {"b", 2}, {"c", 3}]

      assert FailureMerger.merge(old, new) == expected
    end

    test "puts failures in a file with known failures all first" do
      old = [{"a", 1}, {"b", 2}, {"c", 3}]

      new = [{"b", 4}]

      expected = [{"b", 4}, {"b", 2}, {"a", 1}, {"c", 3}]

      assert FailureMerger.merge(old, new) == expected
    end

    test "retains the order of failure from both old and new by file path, newest first" do
      old = [{"a", 1}, {"a", 2}, {"a", 3}]

      new = [{"a", 4}, {"a", 5}, {"a", 6}]

      expected = [{"a", 4}, {"a", 5}, {"a", 6}, {"a", 1}, {"a", 2}, {"a", 3}]

      assert FailureMerger.merge(old, new) == expected
    end

    test "retains the order of failure from both old and new per file path, newest first, even when failures in a file are interleaved with others" do
      old = [
        {"b", 10},
        {"a", 1},
        {"c", 22},
        {"b", 11},
        {"a", 2},
        {"c", 23},
        {"b", 12},
        {"d", 31},
        {"a", 3},
        {"d", 32},
        {"b", 13},
        {"e", 40}
      ]

      new = [{"a", 4}, {"c", 20}, {"b", 14}, {"a", 5}, {"c", 21}, {"b", 15}, {"d", 30}, {"a", 6}]

      expected = [
        {"a", 4},
        {"a", 5},
        {"a", 6},
        {"a", 1},
        {"a", 2},
        {"a", 3},
        {"c", 20},
        {"c", 21},
        {"c", 22},
        {"c", 23},
        {"b", 14},
        {"b", 15},
        {"b", 10},
        {"b", 11},
        {"b", 12},
        {"b", 13},
        {"d", 30},
        {"d", 31},
        {"d", 32},
        {"e", 40}
      ]

      assert FailureMerger.merge(old, new) == expected
    end
  end
end
