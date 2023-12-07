defmodule PolyglotWatcherV2.StacktraceTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Stacktrace

  describe "find_files/1" do
    test "given some failed mix test output, returns the files in the stacktraces" do
      # IO.puts(mix_test_output())

      assert [
               {"1) test switch/2 returns the expected actions (PolyglotWatcherV2.Elixir.RunAllModeTest)",
                %{
                  raw:
                    "       (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:43: PolyglotWatcherV2.ActionsTreeValidator.check_all_next_actions_exist/2\n       (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:12: PolyglotWatcherV2.ActionsTreeValidator.validate/1\n       test/elixir/run_all_mode_test.exs:28: (test)\n",
                  files: [
                    "test/support/actions_tree_validator.ex",
                    "test/support/actions_tree_validator.ex",
                    "test/elixir/run_all_mode_test.exs"
                  ]
                }}
               | _
             ] = Stacktrace.find_files(mix_test_output())
    end
  end

  defp mix_test_output do
    """
    ...............................................

      1) test switch/2 returns the expected actions (PolyglotWatcherV2.Elixir.RunAllModeTest)
         test/elixir/run_all_mode_test.exs:10
         ** (PolyglotWatcherV2.InvalidActionsTreeError) I require all 'next_actions' in the tree to exist within it, but some 'next_actions' we're pointing to don't exist in the tree MapSet.new([:put_success_msg])
         code: ActionsTreeValidator.validate(tree)
         stacktrace:
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:43: PolyglotWatcherV2.ActionsTreeValidator.check_all_next_actions_exist/2
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:12: PolyglotWatcherV2.ActionsTreeValidator.validate/1
           test/elixir/run_all_mode_test.exs:28: (test)



      2) test determine_actions/2 returns the valid expected actions (PolyglotWatcherV2.Elixir.RunAllModeTest)
         test/elixir/run_all_mode_test.exs:35
         ** (PolyglotWatcherV2.InvalidActionsTreeError) I require all 'next_actions' in the tree to exist within it, but some 'next_actions' we're pointing to don't exist in the tree MapSet.new([:put_success_msg])
         code: ActionsTreeValidator.validate(tree)
         stacktrace:
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:43: PolyglotWatcherV2.ActionsTreeValidator.check_all_next_actions_exist/2
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:12: PolyglotWatcherV2.ActionsTreeValidator.validate/1
           test/elixir/run_all_mode_test.exs:51: (test)

    ..................

      3) test determine_actions/2 returns the run_all actions when in that mode (PolyglotWatcherV2.Elixir.DeterminerTest)
         test/elixir/determiner_test.exs:34
         ** (PolyglotWatcherV2.InvalidActionsTreeError) I require all 'next_actions' in the tree to exist within it, but some 'next_actions' we're pointing to don't exist in the tree MapSet.new([:put_success_msg])
         code: ActionsTreeValidator.validate(tree)
         stacktrace:
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:43: PolyglotWatcherV2.ActionsTreeValidator.check_all_next_actions_exist/2
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:12: PolyglotWatcherV2.ActionsTreeValidator.validate/1
           test/elixir/determiner_test.exs:52: (test)

    .....

      4) test user_input_actions/2 switching to run_all mode returns the expected functioning actions (PolyglotWatcherV2.Elixir.DeterminerTest)
         test/elixir/determiner_test.exs:212
         ** (PolyglotWatcherV2.InvalidActionsTreeError) I require all 'next_actions' in the tree to exist within it, but some 'next_actions' we're pointing to don't exist in the tree MapSet.new([:put_success_msg])
         code: ActionsTreeValidator.validate(tree)
         stacktrace:
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:43: PolyglotWatcherV2.ActionsTreeValidator.check_all_next_actions_exist/2
           (polyglot_watcher_v2 0.1.0) test/support/actions_tree_validator.ex:12: PolyglotWatcherV2.ActionsTreeValidator.validate/1
           test/elixir/determiner_test.exs:230: (test)

    .....
    Finished in 0.1 seconds (0.1s async, 0.01s sync)
    79 tests, 4 failures

    Randomized with seed 798228
    """
  end
end
