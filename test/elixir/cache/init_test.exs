defmodule PolyglotWatcherV2.Elixir.Cache.InitTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.{ExUnitFailuresManifest, SystemCall}
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.Elixir.Cache.{Init, File, LibFile, TestFile}

  @cwd "/home/berners/src/fib"
  @lib_path_rel_1 "lib/fib.ex"
  @test_path_abs_1 "/home/berners/src/fib/test/fib_test.exs"
  @test_path_rel_1 "test/fib_test.exs"
  @lib_contents_1 """
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
  @test_contents_1 """
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

  @lib_path_rel_2 "lib/another.ex"
  @test_path_abs_2 "/home/berners/src/fib/test/another_test.exs"
  @test_path_rel_2 "test/another_test.exs"
  @lib_contents_2 """
    defmodule Fib.Another do
      def hello, do: :world
    end
  """
  @test_contents_2 """
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

  describe "run/0" do
    test "reads the ExUnit test failures manifest, parses it & updates it in the GenServer state" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(FileWrapper, :cwd!, fn -> "/home/berners/src/fib" end)

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{
          {FibTest, :"test can generate 1 item of the Fibonacci sequence"} => @test_path_abs_1,
          {FibTest, :"test can generate 2 items of the Fibonacci sequence"} => @test_path_abs_1,
          {FibTest, :"test can generate many items of the Fibonacci sequence"} =>
            @test_path_abs_1,
          {AnotherTest, :"test greets the world"} => @test_path_abs_2,
          {AnotherTest, :"test other test"} => @test_path_abs_2
        }
      end)

      Mimic.expect(FileWrapper, :read, 4, fn
        @test_path_rel_1 -> {:ok, @test_contents_1}
        @lib_path_rel_1 -> {:ok, @lib_contents_1}
        @test_path_rel_2 -> {:ok, @test_contents_2}
        @lib_path_rel_2 -> {:ok, @lib_contents_2}
      end)

      assert %{
               @test_path_rel_1 => %File{
                 test: %TestFile{
                   path: @test_path_rel_1,
                   contents: @test_contents_1,
                   failed_line_numbers: [11, 15, 19]
                 },
                 lib: %LibFile{path: @lib_path_rel_1, contents: @lib_contents_1},
                 mix_test_output: nil,
                 rank: rank_1
               },
               @test_path_rel_2 => %{
                 test: %{
                   path: @test_path_rel_2,
                   contents: @test_contents_2,
                   failed_line_numbers: [3, 7]
                 },
                 lib: %{path: @lib_path_rel_2, contents: @lib_contents_2},
                 mix_test_output: nil,
                 rank: rank_2
               }
             } =
               Init.run()

      assert Enum.sort([rank_1, rank_2]) == [1, 2]
    end

    test "handles describe blocks which change the ExUnit Failure manifest structure to have the test named prefixed by it" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(FileWrapper, :cwd!, fn -> "/home/berners/src/fib" end)

      test_contents = """
        defmodule FibTest do
          use ExUnit.Case
          doctest Fib

          describe "sequence/1" do
            test "can generate 0 items of the Fibonacci sequence" do
              assert Fib.sequence(0) == []
            end

            test "can generate 1 item of the Fibonacci sequence" do
              assert Fib.sequence(1) == [1]
            end
          end

          test "can generate 1 item of the Fibonacci sequence" do
            assert Fib.sequence(1) == [1]
          end

          test "can cool 0" do
            assert Fib.cool(0) == []
          end

          describe "cool/1" do
            test "can cool 0" do
              assert Fib.cool(0) == []
            end

            test "can cool 1" do
              assert Fib.cool(1) == [1]
            end
          end
        end
      """

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{
          {FibTest, :"test sequence/0 can generate 0 items of the Fibonacci sequence"} =>
            @test_path_abs_1,
          {FibTest, :"test sequence/0 can generate 1 item of the Fibonacci sequence"} =>
            @test_path_abs_1,
          {FibTest, :"test can generate 1 item of the Fibonacci sequence"} => @test_path_abs_1,
          {FibTest, :"test can cool/0"} => @test_path_abs_1,
          {FibTest, :"test cool/0 can cool 0"} => @test_path_abs_1,
          {FibTest, :"test cool/0 can cool 1"} => @test_path_abs_1
        }
      end)

      Mimic.expect(FileWrapper, :read, 2, fn
        @test_path_rel_1 -> {:ok, test_contents}
        @lib_path_rel_1 -> {:ok, @lib_contents_1}
      end)

      assert %{
               @test_path_rel_1 => %File{
                 test: %TestFile{
                   failed_line_numbers: actual_failed_line_numbers
                 }
               }
             } = Init.run()

      assert [6, 10, 15, 19, 24, 28] == actual_failed_line_numbers
    end

    test "returns no files when no manifest file was found by 'find'" do
      Mimic.expect(SystemCall, :cmd, fn _, _ -> {"", 0} end)

      assert %{} == Init.run()
    end

    test "returns no files when 'find' system call errors" do
      Mimic.expect(SystemCall, :cmd, fn _, _ -> {"error", 1} end)

      assert %{} == Init.run()
    end

    test "when a test file is not found, ignore it and do not attempt to read its lib file, but keep the others" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(FileWrapper, :cwd!, fn -> @cwd end)

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{
          {FibTest, :"test can generate 1 item of the Fibonacci sequence"} => @test_path_abs_1,
          {FibTest, :"test can generate 2 items of the Fibonacci sequence"} => @test_path_abs_1,
          {FibTest, :"test can generate many items of the Fibonacci sequence"} =>
            @test_path_abs_1,
          {AnotherTest, :"test greets the world"} => @test_path_abs_2,
          {AnotherTest, :"test other test"} => @test_path_abs_2
        }
      end)

      Mimic.expect(FileWrapper, :read, 3, fn
        @test_path_rel_1 -> {:ok, @test_contents_1}
        @lib_path_rel_1 -> {:ok, @lib_contents_1}
        @test_path_rel_2 -> {:error, :enoent}
      end)

      assert %{
               @test_path_rel_1 => %File{
                 test: %TestFile{
                   path: @test_path_rel_1,
                   contents: @test_contents_1,
                   failed_line_numbers: [11, 15, 19]
                 },
                 lib: %LibFile{path: @lib_path_rel_1, contents: @lib_contents_1},
                 mix_test_output: nil,
                 rank: 1
               }
             } == Init.run()
    end

    test "when no equivalent lib file is found, keep the test file but make the lib file nil" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(FileWrapper, :cwd!, fn -> @cwd end)

      bad_test_path = "bad/path/for/testing/fail_test.exs"

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{
          {FibTest, :"test can generate 1 item of the Fibonacci sequence"} => bad_test_path
        }
      end)

      Mimic.expect(FileWrapper, :read, 1, fn
        ^bad_test_path -> {:ok, @test_contents_1}
      end)

      assert %{
               bad_test_path => %File{
                 test: %TestFile{
                   path: bad_test_path,
                   contents: @test_contents_1,
                   failed_line_numbers: [11]
                 },
                 lib: %LibFile{path: nil, contents: nil},
                 mix_test_output: nil,
                 rank: 1
               }
             } == Init.run()
    end

    test "when no lib file is found, keep the test file but make the lib file nil" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(FileWrapper, :cwd!, fn -> @cwd end)

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{
          {FibTest, :"test can generate 1 item of the Fibonacci sequence"} => @test_path_abs_1
        }
      end)

      Mimic.expect(FileWrapper, :read, 2, fn
        @test_path_rel_1 -> {:ok, @test_contents_1}
        @lib_path_rel_1 -> {:error, :enoent}
      end)

      assert %{
               @test_path_rel_1 => %File{
                 test: %TestFile{
                   path: @test_path_rel_1,
                   contents: @test_contents_1,
                   failed_line_numbers: [11]
                 },
                 lib: %LibFile{path: @lib_path_rel_1, contents: nil},
                 mix_test_output: nil,
                 rank: 1
               }
             } == Init.run()
    end

    test "handles empty manifest" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(FileWrapper, :cwd!, fn -> @cwd end)

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{}
      end)

      assert %{} == Init.run()
    end

    test "when the manifests tests aren't found in the test contents we igonre them" do
      Mimic.expect(SystemCall, :cmd, fn _, _ ->
        {"./_build/test/lib/fib/.mix/.mix_test_failures\n", 0}
      end)

      Mimic.expect(FileWrapper, :cwd!, fn -> @cwd end)

      Mimic.expect(ExUnitFailuresManifest, :read, fn _ ->
        %{
          {FibTest, :"test BAD FAKE MISSING"} => @test_path_abs_1,
          {FibTest, :"test can generate 0 items of the Fibonacci sequence"} => @test_path_abs_1
        }
      end)

      Mimic.expect(FileWrapper, :read, 2, fn
        @test_path_rel_1 -> {:ok, @test_contents_1}
        @lib_path_rel_1 -> {:ok, @lib_contents_1}
      end)

      assert %{
               @test_path_rel_1 => %File{
                 test: %TestFile{
                   path: @test_path_rel_1,
                   contents: @test_contents_1,
                   failed_line_numbers: [7]
                 },
                 lib: %LibFile{path: @lib_path_rel_1, contents: @lib_contents_1},
                 mix_test_output: nil,
                 rank: 1
               }
             } == Init.run()
    end
  end
end
