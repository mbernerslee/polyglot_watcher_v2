defmodule PolyglotWatcherV2.FilePatchesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.FilePatches
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.ServerStateBuilder

  describe "patch/2 - :all" do
    test "given 2 files, which both exist, patches to them are written to file" do
      file_patches = [
        {"lib/cool.ex",
         %{
           contents: "AAA\nCCC",
           patches: [
             %{
               search: "AAA",
               replace: "BBB",
               index: 1
             },
             %{
               search: "CCC",
               replace: "DDD",
               index: 2
             }
           ]
         }},
        {"test/cool_test.exs",
         %{
           contents: "EEE\nGGG",
           patches: [
             %{
               search: "EEE",
               replace: "FFF",
               index: 3
             },
             %{
               search: "GGG",
               replace: "HHH",
               index: 4
             }
           ]
         }}
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

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

      assert {0, %{server_state | file_patches: nil}} ==
               FilePatches.patch(:all, server_state)
    end

    test "when a file does not exist, but another does, make no file changes and removed all file_patches from the server_state" do
      file_patches = [
        {
          "lib/existing.ex",
          %{
            contents: "AAA\nCCC",
            patches: [
              %{
                search: "AAA",
                replace: "BBB",
                index: 1
              }
            ]
          }
        },
        {"lib/non_existent.ex",
         %{
           contents: "DDD\nFFF",
           patches: [
             %{
               search: "DDD",
               replace: "EEE",
               index: 2
             }
           ]
         }}
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

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
                    "Failed to write update to lib/non_existent.ex. Error was {:error, :enoent}",
                  file_patches: nil
              }} == FilePatches.patch(:all, server_state)
    end

    test "given 2 files, when one does not contain any search text, make no file changes and return error" do
      file_patches = [
        {
          "lib/existing.ex",
          %{
            contents: "AAA\nCCC",
            patches: [
              %{
                search: "AAA",
                replace: "BBB",
                index: 1
              }
            ]
          }
        },
        {"lib/no_match.ex",
         %{
           contents: "DDD\nFFF",
           patches: [
             %{
               search: "XXX",
               replace: "YYY",
               index: 2
             }
           ]
         }}
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

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
                    "Failed to write update to lib/no_match.ex. Error was {:error, :search_failed}",
                  file_patches: nil
              }} == FilePatches.patch(:all, server_state)
    end

    test "given 2 files, when one contains the search text multiple times, allow it & update both places" do
      file_patches = [
        {
          "lib/single_match.ex",
          %{
            contents: "AAA\nCCC",
            patches: [
              %{
                search: "AAA",
                replace: "BBB",
                index: 1
              }
            ]
          }
        },
        {"lib/multiple_matches.ex",
         %{
           contents: "DDD\nDDD\nFFF",
           patches: [
             %{
               search: "DDD",
               replace: "EEE",
               index: 2
             }
           ]
         }}
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

      Mimic.expect(FileWrapper, :read, 2, fn
        "lib/single_match.ex" -> {:ok, "AAA\nCCC"}
        "lib/multiple_matches.ex" -> {:ok, "DDD\nDDD\nFFF"}
      end)

      Mimic.expect(FileWrapper, :write, 2, fn
        "lib/single_match.ex", "BBB\nCCC" -> :ok
        "lib/multiple_matches.ex", "EEE\nEEE\nFFF" -> :ok
      end)

      Mimic.expect(Puts, :on_new_line, 2, fn
        "Updated lib/single_match.ex" -> :ok
        "Updated lib/multiple_matches.ex" -> :ok
      end)

      assert {0,
              %{
                server_state
                | action_error: nil,
                  file_patches: nil
              }} == FilePatches.patch(:all, server_state)
    end

    # TODO test file_patches = nil in the server state.
    test "given a file with an empty patch list, no changes are made" do
      file_patches = [
        {
          "lib/empty_patch.ex",
          %{
            contents: "AAA\nBBB",
            patches: []
          }
        }
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

      Mimic.reject(&FileWrapper.read/1)
      Mimic.reject(&FileWrapper.write/2)
      Mimic.reject(&Puts.on_new_line/1)

      assert {0, %{server_state | file_patches: nil}} ==
               FilePatches.patch(:all, server_state)
    end

    test "when writing to a file fails, return an error" do
      file_patches = [
        {
          "lib/write_fail.ex",
          %{
            contents: "AAA\nCCC",
            patches: [%{search: "AAA", replace: "BBB", index: 1}]
          }
        }
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

      Mimic.expect(FileWrapper, :read, 1, fn "lib/write_fail.ex" -> {:ok, "AAA\nCCC"} end)

      Mimic.expect(FileWrapper, :write, 1, fn "lib/write_fail.ex", "BBB\nCCC" ->
        {:error, :eacces}
      end)

      Mimic.reject(Puts, :on_new_line, 1)

      assert {1,
              %{
                server_state
                | action_error:
                    "Failed to write update to lib/write_fail.ex. Error was {:error, :eacces}",
                  file_patches: nil
              }} ==
               FilePatches.patch(:all, server_state)
    end

    test "given a file with multiple patches, all patches are applied" do
      file_patches = [
        {"lib/multi_patch.ex",
         %{
           contents: "AAA\nBBB\nCCC",
           patches: [
             %{search: "AAA", replace: "XXX", index: 1},
             %{search: "BBB", replace: "YYY", index: 2},
             %{search: "CCC", replace: "ZZZ", index: 3}
           ]
         }}
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

      Mimic.expect(FileWrapper, :read, 1, fn "lib/multi_patch.ex" -> {:ok, "AAA\nBBB\nCCC"} end)
      Mimic.expect(FileWrapper, :write, 1, fn "lib/multi_patch.ex", "XXX\nYYY\nZZZ" -> :ok end)
      Mimic.expect(Puts, :on_new_line, 1, fn "Updated lib/multi_patch.ex" -> :ok end)

      assert {0, %{server_state | file_patches: nil}} == FilePatches.patch(:all, server_state)
    end

    test "handles replacements of nil" do
      file_patches = [
        {
          "lib/nil_replace.ex",
          %{
            contents: "AAA\nBBB",
            patches: [
              %{search: "AAA", replace: nil, index: 1},
              %{search: "BBB", replace: "CCC", index: 2}
            ]
          }
        }
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

      Mimic.expect(FileWrapper, :read, 1, fn "lib/nil_replace.ex" -> {:ok, "AAA\nBBB"} end)
      Mimic.expect(FileWrapper, :write, 1, fn "lib/nil_replace.ex", "\nCCC" -> :ok end)
      Mimic.expect(Puts, :on_new_line, 1, fn "Updated lib/nil_replace.ex" -> :ok end)

      assert {0, %{server_state | file_patches: nil}} ==
               FilePatches.patch(:all, server_state)
    end
  end

  describe "patch/2 - subset" do
    test "given a list of integers, only applies those patches, and keeps the rest" do
      file_patches = [
        {"lib/cool.ex",
         %{
           contents: "AAA\nCCC",
           patches: [
             %{
               search: "AAA",
               replace: "BBB",
               index: 1
             },
             %{
               search: "CCC",
               replace: "DDD",
               index: 2
             }
           ]
         }},
        {"test/cool_test.exs",
         %{
           contents: "EEE\nGGG",
           patches: [
             %{
               search: "EEE",
               replace: "FFF",
               index: 3
             },
             %{
               search: "GGG",
               replace: "HHH",
               index: 4
             }
           ]
         }}
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file_patches(file_patches)

      Mimic.expect(FileWrapper, :read, 2, fn
        "lib/cool.ex" -> {:ok, "AAA\nCCC"}
        "test/cool_test.exs" -> {:ok, "EEE\nGGG"}
      end)

      Mimic.expect(FileWrapper, :write, 2, fn
        "lib/cool.ex", "BBB\nCCC" -> :ok
        "test/cool_test.exs", "FFF\nGGG" -> :ok
      end)

      Mimic.expect(Puts, :on_new_line, 2, fn
        "Updated lib/cool.ex" -> :ok
        "Updated test/cool_test.exs" -> :ok
      end)

      expected_remaining_patches = [
        {"lib/cool.ex",
         %{
           contents: "AAA\nCCC",
           patches: [
             %{
               search: "CCC",
               replace: "DDD",
               index: 2
             }
           ]
         }},
        {"test/cool_test.exs",
         %{
           contents: "EEE\nGGG",
           patches: [
             %{
               search: "GGG",
               replace: "HHH",
               index: 4
             }
           ]
         }}
      ]

      assert {0, %{server_state | file_patches: expected_remaining_patches}} ==
               FilePatches.patch([1, 3], server_state)

      # TODO continue here with more tests
    end
  end
end
