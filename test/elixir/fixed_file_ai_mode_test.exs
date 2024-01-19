defmodule PolyglotWatcherV2.Elixir.FixedFileAITest do
  use ExUnit.Case, async: true
  require PolyglotWatcherV2.ActionsTreeValidator
  alias PolyglotWatcherV2.{Action, ActionsTreeValidator, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.FixedFileAIMode

  describe "switch/2" do
    test "can switch" do
      server_state = ServerStateBuilder.build()

      assert {tree, _server_state} = FixedFileAIMode.switch(server_state, "test/x_test.exs:123")

      assert %{entry_point: :clear_screen, actions_tree: actions_tree} = tree

    assert actions_tree == %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :check_file_exists
      },
      check_file_exists: %Action{
        runnable: {:file_exists, "test/x_test.exs"},
        next_action: %{true => :switch_mode, :fallback => :put_no_file_msg}
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:fixed_file_ai, "test/x_test.exs:123"}},
        next_action: :put_switch_success_msg
      },
      put_no_file_msg: %Action{
        runnable:
          {:puts, :red,
           "I couldn't find a file at test/x_test.exs, so I failed to switch mode"},
        next_action: :exit
      },
      put_switch_success_msg: %Action{
        runnable:
          {:puts, :magenta, "Switching Elixir to fixed_file test/x_test.exs AI mode"},
        next_action: :put_intent_msg
      },
      put_intent_msg: %Action{
        runnable: {:puts, :magenta, "Running mix test test/x_test.exs:123"},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: {:mix_test, "test/x_test.exs:123"},
        next_action: %{0 => :put_success_msg, :fallback => :put_insult}
      },
      put_insult: %Action{
        runnable: :put_insult,
        next_action: :call_chat_gpt
      },
      call_chat_gpt: %Action{
        runnable: :elixir_call_chat_gpt,
        next_action: %{0 => :exit, :fallback => :put_chat_gpt_failure_msg}
      },
      put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
      put_chat_gpt_failure_msg: %Action{
        runnable: {:puts, :red, "I failed to call Chat GPT, so I'm giving up for now!"},
        next_action: :exit
      },
    }

      ActionsTreeValidator.validate(tree)
    end

    test "can switch to a different file" do
      server_state = ServerStateBuilder.build()

      assert {tree, _server_state} = FixedFileAIMode.switch(server_state, "test/cool_test.exs:123")

      assert %{entry_point: :clear_screen, actions_tree: actions_tree} = tree

    assert actions_tree == %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :check_file_exists
      },
      check_file_exists: %Action{
        runnable: {:file_exists, "test/cool_test.exs"},
        next_action: %{true => :switch_mode, :fallback => :put_no_file_msg}
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:fixed_file_ai, "test/cool_test.exs:123"}},
        next_action: :put_switch_success_msg
      },
      put_no_file_msg: %Action{
        runnable:
          {:puts, :red,
           "I couldn't find a file at test/cool_test.exs, so I failed to switch mode"},
        next_action: :exit
      },
      put_switch_success_msg: %Action{
        runnable:
          {:puts, :magenta, "Switching Elixir to fixed_file test/cool_test.exs AI mode"},
        next_action: :put_intent_msg
      },
      put_intent_msg: %Action{
        runnable: {:puts, :magenta, "Running mix test test/cool_test.exs:123"},
        next_action: :mix_test
      },
      mix_test: %Action{
        runnable: {:mix_test, "test/cool_test.exs:123"},
        next_action: %{0 => :put_success_msg, :fallback => :put_insult}
      },
      put_insult: %Action{
        runnable: :put_insult,
        next_action: :call_chat_gpt
      },
      call_chat_gpt: %Action{
        runnable: :elixir_call_chat_gpt,
        next_action: %{0 => :exit, :fallback => :put_chat_gpt_failure_msg}
      },
      put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
      put_chat_gpt_failure_msg: %Action{
        runnable: {:puts, :red, "I failed to call Chat GPT, so I'm giving up for now!"},
        next_action: :exit
      },
    }

      ActionsTreeValidator.validate(tree)
    end
  end

  describe "determine_actions/1" do
    test "pho queglrkj" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode({:fixed_file_ai, "test/x_test.exs:5"})
        |> ServerStateBuilder.with_elixir_failures([
          {"test/x_test.exs", 1},
          {"test/x_test.exs", 2},
          {"test/x_test.exs", 3},
          {"test/x_test.exs", 4},
          {"test/x_test.exs", 5},
          {"test/x_test.exs", 6},
          {"test/x_test.exs", 7},
          {"test/x_test.exs", 8}
        ])

      assert {tree, ^server_state} = FixedFileAIMode.determine_actions(server_state)

      assert %{entry_point: :clear_screen, actions_tree: actions_tree} = tree
      expected_actions_tree = %{
        clear_screen: %Action{
          runnable: :clear_screen,
          next_action: :put_intent_msg
        },
        put_intent_msg: %Action{
          runnable: {:puts, :magenta, "Running mix test test/x_test.exs:5"},
          next_action: :mix_test
        },
        mix_test: %Action{
          runnable: {:mix_test, "test/x_test.exs:5"},
          next_action: %{0 => :put_success_msg, :fallback => :put_insult}
        },
        put_insult: %Action{
          runnable: :put_insult,
          next_action: :call_chat_gpt
        },
        call_chat_gpt: %Action{
          runnable: :elixir_call_chat_gpt,
          next_action: %{0 => :exit, :fallback => :put_chat_gpt_failure_msg}
        },
        put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
        put_chat_gpt_failure_msg: %Action{
          runnable: {:puts, :red, "I failed to call Chat GPT, so I'm giving up for now!"},
          next_action: :exit
        },
      }

      assert expected_actions_tree == actions_tree
      ActionsTreeValidator.validate(tree)
    end
  end
end
