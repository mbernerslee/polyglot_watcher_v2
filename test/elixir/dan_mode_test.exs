defmodule PolyglotWatcherV2.Elixir.DanModeTest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator
  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, FilePath, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.DanMode

  describe "determine_actions/1" do
    test "mix test mode" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:dan, :mix_test})

      assert {tree, ^server_state} = DanMode.determine_actions(server_state)

      assert_mix_test_actions(server_state)
    end

    test "next_file mode - with known test failures" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:dan, :next_file})
        |> ServerStateBuilder.with_elixir_failures([
          {"test/x_test.exs", 1},
          {"test/x_test.exs", 2},
          {"test/x_test.exs", 3}
        ])

      assert {tree, ^server_state} = DanMode.determine_actions(server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :switch_to_fixed_file_mode,
        :mix_test_msg,
        :mix_test,
        :put_test_passed_count_msg,
        :put_test_failed_count_msg,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      assert ActionsTreeValidator.validate(tree)
    end

    test "next_file mode - with NO known test failures" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:dan, :next_file})
        |> ServerStateBuilder.with_elixir_failures([])

      assert_mix_test_actions(server_state)
    end

    test "fixed_file mode - with more than 1 failure in that file" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:dan, {:fixed_file, "text/x_test.exs"}})
        |> ServerStateBuilder.with_elixir_failures([
          {"test/x_test.exs", 1},
          {"test/x_test.exs", 2},
          {"test/x_test.exs", 3}
        ])
        |> ServerStateBuilder.with_elixir_failures([])

      assert {tree, ^server_state} = DanMode.determine_actions(server_state)

      assert %{entry_point: :clear_screen} = tree

      expected_action_tree_keys = [
        :clear_screen,
        :mix_test_msg,
        :mix_test,
        :switch_to_next_file_mode,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
      assert ActionsTreeValidator.validate(tree)
    end
  end

  defp assert_mix_test_actions(server_state) do
    assert {tree, ^server_state} = DanMode.determine_actions(server_state)

    assert %{entry_point: :clear_screen} = tree

    expected_action_tree_keys = [
      :clear_screen,
      :mix_test_msg,
      :mix_test,
      :switch_to_next_file_mode,
      :put_success_msg,
      :put_failure_msg
    ]

    ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)
    assert ActionsTreeValidator.validate(tree)
  end
end
