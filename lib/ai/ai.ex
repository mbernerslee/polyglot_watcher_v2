defmodule PolyglotWatcherV2.AI do
  @moduledoc """
  HTTPoison request we used to make before using InstructorLite:

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

  """
  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.Config.AI
  alias PolyglotWatcherV2.FileSystem
  alias PolyglotWatcherV2.InstructorLiteWrapper

  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.InstructorLiteSchemas.CodeFileUpdates

  @response_models %{replace: CodeFileUpdates}

  def vendors do
    %{
      "Anthropic" => %{
        adapter: InstructorLite.Adapters.Anthropic,
        instructor_adapter: Instructor.Adapters.Anthropic,
        api_key_env_var_name: "ANTHROPIC_API_KEY",
        models: ["claude-3-5-sonnet-20240620", "claude-3-5-haiku-20241022"]
      },
      "Gemini" => %{
        adapter: InstructorLite.Adapters.Gemini,
        instructor_adapter: Instructor.Adapters.Gemini,
        api_key_env_var_name: "GEMINI_API_KEY",
        models: ["gemini-2.0-flash"]
      }
    }
  end

  def reload_prompt(name, server_state) do
    unexpanded_path = Path.join(Const.prompts_dir_path(), to_string(name))

    unexpanded_path
    |> FileSystem.expand_path()
    |> FileSystem.read()
    |> case do
      {:ok, prompt} ->
        {0, put_in(server_state, [:ai_prompts, name], prompt)}

      {:error, error} ->
        action_error =
          """
          I failed to read an AI prompt from
            #{unexpanded_path}

          The error was #{inspect(error)}

          Please ensure the file exists and is readable.
          You should have a backup in the prompts directory if you need it.
          """

        {1, %{server_state | action_error: action_error}}
    end
  end

  def build_api_request(name, test_path, server_state) do
    config = server_state.config.ai

    with {:ok, files} <- get_files_from_cache(test_path),
         {:ok, api_key} <- get_api_key(server_state),
         {:ok, model} <- get_response_model(name),
         {:ok, prompt} <- get_prompt(name, server_state),
         prompt <- hydrate_prompt(prompt, files),
         request <- do_build_api_request(config, prompt, api_key, model) do
      ai_state =
        server_state.ai_state
        |> Map.put_new(name, %{})
        |> put_in([name, :request], request)

      {0, Map.replace!(server_state, :ai_state, ai_state)}
    else
      {:error, :cache_miss} ->
        action_error =
          """
          I tried to build an AI API request for the failing test
            test/a_test.exs

          ...but I have no such failing test in my memory.
          This shouldn't happen and is a bug in my code sadly :-(
          """

        {1, %{server_state | action_error: action_error}}

      {:error, :unknown_api_request_name} ->
        action_error =
          """
          I tried to build an AI API request of the type #{name}

          ...but that's not a recognised type.
          This shouldn't happen and is a bug in my code sadly :-(
          """

        {1, %{server_state | action_error: action_error}}

      {:error, :prompt_missing} ->
        action_error =
          """
          I tried to build an AI API request of the type #{name}

          ...but I haven't loaded a prompt for this type.
          This shouldn't happen and is a bug in my code sadly :-(
          """

        {1, %{server_state | action_error: action_error}}

      {:error, :api_key_missing} ->
        action_error =
          """
          I tried to build an AI API request for #{adapter_name(config.adapter)}

          ...but I haven't loaded the #{config.api_key_env_var_name} API key
          from the environment variable of the same name

          This shouldn't happen and is a bug in my code sadly :-(
          """

        {1, %{server_state | action_error: action_error}}
    end
  end

  def perform_api_request(name, server_state) do
    with {:ok, %{params: params, opts: opts}} <- get_request(name, server_state),
         :ok <- put_awaiting_api_response_msg(opts),
         response <- InstructorLiteWrapper.instruct(params, opts) do
      {0, put_in(server_state, [:ai_state, name], %{response: response})}
    else
      {:error, :missing_request} ->
        action_error =
          """
          I tried to perform an AI API call

          ...but I have no API request in my memory
          This shouldn't happen and is a bug in my code sadly :-(
          """

        {1, %{server_state | action_error: action_error}}
    end
  end

  defp get_request(name, server_state) do
    case server_state.ai_state[name] do
      %{request: request} -> {:ok, request}
      _ -> {:error, :missing_request}
    end
  end

  defp put_awaiting_api_response_msg(opts) do
    adapter_name =
      opts
      |> Keyword.fetch!(:adapter)
      |> adapter_name()

    Puts.on_new_line("Waiting for #{adapter_name} API call response...")
  end

  defp adapter_name(adapter) do
    full_name = to_string(adapter)

    full_name
    |> String.split(".")
    |> Enum.reverse()
    |> case do
      [name | _] -> name
      _ -> full_name
    end
  end

  defp do_build_api_request(config, prompt, api_key, model) do
    params = %{messages: [%{role: "user", content: prompt}]}

    opts = [
      response_model: model,
      adapter: config.adapter,
      adapter_context: [api_key: api_key]
    ]

    %{params: params, opts: opts}
  end

  defp hydrate_prompt(prompt, %{test: test, lib: lib, mix_test_output: mix_test_output}) do
    prompt
    |> String.replace("$LIB_PATH_PLACEHOLDER", lib.path)
    |> String.replace("$LIB_CONTENT_PLACEHOLDER", lib.contents)
    |> String.replace("$TEST_PATH_PLACEHOLDER", test.path)
    |> String.replace("$TEST_CONTENT_PLACEHOLDER", test.contents)
    |> String.replace("$MIX_TEST_OUTPUT_PLACEHOLDER", mix_test_output)
  end

  defp get_files_from_cache(test_path) do
    case Cache.get_files(test_path) do
      {:ok, files} -> {:ok, files}
      _error -> {:error, :cache_miss}
    end
  end

  defp get_response_model(name) do
    case Map.get(@response_models, name) do
      nil -> {:error, :unknown_api_request_name}
      model -> {:ok, model}
    end
  end

  defp get_prompt(name, %{ai_prompts: prompts}) do
    case Map.get(prompts, name) do
      nil -> {:error, :prompt_missing}
      prompt -> {:ok, prompt}
    end
  end

  defp get_api_key(server_state) do
    %{
      env_vars: env_vars,
      config: %{
        ai: %AI{
          api_key_env_var_name: api_key_env_var_name
        }
      }
    } = server_state

    case Map.get(env_vars, api_key_env_var_name) do
      nil -> {:error, :api_key_missing}
      api_key -> {:ok, api_key}
    end
  end
end
