defmodule PolyglotWatcherV2.AITest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{AI, Puts, ServerStateBuilder}
  alias PolyglotWatcherV2.Config
  alias PolyglotWatcherV2.InstructorLiteWrapper

  describe "build_api_request/2" do
    test "puts the arguments for InstructorLite.instruct into the server state" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")

      messages = [%{role: "user", content: "tell me a joke"}]

      assert {0, new_server_state} = AI.build_api_request(server_state, messages)

      %{ai_state: %{request: {params, opts}}} = new_server_state

      assert %{messages: messages, model: "cool-model"} == params

      assert [
               response_model: %{raw_response: :string},
               adapter: InstructorLite.Adapters.Anthropic,
               adapter_context: [api_key: "COOL_API_KEY"]
             ] == opts
    end

    test "when the API key is missing, return error" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_config(%Config.AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })

      messages = [%{role: "user", content: "tell me a joke"}]

      assert {1, server_state} == AI.build_api_request(server_state, messages)
    end
  end

  describe "perform_api_call/2" do
    test "when there's a request in the server_state, perform the call with InstructorLite" do
      params = %{messages: [%{role: "user", content: "tell me a joke"}], model: "cool-model"}

      opts = [
        response_model: %{raw_response: :string},
        adapter: InstructorLite.Adapters.Anthropic,
        adapter_context: [api_key: "COOL_API_KEY"]
      ]

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_state_request({params, opts})

      response = {:ok, %{raw_response: "some raw text response"}}

      Mimic.expect(InstructorLiteWrapper, :instruct, fn _params, _opts ->
        response
      end)

      assert {0, new_server_state} = AI.perform_api_call(server_state)

      assert new_server_state == put_in(server_state, [:ai_state, :response], response)
    end

    test "with no request in the server_state, put an action error" do
      server_state = ServerStateBuilder.build()

      Mimic.reject(&InstructorLiteWrapper.instruct/2)

      assert {1, new_server_state} = AI.perform_api_call(server_state)

      expected_action_error =
        """
        I was asked to perform an AI API call, but I don't have a request in my memory.

        This is a bug! I should never be called in this state!
        """

      assert new_server_state == %{server_state | action_error: expected_action_error}
    end
  end

  describe "parse_ai_api_response/2" do
    test "given some server state containing a happy InstructorLite response, put the parsed response into the server state" do
      # response_text = "some text"
      # body = Jason.encode!(%{"content" => [%{"text" => response_text}]})

      # response = {:ok, %Response{status_code: 200, body: body}}

      response = {:ok, %{raw_response: "some raw text response"}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_state_response(response)

      assert {0, new_server_state} = AI.parse_ai_api_response(server_state)

      parsed = {:ok, {:parsed, "some raw text response"}}

      assert put_in(server_state, [:ai_state, :response], parsed) ==
               new_server_state
    end

    test "given some server state containing a sad api response put the parsed response into the server state" do
      response = {:error, :some_instructor_lite_error}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_state_response(response)

      assert {1, new_server_state} = AI.parse_ai_api_response(server_state)

      expected_action_error =
        """
        I failed to decode an AI API call response.
        It was {:error, :some_instructor_lite_error}
        """

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end

    test "given some server state NOT containing a response whatsoever, return an error" do
      server_state = ServerStateBuilder.build()

      assert {1, new_server_state} = AI.parse_ai_api_response(server_state)

      expected_action_error =
        """
        I was asked to parse an AI API call response, but I don't have one in my memory.

        This should never happen and is a bug in the code most likely :-(
        """

      assert %{server_state | action_error: expected_action_error} == new_server_state
    end
  end

  describe "put_parsed_response/1" do
    test "given a parsed ok response, put it on the screen" do
      parsed_content = "it's all good"
      ok_response = {:ok, {:parsed, parsed_content}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_ai_state_response(ok_response)

      Mimic.expect(Puts, :on_new_line_unstyled, fn msg ->
        assert msg == parsed_content
      end)

      assert {0, server_state} == AI.put_parsed_response(server_state)
    end

    test "given no response whatsoever in memory, return an error" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Puts, :on_new_line, fn msg, _style ->
        assert msg ==
                 """
                   I was asked to put an AI API call response on the screen, but I don't have one in my memory...

                   This is probably due to a bug in my code sadly :-(
                 """
      end)

      assert {1, server_state} == AI.put_parsed_response(server_state)
    end
  end
end
