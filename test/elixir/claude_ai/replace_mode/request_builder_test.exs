defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.RequestBuilderTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.ServerStateBuilder
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.RequestBuilder

  describe "build/2" do
    test "given server_state that contains the required info to build the API call, then it is built and stored in the server_state" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      assert {0, new_server_state} =
               RequestBuilder.build("test/cool_test.exs", server_state)

      assert %{claude_ai: %{request: api_request}} = new_server_state

      assert put_in(server_state, [:claude_ai, :request], api_request) == new_server_state

      assert %{body: body} = api_request

      assert %{
               "messages" => [%{"role" => "user", "content" => prompt}]
             } = Jason.decode!(body)

      assert prompt =~ "lib/cool.ex"
      assert prompt =~ "cool lib"
      assert prompt =~ "test/cool_test.exs"
      assert prompt =~ "cool test"
      assert prompt =~ mix_test_output
    end

    test "when the cache returns an error of any kind, return error" do
      api_key = "super-secret"

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"
        {:error, :not_found}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      assert {1, server_state} ==
               RequestBuilder.build("test/cool_test.exs", server_state)
    end

    test "prompt placeholders get populated" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      expected_prompt_start =
        """
        <buffer>
          <name>
            Elixir Code
          </name>
          <filePath>
            lib/cool.ex
          </filePath>
          <content>
            cool lib
          </content>
        </buffer>

        <buffer>
          <name>
            Elixir Test
          </name>
          <filePath>
            test/cool_test.exs
          </filePath>
          <content>
            cool test
          </content>
        </buffer>

        <buffer>
          <name>
            Elixir Mix Test Output
          </name>
          <content>
            it failed mate. get good.
          </content>
        </buffer>
        """

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      {0, new_server_state} = RequestBuilder.build("test/cool_test.exs", server_state)

      %{claude_ai: %{request: api_request}} = new_server_state

      %{body: body} = api_request

      assert %{
               "messages" => [%{"role" => "user", "content" => actual_prompt}]
             } = Jason.decode!(body)

      assert String.starts_with?(actual_prompt, expected_prompt_start)
    end

    test "given server_state that is missing any of the required info to build the API call, then we return exit_code 1 and leave the server_state unchanged" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", nil)

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"

        {:ok, %{test: test_file, lib: lib_file, mix_test_output: mix_test_output}}
      end)

      assert {1, server_state} ==
               RequestBuilder.build("test/cool_test.exs", server_state)
    end
  end
end
