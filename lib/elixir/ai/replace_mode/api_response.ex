defmodule PolyglotWatcherV2.Elixir.AI.ReplaceMode.APIResponse do
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.GitDiff
  alias PolyglotWatcherV2.Elixir.AI.ReplaceMode.FilePatchesBuilder

  def action(test_path, server_state) do
    with {:ok, code_file_updates} <- get_api_response(server_state),
         {:ok, files} <- get_files_from_cache(test_path),
         {:ok, file_patches} <- FilePatchesBuilder.build(code_file_updates, files),
         {:ok, git_diffs} <- git_diff(file_patches),
         :ok <- put_diffs_with_explanations(git_diffs, file_patches) do
      update_server_state(file_patches, server_state)
    else
      {:error, {:api_key_env_var_missing, env_var_name}} ->
        action_error =
          "I failed I couldn't find the #{inspect(env_var_name)} env var in my memory. This shouldn't happen and is a bug in my code :-("

        {1, %{server_state | action_error: action_error}}

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

  defp get_api_response(server_state) do
    case server_state.ai_state[:replace] do
      %{response: {:ok, code_file_updates}} -> {:ok, code_file_updates}
      %{response: {:error, error}} -> {:error, {:instructor_lite, error}}
      %{response: {:error, error, details}} -> {:error, {:instructor_lite, {error, details}}}
    end
  end

  defp git_diff(file_patches) do
    file_patches
    |> GitDiff.run()
    |> case do
      {:ok, res} -> {:ok, res}
      {:error, error} -> {:error, {:git_diff, error}}
    end
  end

  defp put_diffs_with_explanations(git_diffs, file_patches) do
    Puts.on_new_line([
      {[:magenta], "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄\n"},
      {[:magenta], "██████████████████ AI Response ██████████████████\n"},
      {[:magenta], "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"}
    ])

    Enum.reduce(file_patches, [], fn {path, %{patches: patches}}, acc ->
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

  defp update_server_state(file_patches, server_state) do
    server_state =
      server_state
      |> put_in([:file_patches], file_patches)
      |> put_in([:ai_state, :phase], :waiting)
      |> Map.replace!(:ignore_file_changes, true)

    {0, server_state}
  end

  defp get_files_from_cache(test_path) do
    case Cache.get_files(test_path) do
      {:ok, files} -> {:ok, files}
      _error -> {:error, :cache_miss}
    end
  end
end
