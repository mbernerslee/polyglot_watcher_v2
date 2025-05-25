defmodule PolyglotWatcherV2.Elixir.AI.ReplaceMode do
  @behaviour PolyglotWatcherV2.Mode
  alias PolyglotWatcherV2.{Action, FilePath}
  alias PolyglotWatcherV2.Elixir.{Determiner, EquivalentPath, MixTestArgs}
  alias PolyglotWatcherV2.Elixir.AI.ReplaceMode.UserInputActions

  @ex Determiner.ex()
  @exs Determiner.exs()

  @impl PolyglotWatcherV2.Mode
  def user_input_actions(user_input, server_state) do
    UserInputActions.determine(user_input, server_state)
  end

  @impl PolyglotWatcherV2.Mode
  def switch(server_state) do
    %{config: %{ai: %{api_key_env_var_name: api_key_env_var_name}}} = server_state

    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switching to AI Replace mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :ai_replace},
           next_action: :persist_api_key
         },
         persist_api_key: %Action{
           runnable: {:persist_env_var, api_key_env_var_name},
           next_action: %{0 => :put_awaiting_file_save_msg, :fallback => :no_api_key_fail_msg}
         },
         no_api_key_fail_msg: %Action{
           runnable:
             {:puts, :red,
              "I read the environment variable '#{api_key_env_var_name}', but nothing was there, so I'm giving up! Try setting it and running me again..."},
           next_action: :exit
         },
         put_awaiting_file_save_msg: %Action{
           runnable: {:puts, :magenta, "Awaiting a file save..."},
           next_action: :exit
         }
       }
     }, server_state}
  end

  @impl PolyglotWatcherV2.Mode
  def determine_actions(%FilePath{extension: @exs} = test_path, server_state) do
    test_path_string = FilePath.stringify(test_path)
    do_determine_actions(test_path_string, server_state)
  end

  @impl PolyglotWatcherV2.Mode
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
           next_action: %{0 => :put_success_msg, :fallback => :reload_ai_prompt}
         },
         reload_ai_prompt: %Action{
           runnable: {:reload_ai_prompt, :replace},
           next_action: %{0 => :build_ai_api_request, :fallback => :exit}
         },
         build_ai_api_request: %Action{
           runnable: {:build_ai_api_request, :replace, test_path},
           next_action: %{0 => :perform_ai_api_request, :fallback => :exit}
         },
         # TODO should put "Waiting for AI API call response...", but tell you which vendor / model
         perform_ai_api_request: %Action{
           runnable: {:perform_ai_api_request, :replace},
           next_action: :action_ai_api_response
         },
         action_ai_api_response: %Action{
           runnable: {:action_ai_api_response, :replace, test_path},
           next_action: :exit
         },
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
