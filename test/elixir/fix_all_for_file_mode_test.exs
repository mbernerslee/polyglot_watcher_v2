defmodule PolyglotWatcherV2.Elixir.FixAllForFileModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Determiner, FixAllForFileMode}

  @ex Determiner.ex()
  @ex_file_path %FilePath{path: "lib/cool", extension: @ex}

  test "fails given no provided test file or test failures in memory" do
    server_state = ServerStateBuilder.build()

    assert {tree, _} = FixAllForFileMode.switch(server_state)

    assert %{entry_point: :clear_screen} = tree

    expected_action_tree_keys = [
      :clear_screen,
      :put_failed_to_switch_msg
    ]

    ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
    ActionsTreeValidator.validate(tree)
  end

  describe "determine_actions/1" do
    test "are as expected" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fix_all_for_file, "test/x_test.exs"})

      assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)

      ActionsTreeValidator.validate(tree)

      assert %{
               actions_tree: %{
                 :clear_screen => %Action{
                   next_action: :mix_test_next,
                   runnable: :clear_screen
                 },
                 :mix_test_next => %Action{
                   runnable: {:mix_test_next, "test/x_test.exs"},
                   next_action: %{
                     {:cache, :miss} => :put_mix_test_all_for_file_msg,
                     {:mix_test, :passed} => :mix_test_next,
                     {:mix_test, :failed} => :exit,
                     {:mix_test, :error} => :put_mix_test_all_for_file_msg,
                     :fallback => :put_mix_test_all_for_file_msg
                   }
                 },
                 :put_mix_test_all_for_file_msg => %Action{
                   runnable: {:puts, :magenta, "Running mix test test/x_test.exs"},
                   next_action: :mix_test_all_for_file
                 },
                 :mix_test_all_for_file => %Action{
                   runnable: {:mix_test, "test/x_test.exs"},
                   next_action: %{
                     0 => :put_sarcastic_success,
                     2 => :mix_test_next,
                     1 => :put_mix_test_error,
                     :fallback => :put_mix_test_error
                   }
                 },
                 :put_mix_test_error => %Action{
                   next_action: :exit,
                   runnable:
                     {:puts, :red,
                      "Something went wrong running `mix test`. It errored (as opposed to running successfully with tests failing)"}
                 },
                 :put_sarcastic_success => %Action{
                   next_action: :exit,
                   runnable: :put_sarcastic_success
                 }
               },
               entry_point: :clear_screen
             } == tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
