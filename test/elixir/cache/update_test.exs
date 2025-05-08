defmodule PolyglotWatcherV2.Elixir.Cache.UpdateTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.Cache.{File, LibFile, TestFile}
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.Elixir.Cache.Update

  describe "run/4" do
    test "new - reads the lib & test file & adds them to the files" do
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
      test_path = "test/elixir_lang_mix_test_test.exs:6"

      Mimic.expect(FileWrapper, :read, 2, fn
        "test/elixir_lang_mix_test_test.exs" -> {:ok, "test contents"}
        "lib/elixir_lang_mix_test.ex" -> {:ok, "lib contents"}
      end)

      assert %{
               "test/elixir_lang_mix_test_test.exs" => %File{
                 test: %TestFile{
                   path: "test/elixir_lang_mix_test_test.exs",
                   contents: "test contents",
                   failed_line_numbers: [6]
                 },
                 lib: %LibFile{path: "lib/elixir_lang_mix_test.ex", contents: "lib contents"},
                 mix_test_output: mix_test_output,
                 rank: 1
               }
             } == Update.run(%{}, test_path, mix_test_output, exit_code)
    end

    test "update - reads the lib & test file & adds them to the files" do
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
      test_path = "test/elixir_lang_mix_test_test.exs:6"

      Mimic.expect(FileWrapper, :read, 2, fn
        "test/elixir_lang_mix_test_test.exs" -> {:ok, "new test contents"}
        "lib/elixir_lang_mix_test.ex" -> {:ok, "new lib contents"}
      end)

      old_files = %{
        "test/elixir_lang_mix_test_test.exs" => %File{
          test: %TestFile{
            path: "test/elixir_lang_mix_test_test.exs",
            contents: "old test contents",
            failed_line_numbers: []
          },
          lib: %LibFile{path: "lib/elixir_lang_mix_test.ex", contents: "old lib contents"},
          mix_test_output: nil,
          rank: 1
        }
      }

      expected_new_files = %{
        "test/elixir_lang_mix_test_test.exs" => %File{
          test: %TestFile{
            path: "test/elixir_lang_mix_test_test.exs",
            contents: "new test contents",
            failed_line_numbers: [6]
          },
          lib: %LibFile{path: "lib/elixir_lang_mix_test.ex", contents: "new lib contents"},
          mix_test_output: mix_test_output,
          rank: 1
        }
      }

      assert expected_new_files == Update.run(old_files, test_path, mix_test_output, exit_code)
    end

    test "new tests get lower rankings" do
      mix_test_output =
        """
        Running ExUnit with seed: 809977, max_cases: 16



        1) test can generate many items of the Fibonacci sequence (FibTest)
           test/fib_test.exs:19
           Assertion with == failed
           code:  assert Fib.sequence(3) == [1, 1, 2]
           left:  [2, 1, 3]
           right: [1, 1, 2]
           stacktrace:
             test/fib_test.exs:20: (test)



        2) test can generate 1 item of the Fibonacci sequence (FibTest)
           test/fib_test.exs:11
           Assertion with == failed
           code:  assert Fib.sequence(1) == [1]
           left:  [2]
           right: [1]
           stacktrace:
             test/fib_test.exs:12: (test)



        3) test can generate 0 items of the Fibonacci sequence (FibTest)
           test/fib_test.exs:7
           Assertion with == failed
           code:  assert Fib.sequence(0) == []
           left:  [0]
           right: []
           stacktrace:
             test/fib_test.exs:8: (test)



        4) test can generate 2 items of the Fibonacci sequence (FibTest)
           test/fib_test.exs:15
           Assertion with == failed
           code:  assert Fib.sequence(2) == [1, 1]
           left:  [1, 2]
           right: [1, 1]
           stacktrace:
             test/fib_test.exs:16: (test)



        5) test run returns the number as a string for non-multiples of 3 or 5 (FizzBuzzTest)
           test/fizz_buzz_test.exs:23
           Assertion with == failed
           code:  assert FizzBuzz.run(1) == "1"
           left:  ["1"]
           right: "1"
           stacktrace:
             test/fizz_buzz_test.exs:24: (test)



        6) test run returns 'Buzz' for multiples of 5 (FizzBuzzTest)
           test/fizz_buzz_test.exs:11
           Assertion with == failed
           code:  assert FizzBuzz.run(5) == "Buzz"
           left:  ["1", "2", "Fizz", "4", "Buzz"]
           right: "Buzz"
           stacktrace:
             test/fizz_buzz_test.exs:12: (test)



        7) test run returns 'Fizz' for multiples of 3 (FizzBuzzTest)
           test/fizz_buzz_test.exs:5
           Assertion with == failed
           code:  assert FizzBuzz.run(3) == "Fizz"
           left:  ["1", "2", "Fizz"]
           right: "Fizz"
           stacktrace:
             test/fizz_buzz_test.exs:6: (test)



        8) test run prints the FizzBuzz sequence up to n (FizzBuzzTest)
           test/fizz_buzz_test.exs:30
           Assertion with == failed
           code:  assert output == expected_output
           left:  ""
           right: "1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz\n"
           stacktrace:
             test/fizz_buzz_test.exs:34: (test)



        9) test run returns 'FizzBuzz' for multiples of both 3 and 5 (FizzBuzzTest)
           test/fizz_buzz_test.exs:17
           Assertion with == failed
           code:  assert FizzBuzz.run(15) == "FizzBuzz"
           left:  ["1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz", "11", "Fizz", "13", "14", "FizzBuzz"]
           right: "FizzBuzz"
           stacktrace:
             test/fizz_buzz_test.exs:18: (test)



        10) Umbrella
            apps/umbrella/test/cool_test.exs:100
            Assertion with == failed
            code:  assert Umbrella.run(1) == "2"
            left:  "1"
            right: "2"
            stacktrace:
              apps/umbrella/test/cool_test.exs:200: (test)


        Finished in 0.04 seconds (0.00s async, 0.04s sync)
        10 tests, 10 failures
        """

      exit_code = 1

      Mimic.expect(FileWrapper, :read, 2, fn
        "test/fib_test.exs" -> {:ok, "new fib test contents"}
        "lib/fib.ex" -> {:ok, "new fib lib contents"}
        "test/fizz_buzz_test.exs" -> {:ok, "new fizz_buzz test contents"}
        "lib/fizz_buzz.ex" -> {:ok, "new fizz_buzz lib contents"}
        "apps/umbrella/test/cool_test.exs" -> {:ok, "new umbrella test contents"}
        "apps/umbrella/lib/cool.ex" -> {:ok, "new umbrella lib contents"}
      end)

      old_files = %{
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: []
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: nil,
          rank: 1
        },
        "test/fib_test.exs" => %File{
          test: %TestFile{
            path: "test/fib_test.exs",
            contents: "old fib test contents",
            failed_line_numbers: []
          },
          lib: %LibFile{path: "lib/fib.ex", contents: "old fib lib contents"},
          mix_test_output: nil,
          rank: 2
        },
        "test/fizz_buzz_test.exs" => %File{
          test: %TestFile{
            path: "test/fizz_buzz_test.exs",
            contents: "old fizz_buzz test contents",
            failed_line_numbers: []
          },
          lib: %LibFile{path: "lib/fizz_buzz.ex", contents: "old fizz_buzz lib contents"},
          mix_test_output: nil,
          rank: 3
        },
        "app/umbrella/test/cool_test.exs" => %File{
          test: %TestFile{
            path: "app/umbrella/test/cool_test.exs",
            contents: "old umbrella test contents",
            failed_line_numbers: []
          },
          lib: %LibFile{
            path: "app/umbrella/test/lib/umbrella.ex",
            contents: "old umbrella lib contents"
          },
          mix_test_output: nil,
          rank: 4
        }
      }

      assert %{
               "apps/umbrella/test/cool_test.exs" => %File{
                 rank: 1
               },
               "test/fizz_buzz_test.exs" => %File{
                 rank: 2
               },
               "test/fib_test.exs" => %File{
                 rank: 3
               },
               "test/other_test.exs" => %File{
                 rank: 4
               }
             } = Update.run(old_files, "test/fib_test.exs", mix_test_output, exit_code)
    end

    test "when all tests pass, they are deleted" do
      mix_test_output =
        """
        Finished in 0.1 seconds (0.1s async, 0.00s sync)
        3 tests, 0 failures

        Randomized with seed 373936
        """

      exit_code = 0

      old_files = %{
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: [1, 2, 3, 4, 5]
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: "x",
          rank: 1
        },
        "test/fib_test.exs" => %File{
          test: %TestFile{
            path: "test/fib_test.exs",
            contents: "old fib test contents",
            failed_line_numbers: [6, 7, 8]
          },
          lib: %LibFile{path: "lib/fib.ex", contents: "old fib lib contents"},
          mix_test_output: "y",
          rank: 2
        },
        "test/fizz_buzz_test.exs" => %File{
          test: %TestFile{
            path: "test/fizz_buzz_test.exs",
            contents: "old fizz_buzz test contents",
            failed_line_numbers: [9, 10, 11, 12, 13, 14]
          },
          lib: %LibFile{path: "lib/fizz_buzz.ex", contents: "old fizz_buzz lib contents"},
          mix_test_output: "z",
          rank: 3
        },
        "app/umbrella/test/cool_test.exs" => %File{
          test: %TestFile{
            path: "app/umbrella/test/cool_test.exs",
            contents: "old umbrella test contents",
            failed_line_numbers: [15, 16, 17, 18]
          },
          lib: %LibFile{
            path: "app/umbrella/test/lib/umbrella.ex",
            contents: "old umbrella lib contents"
          },
          mix_test_output: "zz",
          rank: 4
        }
      }

      assert %{} == Update.run(old_files, :all, mix_test_output, exit_code)
    end

    test "when all tests pass for a file only, they are deleted" do
      mix_test_output =
        """
        Finished in 0.1 seconds (0.1s async, 0.00s sync)
        3 tests, 0 failures

        Randomized with seed 373936
        """

      exit_code = 0

      old_files = %{
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: [1, 2, 3, 4, 5]
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: "x",
          rank: 1
        },
        "test/fib_test.exs" => %File{
          test: %TestFile{
            path: "test/fib_test.exs",
            contents: "old fib test contents",
            failed_line_numbers: [6, 7, 8]
          },
          lib: %LibFile{path: "lib/fib.ex", contents: "old fib lib contents"},
          mix_test_output: "y",
          rank: 2
        },
        "test/fizz_buzz_test.exs" => %File{
          test: %TestFile{
            path: "test/fizz_buzz_test.exs",
            contents: "old fizz_buzz test contents",
            failed_line_numbers: [9, 10, 11, 12, 13, 14]
          },
          lib: %LibFile{path: "lib/fizz_buzz.ex", contents: "old fizz_buzz lib contents"},
          mix_test_output: "z",
          rank: 3
        },
        "app/umbrella/test/cool_test.exs" => %File{
          test: %TestFile{
            path: "app/umbrella/test/cool_test.exs",
            contents: "old umbrella test contents",
            failed_line_numbers: [15, 16, 17, 18]
          },
          lib: %LibFile{
            path: "app/umbrella/test/lib/umbrella.ex",
            contents: "old umbrella lib contents"
          },
          mix_test_output: "zz",
          rank: 4
        }
      }

      expected_files = %{
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: [1, 2, 3, 4, 5]
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: "x",
          rank: 1
        },
        "test/fizz_buzz_test.exs" => %File{
          test: %TestFile{
            path: "test/fizz_buzz_test.exs",
            contents: "old fizz_buzz test contents",
            failed_line_numbers: [9, 10, 11, 12, 13, 14]
          },
          lib: %LibFile{path: "lib/fizz_buzz.ex", contents: "old fizz_buzz lib contents"},
          mix_test_output: "z",
          rank: 3
        },
        "app/umbrella/test/cool_test.exs" => %File{
          test: %TestFile{
            path: "app/umbrella/test/cool_test.exs",
            contents: "old umbrella test contents",
            failed_line_numbers: [15, 16, 17, 18]
          },
          lib: %LibFile{
            path: "app/umbrella/test/lib/umbrella.ex",
            contents: "old umbrella lib contents"
          },
          mix_test_output: "zz",
          rank: 4
        }
      }

      assert expected_files ==
               Update.run(old_files, "test/fib_test.exs", mix_test_output, exit_code)
    end

    test "when tests pass for single test in a file only, that failing test alone is removed from the list" do
      mix_test_output =
        """
        Finished in 0.1 seconds (0.1s async, 0.00s sync)
        3 tests, 0 failures

        Randomized with seed 373936
        """

      exit_code = 0

      old_files = %{
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: [1, 2, 3, 4, 5]
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: "x",
          rank: 1
        },
        "test/fib_test.exs" => %File{
          test: %TestFile{
            path: "test/fib_test.exs",
            contents: "old fib test contents",
            failed_line_numbers: [6, 7, 8]
          },
          lib: %LibFile{path: "lib/fib.ex", contents: "old fib lib contents"},
          mix_test_output: "y",
          rank: 2
        },
        "test/fizz_buzz_test.exs" => %File{
          test: %TestFile{
            path: "test/fizz_buzz_test.exs",
            contents: "old fizz_buzz test contents",
            failed_line_numbers: [9, 10, 11, 12, 13, 14]
          },
          lib: %LibFile{path: "lib/fizz_buzz.ex", contents: "old fizz_buzz lib contents"},
          mix_test_output: "z",
          rank: 3
        },
        "app/umbrella/test/cool_test.exs" => %File{
          test: %TestFile{
            path: "app/umbrella/test/cool_test.exs",
            contents: "old umbrella test contents",
            failed_line_numbers: [15, 16, 17, 18]
          },
          lib: %LibFile{
            path: "app/umbrella/test/lib/umbrella.ex",
            contents: "old umbrella lib contents"
          },
          mix_test_output: "zz",
          rank: 4
        }
      }

      expected_files = %{
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: [1, 2, 3, 4, 5]
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: "x",
          rank: 1
        },
        "test/fib_test.exs" => %File{
          test: %TestFile{
            path: "test/fib_test.exs",
            contents: "old fib test contents",
            failed_line_numbers: [6, 8]
          },
          lib: %LibFile{path: "lib/fib.ex", contents: "old fib lib contents"},
          mix_test_output: "y",
          rank: 2
        },
        "test/fizz_buzz_test.exs" => %File{
          test: %TestFile{
            path: "test/fizz_buzz_test.exs",
            contents: "old fizz_buzz test contents",
            failed_line_numbers: [9, 10, 11, 12, 13, 14]
          },
          lib: %LibFile{path: "lib/fizz_buzz.ex", contents: "old fizz_buzz lib contents"},
          mix_test_output: "z",
          rank: 3
        },
        "app/umbrella/test/cool_test.exs" => %File{
          test: %TestFile{
            path: "app/umbrella/test/cool_test.exs",
            contents: "old umbrella test contents",
            failed_line_numbers: [15, 16, 17, 18]
          },
          lib: %LibFile{
            path: "app/umbrella/test/lib/umbrella.ex",
            contents: "old umbrella lib contents"
          },
          mix_test_output: "zz",
          rank: 4
        }
      }

      assert expected_files ==
               Update.run(old_files, "test/fib_test.exs:7", mix_test_output, exit_code)
    end

    test "when the last failing test for a file passes, the entire file entry is removed" do
      mix_test_output = """
      Finished in 0.1 seconds (0.1s async, 0.00s sync)
      1 test, 0 failures

      Randomized with seed 373936
      """

      exit_code = 0

      old_files = %{
        "test/fib_test.exs" => %File{
          test: %TestFile{
            path: "test/fib_test.exs",
            contents: "old fib test contents",
            failed_line_numbers: [7]
          },
          lib: %LibFile{path: "lib/fib.ex", contents: "old fib lib contents"},
          mix_test_output: "y",
          rank: 2
        },
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: [1, 2, 3]
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: "x",
          rank: 1
        }
      }

      expected_files = %{
        "test/other_test.exs" => %File{
          test: %TestFile{
            path: "test/other_test.exs",
            contents: "old other test contents",
            failed_line_numbers: [1, 2, 3]
          },
          lib: %LibFile{path: "lib/other.ex", contents: "old other lib contents"},
          mix_test_output: "x",
          rank: 1
        }
      }

      assert expected_files ==
               Update.run(old_files, "test/fib_test.exs:7", mix_test_output, exit_code)
    end
  end
end
