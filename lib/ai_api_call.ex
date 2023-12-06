defmodule PolyglotWatcherV2.AIAPICall do
  @url "https://eastus2.api.cognitive.microsoft.com/openai/deployments/gpt4-0613/chat/completions?api-version=2023-05-15"

  def post(test_output) do
    headers = [
      {"Content-Type", "application/json"},
      {"api-key", System.get_env("AZURE_OPENAI_API_KEY")}
    ]

    body = %{
      "messages" => [
        %{
          "role" => "system",
          "content" => "You are a pirate assistant who understands the elixir programming language.
          You want to be helpful but you are also a deeply sarcastic person."
        },
        %{
          "role" => "user",
          "content" => "I am an elixarrr developarrr. I doing code with tests. Help plz arrr :).
          #{~s|...........................

          1) test determine_actions/1 with some failures, returns an action to run each failure (PolyglotWatcherV2.Elixir.FixAllForFileModeTest)
             test/elixir/fix_all_for_file_mode_test.exs:52
             Assertion with == failed
             code:  assert %{
                      actions_tree: %{
                        :clear_screen => %Action{next_action: {:mix_test_puts, 0}, runnable: :clear_screen},
                        :put_mix_test_msg => %Action{
                          next_action: :mix_test,
                          runnable: {:puts, :magenta, "Running mix test test/x_test.exs"}
                        },
                        :mix_test => %Action{
                          next_action: %{0 => :put_sarcastic_success, fallback: :put_failure_msg},
                          runnable: {:mix_test, "test/x_test.exs"}
                        },
                        :put_failure_msg => %Action{
                          next_action: :exit,
                          runnable:
                            {:puts, :red,
                             "At least one test in test/x_test.exs is busted. I'll run it exclusively until you fix it... (unless you break another one in the process)"}
                        },
                        :put_sarcastic_success => %Action{next_action: :exit, runnable: :put_sarcastic_success},
                        {:mix_test_puts, 0} => %Action{
                          next_action: {:mix_test, 0},
                          runnable: {:puts, :magenta, "Running mix test test/x_test.exs:1"}
                        },
                        {:mix_test, 0} => %Action{
                          next_action: {:put_elixir_failures_count, 0},
                          runnable: {:mix_test, "test/x_test.exs:1"}
                        },
                        {:put_elixir_failures_count, 0} => %Action{
                          runnable: {:put_elixir_failures_count, "test/x_test.exs"},
                          next_action: %{0 => {:mix_test_puts, 1}, fallback: :put_failure_msg}
                        },
                        {:mix_test_puts, 1} => %Action{
                          next_action: {:mix_test, 1},
                          runnable: {:puts, :magenta, "Running mix test test/x_test.exs --max-failures 1"}
                        },
                        {:mix_test, 1} => %Action{
                          next_action: {:put_elixir_failures_count, 1},
                          runnable: {:mix_test, "test/x_test.exs --max-failures 1"}
                        },
                        {:put_elixir_failures_count, 1} => %Action{
                          runnable: {:put_elixir_failures_count, "test/x_test.exs"},
                          next_action: %{0 => :put_mix_test_msg, fallback: :put_failure_msg}
                        }
                      },
                      entry_point: :clear_screen
                    } == tree
             left:  %{
                      actions_tree: %{
                        :clear_screen => %PolyglotWatcherV2.Action{
                          runnable: :clear_screen,
                          next_action: {:mix_test_puts, 0}
                        },
                        :mix_test => %PolyglotWatcherV2.Action{
                          runnable: {:mix_test, "test/x_test.exs"},
                          next_action: %{
                            0 => :put_sarcastic_success,
                            :fallback => :put_failure_msg
                          }
                        },
                        :put_failure_msg => %PolyglotWatcherV2.Action{
                          runnable: {:puts, :red,
                           "At least one test in test/x_test.exs is busted. I'll run it exclusively until you fix it... (unless you break another one in the process)"},
                          next_action: :exit
                        },
                        :put_mix_test_msg => %PolyglotWatcherV2.Action{
                          runnable: {:puts, :magenta,
                           "Running mix test test/x_test.exs"},
                          next_action: :mix_test
                        },
                        :put_sarcastic_success => %PolyglotWatcherV2.Action{
                          runnable: :put_sarcastic_success,
                          next_action: :exit
                        },
                        {:mix_test, 0} => %PolyglotWatcherV2.Action{
                          runnable: {:mix_test,
                           "test/x_test.exs:1"},
                          next_action: {:put_elixir_failures_count,
                           0}
                        },
                        {:mix_test, 1} => %PolyglotWatcherV2.Action{
                          runnable: {:mix_test,
                           "test/x_test.exs --max-failures 1"},
                          next_action: {:put_elixir_failures_count,
                           1}
                        },
                        {:mix_test_puts, 0} => %PolyglotWatcherV2.Action{
                          runnable: {:puts, :magenta,
                           "Running mix test test/x_test.exs:1"},
                          next_action: {:mix_test, 0}
                        },
                        {:mix_test_puts, 1} => %PolyglotWatcherV2.Action{
                          runnable: {:puts, :magenta,
                           "Running mix test test/x_test.exs --max-failures 1"},
                          next_action: {:mix_test, 1}
                        },
                        {:put_elixir_failures_count, 0} => %PolyglotWatcherV2.Action{
                          runnable: {:put_elixir_failures_count,
                           "test/x_test.exs"},
                          next_action: %{
                            0 => {:mix_test_puts, 1},
                            :fallback => :put_failure_msg
                          }
                        },
                        {:put_elixir_failures_count, 1} => %PolyglotWatcherV2.Action{
                          runnable: {:put_elixir_failures_count,
                           "test/x_test.exs"},
                          next_action: %{
                            0 => :put_mix_test_msg,
                            :fallback => :put_failure_msg
                          }
                        }
                      },
                      entry_point: :clear_screen
                    }
             right: %{
                      actions_tree: %{
                        check_file_exists: %PolyglotWatcherV2.Action{
                          runnable: {:file_exists,
                           "test/cool_test.exs"},
                          next_action: %{
                            fallback: :no_test_msg,
                            true: :put_intent_msg
                          }
                        },
                        clear_screen: %PolyglotWatcherV2.Action{
                          runnable: :clear_screen,
                          next_action: :check_file_exists
                        },
                        mix_test: %PolyglotWatcherV2.Action{
                          runnable: {:mix_test,
                           "test/cool_test.exs"},
                          next_action: %{
                            0 => :put_success_msg,
                            :fallback => :put_failure_msg
                          }
                        },
                        no_test_msg: %PolyglotWatcherV2.Action{
                          runnable: {:puts, :magenta,
                           "You saved the former, but the latter doesn't exist:\n\n  lib/cool.ex\n  test/cool_test.exs\n\nThat's a bit naughty! You cheeky little fellow...\n"},
                          next_action: :exit
                        },
                        put_failure_msg: %PolyglotWatcherV2.Action{
                          runnable: :put_insult,
                          next_action: :exit
                        },
                        put_intent_msg: %PolyglotWatcherV2.Action{
                          runnable: {:puts, :magenta,
                           "Running mix test test/cool_test.exs"},
                          next_action: :mix_test
                        },
                        put_success_msg: %PolyglotWatcherV2.Action{
                          runnable: :put_sarcastic_success,
                          next_action: :exit
                        }
                      },
                      entry_point: :clear_screen
                    }
             stacktrace:
               test/elixir/fix_all_for_file_mode_test.exs:68: (test)



          2) test determine_actions/1 with no failures for the fixed file, runs all the tests (PolyglotWatcherV2.Elixir.FixAllForFileModeTest)
             test/elixir/fix_all_for_file_mode_test.exs:30
             Assertion with == failed
             code:  assert actual_action_tree_keys == expected_action_tree_keys
             left:  MapSet.new([:check_file_exists, :clear_screen, :mix_test,
                     :no_test_msg, :put_failure_msg,
                     :put_intent_msg, :put_success_msg])
             right: MapSet.new([:clear_screen, :mix_test, :put_failure_msg,
                     :put_mix_test_msg, :put_sarcastic_success])
             stacktrace:
               test/elixir/fix_all_for_file_mode_test.exs:48: (test)

        ................................

          3) test determine_actions/2 returns the fix_all actions when in that state (PolyglotWatcherV2.Elixir.DeterminerTest)
             test/elixir/determiner_test.exs:55
             Assertion with == failed
             code:  assert actual_action_tree_keys == expected_action_tree_keys
             left:  MapSet.new([:check_file_exists, :clear_screen, :mix_test,
                     :no_test_msg, :put_failure_msg,
                     :put_intent_msg, :put_success_msg])
             right: MapSet.new([
                      :clear_screen,
                      :mix_test,
                      :mix_test_msg,
                      :put_failure_msg,
                      :put_sarcastic_success,
                      {:mix_test, 0},
                      {:mix_test, 1},
                      {:mix_test_puts, 0},
                      {:mix_test_puts, 1},
                      {:put_elixir_failures_count, 0},
                      {:put_elixir_failures_count, 1}
                    ])
             stacktrace:
               test/elixir/determiner_test.exs:88: (test)

        .......

          4) test determine_actions/2 returns the run_all actions when in that mode (PolyglotWatcherV2.Elixir.DeterminerTest)
             test/elixir/determiner_test.exs:34
             Assertion with == failed
             code:  assert actual_action_tree_keys == expected_action_tree_keys
             left:  MapSet.new([:check_file_exists, :clear_screen, :mix_test,
                     :no_test_msg, :put_failure_msg,
                     :put_intent_msg, :put_success_msg])
             right: MapSet.new([:clear_screen, :mix_test, :put_failure_msg,
                     :put_mix_test_msg, :put_success_msg])
             stacktrace:
               test/elixir/determiner_test.exs:51: (test)

        .

          5) test determine_actions/2 returns the fix_all_for_file_actions when in that state (PolyglotWatcherV2.Elixir.DeterminerTest)
             test/elixir/determiner_test.exs:92
             Assertion with == failed
             code:  assert actual_action_tree_keys == expected_action_tree_keys
             left:  MapSet.new([:check_file_exists, :clear_screen, :mix_test,
                     :no_test_msg, :put_failure_msg,
                     :put_intent_msg, :put_success_msg])
             right: MapSet.new([
                      :clear_screen,
                      :mix_test,
                      :put_failure_msg,
                      :put_mix_test_msg,
                      :put_sarcastic_success,
                      {:mix_test, 0},
                      {:mix_test, 1},
                      {:mix_test_puts, 0},
                      {:mix_test_puts, 1},
                      {:put_elixir_failures_count, 0},
                      {:put_elixir_failures_count, 1}
                    ])
             stacktrace:
               test/elixir/determiner_test.exs:125: (test)

        .......
        Finished in 0.1 seconds (0.1s async, 0.00s sync)
        79 tests, 5 failures

        Randomized with seed 829186
        |}
          "
        }
      ]
    }
    |> Jason.encode!()

    options = [recv_timeout: 100_000]

    case HTTPoison.post(@url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
