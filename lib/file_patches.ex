defmodule PolyglotWatcherV2.FilePatches do
  alias PolyglotWatcherV2.FileSystem
  alias PolyglotWatcherV2.Puts

  def patch(_selector, %{file_patches: nil} = server_state), do: {{:ok, :done}, server_state}

  def patch(selector, %{file_patches: file_patches} = server_state) do
    {use, keep} = select(file_patches, selector)

    use
    |> build_patches(server_state)
    |> write_patches()
    |> update_patches(keep)
  end

  defp select(file_patches, :all) do
    {file_patches, []}
  end

  defp select(file_patches, indices) do
    {use, keep} =
      Enum.reduce(file_patches, {[], []}, fn {path, file_patch}, {use, keep} ->
        %{patches: patches, contents: contents} = file_patch

        {use_patches, keep_patches} = Enum.split_with(patches, &(&1.index in indices))

        use_file_patch = file_patch(path, use_patches, contents)
        keep_file_patch = file_patch(path, keep_patches, contents)

        {[use_file_patch | use], [keep_file_patch | keep]}
      end)

    use = use |> List.flatten() |> Enum.reverse()
    keep = keep |> List.flatten() |> Enum.reverse()

    {use, keep}
  end

  defp file_patch(_path, [], _contents) do
    []
  end

  defp file_patch(path, patches, contents) do
    [{path, %{patches: patches, contents: contents}}]
  end

  defp update_patches({:ok, server_state}, []) do
    {{:ok, :done}, %{server_state | file_patches: nil}}
  end

  defp update_patches({:ok, server_state}, keep) do
    {{:ok, :cont}, %{server_state | file_patches: keep}}
  end

  defp update_patches({:error, server_state}, _) do
    {:error, %{server_state | file_patches: nil}}
  end

  defp write_patches({:ok, {patches, server_state}}) do
    do_write_patches(patches, server_state)
  end

  defp write_patches({:error, server_state}) do
    {:error, server_state}
  end

  defp do_write_patches([], server_state) do
    {:ok, server_state}
  end

  defp do_write_patches([{path, new_contents} | rest], server_state) do
    case FileSystem.write(path, new_contents) do
      :ok ->
        Puts.on_new_line("Updated #{path}")
        do_write_patches(rest, server_state)

      error ->
        action_error = "Failed to write update to #{path}. Error was #{inspect(error)}"
        {:error, %{server_state | action_error: action_error}}
    end
  end

  defp build_patches(patches, server_state) do
    build_patches([], patches, server_state)
  end

  defp build_patches(acc, [], server_state) do
    {:ok, {acc, server_state}}
  end

  defp build_patches(acc, [{path, %{patches: patches}} | rest], server_state) do
    case build_file_patch(path, patches, server_state) do
      {:ok, path, new_file_contents} ->
        build_patches([{path, new_file_contents} | acc], rest, server_state)

      :noop ->
        build_patches(acc, rest, server_state)

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
    multi_match = String.replace(contents, search, replace, global: true)

    if multi_match == contents do
      {:error, :search_failed}
    else
      {:ok, multi_match}
    end
  end
end
