defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICallTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.ServerStateBuilder
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICall
  alias PolyglotWatcherV2.InstructorLiteWrapper
  alias PolyglotWatcherV2.InstructorLiteSchemas.{CodeFileUpdate, CodeFileUpdates}

  describe "perform/2" do
    test "given a test path that's in the cache & an ANTHROPIC_API_KEY in the server_state, we fire the API call with InstructorLite with the expected args" do
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
        |> ServerStateBuilder.with_elixir_mode(:claude_ai_replace)
        |> ServerStateBuilder.with_claude_api_key(api_key)

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == test_path

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        {:ok,
         %CodeFileUpdates{
           updates: [
             %CodeFileUpdate{
               file_path: lib_path,
               explanation: "some code was awful",
               search: "the bad code",
               replace: "better code"
             }
           ]
         }}
      end)

      assert {0, new_server_state} = APICall.perform(test_path, server_state)
    end
  end
end
