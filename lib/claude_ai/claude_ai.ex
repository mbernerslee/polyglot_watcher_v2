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

  # TODO ask claude for the full file contents, but then generate our own diff and show that to the user & apply the diff?
  # https://stackoverflow.com/questions/34932508/git-one-liner-for-applying-a-patch-interactively
  def handle_api_response(
        %{claude_ai: %{response: {:ok, %Response{status_code: 200, body: body}}}} = server_state
      ) do
    case Jason.decode(body) do
      {:ok, %{"content" => [%{"text" => text} | _]}} ->
        Puts.on_new_line_unstyled(text)
        {0, put_in(server_state, [:claude_ai, :response], {:ok, {:parsed, text}})}

      _ ->
        error = """
        I failed to decode the Claude API HTTP 200 response :-(
        It was:

        #{body}
        """

        handle_api_response_error(server_state, error)
    end
  end

  def handle_api_response(%{claude_ai: %{response: response}} = server_state) do
    error = """
    Claude API did not return a HTTP 200 response :-(
    It was:

    #{inspect(response)}
    """

    handle_api_response_error(server_state, error)
  end

  def handle_api_response(server_state) do
    handle_api_response_error(server_state, "I have no Claude API response in my memory...")
  end

  defp handle_api_response_error(server_state, error) do
    Puts.on_new_line(error, :red)
    {1, put_in(server_state, [:claude_ai, :response], {:error, {:parsed, error}})}
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
