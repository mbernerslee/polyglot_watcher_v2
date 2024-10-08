defmodule PolyglotWatcherV2.ClaudeAITest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{ClaudeAI, Puts, ServerStateBuilder}
  alias HTTPoison.{Request, Response}

  describe "build_api_request/2" do
    test "given some server state containing an ANTHROPIC_API_KEY env var and list of messages, returns new server state with the API request inside it" do
      api_key = "super-secret"
      messages = [%{role: "user", content: "tell me a joke"}]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_api_key(api_key)

      assert {0, new_server_state} = ClaudeAI.build_api_request(server_state, messages)

      expected_request = %Request{
        method: :post,
        url: "https://api.anthropic.com/v1/messages",
        headers: [
          {"x-api-key", api_key},
          {"anthropic-version", "2023-06-01"},
          {"content-type", "application/json"}
        ],
        body:
          ~s|{"messages":[{"role":"user","content":"tell me a joke"}],"max_tokens":2048,"model":"claude-3-5-sonnet-20240620"}|,
        options: [recv_timeout: 180_000]
      }

      assert put_in(server_state, [:claude_ai, :request], expected_request) ==
               new_server_state
    end

    test "given a server state with a the API key missing, return the original server state and an error" do
      server_state = ServerStateBuilder.build()

      assert {1, server_state} == ClaudeAI.build_api_request(server_state, [])
    end

    test "given a server state with a the API key of nil, return the original server state and an error" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_api_key(nil)

      assert {1, server_state} == ClaudeAI.build_api_request(server_state, [])
    end
  end

  describe "handle_api_response/2" do
    test "given some server state containing a happy api response, put the parsed response into the server state and onto the screen" do
      response_text = "some text"
      body = Jason.encode!(%{"content" => [%{"text" => response_text}]})

      response = {:ok, %Response{status_code: 200, body: body}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      Mimic.expect(Puts, :on_new_line_unstyled, fn msg ->
        assert msg == response_text
      end)

      assert {0, new_server_state} = ClaudeAI.handle_api_response(server_state)

      parsed = {:ok, {:parsed, response_text}}

      assert put_in(server_state, [:claude_ai, :response], parsed) ==
               new_server_state
    end

    test "given some server state containing a sad api response with an unparsable HTTP 200 body, put the parsed response into the server state" do
      body = Jason.encode!(%{"nope" => [%{"sad" => "times"}]})

      response = {:ok, %Response{status_code: 200, body: body}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      Mimic.expect(Puts, :on_new_line, fn msg, _style ->
        assert msg == """
               I failed to decode the Claude API HTTP 200 response :-(
               It was:

               #{body}
               """
      end)

      assert {1, new_server_state} = ClaudeAI.handle_api_response(server_state)

      parsed =
        {:error,
         {:parsed,
          """
          I failed to decode the Claude API HTTP 200 response :-(
          It was:

          #{body}
          """}}

      assert put_in(server_state, [:claude_ai, :response], parsed) ==
               new_server_state
    end

    test "given some server state containing a sad api response with a non HTTP 200 response, put the parsed response into the server state" do
      body = Jason.encode!(%{"its" => "wrecked"})

      response = %Response{status_code: 500, body: body}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      Mimic.expect(Puts, :on_new_line, fn msg, _style ->
        assert msg == """
               Claude API did not return a HTTP 200 response :-(
               It was:

               #{inspect(response)}
               """
      end)

      assert {1, new_server_state} = ClaudeAI.handle_api_response(server_state)

      parsed =
        {:error,
         {:parsed,
          """
          Claude API did not return a HTTP 200 response :-(
          It was:

          #{inspect(response)}
          """}}

      assert put_in(server_state, [:claude_ai, :response], parsed) ==
               new_server_state
    end

    test "given some server state NOT containing a response whatsoever, return an error" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Puts, :on_new_line, fn msg, _style ->
        assert msg == "I have no Claude API response in my memory..."
      end)

      assert {1, new_server_state} = ClaudeAI.handle_api_response(server_state)

      parsed = {:error, {:parsed, "I have no Claude API response in my memory..."}}

      assert put_in(server_state, [:claude_ai, :response], parsed) ==
               new_server_state
    end
  end
end
