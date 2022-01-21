defmodule PolyglotWatcherV2.DetermineTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{Determine, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.Determiner, as: ElixirDeterminer
  alias PolyglotWatcherV2.Elm.Determiner, as: ElmDeterminer

  @elm ElmDeterminer.elm()

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
      ex = ElixirDeterminer.ex()

      assert {%{actions_tree: %{}, entry_point: _}, ^server_state} =
               Determine.actions({:ok, %FilePath{path: "cool", extension: ex}}, server_state)
    end

    test "elm file saves return some actions" do
      server_state = ServerStateBuilder.build()

      assert {%{actions_tree: %{}, entry_point: _}, ^server_state} =
               Determine.actions({:ok, %FilePath{path: "Cool", extension: @elm}}, server_state)
    end
  end
end
