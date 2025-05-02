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
  end
end
