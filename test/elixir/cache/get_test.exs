defmodule PolyglotWatcherV2.Elixir.Cache.GetTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.Cache.{Get, CacheItem}

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
end
