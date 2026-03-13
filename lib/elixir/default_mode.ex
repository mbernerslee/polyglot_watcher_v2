defmodule PolyglotWatcherV2.Elixir.DefaultMode do
  @behaviour PolyglotWatcherV2.Mode
  alias PolyglotWatcherV2.{Action, FilePath}
  alias PolyglotWatcherV2.Elixir.{Determiner, EquivalentPath, MixTestArgs}

  @ex Determiner.ex()
  @exs Determiner.exs()

  @impl PolyglotWatcherV2.Mode
  def determine_actions(%FilePath{extension: @exs} = file_path, server_state) do
    test_path = FilePath.stringify(file_path)
    mix_test_args = %MixTestArgs{path: test_path}

    {%{
       entry_point: :mix_test,
       actions_tree: %{
         mix_test: %Action{
           runnable: {:mix_test, mix_test_args},
           next_action: :exit
         }
       }
     }, server_state}
  end

  @impl PolyglotWatcherV2.Mode
  def determine_actions(%FilePath{extension: @ex} = lib_path, server_state) do
    lib_path_string = FilePath.stringify(lib_path)

    case EquivalentPath.determine(lib_path) do
      {:ok, test_path} ->
        {mix_test_with_file_exists_check(lib_path_string, test_path), server_state}

      :error ->
        {no_idea_what_to_run(lib_path_string), server_state}
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
    mix_test_args = %MixTestArgs{path: test_path}

    %{
      entry_point: :check_file_exists,
      actions_tree: %{
        check_file_exists: %Action{
          runnable: {:file_exists, test_path},
          next_action: %{true => :mix_test, :fallback => :no_test_msg}
        },
        mix_test: %Action{
          runnable: {:mix_test, mix_test_args},
          next_action: :exit
        },
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
end
