defmodule PolyglotWatcherV2.Elixir.ClaudeAIMode do
  alias PolyglotWatcherV2.{Action, EnvironmentVariables, FilePath, FileSystem, Puts}
  alias PolyglotWatcherV2.Elixir.{Determiner, EquivalentPath}
  alias HTTPoison.{Request, Response}

  @ex Determiner.ex()
  @exs Determiner.exs()

  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switching to Claude AI mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :claude_ai},
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

    case EquivalentPath.determine(test_path) do
      {:ok, lib_path} ->
        determine_actions(lib_path, test_path_string, server_state)

      :error ->
        {cannot_determine_lib_path_from_test_path(test_path_string), server_state}
    end
  end

  def determine_actions(%FilePath{extension: @ex} = lib_path, server_state) do
    lib_path_string = FilePath.stringify(lib_path)

    case EquivalentPath.determine(lib_path) do
      {:ok, test_path} ->
        determine_actions(lib_path_string, test_path, server_state)

      :error ->
        {cannot_determine_test_path_from_lib_path(lib_path_string), server_state}
    end
  end

  defp determine_actions(lib_path, test_path, server_state) do
    {%{
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
           next_action: %{0 => :put_success_msg, :fallback => :put_claude_init_msg}
         },
         put_claude_init_msg: %Action{
           runnable: {:puts, :magenta, "Doing some Claude setup..."},
           next_action: :put_perist_files_msg
         },
         put_perist_files_msg: %Action{
           runnable: {:puts, :magenta, "Saving the lib & test files to memory..."},
           next_action: :persist_lib_file
         },
         persist_lib_file: %Action{
           runnable: {:persist_file, lib_path, :lib},
           next_action: %{0 => :persist_test_file, :fallback => :missing_file_msg}
         },
         persist_test_file: %Action{
           runnable: {:persist_file, test_path, :test},
           next_action: %{
             0 => :load_prompt,
             :fallback => :missing_file_msg
           }
         },
         load_prompt: %Action{
           runnable: :load_claude_ai_prompt,
           next_action: %{
             0 => :build_claude_api_request,
             :fallback => :exit
           }
         },
         build_claude_api_request: %Action{
           runnable: :build_claude_api_request,
           next_action: %{
             0 => :put_calling_claude_msg,
             :fallback => :fallback_placeholder_error
           }
         },
         put_calling_claude_msg: %Action{
           runnable: {:puts, :magenta, "Waiting for Claude API call response..."},
           next_action: :perform_claude_api_request
         },
         perform_claude_api_request: %Action{
           runnable: :perform_claude_api_request,
           next_action: %{
             0 => :parse_claude_api_response,
             :fallback => :fallback_placeholder_error
           }
         },
         parse_claude_api_response: %Action{
           runnable: :parse_claude_api_response,
           next_action: %{
             0 => :put_parsed_claude_api_response,
             :fallback => :fallback_placeholder_error
           }
         },
         put_parsed_claude_api_response: %Action{
           runnable: :put_parsed_claude_api_response,
           next_action: %{0 => :exit, :fallback => :fallback_placeholder_error}
         },
         missing_file_msg: %Action{
           runnable:
             {:puts, :red,
              """
              You saved one of these, but the other doesn't exist:

                #{lib_path}
                #{test_path}

              So you're beyond this particular Claude integrations help until both exist.
              Create the missing one please!
              """},
           next_action: :put_failure_msg
         },
         fallback_placeholder_error: %Action{
           runnable:
             {:puts, :red,
              """
              Claude fallback error
              Oh no!
              """},
           next_action: :put_failure_msg
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end

  def load_prompt(server_state) do
    {:ok, %{}}
    |> and_then(:home, &get_home_env_var/1)
    |> and_then(:custom_prompt, &read_custom_prompt_file/1)
    |> case do
      {:ok, %{custom_prompt: custom_prompt}} ->
        Puts.on_new_line("Loading custom prompt from file...", :magenta)
        {0, put_in(server_state, [:elixir, :claude_prompt], custom_prompt)}

      {:error, :missing_custom_prompt_file} ->
        Puts.on_new_line("No custom prompt file found, using default...", :magenta)
        {0, put_in(server_state, [:elixir, :claude_prompt], default_prompt())}

      {:error, :no_home_env_var} ->
        Puts.on_new_line(
          "I can't check if you've got a custom prompt, because $HOME doesn't exist... sort your system out to have $HOME, then try again?",
          :red
        )

        {1, server_state}
    end
  end

  def default_prompt do
    """
    <buffer>
      <name>
        Elixir Code
      </name>
      <filePath>
        $LIB_PATH_PLACEHOLDER
      </filePath>
      <content>
        $LIB_CONTENT_PLACEHOLDER
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Test
      </name>
      <filePath>
        $TEST_PATH_PLACEHOLDER
      </filePath>
      <content>
        $TEST_CONTENT_PLACEHOLDER
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Mix Test Output
      </name>
      <content>
        $MIX_TEST_OUTPUT_PLACEHOLDER
      </content>
    </buffer>

    *****

    Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide a diff, which when applied to the file containing the Elixir Code, will fix the test?

    """
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

  def build_api_request(
        %{
          files: %{lib: lib, test: test},
          elixir: %{mix_test_output: mix_test_output, claude_prompt: claude_prompt},
          env_vars: %{"ANTHROPIC_API_KEY" => claude_api_key}
        } = server_state
      )
      when not is_nil(mix_test_output) and not is_nil(lib) and not is_nil(test) and
             not is_nil(claude_api_key) do
    request = build_api_request(lib, test, mix_test_output, claude_prompt, claude_api_key)
    {0, put_in(server_state, [:elixir, :claude_api_request], request)}
  end

  def build_api_request(server_state) do
    {1, server_state}
  end

  def parse_api_response(
        %{elixir: %{claude_api_response: {:ok, %Response{status_code: 200, body: body}}}} =
          server_state
      ) do
    case Jason.decode(body) do
      {:ok, %{"content" => [%{"text" => text} | _]}} ->
        {0, put_in(server_state, [:elixir, :claude_api_response], {:ok, {:parsed, text}})}

      _ ->
        result =
          {:error,
           {:parsed,
            """
            I failed to decode the Claude API HTTP 200 response :-(
            It was:

            #{body}
            """}}

        {1, put_in(server_state, [:elixir, :claude_api_response], result)}
    end
  end

  def parse_api_response(%{elixir: %{claude_api_response: response}} = server_state) do
    result =
      {:error,
       {:parsed,
        """
        Claude API did not return a HTTP 200 response :-(
        It was:

        #{inspect(response)}
        """}}

    {1, put_in(server_state, [:elixir, :claude_api_response], result)}
  end

  def parse_api_response(server_state) do
    {1,
     put_in(
       server_state,
       [:elixir, :claude_api_response],
       {:error, {:parsed, "I have no Claude API response in my memory..."}}
     )}
  end

  # https://docs.anthropic.com/en/api/messages-examples
  # https://github.com/lebrunel/anthropix - use this instead?
  defp build_api_request(lib, test, mix_test_output, prompt, claude_api_key) do
    %Request{
      method: :post,
      url: "https://api.anthropic.com/v1/messages",
      headers: [
        {"x-api-key", claude_api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ],
      body:
        Jason.encode!(%{
          max_tokens: 2048,
          model: "claude-3-5-sonnet-20240620",
          messages: [%{role: "user", content: api_content(lib, test, prompt, mix_test_output)}]
        }),
      options: [recv_timeout: 30_000]
    }
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

  defp cannot_determine_lib_path_from_test_path(test_path) do
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
             You saved this test file, but I can't figure out what it's equivalent lib file is

               #{test_path}

             Hmmmmm...

             """},
          next_action: :exit
        }
      }
    }
  end
end
