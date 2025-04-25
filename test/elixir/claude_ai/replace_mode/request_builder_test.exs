defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.RequestBuilderTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.ServerStateBuilder
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.RequestBuilder

  describe "build/2" do
    test "given server_state that contains the required info to build the API call, then it is built and stored in the server_state" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      assert {0, new_server_state} =
               RequestBuilder.build(server_state)

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
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      {0, new_server_state} = RequestBuilder.build(server_state)

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
      api_key = "super-secret"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)

      assert {0, _} = RequestBuilder.build(server_state)

      bad_server_states = [
        ServerStateBuilder.with_file(server_state, :lib, nil),
        ServerStateBuilder.with_file(server_state, :test, nil),
        ServerStateBuilder.with_mix_test_output(server_state, nil),
        ServerStateBuilder.with_env_var(server_state, "ANTHROPIC_API_KEY", nil)
      ]

      Enum.each(bad_server_states, fn bad_server_state ->
        assert {1, bad_server_state} ==
                 RequestBuilder.build(bad_server_state)
      end)
    end
  end
end
