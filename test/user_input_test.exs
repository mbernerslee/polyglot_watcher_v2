defmodule PolyglotWatcherV2.UserInputTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.{UserInput, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.Determiner, as: ElixirDeterminer
  alias PolyglotWatcherV2.Rust.Determiner, as: RustDeterminer

  describe "determine_actions/2" do
    test "can read elixir (ex) actions, returning an actions tree thats a map" do
      server_state = ServerStateBuilder.build()

      assert {%{actions_tree: %{switch_mode: _}}, ^server_state} =
               UserInput.determine_actions("#{ElixirDeterminer.ex()} d", server_state)
    end

    test "can read rust (rs) actions, returning an actions tree thats a map" do
      server_state = ServerStateBuilder.build()

      assert {%{actions_tree: %{switch_mode: _}}, ^server_state} =
               UserInput.determine_actions("#{RustDeterminer.rs()} d", server_state)
    end

    test "given nonsense input returns help" do
      server_state = ServerStateBuilder.build()

      assert {%{actions_tree: %{put_help_command: _}}, ^server_state} =
               UserInput.determine_actions("nonesense dude", server_state)
    end
  end
end
