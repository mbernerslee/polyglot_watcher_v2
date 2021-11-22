defmodule PolyglotWatcherV2.DetermineTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{Determine, ElixirLangDeterminer, FilePath, ServerStateBuilder}

  describe "actions/2" do
    test "given :ignore, returns no actions" do
      server_state = ServerStateBuilder.build()
      assert {:none, server_state} == Determine.actions(:ignore, server_state)
    end

    test "given a file path that nobody understands, returns no actions" do
      server_state = ServerStateBuilder.build()

      assert {:none, server_state} ==
               Determine.actions({:ok, %FilePath{path: "cool", extension: "crazy"}}, server_state)
    end

    test "given a file path that somebody understands, returns some actions" do
      server_state = ServerStateBuilder.build()
      ex = ElixirLangDeterminer.ex()

      assert {%{actions_tree: %{}, entry_point: _}, ^server_state} =
               Determine.actions({:ok, %FilePath{path: "cool", extension: ex}}, server_state)
    end
  end
end
