defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode do
  alias PolyglotWatcherV2.{Action, FilePath}
  alias PolyglotWatcherV2.Elixir.{Determiner, EquivalentPath, MixTestArgs}

  @ex Determiner.ex()
  @exs Determiner.exs()
  @yes "y\n"
  @no "n\n"

  def user_input_actions(
        @yes,
        %{
          elixir: %{mode: :claude_ai_replace},
          claude_ai: %{phase: :waiting, file_updates: file_updates}
        } = server_state
      ) do
    {%{
       entry_point: :patch_files,
       actions_tree: %{
         patch_files: %Action{
           runnable: {:patch_files, file_updates},
           next_action: :exit
         }
       }
     }, %{server_state | claude_ai: %{}, ignore_file_changes: false}}
  end

  def user_input_actions(
        @no,
        %{
          elixir: %{mode: :claude_ai_replace},
          claude_ai: %{phase: :waiting, file_updates: _file_updates}
        } = server_state
      ) do
    {%{
       entry_point: :put_msg,
       actions_tree: %{
         put_msg: %Action{
           runnable: {:puts, :magenta, "Ok, ignoring suggestion..."},
           next_action: :exit
         }
       }
     }, %{server_state | claude_ai: %{}, ignore_file_changes: false}}
  end

  # TODO could purge state, & ignore_file_changes = true here ??
  def user_input_actions(_, _server_state) do
    false
  end

  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switching to Claude AI Replace mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :claude_ai_replace},
           next_action: :persist_api_key
         },
         persist_api_key: %Action{
           runnable: {:persist_env_var, "ANTHROPIC_API_KEY"},
           next_action: %{0 => :put_awaiting_file_save_msg, :fallback => :no_api_key_fail_msg}
         },
         no_api_key_fail_msg: %Action{
           runnable:
             {:puts, :red,
              "I read the environment variable 'ANTHROPIC_API_KEY', but nothing was there, so I'm giving up! Try setting it and running me again..."},
           next_action: :exit
         },
         put_awaiting_file_save_msg: %Action{
           runnable: {:puts, :magenta, "Awaiting a file save..."},
           next_action: :exit
         }
       }
     }, server_state}
  end

  def determine_actions(%FilePath{extension: @exs} = test_path, server_state) do
    test_path_string = FilePath.stringify(test_path)
    do_determine_actions(test_path_string, server_state)
  end

  def determine_actions(%FilePath{extension: @ex} = lib_path, server_state) do
    lib_path_string = FilePath.stringify(lib_path)

    case EquivalentPath.determine(lib_path) do
      {:ok, test_path} ->
        do_determine_actions(test_path, server_state)

      :error ->
        {cannot_determine_test_path_from_lib_path(lib_path_string), server_state}
    end
  end

  defp do_determine_actions(test_path, server_state) do
    mix_test_args = %MixTestArgs{path: test_path}
    mix_test_msg = "Running #{MixTestArgs.to_shell_command(mix_test_args)}"

    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_intent_msg
         },
         put_intent_msg: %Action{
           runnable: {:puts, :magenta, mix_test_msg},
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: {:mix_test, mix_test_args},
           next_action: %{0 => :put_success_msg, :fallback => :put_calling_claude_msg}
         },
         put_calling_claude_msg: %Action{
           runnable: {:puts, :magenta, "Waiting for Claude API call response..."},
           next_action: :perform_api_call
         },
         perform_api_call: %Action{
           runnable: {:perform_claude_replace_api_call, test_path},
           next_action: %{0 => :put_awaiting_input_msg, :fallback => :exit}
         },
         put_awaiting_input_msg: %Action{
           runnable: {:puts, :magenta, "Accept file changes (y/n)?"},
           next_action: :exit
         },
         # build_claude_replace_api_request: %Action{
         #  runnable: {:build_claude_replace_api_request, test_path},
         #  next_action: :put_calling_claude_msg
         # },
         # put_calling_claude_msg: %Action{
         #  runnable: {:puts, :magenta, "Waiting for Claude API call response..."},
         #  next_action: :perform_claude_api_request
         # },
         # perform_claude_api_request: %Action{
         #  runnable: :perform_claude_api_request,
         #  next_action: :parse_claude_response
         # },
         # parse_claude_response: %Action{
         #  runnable: :parse_claude_api_response,
         #  next_action: :build_replace_blocks
         # },
         # build_replace_blocks: %Action{
         #  runnable: :build_claude_replace_blocks,
         #  next_action: :build_replace_actions
         # },
         # build_replace_actions: %Action{
         #  runnable: :build_claude_replace_actions,
         #  next_action: :execute_stored_actions
         # },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit}
       }
     }, server_state}
  end

  defp cannot_determine_test_path_from_lib_path(lib_path) do
    %{
      entry_point: :clear_screen,
      actions_tree: %{
        clear_screen: %Action{
          runnable: :clear_screen,
          next_action: :cannot_find_msg
        },
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
end
