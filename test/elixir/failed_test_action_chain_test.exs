defmodule PolyglotWatcherV2.Elixir.FailedTestActionChainTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.FailedTestActionChain

  describe "build/3" do
    test "given no failures, returns a noop action and the input last action" do
      assert %{{:mix_test_puts, 0} => %Action{runnable: :noop, next_action: :zanzibar}} ==
               FailedTestActionChain.build([], :ignored, :zanzibar)
    end

    test "given failures, returns the chain with the last next_action in the chain being the one specified" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/x_test.exs:10"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/x_test.exs:10"},
                 next_action: %{0 => {:mix_test_puts, 1}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/y_test.exs:20"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/y_test.exs:20"},
                 next_action: %{0 => {:mix_test_puts, 2}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 2} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/z_test.exs:30"},
                 next_action: {:mix_test, 2}
               },
               {:mix_test, 2} => %Action{
                 runnable: {:mix_test, "test/z_test.exs:30"},
                 next_action: :zanzibar
               }
             } ==
               FailedTestActionChain.build(
                 [
                   {"test/x_test.exs", 10},
                   {"test/y_test.exs", 20},
                   {"test/z_test.exs", 30}
                 ],
                 :oh_noes,
                 :zanzibar
               )
    end

    test "given a list of many failures, returns actions whereby exponentially more tests are run" do
      assert %{
               {:mix_test_puts, 0} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs:10"},
                 next_action: {:mix_test, 0}
               },
               {:mix_test, 0} => %Action{
                 runnable: {:mix_test, "test/a_test.exs:10"},
                 next_action: %{0 => {:mix_test_puts, 1}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 1} => %Action{
                 runnable:
                   {:puts, :magenta, "Running mix test test/a_test.exs --failed --max-cases 2"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --failed --max-cases 2"},
                 next_action: %{0 => {:mix_test_puts, 2}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 2} => %Action{
                 runnable:
                   {:puts, :magenta, "Running mix test test/a_test.exs --failed --max-cases 4"},
                 next_action: {:mix_test, 2}
               },
               {:mix_test, 2} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --failed --max-cases 4"},
                 next_action: %{0 => {:mix_test_puts, 3}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 3} => %Action{
                 runnable:
                   {:puts, :magenta, "Running mix test test/a_test.exs --failed --max-cases 8"},
                 next_action: {:mix_test, 3}
               },
               {:mix_test, 3} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --failed --max-cases 8"},
                 next_action: %{0 => {:mix_test_puts, 4}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 4} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs --failed"},
                 next_action: {:mix_test, 4}
               },
               {:mix_test, 4} => %Action{
                 runnable: {:mix_test, "test/a_test.exs --failed"},
                 next_action: %{0 => {:mix_test_puts, 5}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 5} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/b_test.exs --failed"},
                 next_action: {:mix_test, 5}
               },
               {:mix_test, 5} => %Action{
                 runnable: {:mix_test, "test/b_test.exs --failed"},
                 next_action: %{0 => {:mix_test_puts, 6}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 6} => %Action{
                 runnable:
                   {:puts, :magenta, "Running mix test test/c_test.exs test/d_test.exs--failed"},
                 next_action: {:mix_test, 6}
               },
               {:mix_test, 6} => %Action{
                 runnable: {:mix_test, "test/c_test.exs test/d_test.exs--failed"},
                 next_action: %{0 => {:mix_test_puts, 7}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 7} => %Action{
                 runnable:
                   {:puts, :magenta,
                    "Running mix test test/e_test.exs test/f_test.exs test/g_test.exs --failed"},
                 next_action: {:mix_test, 7}
               },
               {:mix_test, 7} => %Action{
                 runnable: {:mix_test, "asssssss"},
                 next_action: %{0 => :zanzibar, :fallback => :oh_noes}
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
                   {"test/g_test.exs", 70}
                 ],
                 :oh_noes,
                 :zanzibar
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
                 next_action: %{0 => {:mix_test_puts, 1}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 1} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/a_test.exs --failed"},
                 next_action: {:mix_test, 1}
               },
               {:mix_test, 1} => %Action{
                 runnable: {:mix_test, "test/b_test.exs --failed"},
                 next_action: %{0 => {:mix_test_puts, 2}, :fallback => :oh_noes}
               },
               {:mix_test_puts, 2} => %Action{
                 runnable: {:puts, :magenta, "Running mix test test/b_test.exs --failed"},
                 next_action: {:mix_test, 2}
               },
               {:mix_test, 2} => %Action{
                 runnable: {:mix_test, "test/b_test.exs --failed"},
                 next_action: %{0 => :zanzibar, :fallback => :oh_noes}
               }
             } ==
               FailedTestActionChain.build(
                 [
                   {"test/a_test.exs", 1},
                   {"test/b_test.exs", 2},
                   {"test/a_test.exs", 3},
                   {"test/a_test.exs", 4}
                 ],
                 :oh_noes,
                 :zanzibar
               )
    end
  end
end
