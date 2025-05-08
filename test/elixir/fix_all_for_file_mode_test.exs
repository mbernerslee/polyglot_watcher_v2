defmodule PolyglotWatcherV2.Elixir.FixAllForFileModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Cache, FixAllForFileMode}

  describe "switch/1" do
    test "given no explicit file to use, with a cache hit, switches mode & enters the loop" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"
      line_number = 10

      Mimic.expect(Cache, :get, fn :latest ->
        {:ok, {test_path, line_number}}
      end)

      assert {%{entry_point: :clear_screen, actions_tree: actions_tree} = tree, ^server_state} =
               FixAllForFileMode.switch(server_state)

      assert actions_tree.clear_screen == %Action{
               runnable: :clear_screen,
               next_action: :switch_mode
             }

      assert actions_tree.switch_mode == %Action{
               runnable: {:switch_mode, :elixir, {:fix_all_for_file, test_path}},
               next_action: :put_mode_switch_msg
             }

      assert actions_tree.put_mode_switch_msg == %Action{
               runnable:
                 {:puts,
                  [
                    {[:magenta], "Switching to "},
                    {[:magenta, :italic], "Fix All For File "},
                    {[:magenta], "mode...\n"},
                    {[:magenta], "using the latest failing test in memory..."}
                  ]},
               next_action: :mix_test_latest_line
             }

      ActionsTreeValidator.assert_exact_keys(
        tree,
        [
          :clear_screen,
          :switch_mode,
          :put_mode_switch_msg,
          :mix_test_latest_line,
          :put_mix_test_max_failures_1_msg,
          :mix_test_max_failures_1,
          :put_mix_test_all_for_file_msg,
          :mix_test_all_for_file,
          :put_mix_test_error,
          :put_sarcastic_success,
          :put_insult
        ]
      )

      ActionsTreeValidator.validate(tree)
    end

    # TODO don't return error & instead wait for a file save to determine the test_path?
    test "given no explicit file to use, with a cache miss, returns error" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Cache, :get, fn :latest -> {:error, :not_found} end)

      assert {%{entry_point: :clear_screen, actions_tree: actions_tree} = tree, ^server_state} =
               FixAllForFileMode.switch(server_state)

      assert %{
               clear_screen: %Action{
                 runnable: :clear_screen,
                 next_action: :put_error_msg
               },
               put_error_msg: %Action{
                 runnable:
                   {:puts,
                    [
                      {[:red], "Switching to "},
                      {[:red, :italic], "Fix All For File "},
                      {[:red], "mode failed\n"},
                      {[:red], "I wasn't given a test_path "},
                      {[:red, :italic], "and "},
                      {[:red], "my memory of failing tests is empty\n"},
                      {[:red],
                       "Therefore I don't know which file upon which to fixate testing, so I am forced to give up :-("}
                    ]},
                 next_action: :exit
               }
             } == actions_tree

      ActionsTreeValidator.validate(tree)
    end
  end

  describe "switch/2" do
    test "given a test_path, returns the expected actions" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"

      assert {%{entry_point: :clear_screen, actions_tree: actions_tree} = tree, ^server_state} =
               FixAllForFileMode.switch(server_state, test_path)

      assert actions_tree.clear_screen == %Action{
               runnable: :clear_screen,
               next_action: :switch_mode
             }

      assert actions_tree.switch_mode == %Action{
               runnable: {:switch_mode, :elixir, {:fix_all_for_file, test_path}},
               next_action: :put_mode_switch_msg
             }

      assert actions_tree.put_mode_switch_msg == %Action{
               runnable:
                 {:puts,
                  [
                    {[:magenta], "Switching to "},
                    {[:magenta, :italic], "Fix All For File "},
                    {[:magenta], "mode..."}
                  ]},
               next_action: :mix_test_latest_line
             }

      ActionsTreeValidator.assert_exact_keys(
        tree,
        [
          :clear_screen,
          :switch_mode,
          :put_mode_switch_msg,
          :mix_test_latest_line,
          :put_mix_test_max_failures_1_msg,
          :mix_test_max_failures_1,
          :put_mix_test_all_for_file_msg,
          :mix_test_all_for_file,
          :put_mix_test_error,
          :put_sarcastic_success,
          :put_insult
        ]
      )

      ActionsTreeValidator.validate(tree)
    end
  end

  describe "determine_actions/1" do
    test "are as expected" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fix_all_for_file, "test/x_test.exs"})

      assert {tree, ^server_state} = FixAllForFileMode.determine_actions(server_state)

      assert %{
               actions_tree: %{
                 clear_screen: %PolyglotWatcherV2.Action{
                   next_action: :mix_test_latest_line,
                   runnable: :clear_screen
                 },
                 mix_test_all_for_file: %PolyglotWatcherV2.Action{
                   next_action: %{
                     0 => :put_sarcastic_success,
                     1 => :put_mix_test_error,
                     2 => :mix_test_latest_line,
                     :fallback => :put_mix_test_error
                   },
                   runnable: {:mix_test, "test/x_test.exs"}
                 },
                 mix_test_latest_line: %PolyglotWatcherV2.Action{
                   next_action: %{
                     :fallback => :put_mix_test_error,
                     {:cache, :miss} => :put_mix_test_all_for_file_msg,
                     {:mix_test, :error} => :put_mix_test_error,
                     {:mix_test, :failed} => :exit,
                     {:mix_test, :passed} => :put_mix_test_max_failures_1_msg
                   },
                   runnable: {:mix_test_latest_line, "test/x_test.exs"}
                 },
                 put_mix_test_all_for_file_msg: %PolyglotWatcherV2.Action{
                   next_action: :mix_test_all_for_file,
                   runnable: {
                     :puts,
                     :magenta,
                     "Running mix test test/x_test.exs"
                   }
                 },
                 put_mix_test_error: %PolyglotWatcherV2.Action{
                   next_action: :exit,
                   runnable: {
                     :puts,
                     :red,
                     "Something went wrong running `mix test`. It errored (as opposed to running successfully with tests failing)"
                   }
                 },
                 put_sarcastic_success: %PolyglotWatcherV2.Action{
                   next_action: :exit,
                   runnable: :put_sarcastic_success
                 },
                 mix_test_max_failures_1: %PolyglotWatcherV2.Action{
                   runnable: {:mix_test, "test/x_test.exs --max-failures 1"},
                   next_action: %{
                     0 => :put_sarcastic_success,
                     1 => :put_mix_test_error,
                     2 => :put_insult,
                     :fallback => :put_mix_test_error
                   }
                 },
                 put_insult: %PolyglotWatcherV2.Action{runnable: :put_insult, next_action: :exit},
                 put_mix_test_max_failures_1_msg: %PolyglotWatcherV2.Action{
                   runnable:
                     {:puts, :magenta, "Running mix test test/x_test.exs --max-failures 1"},
                   next_action: :mix_test_max_failures_1
                 }
               },
               entry_point: :clear_screen
             } == tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
