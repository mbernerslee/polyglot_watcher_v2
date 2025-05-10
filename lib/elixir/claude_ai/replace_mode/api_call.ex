defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICall do
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.InstructorLiteSchemas.CodeFileUpdates
  alias PolyglotWatcherV2.InstructorLiteWrapper

  def perform(test_path, %{env_vars: %{"ANTHROPIC_API_KEY" => api_key}} = server_state) do
    with {:ok, %{test: test, lib: lib, mix_test_output: mix_test_output}} <-
           get_files_from_cache(test_path),
         prompt <- hydrate_prompt(lib, test, mix_test_output),
         instruct_result <- instruct(prompt, api_key) do
      action_instruct_result(instruct_result, test, lib, mix_test_output, server_state)
    else
      {:error, :cache_miss} -> {1, server_state}
    end

    # case Cache.get_files(test_path) do
    #  {:ok, %{test: test, lib: lib, mix_test_output: mix_test_output}} ->
    #    prompt = replace_placeholders(prompt(), lib, test, mix_test_output)

    #    server_state =
    #      server_state
    #      |> put_in([:files, :test], test)
    #      |> put_in([:files, :lib], lib)

    #    InstructorLiteWrapper.instruct(
    #      %{
    #        messages: [
    #          %{role: "user", content: prompt()}
    #        ]
    #      },
    #      response_model: CodeFileUpdates,
    #      adapter: InstructorLite.Adapters.Anthropic,
    #      adapter_context: [api_key: api_key]
    #    )

    #  _ ->
    #    {{:error, :cache_miss}, server_state}
    # end
  end

  defp action_instruct_result(instruct_result, test, lib, mix_test_output, server_state) do
    {0, server_state}
  end

  defp instruct(prompt, api_key) do
    InstructorLiteWrapper.instruct(
      %{messages: [%{role: "user", content: prompt}]},
      response_model: CodeFileUpdates,
      adapter: InstructorLite.Adapters.Anthropic,
      adapter_context: [api_key: api_key]
    )
  end

  defp hydrate_prompt(lib, test, mix_test_output) do
    prompt()
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

  defp prompt do
    """
    Given the following -

    <buffer>
      <name>
        Elixir Code
      </name>
      <filePath>
        $LIB_PATH_PLACEHOLDER
      </filePath>
      <content>
        $LIB_CONTENT_PLACEHOLDER
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Test
      </name>
      <filePath>
        $TEST_PATH_PLACEHOLDER
      </filePath>
      <content>
        $TEST_CONTENT_PLACEHOLDER
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Mix Test Output
      </name>
      <content>
        $MIX_TEST_OUTPUT_PLACEHOLDER
      </content>
    </buffer>

    Can you please provide a list of updates to fix the issues?
    """
  end
end
