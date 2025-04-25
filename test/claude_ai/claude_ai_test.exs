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

  describe "perform_api_call/2" do
    test "when there's a request in memory under [:claude_ai, :request] in the server state, then perform the HTTP request" do
      request = %Request{url: "http://example.com"}
      response = {:ok, %Response{}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_request(request)

      Mimic.expect(HTTPoison, :request, fn this_request ->
        assert request == this_request
        response
      end)

      assert {0, new_server_state} = ClaudeAI.perform_api_call(server_state)

      assert new_server_state == put_in(server_state, [:claude_ai, :response], response)
    end

    test "when there's no request in memory under [:claude_ai, :request] in the server state, then return an action_error in the server_state" do
      server_state = ServerStateBuilder.build()

      Mimic.reject(&HTTPoison.request/1)

      assert {1, new_server_state} = ClaudeAI.perform_api_call(server_state)

      expected_action_error =
        """
        I was asked to perform an API call to ClaudeAI, but I don't have a request in my memory.

        This is a bug! I should never be called in this state!
        """

      assert new_server_state == %{server_state | action_error: expected_action_error}
    end
  end

  describe "parse_claude_api_response/2" do
    test "given some server state containing a happy api response, put the parsed response into the server state and onto the screen" do
      response_text = "some text"
      body = Jason.encode!(%{"content" => [%{"text" => response_text}]})

      response = {:ok, %Response{status_code: 200, body: body}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {0, new_server_state} = ClaudeAI.parse_claude_api_response(server_state)

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

      assert {1, new_server_state} = ClaudeAI.parse_claude_api_response(server_state)

      expected_action_error =
        """
        I failed to decode the Claude API HTTP 200 response :-(
        It was:

        #{body}
        """

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end

    test "given some server state containing a sad api response with a non HTTP 200 response, put the parsed response into the server state" do
      body = Jason.encode!(%{"its" => "wrecked"})

      response = %Response{status_code: 500, body: body}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(response)

      assert {1, new_server_state} = ClaudeAI.parse_claude_api_response(server_state)

      expected_action_error =
        """
        Claude API did not return a HTTP 200 response :-(
        It was:

        #{inspect(response)}
        """

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end

    test "given some server state NOT containing a response whatsoever, return an error" do
      server_state = ServerStateBuilder.build()

      assert {1, new_server_state} = ClaudeAI.parse_claude_api_response(server_state)

      expected_action_error =
        """
        I was asked to parse a Claude API response, but I don't have one in my memory.

        This should never happen and is a bug in the code most likely :-(
        """

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end
  end

  describe "put_parsed_response/1" do
    test "given a parsed error response, put it on the screen" do
      error_msg = "something's badly wrong"
      error = {:error, {:parsed, error_msg}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(error)

      Mimic.expect(Puts, :on_new_line, fn msg, _style ->
        assert msg == error_msg
      end)

      assert {1, server_state} == ClaudeAI.put_parsed_response(server_state)
    end

    test "given a parsed ok response, put it on the screen" do
      parsed_content = "it's all good"
      ok_response = {:ok, {:parsed, parsed_content}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(ok_response)

      Mimic.expect(Puts, :on_new_line_unstyled, fn msg ->
        assert msg == parsed_content
      end)

      assert {0, server_state} == ClaudeAI.put_parsed_response(server_state)
    end

    test "given an unparsed response, put an error on the screen" do
      unparsed_response = {:ok, %HTTPoison.Response{status_code: 200, body: "nope"}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_claude_ai_response(unparsed_response)

      Mimic.expect(Puts, :on_new_line, fn msg, _ ->
        assert msg ==
                 """
                   I was asked to put a Claude AI parsed response on the screen, but I don't have one in my memory...

                   What I did have was:
                   #{inspect(unparsed_response)}

                   This is probably due to a bug in my code sadly :-(
                 """
      end)

      assert {1, server_state} == ClaudeAI.put_parsed_response(server_state)
    end

    test "given no response whatsoever in memory, return an error" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Puts, :on_new_line, fn msg, _style ->
        assert msg ==
                 """
                   I was asked to put a Claude AI parsed response on the screen, but I don't have one in my memory...

                   This is probably due to a bug in my code sadly :-(
                 """
      end)

      assert {1, server_state} == ClaudeAI.put_parsed_response(server_state)
    end
  end
end
