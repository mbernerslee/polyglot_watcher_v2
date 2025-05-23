defmodule PolyglotWatcherV2.Elixir.AI.ReplaceMode.APICallTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.Config
  alias PolyglotWatcherV2.ServerStateBuilder
  alias PolyglotWatcherV2.SystemWrapper
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.FilePatch
  alias PolyglotWatcherV2.Patch
  alias PolyglotWatcherV2.Elixir.AI.ReplaceMode.APICall
  alias PolyglotWatcherV2.InstructorLiteWrapper
  alias PolyglotWatcherV2.InstructorLiteSchemas.{CodeFileUpdate, CodeFileUpdates}

  describe "perform/2" do
    test "given a test path that's in the cache & the correct api key env var in the server_state, we fire the API call with InstructorLite with the expected args" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents OLD TEST"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents OLD LIB"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: FakeAdaperModule,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == test_path

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      # TODO model is ignored. do sth with it
      # TODO consider how to check args are compatible
      # TODO create separate ticket - to split this up, and have it work like default mode does with the split actions
      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, opts ->
        assert FakeAdaperModule == opts[:adapter]

        {:ok,
         %CodeFileUpdates{
           updates: [
             %CodeFileUpdate{
               file_path: lib_path,
               explanation: "some lib code was awful",
               search: "OLD LIB",
               replace: "NEW LIB"
             },
             %CodeFileUpdate{
               file_path: test_path,
               explanation: "some test code was awful",
               search: "OLD TEST",
               replace: "NEW TEST"
             }
           ]
         }}
      end)

      Mimic.expect(SystemWrapper, :cmd, 1, fn "git", _ ->
        std_out =
          """
          diff --git a/x_test_old b/x_test_new
          index 5bc7af9..bd4fc95 100644
          --- a/x_test_old
          +++ b/x_test_new
          @@ -1 +1 @@
          -test contents OLD TEST
          +test contents NEW TEST
          """

        {std_out, 1}
      end)

      Mimic.expect(SystemWrapper, :cmd, 1, fn "git", _ ->
        std_out =
          """
          diff --git a/x_lib_old b/x_lib_new
          index 102dcaf..818aacb 100644
          --- a/x_lib_old
          +++ b/x_lib_new
          @@ -1 +1 @@
          -lib contents OLD LIB
          +lib contents NEW LIB
          """

        {std_out, 1}
      end)

      Mimic.expect(Puts, :on_new_line, 1, fn
        [
          {[:magenta], "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄\n"},
          {[:magenta], "██████████████████ AI Response ██████████████████\n"},
          {[:magenta], "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"}
        ] ->
          :ok
      end)

      Mimic.expect(Puts, :on_new_line, 1, fn
        [
          {[], "lib/a.ex\n"},
          {[],
           "────────────────────────\n1) Line: 1\n────────────────────────\n-test contents OLD TEST\n+test contents NEW TEST\n────────────────────────\n"},
          {[], "some lib code was awful"},
          {[], "\n────────────────────────\n"}
        ] ->
          :ok
      end)

      Mimic.expect(Puts, :on_new_line, 1, fn
        [
          {[], "test/a_test.exs\n"},
          {[],
           "────────────────────────\n2) Line: 1\n────────────────────────\n-lib contents OLD LIB\n+lib contents NEW LIB\n────────────────────────\n"},
          {[], "some test code was awful"},
          {[], "\n────────────────────────\n"}
        ] ->
          :ok
      end)

      Mimic.expect(Puts, :on_new_line, 1, fn
        [
          {[:magenta], "█████████████████████████████████████████████████\n"}
        ] ->
          :ok
      end)

      assert {0, new_server_state} = APICall.perform(test_path, server_state)

      assert %{
               ai_state: %{
                 phase: :waiting
               },
               file_patches: file_patches,
               ignore_file_changes: true
             } = new_server_state

      assert [
               {lib_path,
                %FilePatch{
                  patches: [
                    %Patch{
                      search: "OLD LIB",
                      replace: "NEW LIB",
                      explanation: "some lib code was awful",
                      index: 1
                    }
                  ],
                  contents: lib_contents
                }},
               {test_path,
                %FilePatch{
                  patches: [
                    %Patch{
                      search: "OLD TEST",
                      replace: "NEW TEST",
                      explanation: "some test code was awful",
                      index: 2
                    }
                  ],
                  contents: test_contents
                }}
             ] == file_patches
    end

    test "when the API key isn't in the env vars, return error" do
      test_path = "test/non_existent_test.exs"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      action_error =
        "I failed I couldn't find the \"API_KEY_NAME\" env var in my memory. This shouldn't happen and is a bug in my code :-("

      assert new_server_state.action_error == action_error
      assert %{server_state | action_error: action_error} == new_server_state
    end

    test "when reading the cache returns error, return error" do
      test_path = "test/non_existent_test.exs"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "API_KEY")
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:error, :not_found}
      end)

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      action_error = "I failed because my cache did not contain the file #{test_path} :-("

      assert new_server_state.action_error == action_error
      assert %{server_state | action_error: action_error} == new_server_state
    end

    test "when instructor returns an error, put descriptive action_error" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:error, :some_error}
      end)

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      expected_error = "Error from InstructorLite: :some_error"

      assert new_server_state.action_error == expected_error
      assert %{server_state | action_error: expected_error} == new_server_state
    end

    test "when the instructor returns an \"unexpected response\", handle it" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:error, :unexpected_response,
         %{
           "content" => [
             %{
               "id" => "toolu_01Xr1pWys26BrBjNhJdTiRX6",
               "input" => %{},
               "name" => "Schema",
               "type" => "tool_use"
             }
           ],
           "id" => "msg_011WzhD5hWiCXaz7GFzdFc4Y",
           "model" => "claude-3-5-sonnet-20240620",
           "role" => "assistant",
           "stop_reason" => "max_tokens",
           "stop_sequence" => nil,
           "type" => "message",
           "usage" => %{
             "cache_creation_input_tokens" => 0,
             "cache_read_input_tokens" => 0,
             "input_tokens" => 2193,
             "output_tokens" => 1024
           }
         }}
      end)

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      expected_error =
        "Error from InstructorLite: {:unexpected_response, %{\"content\" => [%{\"id\" => \"toolu_01Xr1pWys26BrBjNhJdTiRX6\", \"input\" => %{}, \"name\" => \"Schema\", \"type\" => \"tool_use\"}], \"id\" => \"msg_011WzhD5hWiCXaz7GFzdFc4Y\", \"model\" => \"claude-3-5-sonnet-20240620\", \"role\" => \"assistant\", \"stop_reason\" => \"max_tokens\", \"stop_sequence\" => nil, \"type\" => \"message\", \"usage\" => %{\"cache_creation_input_tokens\" => 0, \"cache_read_input_tokens\" => 0, \"input_tokens\" => 2193, \"output_tokens\" => 1024}}}"

      assert new_server_state.action_error == expected_error
      assert %{server_state | action_error: expected_error} == new_server_state
    end

    test "when the instructor returns any arbitrary 3 element error tuple, handle it" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:error, :any_arbitrary_atom, %{"arbitrary" => "contents"}}
      end)

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      expected_error =
        "Error from InstructorLite: {:any_arbitrary_atom, %{\"arbitrary\" => \"contents\"}}"

      assert new_server_state.action_error == expected_error
      assert %{server_state | action_error: expected_error} == new_server_state
    end

    test "when InstructorLite suggests we update neither the lib nor test file return an error" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:ok, %CodeFileUpdates{updates: []}}
      end)

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      expected_error = "InstructorLite: suggested no changes"
      assert new_server_state.action_error == expected_error
      assert %{server_state | action_error: expected_error} == new_server_state
    end

    test "when InstructorLite suggests we update a file which is neither the lib nor test file, return an error" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents"
      lib_path = "lib/a.ex"
      lib_contents = "lib contents"
      mix_test_output = "mix test output"
      other_file_path = "invalid/file/path.ex"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:ok,
         %CodeFileUpdates{
           updates: [
             %CodeFileUpdate{
               file_path: other_file_path,
               explanation: "Update to invalid file",
               search: "old content",
               replace: "new content"
             }
           ]
         }}
      end)

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      expected_error = "InstructorLite: suggested we update some other file"

      assert new_server_state.action_error == expected_error
      assert %{server_state | action_error: expected_error} == new_server_state
    end

    test "when multiple updates are suggested for the same file, we return them ordered properly" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents"
      lib_path = "lib/a.ex"
      lib_contents = "old content 1\nold content 2"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:ok,
         %CodeFileUpdates{
           updates: [
             %CodeFileUpdate{
               file_path: lib_path,
               explanation: "Update 1",
               search: "old content 1",
               replace: "new content 1"
             },
             %CodeFileUpdate{
               file_path: lib_path,
               explanation: "Update 2",
               search: "old content 2",
               replace: "new content 2"
             }
           ]
         }}
      end)

      Mimic.expect(SystemWrapper, :cmd, 2, fn
        "git",
        [
          _,
          _,
          _,
          "/tmp/polyglot_watcher_v2_old_lib_a_ex_1",
          "/tmp/polyglot_watcher_v2_new_lib_a_ex_1"
        ] ->
          std_out =
            """
            diff --git a/x_lib_old b/x_lib_new
            index 102dcaf..818aacb 100644
            --- a/x_lib_old
            +++ b/x_lib_new
            @@ -1,2 +1,2 @@
            -old content 1
            +new content 1
            """

          {std_out, 1}

        "git",
        [
          _,
          _,
          _,
          "/tmp/polyglot_watcher_v2_old_lib_a_ex_2",
          "/tmp/polyglot_watcher_v2_new_lib_a_ex_2"
        ] ->
          std_out =
            """
            diff --git a/x_lib_old b/x_lib_new
            index 102dcaf..818aacb 100644
            --- a/x_lib_old
            +++ b/x_lib_new
            @@ -1,2 +1,2 @@
            -old content 2
            +new content 2
            """

          {std_out, 1}
      end)

      Mimic.expect(Puts, :on_new_line, 4, fn _ -> :ok end)

      assert {0, new_server_state} = APICall.perform(test_path, server_state)

      assert %{file_patches: file_patches} = new_server_state

      assert [
               {
                 lib_path,
                 %FilePatch{
                   patches: [
                     %Patch{
                       search: "old content 1",
                       replace: "new content 1",
                       explanation: "Update 1",
                       index: 1
                     },
                     %Patch{
                       search: "old content 2",
                       replace: "new content 2",
                       explanation: "Update 2",
                       index: 2
                     }
                   ],
                   contents: lib_contents
                 }
               }
             ] == file_patches
    end

    test "when returns something we can't parse errors, we put an action_error" do
      api_key = "secret API key"
      test_path = "test/a_test.exs"
      test_contents = "test contents"
      lib_path = "lib/a.ex"
      lib_contents = "old content"
      mix_test_output = "mix test output"

      test_file = %{path: test_path, contents: test_contents}
      lib_file = %{path: lib_path, contents: lib_contents}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_mode(:ai_replace)
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", api_key)
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: nil,
          api_key_env_var_name: "API_KEY_NAME"
        })

      Mimic.expect(Cache, :get_files, fn ^test_path ->
        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:ok,
         %CodeFileUpdates{
           updates: [
             %CodeFileUpdate{
               file_path: lib_path,
               explanation: "Update",
               search: "old content",
               replace: "new content"
             }
           ]
         }}
      end)

      Mimic.expect(SystemWrapper, :cmd, fn "git", _ ->
        {"im blowing up", 1}
      end)

      assert {1, new_server_state} = APICall.perform(test_path, server_state)

      expected_error = "Git Diff error: :git_diff_parsing_error"
      assert new_server_state.action_error == expected_error
      assert %{server_state | action_error: expected_error} == new_server_state
    end
  end
end
