defmodule PolyglotWatcherV2.Elixir.CacheTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestArgs
  alias PolyglotWatcherV2.Elixir.Cache.CacheItem
  alias PolyglotWatcherV2.{ExUnitFailuresManifest, SystemWrapper}
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
      Mimic.expect(SystemWrapper, :cmd, fn _, _ ->
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

  describe "update/4 - last_run_results" do
    test "stores the run result with the current epoch" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      Cache.update(pid, args, "1 test, 0 failures", 0)

      state = :sys.get_state(pid)

      assert %{
               "test/cool_test.exs" => %{output: "1 test, 0 failures", exit_code: 0, epoch: 0}
             } = state.last_run_results
    end

    test "stores with tuple key when line number is present" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: {"test/cool_test.exs", 42}}
      Cache.update(pid, args, "1 test, 0 failures", 0)

      state = :sys.get_state(pid)

      assert %{
               {"test/cool_test.exs", 42} => %{output: "1 test, 0 failures", exit_code: 0, epoch: 0}
             } = state.last_run_results
    end

    test "stores with :all key" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: :all}
      Cache.update(pid, args, "10 tests, 0 failures", 0)

      state = :sys.get_state(pid)
      assert %{all: %{output: "10 tests, 0 failures", exit_code: 0, epoch: 0}} = state.last_run_results
    end

    test "does not store run result when max_failures is set" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs", max_failures: 1}
      Cache.update(pid, args, "1 test, 0 failures", 0)

      state = :sys.get_state(pid)
      assert state.last_run_results == %{}
    end

    test "epoch on stored result reflects the change_epoch at time of update" do
      assert {:ok, pid} = Cache.start_link([])

      Cache.bump_change_epoch(pid)
      Cache.bump_change_epoch(pid)
      _ = :sys.get_state(pid)

      args = %MixTestArgs{path: "test/cool_test.exs"}
      Cache.update(pid, args, "output", 0)

      state = :sys.get_state(pid)
      assert state.last_run_results["test/cool_test.exs"].epoch == 2
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

  describe "get_known_failures/1" do
    test "returns empty result when cache is empty" do
      assert {:ok, pid} = Cache.start_link([])
      :sys.replace_state(pid, fn state -> %{state | cache_items: %{}} end)

      assert %{
               failures: [],
               total_failing_test_files: 0,
               total_failing_lines: 0
             } == Cache.get_known_failures(pid)
    end

    test "filters out cache items with no failing lines" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/failing_test.exs" => %CacheItem{
          test_path: "test/failing_test.exs",
          failed_line_numbers: [10],
          lib_path: "lib/failing.ex",
          mix_test_output: "boom",
          rank: 1
        },
        "test/passing_test.exs" => %CacheItem{
          test_path: "test/passing_test.exs",
          failed_line_numbers: [],
          lib_path: "lib/passing.ex",
          mix_test_output: nil,
          rank: 2
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert %{
               failures: [%CacheItem{test_path: "test/failing_test.exs"}],
               total_failing_test_files: 1,
               total_failing_lines: 1
             } = Cache.get_known_failures(pid)
    end

    test "sorts failures by rank ascending (most-recent first) and counts lines across files" do
      assert {:ok, pid} = Cache.start_link([])

      cache_items = %{
        "test/older_test.exs" => %CacheItem{
          test_path: "test/older_test.exs",
          failed_line_numbers: [1, 2],
          lib_path: "lib/older.ex",
          mix_test_output: "older",
          rank: 5
        },
        "test/newest_test.exs" => %CacheItem{
          test_path: "test/newest_test.exs",
          failed_line_numbers: [9],
          lib_path: "lib/newest.ex",
          mix_test_output: "newest",
          rank: 1
        },
        "test/middle_test.exs" => %CacheItem{
          test_path: "test/middle_test.exs",
          failed_line_numbers: [3, 4, 5],
          lib_path: "lib/middle.ex",
          mix_test_output: "middle",
          rank: 3
        }
      }

      :sys.replace_state(pid, fn state -> %{state | cache_items: cache_items} end)

      assert %{
               failures: [
                 %CacheItem{test_path: "test/newest_test.exs", rank: 1},
                 %CacheItem{test_path: "test/middle_test.exs", rank: 3},
                 %CacheItem{test_path: "test/older_test.exs", rank: 5}
               ],
               total_failing_test_files: 3,
               total_failing_lines: 6
             } = Cache.get_known_failures(pid)
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

  describe "await_or_run/1" do
    test "returns :not_running when nothing is running" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      assert :not_running == Cache.await_or_run(pid, args)
    end

    test "blocks when same test is running, unblocks when update is called" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      # First caller acquires the lock
      assert :not_running == Cache.await_or_run(pid, args)

      test_pid = self()

      spawn_link(fn ->
        result = Cache.await_or_run(pid, args)
        send(test_pid, {:result, result})
      end)

      wait_for_same_key_waiters(pid, 1)

      mix_test_output = "1 test, 0 failures"
      Cache.update(pid, args, mix_test_output, 0)

      assert_receive {:result, {:ok, {^mix_test_output, 0}}}
    end

    test "multiple same-key waiters all get notified" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      # First caller acquires the lock
      assert :not_running == Cache.await_or_run(pid, args)

      test_pid = self()

      for _i <- 1..3 do
        spawn_link(fn ->
          result = Cache.await_or_run(pid, args)
          send(test_pid, {:result, result})
        end)
      end

      wait_for_same_key_waiters(pid, 3)

      mix_test_output = "1 test, 1 failure"
      Cache.update(pid, args, mix_test_output, 2)

      for _i <- 1..3 do
        assert_receive {:result, {:ok, {^mix_test_output, 2}}}
      end
    end

    test "waits for matching key even with different line number" do
      assert {:ok, pid} = Cache.start_link([])

      args_with_line = %MixTestArgs{path: {"test/cool_test.exs", 42}}
      # First caller acquires the lock
      assert :not_running == Cache.await_or_run(pid, args_with_line)

      test_pid = self()

      spawn_link(fn ->
        result = Cache.await_or_run(pid, %MixTestArgs{path: "test/cool_test.exs"})
        send(test_pid, {:result, result})
      end)

      wait_for_same_key_waiters(pid, 1)

      mix_test_output = "1 test, 0 failures"
      Cache.update(pid, args_with_line, mix_test_output, 0)

      assert_receive {:result, {:ok, {^mix_test_output, 0}}}
    end

    test "different test queued behind a running test" do
      assert {:ok, pid} = Cache.start_link([])

      args_a = %MixTestArgs{path: "test/a_test.exs"}
      args_b = %MixTestArgs{path: "test/b_test.exs"}

      # First caller acquires the lock for test A
      assert :not_running == Cache.await_or_run(pid, args_a)

      test_pid = self()

      # Second caller wants test B — gets queued
      spawn_link(fn ->
        result = Cache.await_or_run(pid, args_b)
        send(test_pid, {:result_b, result})
      end)

      wait_for_queue_length(pid, 1)

      # Complete test A — test B should get the lock
      Cache.update(pid, args_a, "a output", 0)

      # Test B caller should receive :not_running (their turn to run)
      assert_receive {:result_b, :not_running}

      # Verify test B now holds the lock
      state = :sys.get_state(pid)
      assert state.running_key == "test/b_test.exs"
    end

    test "queue drains in order" do
      assert {:ok, pid} = Cache.start_link([])

      args_a = %MixTestArgs{path: "test/a_test.exs"}
      args_b = %MixTestArgs{path: "test/b_test.exs"}
      args_c = %MixTestArgs{path: "test/c_test.exs"}

      # A acquires the lock
      assert :not_running == Cache.await_or_run(pid, args_a)

      test_pid = self()

      # B and C queue up (in order)
      spawn_link(fn ->
        result = Cache.await_or_run(pid, args_b)
        send(test_pid, {:result_b, result})
      end)

      wait_for_queue_length(pid, 1)

      spawn_link(fn ->
        result = Cache.await_or_run(pid, args_c)
        send(test_pid, {:result_c, result})
      end)

      wait_for_queue_length(pid, 2)

      # Complete A — B gets the lock
      Cache.update(pid, args_a, "a output", 0)
      assert_receive {:result_b, :not_running}

      # Complete B — C gets the lock
      Cache.update(pid, args_b, "b output", 0)
      assert_receive {:result_c, :not_running}

      # Queue is drained
      state = :sys.get_state(pid)
      assert state.queue == []
    end

    test "same-key dedup within the queue" do
      assert {:ok, pid} = Cache.start_link([])

      args_a = %MixTestArgs{path: "test/a_test.exs"}
      args_b = %MixTestArgs{path: "test/b_test.exs"}

      # A acquires the lock
      assert :not_running == Cache.await_or_run(pid, args_a)

      test_pid = self()

      # Two callers queue up for the same test B
      spawn_link(fn ->
        result = Cache.await_or_run(pid, args_b)
        send(test_pid, {:result_b1, result})
      end)

      wait_for_queue_length(pid, 1)

      spawn_link(fn ->
        result = Cache.await_or_run(pid, args_b)
        send(test_pid, {:result_b2, result})
      end)

      wait_for_queue_length(pid, 2)

      # Complete A — first B caller runs, second B caller becomes same_key_waiter
      Cache.update(pid, args_a, "a output", 0)

      # First B caller gets :not_running (runs the test)
      assert_receive {:result_b1, :not_running}

      # Second B caller is waiting as a same_key_waiter (hasn't received anything yet)
      refute_receive {:result_b2, _}

      state = :sys.get_state(pid)
      assert state.running_key == "test/b_test.exs"
      assert length(state.same_key_waiters) == 1
      assert state.queue == []

      # Complete B — second caller gets the result
      Cache.update(pid, args_b, "b output", 0)
      assert_receive {:result_b2, {:ok, {"b output", 0}}}
    end
  end

  describe "update/4 - running state" do
    test "clears running state after update when queue is empty" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      assert :not_running == Cache.await_or_run(pid, args)

      assert "test/cool_test.exs" == :sys.get_state(pid).running_key

      Cache.update(pid, args, "output", 0)

      state = :sys.get_state(pid)
      assert state.running_key == nil
      assert state.same_key_waiters == []
      assert state.queue == []
    end
  end

  describe "get_cached_result/2" do
    test "returns :miss when no cached result exists" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      assert :miss == Cache.get_cached_result(pid, args)
    end

    test "returns {:hit, output, exit_code} when epoch matches" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      Cache.update(pid, args, "1 test, 0 failures", 0)

      assert {:hit, "1 test, 0 failures", 0} == Cache.get_cached_result(pid, args)
    end

    test "returns :miss when epoch has moved on" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: "test/cool_test.exs"}
      Cache.update(pid, args, "1 test, 0 failures", 0)

      Cache.bump_change_epoch(pid)
      _ = :sys.get_state(pid)

      assert :miss == Cache.get_cached_result(pid, args)
    end

    test "distinguishes between file path and file:line path" do
      assert {:ok, pid} = Cache.start_link([])

      file_args = %MixTestArgs{path: "test/cool_test.exs"}
      line_args = %MixTestArgs{path: {"test/cool_test.exs", 42}}

      Cache.update(pid, file_args, "file output", 0)

      assert {:hit, "file output", 0} == Cache.get_cached_result(pid, file_args)
      assert :miss == Cache.get_cached_result(pid, line_args)
    end

    test "works with :all path" do
      assert {:ok, pid} = Cache.start_link([])

      args = %MixTestArgs{path: :all}
      Cache.update(pid, args, "all output", 0)

      assert {:hit, "all output", 0} == Cache.get_cached_result(pid, args)
    end
  end

  describe "bump_change_epoch/1" do
    test "increments the change_epoch in state" do
      assert {:ok, pid} = Cache.start_link([])

      assert :sys.get_state(pid).change_epoch == 0

      Cache.bump_change_epoch(pid)
      # cast is async, use :sys.get_state to force synchronization
      assert :sys.get_state(pid).change_epoch == 1

      Cache.bump_change_epoch(pid)
      assert :sys.get_state(pid).change_epoch == 2
    end
  end

  describe "get_change_epoch/1" do
    test "returns the current change_epoch" do
      assert {:ok, pid} = Cache.start_link([])

      assert 0 == Cache.get_change_epoch(pid)

      Cache.bump_change_epoch(pid)
      _ = :sys.get_state(pid)

      assert 1 == Cache.get_change_epoch(pid)
    end
  end

  describe "child_spec/0" do
    test "returns the default genserver options" do
      assert %{id: Cache, start: {Cache, :start_link, [[name: :elixir_cache]]}} ==
               Cache.child_spec()
    end
  end

  defp wait_for_same_key_waiters(pid, expected_count) do
    state = :sys.get_state(pid)

    if length(state.same_key_waiters) == expected_count do
      :ok
    else
      wait_for_same_key_waiters(pid, expected_count)
    end
  end

  defp wait_for_queue_length(pid, expected_count) do
    state = :sys.get_state(pid)

    if length(state.queue) == expected_count do
      :ok
    else
      wait_for_queue_length(pid, expected_count)
    end
  end
end
