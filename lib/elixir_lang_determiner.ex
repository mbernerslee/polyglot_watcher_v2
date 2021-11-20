defmodule PolyglotWatcherV2.ElixirLangDeterminer do
  alias PolyglotWatcherV2.{Action, FilePath}
  @ex "ex"
  @exs "exs"
  @extensions [@ex, @exs]

  def determine_actions(%FilePath{} = file_path) do
    if file_path.extension in @extensions do
      do_determine_actions(file_path)
    else
      :none
    end
  end

  defp do_determine_actions(%FilePath{extension: @exs} = file_path) do
    test_path = FilePath.stringify(file_path)

    %{
      entry_point: :clear_screen,
      actions_tree: %{
        clear_screen: %Action{
          runnable: :clear_screen,
          next_action: :put_intent_msg
        },
        put_intent_msg: %Action{
          runnable: {:puts, :magenta, "Running mix test #{test_path}"},
          next_action: :mix_test
        },
        mix_test: %Action{
          runnable: {:mix_test, test_path},
          next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
        },
        put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
        put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
      }
    }
  end

  defp do_determine_actions(%FilePath{extension: @ex} = file_path) do
    test_path = determine_equivalent_test_path(file_path)

    %{
      entry_point: :clear_screen,
      actions_tree: %{
        clear_screen: %Action{
          runnable: {:run_sys_cmd, "tput", ["reset"]},
          next_action: :check_file_exists
        },
        check_file_exists: %Action{
          runnable: {:file_exists, test_path},
          next_action: %{true => :put_intent_msg, :fallback => :no_test_msg}
        },
        put_intent_msg: %Action{
          runnable: {:puts, :magenta, "Running mix test #{test_path}"},
          next_action: :mix_test
        },
        mix_test: %Action{
          runnable: {:mix_test, test_path},
          next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
        },
        put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
        put_failure_msg: %Action{runnable: :put_insult, next_action: :exit},
        no_test_msg: %Action{
          runnable: {
            :puts,
            :magenta,
            """
            You saved the former, but the latter doesn't exist:

              #{FilePath.stringify(file_path)}
              #{test_path}

            That's a bit naughty! You naughty little fellow...
            """
          },
          next_action: :exit
        }
      }
    }
  end

  # move this to its own module & test it, especially with paths that have more than one "lib/" in the name
  defp determine_equivalent_test_path(%FilePath{path: path, extension: @ex}) do
    case String.split(path, "lib/") do
      ["", middle_bit_of_file_path] ->
        "test/" <> middle_bit_of_file_path <> "_test.#{@exs}"
    end
  end
end
