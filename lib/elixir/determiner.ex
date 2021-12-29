defmodule PolyglotWatcherV2.Elixir.Determiner do
  alias PolyglotWatcherV2.{Action, FilePath}

  alias PolyglotWatcherV2.Elixir.{
    DefaultMode,
    FixAllForFileMode,
    FixedLastMode,
    FixedFileMode,
    RunAllMode
  }

  @ex "ex"
  @exs "exs"
  @extensions [@ex, @exs]

  def ex, do: @ex
  def exs, do: @exs

  def determine_actions(%FilePath{} = file_path, server_state) do
    if file_path.extension in @extensions do
      by_mode(file_path, server_state)
    else
      {:none, server_state}
    end
  end

  def user_input_actions(user_input, server_state) do
    ex_space = "#{@ex} "

    if String.starts_with?(user_input, ex_space) do
      user_input
      |> String.trim()
      |> String.trim_leading(ex_space)
      |> String.split(" ")
      |> map_user_input_to_actions(server_state)
    else
      {:none, server_state}
    end
  end

  def usage_puts do
    [
      {:magenta, "Elixir\n"},
      {:light_magenta, "ex d\n"},
      {:white, "  Default Mode\n"},
      {:white, "  Will run the equivalently pathed test only\n"},
      {:white,
       "  In other words... mix test/x_test.exs when lib/x.ex or test/x_test.exs itself is saved\n"},
      {:light_magenta, "ex ra\n"},
      {:white, "  Run All Mode\n"},
      {:white, "  Runs 'mix test' whenever any .ex or .exs file is saved\n"},
      {:light_magenta, "ex f [path]\n"},
      {:white, "  Fixed Mode\n"},
      {:white, "  Runs 'mix test [path]' whenever any .ex or .exs file is saved\n"},
      {:white,
       "  You can specify an exact line number e.g. test/cool_test.exs:100, if you want\n"},
      {:light_magenta, "ex faff [path]\n"},
      {:white, "  Fix All For File Mode\n"},
      {:white, "  Runs:\n"},
      {:white, "    (1) 'mix test [path]'\n"},
      {:white,
       "    (2) 'mix test [path]:10' for each failing line number in turn until it's fixed and then (1) again to check we really are done\n"},
      {:light_magenta, "ex fl\n"},
      {:white, "  Fixed Last Mode\n"},
      {:white,
       "  Only runs the most recently failed test when any .ex or .exs files are saved\n"},
      {:white, "  I do this by keeping track of which tests have failed as I go\n"},
      {:white,
       "  This means that when the most recently failed test passes, I'll start only running the next one that failed, and so on.\n"},
      {:white,
       "  Initialising in this mode isn't reccommended because on startup my memory of failing tests is empty...\n"},
      {:white,
       "  So maybe try starting out in a different mode (e.g. Run All Mode) then switching to this one\n"}
    ]
  end

  defp input_to_actions_mapping(user_input) do
    case user_input do
      ["d"] -> &switch_to_default_mode(&1)
      ["f", test_file] -> &switch_to_fixed_file_mode(&1, test_file)
      ["faff", test_file] -> &FixAllForFileMode.switch(&1, test_file)
      ["ra"] -> &switch_to_run_all_mode(&1)
      ["fl"] -> &switch_to_fixed_last_mode(&1)
      _ -> nil
    end
  end

  defp map_user_input_to_actions(user_input, server_state) do
    case input_to_actions_mapping(user_input) do
      nil -> dont_undstand_user_input(server_state)
      actions_fun -> actions_fun.(server_state)
    end
  end

  defp switch_to_default_mode(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switched Elixir to default mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :default},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp switch_to_fixed_file_mode(server_state, test_path) do
    test_path = parse_test_path(test_path)

    {%{actions_tree: fixed_file_actions_tree}, _} =
      FixedFileMode.determine_actions(%{
        elixir: %{mode: {:fixed_file, test_path.with_line_number}}
      })

    fixed_file_actions_tree = Map.delete(fixed_file_actions_tree, :clear_screen)

    switch_mode_actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :check_file_exists
      },
      check_file_exists: %Action{
        runnable: {:file_exists, test_path.without_line_number},
        next_action: %{true => :switch_mode, :fallback => :put_no_file_msg}
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, {:fixed_file, test_path.with_line_number}},
        next_action: :put_switch_success_msg
      },
      put_no_file_msg: %Action{
        runnable:
          {:puts, :red,
           "I couldn't find a file at #{test_path.without_line_number}, so I failed to switch mode"},
        next_action: :exit
      },
      put_switch_success_msg: %Action{
        runnable:
          {:puts, :magenta, "Switching Elixir to fixed_file #{test_path.with_line_number} mode"},
        next_action: :put_intent_msg
      }
    }

    {%{
       entry_point: :clear_screen,
       actions_tree: Map.merge(switch_mode_actions_tree, fixed_file_actions_tree)
     }, server_state}
  end

  defp parse_test_path(file_path) do
    case String.split(file_path, ":") do
      [result] -> %{with_line_number: result, without_line_number: result}
      [result, _line_number] -> %{with_line_number: file_path, without_line_number: result}
      _ -> %{with_line_number: file_path, without_line_number: file_path}
    end
  end

  defp switch_to_run_all_mode(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :run_all},
           next_action: :put_msg
         },
         put_msg: %Action{
           runnable: {:puts, :magenta, "Switching to Elixir run_all mode"},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp switch_to_fixed_last_mode(server_state) do
    {%{actions_tree: fixed_last_actions_tree}, _} =
      FixedLastMode.determine_actions(%{
        elixir: %{failures: server_state.elixir.failures}
      })

    fixed_last_actions_tree = Map.delete(fixed_last_actions_tree, :clear_screen)

    switch_mode_actions_tree = %{
      clear_screen: %Action{
        runnable: :clear_screen,
        next_action: :switch_mode
      },
      switch_mode: %Action{
        runnable: {:switch_mode, :elixir, :fixed_last},
        next_action: :put_switch_msg
      },
      put_switch_msg: %Action{
        runnable: {:puts, :magenta, "Switching to Elixir fixed_last mode"},
        next_action: :put_intent_msg
      }
    }

    {%{
       entry_point: :clear_screen,
       actions_tree: Map.merge(switch_mode_actions_tree, fixed_last_actions_tree)
     }, server_state}
  end

  defp dont_undstand_user_input(server_state) do
    {:none, server_state}
  end

  defp by_mode(file_path, server_state) do
    case server_state.elixir.mode do
      :default ->
        DefaultMode.determine_actions(file_path, server_state)

      {:fixed_file, _file} ->
        FixedFileMode.determine_actions(server_state)

      {:fix_all_for_file, _file} ->
        FixAllForFileMode.determine_actions(server_state)

      :run_all ->
        RunAllMode.determine_actions(server_state)

      :fixed_last ->
        FixedLastMode.determine_actions(server_state)
    end
  end
end
