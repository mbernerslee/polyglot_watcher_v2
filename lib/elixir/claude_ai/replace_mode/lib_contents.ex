defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.LibContents do
  # TODO this is uncalled right now. wire it into the new plan (git_diff action)
  def replace(block, lib) do
    replace =
      block.replace
      |> String.split("\n")
      |> remove_trailing_newline()
      |> Enum.reverse()

    acc = %{new_lib: [], state: :search, replace: replace}

    block.search
    |> String.split("\n")
    |> replace(lib, acc)
  end

  defp replace([], [], %{new_lib: new_lib, state: :replacing}) do
    {:ok, Enum.reverse(new_lib)}
  end

  defp replace([], [lib | lib_rest], %{state: :replacing} = acc) do
    acc = %{acc | new_lib: [lib | acc.new_lib]}
    replace([], lib_rest, acc)
  end

  defp replace([""], [lib | lib_rest], %{state: :replacing} = acc) do
    acc = %{acc | new_lib: [lib | acc.new_lib]}
    replace([], lib_rest, acc)
  end

  defp replace([find | search_rest], [find | lib_rest], %{state: :replacing} = acc) do
    replace(search_rest, lib_rest, acc)
  end

  defp replace(_, _, %{state: :replacing}) do
    {:error, :not_found}
  end

  defp replace([find | search_rest], [find | lib_rest], %{state: :search} = acc) do
    acc = %{acc | new_lib: acc.replace ++ acc.new_lib, state: :replacing}
    replace(search_rest, lib_rest, acc)
  end

  defp replace(search, [line | lib_rest], %{state: :search} = acc) do
    acc = %{acc | new_lib: [line | acc.new_lib]}
    replace(search, lib_rest, acc)
  end

  defp remove_trailing_newline(list) do
    case Enum.reverse(list) do
      ["" | rest] -> Enum.reverse(rest)
      other -> other
    end
  end
end
