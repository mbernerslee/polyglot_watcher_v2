defmodule PolyglotWatcherV2.Elixir.FailuresTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.Failures

  describe "update/4" do
    test "parses mix test output, adding failures to the list" do
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

      assert [{"test/elixir_lang_mix_test_test.exs", 6}] ==
               Failures.update([], test_path, mix_test_output, exit_code)
    end

    test "puts multiple failes in the list in the correct order, last first" do
      mix_test_output = """
        1) test update/4 parses mix test output, adding failures to the list (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:6
           ** (RuntimeError) no
           code:
           stacktrace:
             test/elixir_lang_mix_test_test.exs:29: (test)



        2) test update/4 x (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:32
           ** (RuntimeError) no
           code: test "x" do
           stacktrace:
             test/elixir_lang_mix_test_test.exs:33: (test)



      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      2 tests, 2 failures

      Randomized with seed 856017
      """

      exit_code = 1
      test_path = "test/elixir_lang_mix_test_test.exs"

      assert [
               {"test/elixir_lang_mix_test_test.exs", 32},
               {"test/elixir_lang_mix_test_test.exs", 6}
             ] ==
               Failures.update([], test_path, mix_test_output, exit_code)
    end

    test "clears failures from the list if the test passed" do
      mix_test_output = """
      ...

      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      3 tests, 0 failures

      Randomized with seed 821110

      """

      exit_code = 0
      test_path = "test/elixir_lang_mix_test_test.exs"

      failures = [
        {"test/elixir_lang_mix_test_test.exs", 32},
        {"test/elixir_lang_mix_test_test.exs", 6}
      ]

      assert [] ==
               Failures.update(failures, test_path, mix_test_output, exit_code)
    end

    test "clears failures from the list if the test (for a specific line only) passed" do
      mix_test_output = """
      ...

      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      3 tests, 0 failures

      Randomized with seed 821110

      """

      exit_code = 0
      test_path = "test/elixir_lang_mix_test_test.exs:32"

      failures = [
        {"test/elixir_lang_mix_test_test.exs", 32},
        {"test/elixir_lang_mix_test_test.exs", 6}
      ]

      assert [{"test/elixir_lang_mix_test_test.exs", 6}] ==
               Failures.update(failures, test_path, mix_test_output, exit_code)
    end

    test "clears failures from the list if 'mix test' passed" do
      mix_test_output = """
      ...

      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      3 tests, 0 failures

      Randomized with seed 821110

      """

      exit_code = 0
      test_path = :all

      failures = [
        {"test/elixir_lang_mix_test_test.exs", 32},
        {"test/elixir_lang_mix_test_test.exs", 6},
        {"test/cool_test.exs", 200},
        {"test/cool_test.exs", 1000}
      ]

      assert [] ==
               Failures.update(failures, test_path, mix_test_output, exit_code)
    end

    test "running a failing 'mix test' wipes historical test failures that didn't come up this time" do
      mix_test_output = """
        1) test update/4 parses mix test output, adding failures to the list (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:6
           ** (RuntimeError) no
           code:
           stacktrace:
             test/elixir_lang_mix_test_test.exs:29: (test)



        2) test update/4 x (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:32
           ** (RuntimeError) no
           code: test "x" do
           stacktrace:
             test/elixir_lang_mix_test_test.exs:33: (test)



      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      2 tests, 2 failures

      Randomized with seed 856017
      """

      exit_code = 1

      old_failures = [{"test/x_test.exs", 1}, {"test/y_test.exs", 2}]

      assert [
               {"test/elixir_lang_mix_test_test.exs", 32},
               {"test/elixir_lang_mix_test_test.exs", 6}
             ] ==
               Failures.update(old_failures, :all, mix_test_output, exit_code)
    end

    test "groups failures by path, with newest failures first" do
      mix_test_output = """
        1) test update/4 clears failures from the list if 'mix test' passed (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:3
           ** (RuntimeError) no
           code: raise "no"
           stacktrace:
             test/elixir_lang_mix_test_test.exs:3: (test)

        2) test update/4 clears failures from the list if 'mix test' passed (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:2
           ** (RuntimeError) no
           code: raise "no"
           stacktrace:
             test/elixir_lang_mix_test_test.exs:2: (test)

        3) test update/4 clears failures from the list if 'mix test' passed (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:1
           ** (RuntimeError) no
           code: raise "no"
           stacktrace:
             test/elixir_lang_mix_test_test.exs:1: (test)

        4) test x/4 a
           test/x_test.exs:10
           ** (RuntimeError) no
           code: raise "no"
           stacktrace:
             test/x_test.exs:10: (test)

        5) test x/4 b
           test/x_test.exs:11
           ** (RuntimeError) no
           code: raise "no"
           stacktrace:
             test/x_test.exs:11: (test)

      ....

      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      5 tests, 1 failure

      Randomized with seed 211756

      """

      exit_code = 1
      test_path = "elixir_lang_mix_test_test"

      failures = [
        {"test/elixir_lang_determiner_test.exs", 6},
        {"test/server_test.exs", 7},
        {"test/elixir_lang_fix_all_for_file_mode_test.exs", 8},
        {"test/elixir_lang_mix_test_test.exs", 4},
        {"test/elixir_lang_mix_test_test.exs", 5},
        {"test/determine_test.exs", 9}
      ]

      assert [
               {"test/x_test.exs", 11},
               {"test/x_test.exs", 10},
               {"test/elixir_lang_mix_test_test.exs", 1},
               {"test/elixir_lang_mix_test_test.exs", 2},
               {"test/elixir_lang_mix_test_test.exs", 3},
               {"test/elixir_lang_mix_test_test.exs", 4},
               {"test/elixir_lang_mix_test_test.exs", 5},
               {"test/elixir_lang_determiner_test.exs", 6},
               {"test/server_test.exs", 7},
               {"test/elixir_lang_fix_all_for_file_mode_test.exs", 8},
               {"test/determine_test.exs", 9}
             ] ==
               Failures.update(failures, test_path, mix_test_output, exit_code)
    end

    test "shell colour stuff isn't saved in the test_path" do
      mix_test_output = """
        1) test update/4 clears failures from the list if 'mix test' passed (PolyglotWatcherV2.FailuresTest)
           \e[1m\e[30mtest/elixir_lang_mix_test_test.exs:113
           ** (RuntimeError) no
           code: raise "no"
           stacktrace:
             test/elixir_lang_mix_test_test.exs:134: (test)

      ....

      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      5 tests, 1 failure

      Randomized with seed 211756
      """

      exit_code = 1
      test_path = :all

      failures = []

      assert [{"test/elixir_lang_mix_test_test.exs", 113}] ==
               Failures.update(failures, test_path, mix_test_output, exit_code)
    end

    test "when the test path is test/x_test.exs --max-failures 1, and it passed, then remove all x_test failures from the list" do
      mix_test_output = """
      ...

      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      3 tests, 0 failures

      Randomized with seed 821110

      """

      exit_code = 0
      test_path = "test/x_test.exs --max-failures 1"

      failures = [
        {"test/x_test.exs", 1},
        {"test/x_test.exs", 2},
        {"test/x_test.exs", 3},
        {"test/y_test.exs", 4}
      ]

      assert [{"test/y_test.exs", 4}] ==
               Failures.update(failures, test_path, mix_test_output, exit_code)
    end

    test "when the test path is '--failed --max-failures 1', and it passed, then remove all failures from the list" do
      mix_test_output = """
      ...

      Finished in 0.02 seconds (0.02s async, 0.00s sync)
      3 tests, 0 failures

      Randomized with seed 821110

      """

      exit_code = 0
      test_path = "--failed --max-failures 1"

      failures = [
        {"test/x_test.exs", 1},
        {"test/y_test.exs", 2},
        {"test/z_test.exs", 3}
      ]

      assert [] == Failures.update(failures, test_path, mix_test_output, exit_code)
    end
  end

  test "for_file/2 given a test_file_path & a list of failures, returns the ordered failures for that file path only" do
    assert [] == Failures.for_file([], "test/x_test.exs")

    assert [{"test/x_test.exs", 10}] ==
             Failures.for_file([{"test/x_test.exs", 10}], "test/x_test.exs")

    assert [
             {"test/x_test.exs", 10},
             {"test/x_test.exs", 20},
             {"test/x_test.exs", 30},
             {"test/x_test.exs", 40},
             {"test/x_test.exs", 50}
           ] ==
             Failures.for_file(
               [
                 {"test/x_test.exs", 10},
                 {"test/x_test.exs", 20},
                 {"test/x_test.exs", 30},
                 {"test/other_test.exs", 10},
                 {"test/other_test.exs", 20},
                 {"test/other_test.exs", 30},
                 {"test/x_test.exs", 40},
                 {"test/yet_another_test.exs", 10},
                 {"test/yet_another_test.exs", 20},
                 {"test/yet_another_test.exs", 30},
                 {"test/x_test.exs", 50}
               ],
               "test/x_test.exs"
             )
  end

  describe "count/2" do
    test "given a list of failures and a filename, counts all the failures for that file name" do
      assert Failures.count(
               [
                 {"test/x_test.exs", 10},
                 {"test/x_test.exs", 20},
                 {"test/x_test.exs", 30},
                 {"test/other_test.exs", 10},
                 {"test/other_test.exs", 20},
                 {"test/other_test.exs", 30},
                 {"test/x_test.exs", 40},
                 {"test/yet_another_test.exs", 10},
                 {"test/yet_another_test.exs", 20},
                 {"test/yet_another_test.exs", 30},
                 {"test/x_test.exs", 50}
               ],
               "test/x_test.exs"
             ) == 5
    end

    test "given a list of failures and :all, counts all the failures" do
      assert Failures.count(
               [
                 {"test/x_test.exs", 10},
                 {"test/x_test.exs", 20},
                 {"test/x_test.exs", 30},
                 {"test/other_test.exs", 10},
                 {"test/other_test.exs", 20},
                 {"test/other_test.exs", 30},
                 {"test/x_test.exs", 40},
                 {"test/yet_another_test.exs", 10},
                 {"test/yet_another_test.exs", 20},
                 {"test/yet_another_test.exs", 30},
                 {"test/x_test.exs", 50}
               ],
               :all
             ) == 11
    end
  end

  describe "failures_count_message/1" do
    test "given a count > 1, return a magenta message" do
      assert Failures.count_message(2) ==
               [
                 {[:cyan, :italic], "--------------------------------------"},
                 {[:cyan, :italic], " 2 failing tests remain "},
                 {[:cyan, :italic], "--------------------------------------"}
               ]

      assert Failures.count_message(42) ==
               [
                 {[:cyan, :italic], "--------------------------------------"},
                 {[:cyan, :italic], " 42 failing tests remain "},
                 {[:cyan, :italic], "--------------------------------------"}
               ]
    end

    test "given a count = 1, return a magenta message in the singular" do
      assert Failures.count_message(1) ==
               [
                 {[:cyan, :italic], "--------------------------------------"},
                 {[:cyan, :italic], " 1 failing test remains "},
                 {[:cyan, :italic], "--------------------------------------"}
               ]
    end

    test "given a count = 0, return a green message" do
      assert Failures.count_message(0) ==
               [
                 {[:green, :italic], "--------------------------------------"},
                 {[:green, :italic], " 0 failing tests remain! "},
                 {[:green, :italic], "--------------------------------------"}
               ]
    end
  end
end
