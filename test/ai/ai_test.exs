defmodule PolyglotWatcherV2.AITest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{
    AI,
    Config,
    InstructorLiteWrapper,
    Puts,
    ServerStateBuilder
  }

  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.InstructorLiteWrapper
  alias PolyglotWatcherV2.InstructorLiteSchemas.{CodeFileUpdate, CodeFileUpdates}

  describe "reload_prompt/2" do
    test "given a prompt name & server_state, reloads the prompt from file" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(
        FileWrapper,
        :expand_path,
        1,
        fn "~/.config/polyglot_watcher_v2/prompts/replace" ->
          "/home/el_dude/.config/polyglot_watcher_v2/prompts/replace"
        end
      )

      Mimic.expect(
        FileWrapper,
        :read,
        1,
        fn "/home/el_dude/.config/polyglot_watcher_v2/prompts/replace" ->
          {:ok, "prompt contents"}
        end
      )

      assert {0, %{server_state | ai_prompts: %{replace: "prompt contents"}}} ==
               AI.reload_prompt(:replace, server_state)
    end

    test "when the prompt file does not exist (or there's any other error reading it) then put an action error" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(
        FileWrapper,
        :expand_path,
        1,
        fn "~/.config/polyglot_watcher_v2/prompts/replace" ->
          "/home/el_dude/.config/polyglot_watcher_v2/prompts/replace"
        end
      )

      Mimic.expect(FileWrapper, :read, 1, fn _ -> {:error, :arbitrary_error} end)

      action_error =
        """
        I failed to read an AI prompt from
          ~/.config/polyglot_watcher_v2/prompts/replace

        The error was :arbitrary_error

        Please ensure the file exists and is readable.
        You should have a backup in the prompts directory if you need it.
        """

      assert {1, %{server_state | action_error: action_error}} ==
               AI.reload_prompt(:replace, server_state)
    end
  end

  describe "build_api_request/3" do
    test "works with replace when all required data is known" do
      test_path = "test/a_test.exs"
      test_contents = "test contents OLD TEST"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents OLD LIB"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == test_path

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_prompt(:replace, "replace prompt")
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")

      expected_ai_state = %{
        replace: %{
          request: %{
            params: %{messages: [%{role: "user", content: "replace prompt"}]},
            opts: [
              response_model: CodeFileUpdates,
              adapter: InstructorLite.Adapters.Anthropic,
              adapter_context: [api_key: "COOL_API_KEY"]
            ]
          }
        }
      }

      assert {0, %{server_state | ai_state: expected_ai_state}} ==
               AI.build_api_request(:replace, test_path, server_state)
    end

    test "when the cache does not have the test path, return an action_error" do
      test_path = "test/a_test.exs"

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:error, :not_found}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_prompt(:replace, "replace prompt")
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")

      assert {1, new_server_state} = AI.build_api_request(:replace, test_path, server_state)

      expected_action_error =
        """
        I tried to build an AI API request for the failing test
          test/a_test.exs

        ...but I have no such failing test in my memory.
        This shouldn't happen and is a bug in my code sadly :-(
        """

      assert expected_action_error == new_server_state.action_error

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end

    test "when the api key is not in the server_state env vars, return an action_error" do
      test_path = "test/a_test.exs"
      test_contents = "test contents OLD TEST"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents OLD LIB"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == test_path

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_prompt(:replace, "replace prompt")
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })

      assert {1, new_server_state} = AI.build_api_request(:replace, test_path, server_state)

      expected_action_error =
        """
        I tried to build an AI API request for Anthropic

        ...but I haven't loaded the API_KEY_NAME API key
        from the environment variable of the same name

        This shouldn't happen and is a bug in my code sadly :-(
        """

      assert expected_action_error == new_server_state.action_error

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end

    test "when the given api request name is unknown, so does not have a model, return an action_error" do
      test_path = "test/a_test.exs"
      test_contents = "test contents OLD TEST"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents OLD LIB"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_prompt(:replace, "replace prompt")
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")

      assert {1, new_server_state} = AI.build_api_request(:nonsense, test_path, server_state)

      expected_action_error =
        """
        I tried to build an AI API request of the type nonsense

        ...but that's not a recognised type.
        This shouldn't happen and is a bug in my code sadly :-(
        """

      assert expected_action_error == new_server_state.action_error

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end

    test "when there is no prompt for the given name in the ai_prompts, return action_error" do
      test_path = "test/a_test.exs"
      test_contents = "test contents OLD TEST"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents OLD LIB"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == test_path

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")

      assert {1, new_server_state} = AI.build_api_request(:replace, test_path, server_state)

      expected_action_error =
        """
        I tried to build an AI API request of the type replace

        ...but I haven't loaded a prompt for this type.
        This shouldn't happen and is a bug in my code sadly :-(
        """

      assert expected_action_error == new_server_state.action_error

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end
  end

  describe "perform_api_request/2" do
    test "given an API name (e.g. replace) and a request in memory, we make it with InstructorLite" do
      params = %{messages: [%{role: "user", content: "replace prompt"}]}

      opts =
        [
          response_model: CodeFileUpdates,
          adapter: InstructorLite.Adapters.Anthropic,
          adapter_context: [api_key: "COOL_API_KEY"]
        ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_state_request(:replace, params, opts)

      response =
        {:ok,
         %CodeFileUpdates{
           updates: [
             %CodeFileUpdate{
               file_path: "lib_path",
               explanation: "some lib code was awful",
               search: "OLD LIB",
               replace: "NEW LIB"
             },
             %CodeFileUpdate{
               file_path: "test_path",
               explanation: "some test code was awful",
               search: "OLD TEST",
               replace: "NEW TEST"
             }
           ]
         }}

      Mimic.expect(Puts, :on_new_line, 1, fn msg ->
        assert msg == "Waiting for Anthropic API call response..."
        :ok
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn ^params, ^opts ->
        response
      end)

      assert {0, new_server_state} = AI.perform_api_request(:replace, server_state)

      expected_ai_state = %{replace: %{response: response}}
      assert expected_ai_state == new_server_state.ai_state

      assert %{server_state | ai_state: expected_ai_state} == new_server_state
    end

    test "when the request is not in the server_state, put an action_error" do
      server_state = ServerStateBuilder.build()

      assert {1, new_server_state} = AI.perform_api_request(:replace, server_state)

      expected_action_error =
        """
        I tried to perform an AI API call

        ...but I have no API request in my memory
        This shouldn't happen and is a bug in my code sadly :-(
        """

      assert expected_action_error == new_server_state.action_error

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end

    test "even when InstructorLite returns an error, put it in the state" do
      params = %{messages: [%{role: "user", content: "replace prompt"}]}

      opts =
        [
          response_model: CodeFileUpdates,
          adapter: InstructorLite.Adapters.Anthropic,
          adapter_context: [api_key: "COOL_API_KEY"]
        ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_state_request(:replace, params, opts)

      response = {:error, :arbitrary_error}

      Mimic.expect(Puts, :on_new_line, 1, fn msg ->
        assert msg == "Waiting for Anthropic API call response..."
        :ok
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn ^params, ^opts ->
        response
      end)

      assert {0, new_server_state} = AI.perform_api_request(:replace, server_state)

      expected_ai_state = %{replace: %{response: response}}
      assert expected_ai_state == new_server_state.ai_state

      assert %{server_state | ai_state: expected_ai_state} == new_server_state
    end
  end
end
