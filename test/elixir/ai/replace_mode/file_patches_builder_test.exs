defmodule PolyglotWatcherV2.Elixir.AI.ReplaceMode.FilePatchesBuilderTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.Elixir.AI.ReplaceMode.FilePatchesBuilder
  alias PolyglotWatcherV2.InstructorLiteSchemas.{CodeFileUpdate, CodeFileUpdates}

  describe "build/2" do
    test "returns error when no changes are suggested" do
      updates = %CodeFileUpdates{updates: []}

      assert {:error, {:instructor_lite, :no_changes_suggested}} =
               FilePatchesBuilder.build(updates, %{})
    end

    test "builds file patches for valid updates" do
      lib = %{path: "lib/example.ex", contents: "old content"}
      test = %{path: "test/example_test.exs", contents: "old test content"}

      updates = %CodeFileUpdates{
        updates: [
          %CodeFileUpdate{
            file_path: lib.path,
            explanation: "Update lib",
            search: "old",
            replace: "new"
          },
          %CodeFileUpdate{
            file_path: test.path,
            explanation: "Update test",
            search: "old test",
            replace: "new test"
          }
        ]
      }

      assert {:ok,
              [
                {"lib/example.ex",
                 %PolyglotWatcherV2.FilePatch{
                   contents: "old content",
                   patches: [
                     %PolyglotWatcherV2.Patch{
                       search: "old",
                       replace: "new",
                       index: 1,
                       explanation: "Update lib"
                     }
                   ]
                 }},
                {"test/example_test.exs",
                 %PolyglotWatcherV2.FilePatch{
                   contents: "old test content",
                   patches: [
                     %PolyglotWatcherV2.Patch{
                       search: "old test",
                       replace: "new test",
                       index: 2,
                       explanation: "Update test"
                     }
                   ]
                 }}
              ]} = FilePatchesBuilder.build(updates, %{lib: lib, test: test})
    end

    test "returns error for invalid file path" do
      updates = %CodeFileUpdates{
        updates: [
          %CodeFileUpdate{
            file_path: "invalid/path.ex",
            explanation: "Invalid",
            search: "old",
            replace: "new"
          }
        ]
      }

      assert {:error, {:instructor_lite, :invalid_file_path}} =
               FilePatchesBuilder.build(updates, %{
                 lib: %{path: "lib/example.ex", content: "lib"},
                 test: %{path: "test/example_test.exs", content: "test"}
               })
    end

    test "returns error when one code file update is to an invalid path, but others are correct" do
      lib = %{path: "lib/example.ex", contents: "old content"}
      test = %{path: "test/example_test.exs", contents: "old test content"}

      updates = %CodeFileUpdates{
        updates: [
          %CodeFileUpdate{
            file_path: lib.path,
            explanation: "Update lib",
            search: "old",
            replace: "new"
          },
          %CodeFileUpdate{
            file_path: "invalid/path.ex",
            explanation: "Invalid path",
            search: "something",
            replace: "something else"
          },
          %CodeFileUpdate{
            file_path: test.path,
            explanation: "Update test",
            search: "old test",
            replace: "new test"
          }
        ]
      }

      assert {:error, {:instructor_lite, :invalid_file_path}} =
               FilePatchesBuilder.build(updates, %{lib: lib, test: test})
    end
  end
end
