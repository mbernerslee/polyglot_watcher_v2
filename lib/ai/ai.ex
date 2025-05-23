defmodule PolyglotWatcherV2.AI do
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.Config.AI
  alias PolyglotWatcherV2.InstructorLiteWrapper

  def build_api_request(server_state, messages) do
    %{
      env_vars: env_vars,
      config: %{
        ai: %AI{
          adapter: adapter,
          model: model,
          api_key_env_var_name: api_key_env_var_name
        }
      }
    } = server_state

    case Map.get(env_vars, api_key_env_var_name) do
      nil -> {1, server_state}
      api_key -> build_instructor_lite_args(server_state, adapter, messages, api_key, model)
    end
  end

  defp build_instructor_lite_args(server_state, adapter, messages, api_key, model) do
    params =
      case model do
        nil -> %{messages: messages}
        model -> %{messages: messages, model: model}
      end

    opts = [
      response_model: %{raw_response: :string},
      adapter: adapter,
      adapter_context: [api_key: api_key]
    ]

    {0, put_in(server_state, [:ai_state, :request], {params, opts})}
  end

  def perform_api_call(%{ai_state: %{request: {params, opts}}} = server_state) do
    response = InstructorLiteWrapper.instruct(params, opts)
    {0, put_in(server_state, [:ai_state, :response], response)}
  end

  def perform_api_call(server_state) do
    action_error =
      """
      I was asked to perform an AI API call, but I don't have a request in my memory.

      This is a bug! I should never be called in this state!
      """

    {1, %{server_state | action_error: action_error}}
  end

  def parse_ai_api_response(
        %{ai_state: %{response: {:ok, %{raw_response: response}}}} = server_state
      ) do
    {0, put_in(server_state, [:ai_state, :response], {:ok, {:parsed, response}})}
  end

  def parse_ai_api_response(%{ai_state: %{response: error}} = server_state) do
    action_error =
      """
      I failed to decode an AI API call response.
      It was #{inspect(error)}
      """

    {1, %{server_state | action_error: action_error}}
  end

  def parse_ai_api_response(server_state) do
    action_error =
      """
      I was asked to parse an AI API call response, but I don't have one in my memory.

      This should never happen and is a bug in the code most likely :-(
      """

    {1, %{server_state | action_error: action_error}}
  end

  def put_parsed_response(%{ai_state: %{response: {:ok, {:parsed, response}}}} = server_state) do
    Puts.on_new_line_unstyled(response)
    {0, server_state}
  end

  def put_parsed_response(server_state) do
    error =
      """
        I was asked to put an AI API call response on the screen, but I don't have one in my memory...

        This is probably due to a bug in my code sadly :-(
      """

    Puts.on_new_line(error, :red)
    {1, server_state}
  end

  # https://docs.anthropic.com/en/api/messages-examples
  # https://github.com/lebrunel/anthropic - use this instead?
  # defp api_request(api_key, messages) do
  #  %Request{
  #    method: :post,
  #    url: "https://api.anthropic.com/v1/messages",
  #    headers: [
  #      {"x-api-key", api_key},
  #      {"anthropic-version", "2023-06-01"},
  #      {"content-type", "application/json"}
  #    ],
  #    body:
  #      Jason.encode!(%{
  #        max_tokens: 2048,
  #        model: "claude-3-5-sonnet-20240620",
  #        messages: messages
  #      }),
  #    options: [recv_timeout: 180_000]
  #  }
  # end
end
