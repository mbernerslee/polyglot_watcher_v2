defmodule PolyglotWatcherV2.FilePatches do
  alias PolyglotWatcherV2.FileSystem
  alias PolyglotWatcherV2.Puts

  def patch(file_patches, server_state) do
    file_patches
    |> Map.to_list()
    |> build_patches(server_state)
    |> write_patches()
  end

  defp write_patches({:ok, {patches, server_state}}) do
    do_write_patches(patches, server_state)
  end

  defp write_patches({:error, server_state}) do
    {1, server_state}
  end

  defp do_write_patches([], server_state) do
    {0, server_state}
  end

  defp do_write_patches([{path, new_contents} | rest], server_state) do
    case FileSystem.write(path, new_contents) do
      :ok ->
        Puts.on_new_line("Updated #{path}")
        do_write_patches(rest, server_state)

      error ->
        action_error = "Failed to write update to #{path}. Error was #{inspect(error)}"
        {1, %{server_state | action_error: action_error}}
    end
  end

  defp build_patches(patches, server_state) do
    do_build_patches([], patches, server_state)
  end

  defp do_build_patches(acc, [], server_state) do
    {:ok, {acc, server_state}}
  end

  defp do_build_patches(acc, [{path, %{patches: patches}} | rest], server_state) do
    case build_file_patch(path, patches, server_state) do
      {:ok, path, new_file_contents} ->
        do_build_patches([{path, new_file_contents} | acc], rest, server_state)

      :noop ->
        do_build_patches(acc, rest, server_state)

      {:error, server_state} ->
        {:error, server_state}
    end
  end

  defp build_file_patch(_path, [], _server_state) do
    :noop
  end

  defp build_file_patch(path, patches, server_state) do
    with {:ok, fresh_contents} <- FileSystem.read(path),
         {:ok, new_file_contents} <- new_file_contents(fresh_contents, patches) do
      {:ok, path, new_file_contents}
    else
      error ->
        action_error = "Failed to write update to #{path}. Error was #{inspect(error)}"
        {:error, %{server_state | action_error: action_error}}
    end
  end

  defp new_file_contents(contents, patches) do
    Enum.reduce_while(patches, {:ok, contents}, fn %{search: search, replace: replace},
                                                   {:ok, contents} ->
      case search_and_replace(contents, search, replace) do
        {:ok, new_contents} -> {:cont, {:ok, new_contents}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp search_and_replace(contents, search, nil) do
    search_and_replace(contents, search, "")
  end

  defp search_and_replace(contents, search, replace) do
    single_match = String.replace(contents, search, replace, global: false)
    multi_match = String.replace(contents, search, replace, global: true)

    cond do
      multi_match == contents ->
        {:error, :search_failed}

      single_match == multi_match ->
        {:ok, single_match}

      true ->
        {:error, :search_multiple_matches}
    end
  end
end
