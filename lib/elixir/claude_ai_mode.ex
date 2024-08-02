defmodule PolyglotWatcherV2.Elixir.ClaudeAIMode do
  alias PolyglotWatcherV2.{Action, FilePath}
  alias PolyglotWatcherV2.Elixir.Determiner
  alias HTTPoison.Request

  @ex Determiner.ex()
  @exs Determiner.exs()

  # TODO if we have the neccessary info to immediately call claude -> then just do it???
  # TODO OR do the full "make calling claude a 1 off, rather than (or in addition to) a mode switch thing... so persist lib & test files all the time by default? (gulp)"
  # TODO test it
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
           runnable: {:switch_mode, :elixir, {:claude_ai, %{messages: [], files: %{}}}},
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

  # TODO deal with the lots of duplication with elixir default
  # TODO test this properly
  # TODO move the determine equivalent path stuff to its own place & test it.

  def determine_actions(%FilePath{extension: @exs} = test_path, server_state) do
    test_path_string = FilePath.stringify(test_path)

    case determine_equivalent_lib_path(test_path) do
      {:ok, lib_path} ->
        determine_actions(lib_path, test_path_string, server_state)

      :error ->
        {cannot_determine_lib_path_from_test_path(test_path_string), server_state}
    end
  end

  def determine_actions(%FilePath{extension: @ex} = lib_path, server_state) do
    lib_path_string = FilePath.stringify(lib_path)

    case determine_equivalent_test_path(lib_path) do
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
           next_action: :persist_lib_file
         },
         persist_lib_file: %Action{
           runnable: {:persist_file, lib_path, :lib},
           next_action: %{0 => :persist_test_file, :fallback => :missing_file_msg}
         },
         persist_test_file: %Action{
           runnable: {:persist_file, test_path, :test},
           next_action: %{
             0 => :build_claude_api_request,
             :fallback => :fallback_placeholder_error
           }
         },
         build_claude_api_request: %Action{
           runnable: :build_claude_api_request,
           next_action: %{
             0 => :perform_claude_api_request,
             :fallback => :fallback_placeholder_error
           }
         },
         perform_claude_api_request: %Action{
           runnable: :perform_claude_api_request,
           next_action: %{0 => :put_claude_api_response, :fallback => :fallback_placeholder_error}
         },
         put_claude_api_response: %Action{
           runnable: :put_claude_api_response,
           next_action: %{0 => :find_claude_api_diff, :fallback => :fallback_placeholder_error}
         },
         find_claude_api_diff: %Action{
           runnable: :find_claude_api_diff,
           next_action: %{
             0 => :write_claude_api_diff_to_file,
             :fallback => :fallback_placeholder_error
           }
         },
         write_claude_api_diff_to_file: %Action{
           runnable: :write_claude_api_diff_to_file,
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
              Clause fallback error
              Oh no!
              """},
           next_action: :put_failure_msg
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end

  def build_api_request(
        %{
          files: %{lib: lib, test: test},
          elixir: %{mix_test_output: mix_test_output},
          env_vars: %{"ANTHROPIC_API_KEY" => claude_api_key}
        } = server_state
      )
      when not is_nil(mix_test_output) and not is_nil(lib) and not is_nil(test) and
             not is_nil(claude_api_key) do
    request = build_api_request(lib, test, mix_test_output, claude_api_key)
    {0, put_in(server_state, [:elixir, :claude_api_request], request)}
  end

  def build_api_request(server_state) do
    {1, server_state}
  end

  # https://docs.anthropic.com/en/api/messages-examples
  # https://github.com/lebrunel/anthropix - use this instead?
  defp build_api_request(lib, test, mix_test_output, claude_api_key) do
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
          messages: [%{role: "user", content: api_content(lib, test, mix_test_output)}]
        }),
      options: [recv_timeout: 30_000]
    }
  end

  def find_diff(response_text) do
    response_text
    |> String.split("\n")
    |> Enum.reduce_while(nil, fn
      "```diff", nil ->
        {:cont, []}

      _line, nil ->
        {:cont, nil}

      "```", [_ | _] = acc ->
        {:halt, acc}

      line, acc when is_list(acc) ->
        {:cont, [line | acc]}
    end)
    |> case do
      nil -> {:error, :no_diff}
      diff -> {:ok, (diff |> Enum.reverse() |> Enum.join("\n")) <> "\n"}
    end
  end

  defp api_content(lib, test, mix_test_output) do
    """
    <buffer>
      <name>
        Elixir Code
      </name>
      <filePath>
        #{lib.path}
      </filePath>
      <content>
        #{lib.contents}
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Test
      </name>
      <filePath>
        #{test.path}
      </filePath>
      <content>
        #{test.contents}
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Mix Test Output
      </name>
      <content>
      #{mix_test_output}
      </content>
    </buffer>

    *****

    Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide a diff, which when applied to the file containing the Elixir Code, will fix the test?

    """
  end

  ####################
  ####################
  ## previous prompt generations

  # Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide some replacement Elixir Code that would make the tests pass?

  # Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide some replacement Elixir Code that would make the tests pass? I would like the entire replacement Elixir module returned, including any unchanged code.

  # Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide a diff, which when applied to the file containing the Elixir Code, will fix the test?

  defp determine_equivalent_lib_path(%FilePath{path: path, extension: @exs}) do
    equivalent_path_finder(path, "test", "lib", ".#{@ex}")
  end

  defp determine_equivalent_test_path(%FilePath{path: path, extension: @ex}) do
    equivalent_path_finder(path, "lib", "test", "_test.#{@exs}")
  end

  defp equivalent_path_finder(path, prefix, replacement_prefix, extension) do
    case String.split(path, prefix <> "/") do
      ["", middle_bit_of_file_path] ->
        {:ok, replacement_prefix <> "/" <> middle_bit_of_file_path <> extension}

      _ ->
        :error
    end
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
