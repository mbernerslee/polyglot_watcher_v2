defmodule PolyglotWatcherV2.Elixir.FixAllForFileModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.Determiner

  @ex Determiner.ex()
  @ex_file_path %FilePath{path: "lib/cool", extension: @ex}

  describe "determine_actions/1" do
    test "with no failures for the fixed file, runs all the tests" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fix_all_for_file, "test/x_test.exs"})
        |> ServerStateBuilder.with_elixir_failures([{"test/other_file_test.exs", 1}])

      assert {tree, _} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :mix_test,
        :put_sarcastic_success,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      ActionsTreeValidator.validate(tree)
    end

    test "with some failures, returns an action to run each failure" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fix_all_for_file, "test/x_test.exs"})
        |> ServerStateBuilder.with_elixir_failures([
          {"test/x_test.exs", 1},
          {"test/x_test.exs", 2},
          {"test/x_test.exs", 3}
        ])

      assert {tree, _} = Determiner.determine_actions(@ex_file_path, server_state)

      assert %{entry_point: :clear_screen} = tree

      ActionsTreeValidator.validate(tree)

      assert %{
               actions_tree: %{
                 :clear_screen => %Action{
                   next_action: {:mix_test_puts, 0},
                   runnable: :clear_screen
                 },
                 :mix_test => %Action{
                   next_action: %{0 => :put_sarcastic_success, :fallback => :put_failure_msg},
                   runnable: :mix_test
                 },
                 :put_failure_msg => %Action{
                   next_action: :exit,
                   runnable:
                     {:puts, :red,
                      "At least one test in test/x_test.exs is busted. I'll run it exclusively until you fix it... (unless you break another one in the process)"}
                 },
                 :put_sarcastic_success => %Action{
                   next_action: :exit,
                   runnable: :put_sarcastic_success
                 },
                 {:mix_test_puts, 0} => %Action{
                   next_action: {:mix_test, 0},
                   runnable: _
                 },
                 {:mix_test_puts, 1} => %Action{
                   next_action: {:mix_test, 1},
                   runnable: _
                 },
                 {:mix_test_puts, 2} => %Action{
                   next_action: {:mix_test, 2},
                   runnable: _
                 },
                 {:mix_test, 0} => %Action{
                   next_action: %{0 => {:mix_test_puts, 1}, :fallback => :put_failure_msg},
                   runnable: {:mix_test, "test/x_test.exs:1"}
                 },
                 {:mix_test, 1} => %Action{
                   next_action: %{0 => {:mix_test_puts, 2}, :fallback => :put_failure_msg},
                   runnable: {:mix_test, "test/x_test.exs:2"}
                 },
                 {:mix_test, 2} => %Action{
                   next_action: %{0 => :mix_test, :fallback => :put_failure_msg},
                   runnable: {:mix_test, "test/x_test.exs:3"}
                 }
               },
               entry_point: :clear_screen
             } = tree
    end
  end
end
