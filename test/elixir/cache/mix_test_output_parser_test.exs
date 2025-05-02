defmodule PolyglotWatcherV2.Elixir.Cache.MixTestOutputParserTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.Elixir.Cache.MixTestOutputParser

  describe "run/1" do
    test "given some mix test output, groups the output by file" do
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

      fib =
        """
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


        """

      fizz =
        """
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


        """

      umbrella =
        """
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

      assert %{
               "test/fizz_buzz_test.exs" => %{
                 rank: 2,
                 raw: fizz,
                 failure_line_numbers: [17, 30, 5, 11, 23]
               },
               "test/fib_test.exs" => %{
                 rank: 3,
                 raw: fib,
                 failure_line_numbers: [15, 7, 11, 19]
               },
               "apps/umbrella/test/cool_test.exs" => %{
                 rank: 1,
                 raw: umbrella,
                 failure_line_numbers: [100]
               }
             } == MixTestOutputParser.run(mix_test_output)
    end

    test "with one test" do
      mix_test_output =
        """
        Running ExUnit with seed: 702986, max_cases: 16



        1) test can generate 2 items of the Fibonacci sequence (FibTest)
        test/fib_test.exs:15
        Assertion with == failed
        code:  assert Fib.sequence(2) == [1, 1]
        left:  [1, 2]
        right: [1, 1]
        stacktrace:
        test/fib_test.exs:16: (test)



        2) test can generate many items of the Fibonacci sequence (FibTest)
        test/fib_test.exs:19
        Assertion with == failed
        code:  assert Fib.sequence(3) == [1, 1, 2]
        left:  [2, 1, 3]
        right: [1, 1, 2]
        stacktrace:
        test/fib_test.exs:20: (test)



        3) test can generate 0 items of the Fibonacci sequence (FibTest)
        test/fib_test.exs:7
        Assertion with == failed
        code:  assert Fib.sequence(0) == []
        left:  [0]
        right: []
        stacktrace:
        test/fib_test.exs:8: (test)



        4) test can generate 1 item of the Fibonacci sequence (FibTest)
        test/fib_test.exs:11
        Assertion with == failed
        code:  assert Fib.sequence(1) == [1]
        left:  [2]
        right: [1]
        stacktrace:
        test/fib_test.exs:12: (test)


        Finished in 0.02 seconds (0.00s async, 0.02s sync)
        4 tests, 4 failures

        """

      mix_test_output_without_starting_lines =
        """
        1) test can generate 2 items of the Fibonacci sequence (FibTest)
        test/fib_test.exs:15
        Assertion with == failed
        code:  assert Fib.sequence(2) == [1, 1]
        left:  [1, 2]
        right: [1, 1]
        stacktrace:
        test/fib_test.exs:16: (test)



        2) test can generate many items of the Fibonacci sequence (FibTest)
        test/fib_test.exs:19
        Assertion with == failed
        code:  assert Fib.sequence(3) == [1, 1, 2]
        left:  [2, 1, 3]
        right: [1, 1, 2]
        stacktrace:
        test/fib_test.exs:20: (test)



        3) test can generate 0 items of the Fibonacci sequence (FibTest)
        test/fib_test.exs:7
        Assertion with == failed
        code:  assert Fib.sequence(0) == []
        left:  [0]
        right: []
        stacktrace:
        test/fib_test.exs:8: (test)



        4) test can generate 1 item of the Fibonacci sequence (FibTest)
        test/fib_test.exs:11
        Assertion with == failed
        code:  assert Fib.sequence(1) == [1]
        left:  [2]
        right: [1]
        stacktrace:
        test/fib_test.exs:12: (test)


        Finished in 0.02 seconds (0.00s async, 0.02s sync)
        4 tests, 4 failures

        """

      assert %{
               "test/fib_test.exs" => %{
                 rank: 1,
                 raw: mix_test_output_without_starting_lines,
                 failure_line_numbers: [11, 7, 19, 15]
               }
             } == MixTestOutputParser.run(mix_test_output)
    end

    test "removes ANSI escape sequences from the result" do
      mix_test_output =
        "Running ExUnit with seed: 143541, max_cases: 16\n\n\n\n  1) test run returns 'Fizz' for multiples of 3 (FizzBuzzTest)\n     \e[1m\e[30mtest/fizz_buzz_test.exs:5\e[0m\n     \e[31mAssertion with == failed\e[0m\n     \e[36mcode:  \e[0massert FizzBuzz.run(3) == \"Fizz\"\n     \e[36mleft:  \e[0m\e[31m[\"1\", \"2\", \"Fizz\"]\e[0m\n     \e[36mright: \e[0m\e[32m\"Fizz\"\e[0m\n     \e[36mstacktrace:\e[0m\n       test/fizz_buzz_test.exs:6: (test)\n\n\n\n  2) test run returns 'Buzz' for multiples of 5 (FizzBuzzTest)\n     \e[1m\e[30mtest/fizz_buzz_test.exs:11\e[0m\n     \e[31mAssertion with == failed\e[0m\n     \e[36mcode:  \e[0massert FizzBuzz.run(5) == \"Buzz\"\n     \e[36mleft:  \e[0m\e[31m[\"1\", \"2\", \"Fizz\", \"4\", \"Buzz\"]\e[0m\n     \e[36mright: \e[0m\e[32m\"Buzz\"\e[0m\n     \e[36mstacktrace:\e[0m\n       test/fizz_buzz_test.exs:12: (test)\n\n\n\n  3) test run returns 'FizzBuzz' for multiples of both 3 and 5 (FizzBuzzTest)\n     \e[1m\e[30mtest/fizz_buzz_test.exs:17\e[0m\n     \e[31mAssertion with == failed\e[0m\n     \e[36mcode:  \e[0massert FizzBuzz.run(15) == \"FizzBuzz\"\n     \e[36mleft:  \e[0m\e[31m[\"1\", \"2\", \"Fizz\", \"4\", \"Buzz\", \"Fizz\", \"7\", \"8\", \"Fizz\", \"Buzz\", \"11\", \"Fizz\", \"13\", \"14\", \"FizzBuzz\"]\e[0m\n     \e[36mright: \e[0m\e[32m\"FizzBuzz\"\e[0m\n     \e[36mstacktrace:\e[0m\n       test/fizz_buzz_test.exs:18: (test)\n\n\n\n  4) test run prints the FizzBuzz sequence up to n (FizzBuzzTest)\n     \e[1m\e[30mtest/fizz_buzz_test.exs:30\e[0m\n     \e[31mAssertion with == failed\e[0m\n     \e[36mcode:  \e[0massert output == expected_output\n     \e[36mleft:  \e[0m\"\e[48;5;88m\e[0m\"\n     \e[36mright: \e[0m\"\e[32m1\\n2\\nFizz\\n4\\nBuzz\\nFizz\\n7\\n8\\nFizz\\nBuzz\\n11\\nFizz\\n13\\n14\\nFizzBuzz\\n\e[0m\"\n     \e[36mstacktrace:\e[0m\n       test/fizz_buzz_test.exs:34: (test)\n\n\n\n  5) test run returns the number as a string for non-multiples of 3 or 5 (FizzBuzzTest)\n     \e[1m\e[30mtest/fizz_buzz_test.exs:23\e[0m\n     \e[31mAssertion with == failed\e[0m\n     \e[36mcode:  \e[0massert FizzBuzz.run(1) == \"1\"\n     \e[36mleft:  \e[0m\e[31m[\"1\"]\e[0m\n     \e[36mright: \e[0m\e[32m\"1\"\e[0m\n     \e[36mstacktrace:\e[0m\n       test/fizz_buzz_test.exs:24: (test)\n\n\nFinished in 0.04 seconds (0.00s async, 0.04s sync)\n\e[31m5 tests, 5 failures\e[0m\n"

      assert %{
               "test/fizz_buzz_test.exs" => %{
                 raw:
                   "  1) test run returns 'Fizz' for multiples of 3 (FizzBuzzTest)\n     test/fizz_buzz_test.exs:5\n     Assertion with == failed\n     code:  assert FizzBuzz.run(3) == \"Fizz\"\n     left:  [\"1\", \"2\", \"Fizz\"]\n     right: \"Fizz\"\n     stacktrace:\n       test/fizz_buzz_test.exs:6: (test)\n\n\n\n  2) test run returns 'Buzz' for multiples of 5 (FizzBuzzTest)\n     test/fizz_buzz_test.exs:11\n     Assertion with == failed\n     code:  assert FizzBuzz.run(5) == \"Buzz\"\n     left:  [\"1\", \"2\", \"Fizz\", \"4\", \"Buzz\"]\n     right: \"Buzz\"\n     stacktrace:\n       test/fizz_buzz_test.exs:12: (test)\n\n\n\n  3) test run returns 'FizzBuzz' for multiples of both 3 and 5 (FizzBuzzTest)\n     test/fizz_buzz_test.exs:17\n     Assertion with == failed\n     code:  assert FizzBuzz.run(15) == \"FizzBuzz\"\n     left:  [\"1\", \"2\", \"Fizz\", \"4\", \"Buzz\", \"Fizz\", \"7\", \"8\", \"Fizz\", \"Buzz\", \"11\", \"Fizz\", \"13\", \"14\", \"FizzBuzz\"]\n     right: \"FizzBuzz\"\n     stacktrace:\n       test/fizz_buzz_test.exs:18: (test)\n\n\n\n  4) test run prints the FizzBuzz sequence up to n (FizzBuzzTest)\n     test/fizz_buzz_test.exs:30\n     Assertion with == failed\n     code:  assert output == expected_output\n     left:  \"\"\n     right: \"1\\n2\\nFizz\\n4\\nBuzz\\nFizz\\n7\\n8\\nFizz\\nBuzz\\n11\\nFizz\\n13\\n14\\nFizzBuzz\\n\"\n     stacktrace:\n       test/fizz_buzz_test.exs:34: (test)\n\n\n\n  5) test run returns the number as a string for non-multiples of 3 or 5 (FizzBuzzTest)\n     test/fizz_buzz_test.exs:23\n     Assertion with == failed\n     code:  assert FizzBuzz.run(1) == \"1\"\n     left:  [\"1\"]\n     right: \"1\"\n     stacktrace:\n       test/fizz_buzz_test.exs:24: (test)\n\n\nFinished in 0.04 seconds (0.00s async, 0.04s sync)\n5 tests, 5 failures\n",
                 rank: 1,
                 failure_line_numbers: [23, 30, 17, 11, 5]
               }
             } = MixTestOutputParser.run(mix_test_output)
    end
  end
end
