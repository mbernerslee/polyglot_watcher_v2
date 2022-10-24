defmodule PolyglotWatcherV2.Elixir.FailedTestActionChainTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.FailedTestActionChain

  describe "build/3" do
    test "given no failures, returns a noop action and the input last action" do
      assert %{{:mix_test_puts, 0} => %Action{runnable: :noop, next_action: :success_action}} ==
               FailedTestActionChain.build([], :ignored, :success_action)
    end

    test "given failures, returns the chain with the last next_action in the chain being the one specified" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/x_test.exs:10"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/x_test.exs:10"},
                 next_action: _
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/x_test.exs --max-failures 1"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/x_test.exs --max-failures 1"},
                 next_action: _
               },
               {:mix_test_puts, 2} => %Action{
                 runnable: {:puts, :magenta, "Running mix test --failed --max-failures 1"},
                 next_action: {:mix_test, 2}
               },
               {:mix_test, 2} => %Action{
                 runnable: {:mix_test, "--failed --max-failures 1"},
                 next_action: {:put_elixir_failures_count, 2}
               },
               {:put_elixir_failures_count, 2} => %Action{
                 runnable: {:put_elixir_failures_count, _},
                 next_action: :success_action
               }
             } =
               FailedTestActionChain.build(
                 [
                   {"test/x_test.exs", 10},
                   {"test/y_test.exs", 20},
                   {"test/z_test.exs", 30}
                 ],
                 :fail_action,
                 :success_action
               )
    end

    test "given a list of many failures, returns precisely the expected chain of first file & subsequent file test" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs:10"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/a_test.exs:10"},
                 next_action: {:put_elixir_failures_count, 0}
               },
               {:put_elixir_failures_count, 0} => %Action{
                 runnable: {:put_elixir_failures_count, :all},
                 next_action: %{0 => {:mix_test_puts, 1}, :fallback => :fail_action}
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs --max-failures 1"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --max-failures 1"},
                 next_action: {:put_elixir_failures_count, 1}
               },
               {:put_elixir_failures_count, 1} => %Action{
                 runnable: {:put_elixir_failures_count, :all},
                 next_action: %{0 => {:mix_test_puts, 2}, :fallback => :fail_action}
               },
               {:mix_test_puts, 2} => %Action{
                 runnable: {:puts, :magenta, "Running mix test --failed --max-failures 1"},
                 next_action: {:mix_test, 2}
               },
               {:mix_test, 2} => %Action{
                 runnable: {:mix_test, "--failed --max-failures 1"},
                 next_action: {:put_elixir_failures_count, 2}
               },
               {:put_elixir_failures_count, 2} => %Action{
                 runnable: {:put_elixir_failures_count, :all},
                 next_action: :success_action
               }
             } ==
               FailedTestActionChain.build(
                 [
                   {"test/a_test.exs", 10},
                   {"test/a_test.exs", 11},
                   {"test/a_test.exs", 12},
                   {"test/a_test.exs", 13},
                   {"test/a_test.exs", 14},
                   {"test/a_test.exs", 15},
                   {"test/a_test.exs", 16},
                   {"test/a_test.exs", 17},
                   {"test/a_test.exs", 18},
                   {"test/a_test.exs", 19},
                   {"test/a_test.exs", 191},
                   {"test/a_test.exs", 192},
                   {"test/a_test.exs", 193},
                   {"test/a_test.exs", 194},
                   {"test/a_test.exs", 195},
                   {"test/b_test.exs", 20},
                   {"test/c_test.exs", 30},
                   {"test/d_test.exs", 40},
                   {"test/e_test.exs", 50},
                   {"test/f_test.exs", 60},
                   {"test/g_test.exs", 70},
                   {"test/h_test.exs", 80},
                   {"test/i_test.exs", 90}
                 ],
                 :fail_action,
                 :success_action
               )
    end

    test "given many failures at the same file, they're deduped in the chain" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs:10"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/a_test.exs:10"},
                 next_action: _
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs --max-failures 1"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --max-failures 1"},
                 next_action: _
               }
             } =
               FailedTestActionChain.build(
                 [
                   {"test/a_test.exs", 10},
                   {"test/a_test.exs", 11},
                   {"test/b_test.exs", 20},
                   {"test/b_test.exs", 30},
                   {"test/c_test.exs", 40},
                   {"test/c_test.exs", 50}
                 ],
                 :fail_action,
                 :success_action
               )
    end

    test "sorts failures by file" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs:1"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/a_test.exs:1"},
                 next_action: _
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs --max-failures 1"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --max-failures 1"},
                 next_action: _
               }
             } =
               FailedTestActionChain.build(
                 [
                   {"test/a_test.exs", 1},
                   {"test/b_test.exs", 2},
                   {"test/a_test.exs", 3},
                   {"test/a_test.exs", 4}
                 ],
                 :fail_action,
                 :success_action
               )
    end

    test "given failures in only one file, returns only failure actions for that file" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs:1"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/a_test.exs:1"},
                 next_action: _
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs --max-failures 1"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --max-failures 1"},
                 next_action: _
               }
             } =
               FailedTestActionChain.build(
                 [{"test/a_test.exs", 1}],
                 :fail_action,
                 :success_action
               )
    end
  end

  describe "puting the remainging failures count" do
    test "given no given mode, defaults to all" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs:1"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/a_test.exs:1"},
                 next_action: {:put_elixir_failures_count, 0}
               },
               {:put_elixir_failures_count, 0} => %Action{
                 runnable: {:put_elixir_failures_count, :all},
                 next_action: %{0 => {:mix_test_puts, 1}, :fallback => :fail_action}
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs --max-failures 1"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --max-failures 1"},
                 next_action: {:put_elixir_failures_count, 1}
               },
               {:put_elixir_failures_count, 1} => %Action{
                 runnable: {:put_elixir_failures_count, :all},
                 next_action: :success_action
               }
             } =
               FailedTestActionChain.build(
                 [{"test/a_test.exs", 1}, {"test/a_test.exs", 2}],
                 :fail_action,
                 :success_action
               )
    end
  end
end
