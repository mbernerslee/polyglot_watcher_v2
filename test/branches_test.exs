defmodule PolyglotWatcherV2.BranchesTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Branches

  describe "branches/2" do
    test "simple no-branching, no-chaining cases" do
      assert Branches.branches([], %{}) == []
      assert Branches.branches([], %{"a" => []}) == []
      assert Branches.branches(["a"], %{"a" => []}) == [["a"]]
      assert Branches.branches(["a", "b"], %{"a" => [], "b" => []}) == [["a"], ["b"]]

      assert Branches.branches(["a", "b", "c"], %{"a" => [], "b" => [], "c" => []}) == [
               ["a"],
               ["b"],
               ["c"]
             ]
    end

    test "simple chain with no branching" do
      assert Branches.branches(["a"], %{"a" => ["b"], "b" => ["c"], "c" => []}) == [
               ["a", "b", "c"]
             ]
    end

    test "1st tier branch point" do
      assert Branches.branches(["a"], %{"a" => ["b", "c"], "b" => [], "c" => []}) == [
               ["a", "b"],
               ["a", "c"]
             ]
    end

    test "1st tier branch point into 3 branches" do
      assert Branches.branches(["a"], %{"a" => ["b", "c", "d"], "b" => [], "c" => [], "d" => []}) ==
               [
                 ["a", "b"],
                 ["a", "c"],
                 ["a", "d"]
               ]
    end

    test "2nd tier branch point" do
      assert Branches.branches(["a"], %{"a" => ["b"], "b" => ["c", "d"], "c" => [], "d" => []}) ==
               [
                 ["a", "b", "c"],
                 ["a", "b", "d"]
               ]
    end

    test "2nd tier branch point into 3 branches" do
      assert Branches.branches(["a"], %{
               "a" => ["b"],
               "b" => ["c", "d", "e"],
               "c" => [],
               "d" => [],
               "e" => []
             }) ==
               [
                 ["a", "b", "c"],
                 ["a", "b", "d"],
                 ["a", "b", "e"]
               ]
    end

    test "1st and 2nd tier branches into 3 branches each time" do
      assert Branches.branches(["a"], %{
               "a" => ["b", "c", "d"],
               "b" => ["e", "f", "g"],
               "c" => [],
               "d" => [],
               "e" => [],
               "f" => [],
               "g" => []
             }) ==
               [
                 ["a", "b", "e"],
                 ["a", "b", "f"],
                 ["a", "b", "g"],
                 ["a", "c"],
                 ["a", "d"]
               ]
    end

    test "1st, 2nd & 3rd tier branches into 3 branches each time" do
      assert Branches.branches(["a"], %{
               "a" => ["b1", "b2", "b3"],
               "b1" => ["c11", "c12", "c13"],
               "b2" => ["c21", "c22", "c23"],
               "b3" => ["c31", "c32", "c33"],
               "c11" => ["d111", "d112", "d113"],
               "c12" => ["d121", "d122", "d123"],
               "c13" => ["d131", "d132", "d133"],
               "c21" => ["d211", "d212", "d213"],
               "c22" => ["d221", "d222", "d223"],
               "c23" => ["d231", "d232", "d233"],
               "c31" => ["d311", "d312", "d313"],
               "c32" => ["d321", "d322", "d323"],
               "c33" => ["d331", "d332", "d333"],
               "d111" => [],
               "d112" => [],
               "d113" => [],
               "d121" => [],
               "d122" => [],
               "d123" => [],
               "d131" => [],
               "d132" => [],
               "d133" => [],
               "d211" => [],
               "d212" => [],
               "d213" => [],
               "d221" => [],
               "d222" => [],
               "d223" => [],
               "d231" => [],
               "d232" => [],
               "d233" => [],
               "d311" => [],
               "d312" => [],
               "d313" => [],
               "d321" => [],
               "d322" => [],
               "d323" => [],
               "d331" => [],
               "d332" => [],
               "d333" => []
             }) ==
               [
                 ["a", "b1", "c11", "d111"],
                 ["a", "b1", "c11", "d112"],
                 ["a", "b1", "c11", "d113"],
                 ["a", "b1", "c12", "d121"],
                 ["a", "b1", "c12", "d122"],
                 ["a", "b1", "c12", "d123"],
                 ["a", "b1", "c13", "d131"],
                 ["a", "b1", "c13", "d132"],
                 ["a", "b1", "c13", "d133"],
                 ["a", "b2", "c21", "d211"],
                 ["a", "b2", "c21", "d212"],
                 ["a", "b2", "c21", "d213"],
                 ["a", "b2", "c22", "d221"],
                 ["a", "b2", "c22", "d222"],
                 ["a", "b2", "c22", "d223"],
                 ["a", "b2", "c23", "d231"],
                 ["a", "b2", "c23", "d232"],
                 ["a", "b2", "c23", "d233"],
                 ["a", "b3", "c31", "d311"],
                 ["a", "b3", "c31", "d312"],
                 ["a", "b3", "c31", "d313"],
                 ["a", "b3", "c32", "d321"],
                 ["a", "b3", "c32", "d322"],
                 ["a", "b3", "c32", "d323"],
                 ["a", "b3", "c33", "d331"],
                 ["a", "b3", "c33", "d332"],
                 ["a", "b3", "c33", "d333"]
               ]
    end

    test "3rd tier branch point" do
      assert Branches.branches(["a"], %{
               "a" => ["b"],
               "b" => ["c"],
               "c" => ["d", "e"],
               "d" => [],
               "e" => []
             }) == [
               ["a", "b", "c", "d"],
               ["a", "b", "c", "e"]
             ]
    end

    test "4th tier branch point" do
      assert Branches.branches(["a"], %{
               "a" => ["b"],
               "b" => ["c"],
               "c" => ["d"],
               "d" => ["e", "f"],
               "e" => [],
               "f" => []
             }) == [
               ["a", "b", "c", "d", "e"],
               ["a", "b", "c", "d", "f"]
             ]
    end

    test "gnarly chaining & multi-branching combos" do
      assert Branches.branches(["a"], %{
               "a" => ["b"],
               "b" => ["c", "d"],
               "c" => [],
               "d" => ["e"],
               "e" => []
             }) == [
               ["a", "b", "c"],
               ["a", "b", "d", "e"]
             ]

      assert Branches.branches(["a"], %{
               "a" => ["d"],
               "d" => ["f"],
               "f" => ["k", "l"],
               "k" => [],
               "l" => ["m"],
               "m" => []
             }) == [
               ["a", "d", "f", "k"],
               ["a", "d", "f", "l", "m"]
             ]

      assert Branches.branches(["a", "b", "c"], %{
               "a" => ["d"],
               "b" => ["e"],
               "c" => [],
               "d" => ["f", "g", "h"],
               "e" => ["i", "j"],
               "f" => ["k", "l"],
               "g" => [],
               "h" => ["o"],
               "i" => [],
               "j" => ["p"],
               "k" => [],
               "l" => ["m"],
               "m" => ["n"],
               "n" => [],
               "o" => [],
               "p" => []
             }) == [
               ["a", "d", "f", "k"],
               ["a", "d", "f", "l", "m", "n"],
               ["a", "d", "g"],
               ["a", "d", "h", "o"],
               ["b", "e", "i"],
               ["b", "e", "j", "p"],
               ["c"]
             ]
    end

    # test "any dependency maps missing nodes will raise" do
    #  bad_combos = [
    #    {["a"], %{}},
    #    {["a"], %{"a" => ["b"]}}
    #  ]

    #  Enum.each(bad_combos, fn {roots, deps} ->
    #    assert_raise KeyError, fn -> Branches.branches(roots, deps) end
    #  end)
    # end
  end
end
