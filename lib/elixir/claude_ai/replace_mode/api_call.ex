defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICall do
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.InstructorLiteSchemas.{CodeFileUpdate, CodeFileUpdates}
  alias PolyglotWatcherV2.InstructorLiteWrapper
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.GitDiff

  #TODO make output prettier
  #TODO stop several changes being allowed for 1 update? (global = false? or explicit line number if multple matches?)
  def perform(test_path, %{env_vars: %{"ANTHROPIC_API_KEY" => api_key}} = server_state) do
    with {:ok, files} <- get_files_from_cache(test_path),
         prompt <- hydrate_prompt(files),
         {:ok, instruct_result} <- instruct(prompt, api_key),
         {:ok, updates} <- group_updates(instruct_result, files),
         {:ok, git_diffs} <- git_diff(updates),
         :ok <- put_diffs_with_explanations(git_diffs, updates) do
      update_server_state(updates, server_state)
    else
      {:error, :cache_miss} ->
        action_error = "I failed because my cache did not contain the file #{test_path} :-("
        {1, %{server_state | action_error: action_error}}

      {:error, {:instructor_lite, :invalid_file_path}} ->
        action_error = "InstructorLite: suggested we update some other file"
        {1, %{server_state | action_error: action_error}}

      {:error, {:instructor_lite, :no_changes_suggested}} ->
        action_error = "InstructorLite: suggested no changes"
        {1, %{server_state | action_error: action_error}}

      {:error, {:instructor_lite, error}} ->
        action_error = "Error from InstructorLite: #{inspect(error)}"
        {1, %{server_state | action_error: action_error}}

      {:error, {:git_diff, error}} ->
        action_error = "Git Diff error: #{inspect(error)}"
        {1, %{server_state | action_error: action_error}}
    end
  end

  defp git_diff(updates) do
    updates
    |> GitDiff.run()
    |> case do
      {:ok, res} -> {:ok, res}
      {:error, error} -> {:error, {:git_diff, error}}
    end
  end

  defp put_diffs_with_explanations(git_diffs, updates) do
    Puts.on_new_line([
      {[:magenta], "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄\n"},
      {[:magenta], "████████████████ Claude Response ████████████████\n"},
      {[:magenta], "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"}
    ])

    # TODO this sorting is untested :-( find a way?
    Enum.reduce(updates, [], fn {path, %{patches: patches}}, acc ->
      Enum.reduce(patches, acc, fn %{index: index, explanation: explanation}, inner ->
        git_diff =
          git_diffs
          |> Map.fetch!(path)
          |> Map.fetch!(index)

        [%{path: path, git_diff: git_diff, explanation: explanation, index: index} | inner]
      end)
    end)
    |> Enum.sort(&(&1.index <= &2.index))
    |> Enum.each(fn %{path: path, git_diff: git_diff, explanation: explanation} ->
      Puts.on_new_line([
        {[], path <> "\n"},
        {[], git_diff},
        {[], explanation},
        {[], "\n────────────────────────\n"}
      ])
    end)

    Puts.on_new_line([
      {[:magenta], "█████████████████████████████████████████████████\n"}
    ])
  end

  defp group_updates(%CodeFileUpdates{updates: []}, _) do
    {:error, {:instructor_lite, :no_changes_suggested}}
  end

  defp group_updates(%CodeFileUpdates{updates: [_ | _] = updates}, %{test: test, lib: lib}) do
    do_group_updates(%{}, 1, updates, test, lib)
  end

  defp do_group_updates(acc, _index, [], _test, _lib) do
    {:ok, Map.to_list(acc)}
  end

  defp do_group_updates(acc, index, [update | rest], test, lib) do
    %CodeFileUpdate{
      file_path: file_path,
      explanation: explanation,
      search: search,
      replace: replace
    } = update

    cond do
      file_path == lib.path -> {:ok, lib}
      file_path == test.path -> {:ok, test}
      true -> {:error, {:instructor_lite, :invalid_file_path}}
    end
    |> case do
      {:ok, file} ->
        patch = %{
          search: search,
          replace: replace,
          explanation: explanation,
          index: index
        }

        acc =
          Map.update(
            acc,
            file.path,
            %{contents: file.contents, patches: [patch]},
            &Map.update!(&1, :patches, fn patches -> patches ++ [patch] end)
          )

        do_group_updates(acc, index + 1, rest, test, lib)

      error ->
        error
    end
  end

  # file_updates structure: %{file_path => %{contents: string, patches: [%{search: string, replace: string, explanation: string}]}}
  defp update_server_state(updates, server_state) do
    server_state =
      server_state
      |> put_in([:claude_ai, :file_updates], updates)
      |> put_in([:claude_ai, :phase], :waiting)

    {0, server_state}
  end

  defp instruct(prompt, api_key) do
    InstructorLiteWrapper.instruct(
      %{messages: [%{role: "user", content: prompt}]},
      response_model: CodeFileUpdates,
      adapter: InstructorLite.Adapters.Anthropic,
      adapter_context: [api_key: api_key]
    )
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, {:instructor_lite, error}}
    end
  end

  defp hydrate_prompt(%{test: test, lib: lib, mix_test_output: mix_test_output}) do
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
    Don't add comments to the code please, leave commentary only in the explanation.
    """
  end
end
