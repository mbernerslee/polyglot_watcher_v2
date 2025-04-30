defmodule PolyglotWatcherV2.Elixir.CacheTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.{ExUnitFailuresManifest, SystemCall}
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @lib_path "/home/berners/src/fib/lib/fib.ex"
  @test_path "/home/berners/src/fib/test/fib_test.exs"
  @lib_contents """
  defmodule Fib do
    def sequence(0), do: []
    def sequence(1), do: [2]
    def sequence(2), do: [1, 1]

    def sequence(n) when n > 2 do
      Enum.reduce(3..n, [1, 1], fn _, [a, b | _] = acc ->
        [a + b | acc]
      end)
      |> Enum.reverse()
    end
  end
  """

  @test_contents """
  defmodule FibTest do
    use ExUnit.Case
    doctest Fib

    # 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89,144,233,377,610,987, 1597, 2584, 4181

    test "can generate 0 items of the Fibonacci sequence" do
      assert Fib.sequence(0) == []
    end

    test "can generate 1 item of the Fibonacci sequence" do
      assert Fib.sequence(1) == [1]
    end

    test "can generate 2 items of the Fibonacci sequence" do
      assert Fib.sequence(2) == [1, 1]
    end

    test "can generate many items of the Fibonacci sequence" do
      assert Fib.sequence(3) == [1, 1, 2]
      assert Fib.sequence(4) == [1, 1, 2, 3]
      assert Fib.sequence(5) == [1, 1, 2, 3, 5]
      assert Fib.sequence(6) == [1, 1, 2, 3, 5, 8]
      assert Fib.sequence(7) == [1, 1, 2, 3, 5, 8, 13]

      assert Fib.sequence(19) == [
               1,
               1,
               2,
               3,
               5,
               8,
               13,
               21,
               34,
               55,
               89,
               144,
               233,
               377,
               610,
               987,
               1597,
               2584,
               4181
             ]
    end
  end
  """

  @failures_manifest %{
    {FibTest, :"test can generate 1 item of the Fibonacci sequence"} =>
      "/home/berners/src/fib/test/fib_test.exs"
  }

  describe "start_link/1" do
    test "with no command line args given, spawns the server process with default starting state" do
      assert {:ok, pid} = Cache.start_link([])
      assert is_pid(pid)

      assert %{status: status} = :sys.get_state(pid)
      # a race condition means we don't know which it will be, so doing this to avoid flakes
      assert status in [:loaded, :loading]
    end
  end

  describe "handle_continue/1" do
    # TODO test
    # - we don't read the same file twice if it appears twice in the manifest with different failed tests
    # - we can handle different test files being in the manifest
    # - the rankings work. just make them increment for now
    test "reads the ExUnit test failures manifest, parses it & updates it in the GenServer state" do
      Mimic.expect(SystemCall, :cmd, fn cmd, args ->
        assert cmd == "find"
        assert args == [".", "-name", ".mix_test_failures"]
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(ExUnitFailuresManifest, :read, fn file_path ->
        assert "./_build/test/lib/fib/.mix/.mix_test_failures" == file_path
        @failures_manifest
      end)

      Mimic.expect(FileWrapper, :read, fn file_path ->
        assert @test_path == file_path
        {:ok, @test_contents}
      end)

      Mimic.expect(FileWrapper, :read, fn file_path ->
        assert @lib_path == file_path
        {:ok, @lib_contents}
      end)

      assert {:noreply,
              %{
                status: :loaded,
                files: %{
                  @test_path => %{
                    test: %{path: @test_path, contents: @test_contents, failed_line_numbers: [11]},
                    lib: %{path: @lib_path, contents: @lib_contents},
                    mix_test_output: nil,
                    rank: 1
                  }
                }
              }} == Cache.handle_continue(:load, %{status: :loading})
    end
  end

  # describe "child_spec/0" do
  #  test "returns the default genserver options, with the callers pid" do
  #    assert %{
  #             id: Server,
  #             start: {Server, :start_link, [[], [name: :server]]}
  #           } == Server.child_spec()
  #  end
  # end

  # describe "handle_info/2 - file_event" do
  #  test "regonises file events from FileSystem, & returns a server_state" do
  #    server_state = ServerStateBuilder.build()

  #    assert {:noreply, new_server_state} =
  #             Server.handle_info(
  #               {:port, {:data, ~c"./test/ CLOSE_WRITE,CLOSE server_test.exs\n"}},
  #               server_state
  #             )

  #    assert new_server_state == server_state
  #  end
  # end
end
