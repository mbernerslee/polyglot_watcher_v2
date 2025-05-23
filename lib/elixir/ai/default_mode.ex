defmodule PolyglotWatcherV2.Elixir.AI.DefaultMode do
  @behaviour PolyglotWatcherV2.Mode
  alias PolyglotWatcherV2.{
    Action,
    Const,
    AI,
    EnvironmentVariables,
    FilePath,
    FileSystem,
    Puts
  }

  alias PolyglotWatcherV2.Elixir.{Cache, Determiner, EquivalentPath, MixTestArgs}

  @ex Determiner.ex()
  @exs Determiner.exs()
  @default_prompt Const.default_prompt()

  @impl PolyglotWatcherV2.Mode
  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switching to AI mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :ai_default},
           next_action: :persist_api_key
         },
         persist_api_key: %Action{
           runnable: {:persist_env_var, server_state.config.ai.api_key_env_var_name},
           next_action: %{0 => :put_awaiting_file_save_msg, :fallback => :no_api_key_fail_msg}
         },
         no_api_key_fail_msg: %Action{
           runnable:
             {:puts, :red,
              "I read the environment variable '#{server_state.config.ai.api_key_env_var_name}', but nothing was there, so I'm giving up! Try setting it and running me again..."},
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
           next_action: %{0 => :put_success_msg, :fallback => :load_in_memory_prompt}
         },
         load_in_memory_prompt: %Action{
           runnable: :load_in_memory_prompt,
           next_action: %{
             0 => :build_api_request,
             :fallback => :exit
           }
         },
         build_api_request: %Action{
           runnable: {:build_ai_api_request_from_in_memory_prompt, test_path},
           next_action: %{
             0 => :put_calling_ai_msg,
             :fallback => :fallback_placeholder_error
           }
         },
         put_calling_ai_msg: %Action{
           runnable: {:puts, :magenta, "Waiting for AI API call response..."},
           next_action: :perform_ai_api_request
         },
         perform_ai_api_request: %Action{
           runnable: :perform_ai_api_request,
           next_action: %{
             0 => :parse_ai_api_response,
             :fallback => :fallback_placeholder_error
           }
         },
         parse_ai_api_response: %Action{
           runnable: :parse_ai_api_response,
           next_action: %{
             :fallback => :put_parsed_ai_api_response
           }
         },
         put_parsed_ai_api_response: %Action{
           runnable: :put_parsed_ai_api_response,
           next_action: %{
             :fallback => :exit
           }
         },
         # TODO get rid of this bs action
         fallback_placeholder_error: %Action{
           runnable:
             {:puts, :red,
              """
              AI fallback error
              Oh no!
              """},
           next_action: :put_failure_msg
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end

  def load_in_memory_prompt(server_state) do
    {:ok, %{}}
    |> and_then(:home, &get_home_env_var/1)
    |> and_then(:custom_prompt, &read_custom_prompt_file/1)
    |> case do
      {:ok, %{custom_prompt: custom_prompt}} ->
        Puts.on_new_line(
          "Loading custom prompt from ~/.config/polyglot_watcher_v2/prompt ...",
          :magenta
        )

        {0, put_in(server_state, [:ai_prompt], custom_prompt)}

      {:error, :missing_custom_prompt_file} ->
        Puts.on_new_line("No custom prompt file found, using default...", :magenta)
        {0, put_in(server_state, [:ai_prompt], @default_prompt)}

      {:error, :no_home_env_var} ->
        Puts.on_new_line(
          "I can't check if you've got a custom prompt, because $HOME doesn't exist... sort your system out to have $HOME, then try again?",
          :red
        )

        {1, server_state}
    end
  end

  defp get_home_env_var(_) do
    case EnvironmentVariables.get_env("HOME") do
      nil -> {:error, :no_home_env_var}
      home -> {:ok, home}
    end
  end

  defp read_custom_prompt_file(%{home: home}) do
    path = home <> "/.config/polyglot_watcher_v2/prompt"

    case FileSystem.read(path) do
      {:ok, contents} -> {:ok, contents}
      _ -> {:error, :missing_custom_prompt_file}
    end
  end

  defp and_then({:ok, acc}, key, fun) do
    case fun.(acc) do
      {:ok, result} -> {:ok, Map.put(acc, key, result)}
      error -> error
    end
  end

  defp and_then(error, _key, _fun), do: error

  def build_api_request_from_in_memory_prompt(
        test_path,
        %{ai_prompt: prompt} = server_state
      ) do
    case Cache.get_files(test_path) do
      {:ok, %{test: test, lib: lib, mix_test_output: mix_test_output}} ->
        messages = [%{role: "user", content: api_content(lib, test, prompt, mix_test_output)}]

        AI.build_api_request(server_state, messages)

      _ ->
        {1, server_state}
    end
  end

  def build_api_request_from_in_memory_prompt(_test_path, server_state) do
    {1, server_state}
  end

  defp api_content(lib, test, prompt, mix_test_output) do
    prompt
    |> String.replace("$LIB_PATH_PLACEHOLDER", lib.path)
    |> String.replace("$LIB_CONTENT_PLACEHOLDER", lib.contents)
    |> String.replace("$TEST_PATH_PLACEHOLDER", test.path)
    |> String.replace("$TEST_CONTENT_PLACEHOLDER", test.contents)
    |> String.replace("$MIX_TEST_OUTPUT_PLACEHOLDER", mix_test_output)
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
