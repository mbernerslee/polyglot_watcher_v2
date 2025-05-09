defmodule PolyglotWatcherV2.Elixir.Cache.TestFileASTParserTest do
  use ExUnit.Case
  alias PolyglotWatcherV2.Elixir.Cache.TestFileASTParser

  describe "run/1" do
    test "very simple module" do
      code = """
      defmodule SimpleTest do
        use ExUnit.Case

        test "basic test" do
          assert true
        end
      end
      """

      assert %{:"test basic test" => 4} == TestFileASTParser.run(code)
    end

    test "module with describe blocks" do
      code = """
      defmodule DescribeTest do
        use ExUnit.Case

        describe "group 1" do
          test "test 1" do
            assert true
          end

          test "test 2" do
            assert false
          end
        end

        describe "group 2" do
          test "test 3" do
            assert nil
          end
        end
      end
      """

      expected = %{
        :"test group 1 test 1" => 5,
        :"test group 1 test 2" => 9,
        :"test group 2 test 3" => 15
      }

      assert expected == TestFileASTParser.run(code)
    end

    test "module with setup and test using context" do
      code = """
      defmodule SetupTest do
        use ExUnit.Case

        setup do
          {:ok, number: 42}
        end

        test "uses setup context", %{number: num} do
          assert num == 42
        end
      end
      """

      assert %{:"test uses setup context" => 8} == TestFileASTParser.run(code)
    end

    test "multiple test modules in one file" do
      code = """
      defmodule FirstTest do
        use ExUnit.Case

        test "first module test" do
          assert true
        end
      end

      defmodule SecondTest do
        use ExUnit.Case

        test "second module test" do
          assert false
        end
      end
      """

      expected = %{
        :"test first module test" => 4,
        :"test second module test" => 12
      }

      assert expected == TestFileASTParser.run(code)
    end

    test "module with various test definitions" do
      code = """
      defmodule VariousTestsModule do
        use ExUnit.Case

        test "simple test" do
          assert true
        end

        @tag :important
        test "tagged test", do: assert 1 + 1 == 2

        test "test with options", timeout: 1000 do
          :timer.sleep(500)
          assert true
        end
      end
      """

      expected = %{
        :"test simple test" => 4,
        :"test tagged test" => 9,
        :"test test with options" => 11
      }

      assert expected == TestFileASTParser.run(code)
    end

    test "handles invalid Elixir code gracefully" do
      invalid_code = "this is not valid Elixir code"
      assert %{} == TestFileASTParser.run(invalid_code)
    end

    test "handles empty string" do
      assert %{} == TestFileASTParser.run("")
    end

    test "handles module without tests" do
      code = """
      defmodule NoTestsModule do
        def some_function, do: :ok
      end
      """

      assert %{} == TestFileASTParser.run(code)
    end
  end
end
