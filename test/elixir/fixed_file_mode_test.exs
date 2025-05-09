defmodule PolyglotWatcherV2.Elixir.FixedFileModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator
  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Cache, FixedFileMode}

  describe "switch/2" do
    test "given a test_path, we switch to that test path and run the determine_actions loop" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs:42"

      assert {%{entry_point: :clear_screen, actions_tree: actions_tree} = tree, ^server_state} =
               FixedFileMode.switch(server_state, test_path)

      assert %{
               clear_screen: %PolyglotWatcherV2.Action{
                 runnable: :clear_screen,
                 next_action: :switch_mode
               },
               switch_mode: %PolyglotWatcherV2.Action{
                 runnable: {:switch_mode, :elixir, {:fixed_file, test_path}},
                 next_action: :put_switch_mode_msg
               },
               put_switch_mode_msg: %Action{
                 runnable:
                   {:puts,
                    [
                      {[:magenta], "Switching to "},
                      {[:magenta, :italic], "Fix All "},
                      {[:magenta], "mode...\n"},
                      {[:magenta], "using the provided test path..."}
                    ]},
                 next_action: :put_mix_test_msg
               },
               put_mix_test_msg: %PolyglotWatcherV2.Action{
                 runnable: {:puts, :magenta, "Running mix test #{test_path}"},
                 next_action: :mix_test
               },
               mix_test: %PolyglotWatcherV2.Action{
                 runnable: {:mix_test, test_path},
                 next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
               },
               put_success_msg: %PolyglotWatcherV2.Action{
                 runnable: :put_sarcastic_success,
                 next_action: :exit
               },
               put_failure_msg: %PolyglotWatcherV2.Action{
                 runnable: :put_insult,
                 next_action: :exit
               }
             } == actions_tree

      ActionsTreeValidator.validate(tree)
    end
  end

  describe "switch/1" do
    test "works if the failed test cache call hits" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Cache, :get_test_failure, fn :latest ->
        {:ok, {"test/cool_test.exs", 10}}
      end)

      assert {%{entry_point: :clear_screen, actions_tree: actions_tree} = tree, ^server_state} =
               FixedFileMode.switch(server_state)

      assert %{
               clear_screen: %PolyglotWatcherV2.Action{
                 runnable: :clear_screen,
                 next_action: :switch_mode
               },
               switch_mode: %PolyglotWatcherV2.Action{
                 runnable: {:switch_mode, :elixir, {:fixed_file, "test/cool_test.exs:10"}},
                 next_action: :put_switch_mode_msg
               },
               put_switch_mode_msg: %Action{
                 runnable:
                   {:puts,
                    [
                      {[:magenta], "Switching to "},
                      {[:magenta, :italic], "Fix All "},
                      {[:magenta], "mode...\n"},
                      {[:magenta], "using the latest failing test in memory..."}
                    ]},
                 next_action: :put_mix_test_msg
               },
               put_mix_test_msg: %PolyglotWatcherV2.Action{
                 runnable: {:puts, :magenta, "Running mix test test/cool_test.exs:10"},
                 next_action: :mix_test
               },
               mix_test: %PolyglotWatcherV2.Action{
                 runnable: {:mix_test, "test/cool_test.exs:10"},
                 next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
               },
               put_success_msg: %PolyglotWatcherV2.Action{
                 runnable: :put_sarcastic_success,
                 next_action: :exit
               },
               put_failure_msg: %PolyglotWatcherV2.Action{
                 runnable: :put_insult,
                 next_action: :exit
               }
             } == actions_tree

      ActionsTreeValidator.validate(tree)
    end

    test "given a cache miss, returns error" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Cache, :get_test_failure, fn :latest -> {:error, :not_found} end)

      assert {%{entry_point: :clear_screen, actions_tree: actions_tree} = tree, ^server_state} =
               FixedFileMode.switch(server_state)

      assert %{
               clear_screen: %PolyglotWatcherV2.Action{
                 runnable: :clear_screen,
                 next_action: :put_error_msg
               },
               put_error_msg: %Action{
                 runnable:
                   {:puts,
                    [
                      {[:red], "Switching to "},
                      {[:red, :italic], "Fix All "},
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

  # describe "switch/0" do
  #  test "works if there's at least 1 test failure in the history" do
  #    server_state =
  #      ServerStateBuilder.build()
  #      |> ServerStateBuilder.with_elixir_failures([{"test/x_test.exs", 100}])

  #    assert {tree, _server_state} = FixedFileMode.switch(server_state)

  #    expected_action_tree_keys = [
  #      :clear_screen,
  #      :put_switch_mode_msg,
  #      :switch_mode,
  #      :put_intent_msg,
  #      :mix_test,
  #      :put_success_msg,
  #      :put_failure_msg
  #    ]

  #    assert %Action{runnable: {:switch_mode, :elixir, {:fixed_file, "test/x_test.exs:100"}}} =
  #             tree.actions_tree.switch_mode

  #    ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
  #    ActionsTreeValidator.validate(tree)
  #  end

  #  test "fails if there're no test failures in the history" do
  #    server_state =
  #      ServerStateBuilder.build()
  #      |> ServerStateBuilder.with_elixir_failures([])

  #    assert {tree, _server_state} = FixedFileMode.switch(server_state)

  #    expected_action_tree_keys = [
  #      :clear_screen,
  #      :put_switch_mode_failure_msg
  #    ]

  #    ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
  #    ActionsTreeValidator.validate(tree)
  #  end
  # end

  describe "determine_actions/1" do
    test "returns the expected actions" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fixed_file, "test/cool_test.exs"})

      assert {tree, ^server_state} = FixedFileMode.determine_actions(server_state)

      assert %{
               actions_tree: %{
                 clear_screen: %PolyglotWatcherV2.Action{
                   runnable: :clear_screen,
                   next_action: :put_mix_test_msg
                 },
                 put_mix_test_msg: %PolyglotWatcherV2.Action{
                   runnable: {:puts, :magenta, "Running mix test test/cool_test.exs"},
                   next_action: :mix_test
                 },
                 mix_test: %PolyglotWatcherV2.Action{
                   runnable: {:mix_test, "test/cool_test.exs"},
                   next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
                 },
                 put_success_msg: %PolyglotWatcherV2.Action{
                   runnable: :put_sarcastic_success,
                   next_action: :exit
                 },
                 put_failure_msg: %PolyglotWatcherV2.Action{
                   runnable: :put_insult,
                   next_action: :exit
                 }
               },
               entry_point: :clear_screen
             } == tree

      ActionsTreeValidator.validate(tree)
    end

    test "returns the expected actions given a <test_path>:<line_number>" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fixed_file, "test/x_test.exs:123"})

      assert {tree, ^server_state} = FixedFileMode.determine_actions(server_state)

      assert %{
               actions_tree: %{
                 clear_screen: %PolyglotWatcherV2.Action{
                   runnable: :clear_screen,
                   next_action: :put_mix_test_msg
                 },
                 put_mix_test_msg: %PolyglotWatcherV2.Action{
                   runnable: {:puts, :magenta, "Running mix test test/x_test.exs:123"},
                   next_action: :mix_test
                 },
                 mix_test: %PolyglotWatcherV2.Action{
                   runnable: {:mix_test, "test/x_test.exs:123"},
                   next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
                 },
                 put_success_msg: %PolyglotWatcherV2.Action{
                   runnable: :put_sarcastic_success,
                   next_action: :exit
                 },
                 put_failure_msg: %PolyglotWatcherV2.Action{
                   runnable: :put_insult,
                   next_action: :exit
                 }
               },
               entry_point: :clear_screen
             } == tree

      ActionsTreeValidator.validate(tree)
    end
  end
end
