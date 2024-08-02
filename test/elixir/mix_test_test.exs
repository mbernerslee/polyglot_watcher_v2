defmodule PolyglotWatcherV2.Elixir.MixTestTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.Elixir.MixTest
  alias PolyglotWatcherV2.{ShellCommandRunner, ServerStateBuilder}

  describe "run/2" do
    test "given a test path & server state, runs the mix test command with the test path" do
      test_path = "test/path/to/file_test.exs"
      mock_mix_test_output = mock_mix_test_output()
      exit_code = 0

      Mimic.expect(ShellCommandRunner, :run, fn shell_command ->
        assert shell_command == "mix test #{test_path} --color"
        {mock_mix_test_output, exit_code}
      end)

      server_state = ServerStateBuilder.build()

      assert {0, new_server_state} = MixTest.run(test_path, server_state)

      assert server_state
             |> put_in([:elixir, :mix_test_output], mock_mix_test_output)
             |> put_in([:elixir, :mix_test_exit_code], exit_code) ==
               new_server_state
    end

    test "given :all & server state, runs all the tests" do
      mock_mix_test_output = mock_mix_test_output()
      exit_code = 0

      Mimic.expect(ShellCommandRunner, :run, fn shell_command ->
        assert shell_command == "mix test --color"
        {mock_mix_test_output, exit_code}
      end)

      server_state = ServerStateBuilder.build()

      assert {0, new_server_state} = MixTest.run(:all, server_state)

      assert server_state
             |> put_in([:elixir, :mix_test_output], mock_mix_test_output)
             |> put_in([:elixir, :mix_test_exit_code], exit_code) ==
               new_server_state
    end
  end

  defp mock_mix_test_output do
    """
    warning: variable "new_server_state" is unused (if the variable is not meant to be used, prefix it with an underscore)
    test/elixir/mix_test/mix_test_test.exs:16: PolyglotWatcherV2.Elixir.MixTestTest."test run/2 given a test path & server state, runs the mix test command with the test path"/1



    1) test run/2 given a test path & server state, runs the mix test command with the test path (PolyglotWatcherV2.Elixir.MixTestTest)
     test/elixir/mix_test/mix_test_test.exs:9
     ** (FunctionClauseError) no function clause matching in String.split/3

     The following arguments were given to String.split/3:

         # 1
         0

         # 2
         "\n"

         # 3
         []

     Attempted function clauses (showing 4 out of 4):

         def split(string, %Regex{} = pattern, options) when is_binary(string) and is_list(options)
         def split(string, "", options) when is_binary(string) and is_list(options)
         def split(string, [], options) when is_binary(string) and is_list(options)
         def split(string, pattern, options) when is_binary(string) and is_list(options)

     code: assert {0, new_server_state} = MixTest.run(test_path, server_state)
     stacktrace:
       (elixir 1.14.5) lib/string.ex:479: String.split/3
       (polyglot_watcher_v2 0.1.0) lib/elixir/failures.ex:114: PolyglotWatcherV2.Elixir.Failures.accumulate_failing_tests/1
       (polyglot_watcher_v2 0.1.0) lib/elixir/failures.ex:22: PolyglotWatcherV2.Elixir.Failures.update/4
       (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/mix_test.ex:13: PolyglotWatcherV2.Elixir.MixTest.run/2
       test/elixir/mix_test/mix_test_test.exs:16: (test)


    Finished in 0.03 seconds (0.03s async, 0.00s sync)
    1 test, 1 failure

    Randomized with seed 916689
    """
  end
end
