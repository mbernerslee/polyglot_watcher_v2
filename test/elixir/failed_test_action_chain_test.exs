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
  end
end
