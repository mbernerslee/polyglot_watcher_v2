defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.FilePatchesBuilder do
  alias PolyglotWatcherV2.InstructorLiteSchemas.{CodeFileUpdate, CodeFileUpdates}
  alias PolyglotWatcherV2.FilePatch
  alias PolyglotWatcherV2.Patch

  def build(%CodeFileUpdates{updates: []}, _) do
    {:error, {:instructor_lite, :no_changes_suggested}}
  end

  def build(%CodeFileUpdates{updates: [_ | _] = updates}, %{test: test, lib: lib}) do
    build(%{}, 1, updates, test, lib)
  end

  defp build(acc, _index, [], _test, _lib) do
    {:ok, Map.to_list(acc)}
  end

  defp build(acc, index, [update | rest], test, lib) do
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
        patch = %Patch{
          search: search,
          replace: replace,
          explanation: explanation,
          index: index
        }

        acc =
          Map.update(
            acc,
            file.path,
            %FilePatch{contents: file.contents, patches: [patch]},
            &Map.update!(&1, :patches, fn patches -> patches ++ [patch] end)
          )

        build(acc, index + 1, rest, test, lib)

      error ->
        error
    end
  end
end
