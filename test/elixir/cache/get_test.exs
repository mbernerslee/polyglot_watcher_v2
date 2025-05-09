defmodule PolyglotWatcherV2.Elixir.Cache.GetTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.Cache.{Get, CacheItem}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  describe "test_failure/2 - given a test_path" do
    test "simple case" do
      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [6, 7, 8],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 1
        }
      }

      assert {:ok, {"test/cool_test.exs", 6}} ==
               Get.test_failure("test/cool_test.exs", cache_items)
    end

    test "returns an error when the given test_path is not in the cache" do
      cache_items = %{}

      assert {:error, :not_found} == Get.test_failure("test/non_existent_test.exs", cache_items)
    end

    test "returns an error when the given test_path has no failed line numbers" do
      cache_items = %{
        "test/empty_test.exs" => %CacheItem{
          test_path: "test/empty_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/empty.ex",
          mix_test_output: "",
          rank: 2
        }
      }

      assert {:error, :not_found} == Get.test_failure("test/empty_test.exs", cache_items)
    end

    test "returns an error when given :latest and the cache is empty" do
      cache_items = %{}

      assert {:error, :not_found} == Get.test_failure(:latest, cache_items)
    end
  end

  describe "test_failure/2 - given :latest" do
    test "returns the test_path & line with the lowest rank, first of the list" do
      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [6, 7, 8],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 2
        },
        "test/awesome_test.exs" => %CacheItem{
          test_path: "test/awesome_test.exs",
          failed_line_numbers: [10, 11],
          lib_path: "lib/awesome.ex",
          mix_test_output: "tests failed awesomely",
          rank: 1
        }
      }

      assert {:ok, {"test/awesome_test.exs", 10}} == Get.test_failure(:latest, cache_items)
    end

    test "when the lowest rank test has no failures, return the test from the next rank" do
      cache_items = %{
        "test/c_test.exs" => %CacheItem{
          test_path: "test/c_test.exs",
          failed_line_numbers: [12, 13, 14],
          lib_path: "lib/c.ex",
          mix_test_output: "tests failed sadly",
          rank: 3
        },
        "test/b_test.exs" => %CacheItem{
          test_path: "test/b_test.exs",
          failed_line_numbers: [9, 10, 11],
          lib_path: "lib/b.ex",
          mix_test_output: "tests failed sadly",
          rank: 2
        },
        "test/a_test.exs" => %CacheItem{
          test_path: "test/a_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/a.ex",
          mix_test_output: "tests failed aly",
          rank: 1
        }
      }

      assert {:ok, {"test/b_test.exs", 9}} == Get.test_failure(:latest, cache_items)
    end

    test "when there's cache with no failures, return error" do
      cache_items = %{
        "test/c_test.exs" => %CacheItem{
          test_path: "test/c_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/c.ex",
          mix_test_output: "tests failed sadly",
          rank: 3
        },
        "test/b_test.exs" => %CacheItem{
          test_path: "test/b_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/b.ex",
          mix_test_output: "tests failed sadly",
          rank: 2
        },
        "test/a_test.exs" => %CacheItem{
          test_path: "test/a_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/a.ex",
          mix_test_output: "tests failed aly",
          rank: 1
        }
      }

      assert {:error, :not_found} == Get.test_failure(:latest, cache_items)
    end

    test "when the cache is empty, return error" do
      assert {:error, :not_found} == Get.test_failure(:latest, %{})
    end
  end

  describe "files/2" do
    test "when both files exist, we return their contents plus the mix test output" do
      test_path = "test/cool_test.exs"
      test_contents = "cool test"
      lib_path = "test/cool.ex"
      lib_contents = "cool lib"
      mix_test_output = "cool mix test output"

      Mimic.expect(FileWrapper, :read, 2, fn
        ^test_path -> {:ok, test_contents}
        ^lib_path -> {:ok, lib_contents}
      end)

      cache_items = %{
        test_path => %CacheItem{
          test_path: test_path,
          failed_line_numbers: [],
          lib_path: lib_path,
          mix_test_output: mix_test_output,
          rank: 1
        }
      }

      assert {:ok,
              %{
                test: %{path: test_path, contents: test_contents},
                lib: %{path: lib_path, contents: lib_contents},
                mix_test_output: mix_test_output
              }} == Get.files(test_path, cache_items)
    end

    test "returns an error when the cache item is missing the lib_path" do
      incomplete_cache_item = %CacheItem{
        test_path: "test/incomplete_test.exs",
        failed_line_numbers: [],
        lib_path: nil,
        mix_test_output: "mix test output",
        rank: 1
      }

      cache_items = %{"test/incomplete_test.exs" => incomplete_cache_item}

      assert {:error, :cache_incomplete} == Get.files("test/incomplete_test.exs", cache_items)
    end

    test "returns an error when the cache item is missing the mix_test_output" do
      test_path = "test/incomplete_test.exs"
      lib_path = "lib/incomplete.ex"

      cache_items = %{
        test_path => %CacheItem{
          test_path: test_path,
          failed_line_numbers: [],
          lib_path: lib_path,
          mix_test_output: nil,
          rank: 1
        }
      }

      assert {:error, :cache_incomplete} == Get.files(test_path, cache_items)
    end

    test "returns an error when the test_path cannot be read" do
      test_path = "test/unreadable_test.exs"
      lib_path = "lib/readable.ex"

      Mimic.expect(FileWrapper, :read, 2, fn
        ^test_path -> {:error, :enoent}
        ^lib_path -> {:ok, "readable content"}
      end)

      cache_items = %{
        test_path => %CacheItem{
          test_path: test_path,
          failed_line_numbers: [],
          lib_path: lib_path,
          mix_test_output: "mix test output",
          rank: 1
        }
      }

      assert {:error, :file_not_found} == Get.files(test_path, cache_items)
    end

    test "returns an error when the lib_path cannot be read" do
      test_path = "test/unreadable_test.exs"
      lib_path = "lib/unreadable.ex"

      Mimic.expect(FileWrapper, :read, 2, fn
        ^test_path -> {:error, :enoent}
        ^lib_path -> {:ok, "readable content"}
      end)

      cache_items = %{
        test_path => %CacheItem{
          test_path: test_path,
          failed_line_numbers: [],
          lib_path: lib_path,
          mix_test_output: "mix test output",
          rank: 1
        }
      }

      assert {:error, :file_not_found} == Get.files(test_path, cache_items)
    end
  end
end
