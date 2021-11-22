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

  defp do_determine_actions(%FilePath{extension: @ex} = lib_path) do
    lib_path_string = FilePath.stringify(lib_path)

    case determine_equivalent_test_path(lib_path) do
      {:ok, test_path} ->
        mix_test_with_file_exists_check(lib_path_string, test_path)

      :error ->
        no_idea_what_to_run(lib_path_string)
    end
  end

  defp no_idea_what_to_run(lib_path) do
    %{
      entry_point: :cannot_find_msg,
      actions_tree: %{
        cannot_find_msg: %Action{
          runnable:
            {:puts, :magenta,
             """
             You saved this file, but I can't work out what I should try and run:

               #{lib_path}

             Hmmmmm...

             """},
          next_action: :exit
        }
      }
    }
  end

  defp mix_test_with_file_exists_check(lib_path, test_path) do
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

              #{FilePath.stringify(lib_path)}
              #{test_path}

            That's a bit naughty! You cheeky little fellow...
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
        {:ok, "test/" <> middle_bit_of_file_path <> "_test.#{@exs}"}

      _ ->
        :error
    end
  end
end
