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
          runnable: {:run_sys_cmd, "tput", ["reset"]},
          next_action: :put_intent_msg
        },
        put_intent_msg: %Action{
          runnable: {:puts, :magenta, "Running mix test #{test_path}"},
          next_action: :mix_test
        },
        mix_test: %Action{
          runnable: {:mix_test, test_path},
          next_action: %{0 => :exit, :fallback => :put_failure_msg}
        },
        put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
      }
    }
  end

  defp do_determine_actions(%FilePath{extension: @ex}) do
    :none
  end
end
