defmodule PolyglotWatcherV2.Elixir.CacheTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestArgs
  alias PolyglotWatcherV2.Elixir.Cache.CacheItem
  alias PolyglotWatcherV2.{ExUnitFailuresManifest, SystemCall}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @lib_path "/home/berners/src/fib/lib/another.ex"
  @test_path "/home/berners/src/fib/test/another_test.exs"
  @test_contents """
    defmodule Fib.AnotherTest do
      use ExUnit.Case
      test "greets the world" do
        assert Fib.Another.hello() == :not_world
      end

      test "other test" do
        assert Fib.Another.hello() == :doomed_to_fail
      end
    end
  """

  describe "start_link/1" do
    test "with no command line args given, spawns the server process with default starting state" do
      assert {:ok, pid} = Cache.start_link([])
      assert is_pid(pid)

      assert %{status: status, cache_items: %{}} = :sys.get_state(pid)
      assert status in [:loaded, :loading]
    end
  end

  describe "handle_continue/1" do
    test "reads the ExUnit test failures manifest, the test file for the failing tests, & updates it in the GenServer state" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{
          {AnotherTest, :"test greets the world"} => @test_path,
          {AnotherTest, :"test other test"} => @test_path
        }
      end)

      Mimic.expect(FileWrapper, :read, 1, fn
        @test_path -> {:ok, @test_contents}
      end)

      assert {:noreply, state} = Cache.handle_continue(:load, %{status: :loading})

      assert %{
               status: :loaded,
               cache_items: %{
                 @test_path => %CacheItem{
                   test_path: @test_path,
                   failed_line_numbers: [3, 7],
                   lib_path: @lib_path,
                   mix_test_output: nil,
                   rank: 1
                 }
               }
             } == state
    end
  end

  describe "update/4" do
    test "updates the cache given new mix test output" do
      assert {:ok, pid} = Cache.start_link([])

      mix_test_output = """
        1) test update/2 parses mix test output, adding failures to the list (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:6
           ** (UndefinedFunctionError) function PolyglotWatcherV2.Failures.update/2 is undefined (module PolyglotWatcherV2.Failures is not available)
           code: Failures.update([], "hi")
           stacktrace:
             PolyglotWatcherV2.Failures.update([], "hi")
             test/elixir_lang_mix_test_test.exs:7: (test)



      Finished in 0.03 seconds (0.03s async, 0.00s sync)
      1 test, 1 failure

      Randomized with seed 529126
      """

      exit_code = 1
      mix_test_args = %MixTestArgs{path: {"test/elixir_lang_mix_test_test.exs", 6}}

      assert :ok == Cache.update(pid, mix_test_args, mix_test_output, exit_code)

      assert %{
               "test/elixir_lang_mix_test_test.exs" => %CacheItem{
                 test_path: "test/elixir_lang_mix_test_test.exs",
                 failed_line_numbers: [6],
                 lib_path: "lib/elixir_lang_mix_test.ex",
                 mix_test_output: mix_test_output,
                 rank: 1
               }
             } == :sys.get_state(pid).cache_items
    end
  end

  describe "get/2" do
    test "when there's the given test_path in the state, return the most recent test failure line" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [6, 7, 8],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 1
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:ok, {"test/cool_test.exs", 6}} == Cache.get_test_failure(pid, "test/cool_test.exs")
    end

    test "when the given test_path is in the state but has no failing tests, return error" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 1
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:error, :not_found} == Cache.get_test_failure(pid, "test/cool_test.exs")
    end

    test "when the given test_path is not in the state, return error" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [6, 7, 8],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 1
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:error, :not_found} == Cache.get_test_failure(pid, "test/DIFFERENT_test.exs")
    end
  end

  describe "get_test_failure/2 - with latest" do
    test "retuns the failing test with the lowest (latest) rank" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [6, 7, 8],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 1
        },
        "test/other_test.exs" => %CacheItem{
          test_path: "test/other_test.exs",
          failed_line_numbers: [1, 2, 3],
          lib_path: "lib/other.ex",
          mix_test_output: "other tests failed sadly",
          rank: 2
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:ok, {"test/cool_test.exs", 6}} == Cache.get_test_failure(pid, :latest)
    end

    test "with no cache_items, returns error" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{}

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:error, :not_found} == Cache.get_test_failure(pid, :latest)
    end

    test "with no test failures, returns error" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 1
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:error, :not_found} == Cache.get_test_failure(pid, :latest)
    end
  end

  describe "get_files/2" do
    test "returns the test and lib files for a given test path" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [6, 7, 8],
          lib_path: "lib/cool.ex",
          mix_test_output: "tests failed sadly",
          rank: 1
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:ok,
              %{
                test: %{path: "test/cool_test.exs", contents: _},
                lib: %{path: "lib/cool.ex", contents: _},
                mix_test_output: "tests failed sadly"
              }} =
               Cache.get_files(pid, "test/cool_test.exs")
    end

    test "when the cache exists but is incomplete, return error" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/cool_test.exs" => %CacheItem{
          test_path: "test/cool_test.exs",
          failed_line_numbers: [6, 7, 8],
          # can be nil, so cache incomplete
          lib_path: nil,
          mix_test_output: "tests failed sadly",
          rank: 1
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert {:error, :cache_incomplete} == Cache.get_files(pid, "test/cool_test.exs")
    end

    test "returns error when the test path is not found in the cache" do
      assert {:ok, pid} = Cache.start_link([])

      assert {:error, :not_found} == Cache.get_files(pid, "test/nonexistent_test.exs")
    end
  end

  describe "child_spec/0" do
    test "returns the default genserver options" do
      assert %{id: Cache, start: {Cache, :start_link, [[name: :elixir_cache]]}} ==
               Cache.child_spec()
    end
  end
end
