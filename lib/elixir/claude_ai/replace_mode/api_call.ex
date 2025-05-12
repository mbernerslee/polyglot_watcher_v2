defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.APICall do
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.InstructorLiteSchemas.{CodeFileUpdate, CodeFileUpdates}
  alias PolyglotWatcherV2.InstructorLiteWrapper
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.GitDiff

  # TODO split up the cache retieval & file fetching? it sounds like we store file contents in the cache when we don't...
  def perform(test_path, %{env_vars: %{"ANTHROPIC_API_KEY" => api_key}} = server_state) do
    with {:ok, files} <- get_files_from_cache(test_path),
         prompt <- hydrate_prompt(files),
         {:ok, instruct_result} <- instruct(prompt, api_key),
         lib_test_to_path <- lib_test_to_path(files),
         {:ok, updates} <- group_updates_by_file(instruct_result, files),
         {:ok, git_diffs} <- git_diff(updates, files),
         :ok <- put_diffs_with_explanations(git_diffs, updates, lib_test_to_path) do
      update_server_state(updates, files, server_state)
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

      {:error, :git_diff} ->
        {1, server_state}
    end
  end

  defp lib_test_to_path(files) do
    %{
      lib: %{path: lib_path},
      test: %{path: test_path}
    } = files

    %{lib: lib_path, test: test_path}
  end

  defp git_diff(updates, files) do
    updates
    |> Map.new(fn {lib_or_test, file_updates} ->
      %{contents: contents} = Map.fetch!(files, lib_or_test)

      {lib_or_test, %{contents: contents, search_replace: file_updates}}
    end)
    |> IO.inspect()
    |> GitDiff.run()
    |> case do
      {:ok, res} -> {:ok, res}
      {:error, error} -> {:error, {:git_diff, error}}
    end
  end

  defp put_diffs_with_explanations(git_diffs, updates, lib_test_to_path) do
    Puts.on_new_line([
      {[:magenta], "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄\n"},
      {[:magenta], "████████████████ Claude Response ████████████████\n"},
      {[:magenta], "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"}
    ])

    Enum.each(updates, fn {lib_or_test, path_updates} ->
      path = Map.fetch!(lib_test_to_path, lib_or_test)
      git_diff = Map.fetch!(git_diffs, lib_or_test)

      explanations =
        path_updates
        |> Enum.map(& &1.explanation)
        |> Enum.join("\n")

      Puts.on_new_line([
        {[], path <> "\n"},
        {[], git_diff},
        {[], explanations},
        {[], "\n────────────────────────\n"}
      ])
    end)

    Puts.on_new_line([
      {[:magenta], "█████████████████████████████████████████████████\n"}
    ])
  end

  defp group_updates_by_file(%CodeFileUpdates{updates: []}, _) do
    {:error, {:instructor_lite, :no_changes_suggested}}
  end

  defp group_updates_by_file(%CodeFileUpdates{updates: [_ | _] = updates}, %{test: test, lib: lib}) do
    updates
    |> Enum.reduce_while({:ok, %{}}, fn update, {:ok, acc} ->
      %CodeFileUpdate{
        file_path: file_path,
        explanation: explanation,
        search: search,
        replace: replace
      } = update

      cond do
        file_path == lib.path -> {:ok, :lib, lib}
        file_path == test.path -> {:ok, :test, test}
        true -> {:error, {:instructor_lite, :invalid_file_path}}
      end
      |> case do
        {:ok, lib_or_test, file} ->
          single_update = %{
            search: search,
            replace: replace,
            explanation: explanation,
            path: file.path,
            contents: file.contents
          }

          {:cont, {:ok, Map.update(acc, lib_or_test, [single_update], &[single_update | &1])}}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, updates} ->
        {:ok, Map.new(updates, fn {path, updates} -> {path, Enum.reverse(updates)} end)}

      error ->
        error
    end
  end

  # TODO continue here. file_updates MUST contain the file contents once & only once. better data structure needed
  defp update_server_state(updates, %{test: test, lib: lib} = files, server_state) do
    IO.inspect(updates)

    updates =
      Map.new(updates, fn {lib_or_test, file_updates} ->
        %{path: path} = Map.fetch!(files, lib_or_test)
        {path, file_updates}
      end)

    server_state =
      server_state
      |> put_in([:files, test.path], test.contents)
      |> put_in([:files, lib.path], lib.contents)
      |> put_in([:claude_ai, :file_updates], updates)
      |> put_in([:claude_ai, :phase], :waiting)
      |> Map.replace!(:ignore_file_changes, true)

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
    """
  end
end
