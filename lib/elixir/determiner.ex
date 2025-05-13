defmodule PolyglotWatcherV2.Elixir.Determiner do
  alias PolyglotWatcherV2.{Action, FilePath}

  alias PolyglotWatcherV2.Elixir.{
    DefaultMode,
    FixAllForFileMode,
    FixAllMode,
    FixedFileMode,
    MixTestArgs,
    RunAllMode
  }

  alias PolyglotWatcherV2.Elixir.ClaudeAI.DefaultMode, as: ClaudeAIDefaultMode
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode, as: ClaudeAIReplaceMode

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
    IO.inspect(user_input)

    [ClaudeAIReplaceMode]
    |> Enum.reduce_while(nil, fn mod, _ ->
      case mod.user_input_actions(user_input, server_state) do
        false ->
          {:cont, nil}

        {tree, server_state} ->
          {:halt, {tree, server_state}}
      end
    end)
    |> case do
      {tree, server_state} -> {tree, server_state}
      nil -> switch_mode_actions(user_input, server_state)
    end
  end

  defp switch_mode_actions(user_input, server_state) do
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

  # keep this up to date with README.md!
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
       "  OR without providing [path], does the above but for the most recent known test failure in memory\n"},
      {:white,
       "  You can specify an exact line number e.g. test/cool_test.exs:100, if you want\n"},
      {:light_magenta, "ex fa \n"},
      {:white, "  Fix All Mode\n"},
      {:white, "  Runs:\n"},
      {:white, "    (1) 'mix test'\n"},
      {:white,
       "    (2) 'mix test [single test only]' for each failing test in turn, until they're all fixed. Then we run (1) again to check we really are done\n"},
      {:light_magenta, "ex faff [path]\n"},
      {:white, "  Fix All For File Mode\n"},
      {:white, "  Runs:\n"},
      {:white, "    (1) 'mix test [path]'\n"},
      {:white,
       "    (2) 'mix test [path]:10' for each failing line number in turn until it's fixed and then (1) again to check we really are done\n"},
      {:white,
       "  OR without providing [path], does the above but for the most recent known test failure in memory\n"},
      {:light_magenta, "ex cl\n"},
      {:white, "  Claude\n"},
      {:white,
       "  The same as default mode, but if the test fails then an automatic API call is made to Anthropic's Claude AI asking it if it can fix the test\n You can set you're own custom prompt which automatically gets the lib file, test file & mix test output spliced into it for you. See README for more details"},
      {:white,
       "  It auto-generates the prompt with the lib file, test file & mix test output for you.\n"},
      {:white,
       "  Requires a valid ANTHROPIC_API_KEY environment variable to be on your system.\n"},
      {:light_magenta, "ex clr\n"},
      {:white, "  Claude Replace\n"},
      {:white,
       "The same as the above mode, but uses a hard-coded prompt resulting in find/replace suggestion codeblocks to fix the test"}
    ]
  end

  defp input_to_actions_mapping(user_input) do
    case user_input do
      ["d"] -> &switch_to_default_mode(&1)
      ["f"] -> &FixedFileMode.switch(&1)
      ["f", test_path] -> &switch_with_file(&1, FixedFileMode, test_path)
      ["faff", test_path] -> &switch_with_file(&1, FixAllForFileMode, test_path)
      ["fa"] -> &FixAllMode.switch(&1)
      ["faff"] -> &FixAllForFileMode.switch(&1)
      ["ra"] -> &RunAllMode.switch(&1)
      ["cl"] -> &ClaudeAIDefaultMode.switch(&1)
      ["clr"] -> &ClaudeAIReplaceMode.switch(&1)
      _ -> nil
    end
  end

  defp switch_with_file(server_state, module, test_path) do
    case MixTestArgs.to_path(test_path) do
      {:ok, test_path} -> module.switch(server_state, test_path)
      _ -> {:none, server_state}
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

  defp dont_undstand_user_input(server_state) do
    {:none, server_state}
  end

  defp by_mode(file_path, server_state) do
    case server_state.elixir.mode do
      :default ->
        DefaultMode.determine_actions(file_path, server_state)

      {:fixed_file, _file} ->
        FixedFileMode.determine_actions(server_state)

      :fix_all ->
        FixAllMode.determine_actions(server_state)

      {:fix_all_for_file, _file} ->
        FixAllForFileMode.determine_actions(server_state)

      :run_all ->
        RunAllMode.determine_actions(server_state)

      :claude_ai ->
        ClaudeAIDefaultMode.determine_actions(file_path, server_state)

      :claude_ai_replace ->
        ClaudeAIReplaceMode.determine_actions(file_path, server_state)
    end
  end
end
