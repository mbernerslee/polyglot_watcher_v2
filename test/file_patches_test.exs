defmodule PolyglotWatcherV2.FilePatchesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.FilePatches
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.ServerStateBuilder

  describe "patch/2" do
    test "given 2 files, which both exist, patches to them are written to file" do
      server_state = ServerStateBuilder.build()

      file_patches = %{
        "lib/cool.ex" => %{
          contents: "AAA\nCCC",
          patches: [
            %{
              search: "AAA",
              replace: "BBB"
            },
            %{
              search: "CCC",
              replace: "DDD"
            }
          ]
        },
        "test/cool_test.exs" => %{
          contents: "EEE\nGGG",
          patches: [
            %{
              search: "EEE",
              replace: "FFF"
            },
            %{
              search: "GGG",
              replace: "HHH"
            }
          ]
        }
      }

      Mimic.expect(FileWrapper, :read, 2, fn
        "lib/cool.ex" -> {:ok, "AAA\nCCC"}
        "test/cool_test.exs" -> {:ok, "EEE\nGGG"}
      end)

      Mimic.expect(FileWrapper, :write, 2, fn
        "lib/cool.ex", "BBB\nDDD" -> :ok
        "test/cool_test.exs", "FFF\nHHH" -> :ok
      end)

      Mimic.expect(Puts, :on_new_line, 2, fn
        "Updated lib/cool.ex" -> :ok
        "Updated test/cool_test.exs" -> :ok
      end)

      assert {0, server_state} == FilePatches.patch(file_patches, server_state)
    end

    test "when a file does not exist, but another does, make no file changes" do
      server_state = ServerStateBuilder.build()

      file_patches = %{
        "lib/existing.ex" => %{
          contents: "AAA\nCCC",
          patches: [
            %{
              search: "AAA",
              replace: "BBB"
            }
          ]
        },
        "lib/non_existent.ex" => %{
          contents: "DDD\nFFF",
          patches: [
            %{
              search: "DDD",
              replace: "EEE"
            }
          ]
        }
      }

      Mimic.expect(FileWrapper, :read, 2, fn
        "lib/existing.ex" -> {:ok, "AAA\nCCC"}
        "lib/non_existent.ex" -> {:error, :enoent}
      end)

      Mimic.reject(FileWrapper, :write, 2)
      Mimic.reject(Puts, :on_new_line, 1)

      assert {1,
              %{
                server_state
                | action_error:
                    "Failed to write update to lib/non_existent.ex. Error was {:error, :enoent}"
              }} == FilePatches.patch(file_patches, server_state)
    end

    test "given 2 files, when one does not contain any search text, make no file changes and return error" do
      server_state = ServerStateBuilder.build()

      file_patches = %{
        "lib/existing.ex" => %{
          contents: "AAA\nCCC",
          patches: [
            %{
              search: "AAA",
              replace: "BBB"
            }
          ]
        },
        "lib/no_match.ex" => %{
          contents: "DDD\nFFF",
          patches: [
            %{
              search: "XXX",
              replace: "YYY"
            }
          ]
        }
      }

      Mimic.expect(FileWrapper, :read, 2, fn
        "lib/existing.ex" -> {:ok, "AAA\nCCC"}
        "lib/no_match.ex" -> {:ok, "DDD\nFFF"}
      end)

      Mimic.reject(FileWrapper, :write, 2)
      Mimic.reject(Puts, :on_new_line, 1)

      assert {1,
              %{
                server_state
                | action_error:
                    "Failed to write update to lib/no_match.ex. Error was {:error, :search_failed}"
              }} == FilePatches.patch(file_patches, server_state)
    end

    test "given 2 files, when one contains the search text multiple times, return error and make no file changes" do
      server_state = ServerStateBuilder.build()

      file_patches = %{
        "lib/single_match.ex" => %{
          contents: "AAA\nCCC",
          patches: [
            %{
              search: "AAA",
              replace: "BBB"
            }
          ]
        },
        "lib/multiple_matches.ex" => %{
          contents: "DDD\nDDD\nFFF",
          patches: [
            %{
              search: "DDD",
              replace: "EEE"
            }
          ]
        }
      }

      Mimic.expect(FileWrapper, :read, 1, fn
        "lib/single_match.ex" -> {:ok, "AAA\nCCC"}
        "lib/multiple_matches.ex" -> {:ok, "DDD\nDDD\nFFF"}
      end)

      Mimic.reject(FileWrapper, :write, 2)
      Mimic.reject(Puts, :on_new_line, 1)

      assert {1,
              %{
                server_state
                | action_error:
                    "Failed to write update to lib/multiple_matches.ex. Error was {:error, :search_multiple_matches}"
              }} == FilePatches.patch(file_patches, server_state)
    end
  end

  test "given a file with an empty patch list, no changes are made" do
    server_state = ServerStateBuilder.build()

    file_patches = %{
      "lib/empty_patch.ex" => %{
        contents: "AAA\nBBB",
        patches: []
      }
    }

    Mimic.reject(&FileWrapper.read/1)
    Mimic.reject(&FileWrapper.write/2)
    Mimic.reject(&Puts.on_new_line/1)

    assert {0, server_state} == FilePatches.patch(file_patches, server_state)
  end

  test "when writing to a file fails, return an error" do
    server_state = ServerStateBuilder.build()

    file_patches = %{
      "lib/write_fail.ex" => %{
        contents: "AAA\nCCC",
        patches: [%{search: "AAA", replace: "BBB"}]
      }
    }

    Mimic.expect(FileWrapper, :read, 1, fn "lib/write_fail.ex" -> {:ok, "AAA\nCCC"} end)

    Mimic.expect(FileWrapper, :write, 1, fn "lib/write_fail.ex", "BBB\nCCC" ->
      {:error, :eacces}
    end)

    Mimic.reject(Puts, :on_new_line, 1)

    assert {1,
            %{
              server_state
              | action_error:
                  "Failed to write update to lib/write_fail.ex. Error was {:error, :eacces}"
            }} ==
             FilePatches.patch(file_patches, server_state)
  end

  test "given a file with multiple patches, all patches are applied" do
    server_state = ServerStateBuilder.build()

    file_patches = %{
      "lib/multi_patch.ex" => %{
        contents: "AAA\nBBB\nCCC",
        patches: [
          %{search: "AAA", replace: "XXX"},
          %{search: "BBB", replace: "YYY"},
          %{search: "CCC", replace: "ZZZ"}
        ]
      }
    }

    Mimic.expect(FileWrapper, :read, 1, fn "lib/multi_patch.ex" -> {:ok, "AAA\nBBB\nCCC"} end)
    Mimic.expect(FileWrapper, :write, 1, fn "lib/multi_patch.ex", "XXX\nYYY\nZZZ" -> :ok end)
    Mimic.expect(Puts, :on_new_line, 1, fn "Updated lib/multi_patch.ex" -> :ok end)

    assert {0, server_state} == FilePatches.patch(file_patches, server_state)
  end
end
