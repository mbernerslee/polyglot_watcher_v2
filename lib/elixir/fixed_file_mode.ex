defmodule PolyglotWatcherV2.Elixir.FixedFileMode do
  @behaviour PolyglotWatcherV2.Mode
  alias PolyglotWatcherV2.Action
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  @impl PolyglotWatcherV2.Mode
  def switch(server_state) do
    case Cache.get_test_failure(:latest) do
      {:ok, {test_path, line_number}} ->
        actions_tree =
          {test_path, line_number}
          |> common_actions_tree()
          |> Map.merge(%{
            clear_screen: %PolyglotWatcherV2.Action{
              runnable: :clear_screen,
              next_action: :switch_mode
            },
            switch_mode: %PolyglotWatcherV2.Action{
              runnable: {:switch_mode, :elixir, {:fixed_file, {test_path, line_number}}},
              next_action: :put_switch_mode_msg
            },
            put_switch_mode_msg: %Action{
              runnable:
                {:puts,
                 [
                   {[:magenta], "Switching to "},
                   {[:magenta, :italic], "Fixed File "},
                   {[:magenta], "mode...\n"},
                   {[:magenta], "using the latest failing test in memory..."}
                 ]},
              next_action: :put_mix_test_msg
            }
          })

        {%{entry_point: :clear_screen, actions_tree: actions_tree}, server_state}

      {:error, :not_found} ->
        {%{
           entry_point: :clear_screen,
           actions_tree: %{
             clear_screen: %PolyglotWatcherV2.Action{
               runnable: :clear_screen,
               next_action: :put_error_msg
             },
             put_error_msg: %Action{
               runnable:
                 {:puts,
                  [
                    {[:red], "Switching to "},
                    {[:red, :italic], "Fixed File "},
                    {[:red], "mode failed\n"},
                    {[:red], "I wasn't given a test_path "},
                    {[:red, :italic], "and "},
                    {[:red], "my memory of failing tests is empty\n"},
                    {[:red],
                     "Therefore I don't know which file upon which to fixate testing, so I am forced to give up :-("}
                  ]},
               next_action: :exit
             }
           }
         }, server_state}
    end
  end

  @impl PolyglotWatcherV2.Mode
  def switch(server_state, test_path) do
    actions_tree =
      test_path
      |> common_actions_tree()
      |> Map.merge(%{
        clear_screen: %PolyglotWatcherV2.Action{
          runnable: :clear_screen,
          next_action: :switch_mode
        },
        switch_mode: %PolyglotWatcherV2.Action{
          runnable: {:switch_mode, :elixir, {:fixed_file, test_path}},
          next_action: :put_switch_mode_msg
        },
        put_switch_mode_msg: %Action{
          runnable:
            {:puts,
             [
               {[:magenta], "Switching to "},
               {[:magenta, :italic], "Fixed File "},
               {[:magenta], "mode...\n"},
               {[:magenta], "using the provided test path..."}
             ]},
          next_action: :put_mix_test_msg
        }
      })

    {%{entry_point: :clear_screen, actions_tree: actions_tree}, server_state}
  end

  @impl PolyglotWatcherV2.Mode
  def determine_actions(%{elixir: %{mode: {:fixed_file, test_path}}} = server_state) do
    actions_tree =
      test_path
      |> common_actions_tree()
      |> Map.put(:clear_screen, %Action{runnable: :clear_screen, next_action: :put_mix_test_msg})

    {%{entry_point: :clear_screen, actions_tree: actions_tree}, server_state}
  end

  defp common_actions_tree(test_path) do
    mix_test_args = %MixTestArgs{path: test_path}
    mix_test_msg = "Running #{MixTestArgs.to_shell_command(mix_test_args)}"

    %{
      put_mix_test_msg: %PolyglotWatcherV2.Action{
        runnable: {:puts, :magenta, mix_test_msg},
        next_action: :mix_test
      },
      mix_test: %PolyglotWatcherV2.Action{
        runnable: {:mix_test, mix_test_args},
        next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
      },
      put_success_msg: %PolyglotWatcherV2.Action{
        runnable: :put_sarcastic_success,
        next_action: :exit
      },
      put_failure_msg: %PolyglotWatcherV2.Action{
        runnable: :put_insult,
        next_action: :exit
      }
    }
  end
end
