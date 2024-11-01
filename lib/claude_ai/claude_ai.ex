defmodule PolyglotWatcherV2.ClaudeAI do
  alias PolyglotWatcherV2.Puts
  alias HTTPoison.{Request, Response}

  def build_api_request(%{env_vars: %{"ANTHROPIC_API_KEY" => api_key}} = server_state, messages)
      when api_key != nil do
    {0, put_in(server_state, [:claude_ai, :request], api_request(api_key, messages))}
  end

  def build_api_request(server_state, _messages) do
    {1, server_state}
  end

  def perform_api_call(%{claude_ai: %{request: %Request{} = request}} = server_state) do
    response = HTTPoison.request(request)
    {0, put_in(server_state, [:claude_ai, :response], response)}
  end

  def perform_api_call(server_state) do
    action_error =
      """
      I was asked to perform an API call to ClaudeAI, but I don't have a request in my memory.

      This is a bug! I should never be called in this state!
      """

    {1, %{server_state | action_error: action_error}}
  end

  def parse_claude_api_response(
        %{claude_ai: %{response: {:ok, %Response{status_code: 200, body: body}}}} = server_state
      ) do
    case Jason.decode(body) do
      {:ok, %{"content" => [%{"text" => text} | _]}} ->
        {0, put_in(server_state, [:claude_ai, :response], {:ok, {:parsed, text}})}

      _ ->
        action_error =
          """
          I failed to decode the Claude API HTTP 200 response :-(
          It was:

          #{body}
          """

        {1, %{server_state | action_error: action_error}}
    end
  end

  def parse_claude_api_response(%{claude_ai: %{response: response}} = server_state) do
    action_error = """
    Claude API did not return a HTTP 200 response :-(
    It was:

    #{inspect(response)}
    """

    {1, %{server_state | action_error: action_error}}
  end

  def parse_claude_api_response(server_state) do
    action_error =
      """
      I was asked to parse a Claude API response, but I don't have one in my memory.

      This should never happen and is a bug in the code most likely :-(
      """

    {1, %{server_state | action_error: action_error}}
  end

  def put_parsed_response(
        %{claude_ai: %{response: {:error, {:parsed, error_msg}}}} = server_state
      ) do
    Puts.on_new_line(error_msg, :red)
    {1, server_state}
  end

  def put_parsed_response(%{claude_ai: %{response: {:ok, {:parsed, response}}}} = server_state) do
    Puts.on_new_line_unstyled(response)
    {0, server_state}
  end

  def put_parsed_response(%{claude_ai: %{response: unparsed_response}} = server_state) do
    error =
      """
        I was asked to put a Claude AI parsed response on the screen, but I don't have one in my memory...

        What I did have was:
        #{inspect(unparsed_response)}

        This is probably due to a bug in my code sadly :-(
      """

    Puts.on_new_line(error, :red)
    {1, server_state}
  end

  def put_parsed_response(server_state) do
    error =
      """
        I was asked to put a Claude AI parsed response on the screen, but I don't have one in my memory...

        This is probably due to a bug in my code sadly :-(
      """

    Puts.on_new_line(error, :red)
    {1, server_state}
  end

  # https://docs.anthropic.com/en/api/messages-examples
  # https://github.com/lebrunel/anthropix - use this instead?
  defp api_request(api_key, messages) do
    %Request{
      method: :post,
      url: "https://api.anthropic.com/v1/messages",
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ],
      body:
        Jason.encode!(%{
          max_tokens: 2048,
          model: "claude-3-5-sonnet-20240620",
          messages: messages
        }),
      options: [recv_timeout: 180_000]
    }
  end
end
