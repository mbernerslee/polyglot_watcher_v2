defmodule PolyglotWatcherV2.Elm.FileFinderTest do
  use ExUnit.Case, async: false
  alias PolyglotWatcherV2.{FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elm.{Determiner, FileFinder}

  @elm Determiner.elm()

  describe "json/2" do
    test "can find the Main file" do
      server_state = ServerStateBuilder.build()
      # |> ServerStateBuilder.with_starting_dir("./test/elm_examples/simplest_project")

      assert {0, %{elm: %{json_path: "test/elm_examples/simplest_project"}}} =
               FileFinder.json(
                 %FilePath{path: "test/elm_examples/simplest_project/src/Cool", extension: @elm},
                 server_state
               )

      flunk("write this test NEXT DUUDEE")
    end
  end

  def json(file_path, server_state) do
    {0, server_state}
  end
end
