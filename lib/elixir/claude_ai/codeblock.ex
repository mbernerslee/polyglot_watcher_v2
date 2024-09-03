defmodule PolyglotWatcherV2.Elixir.ClaudeAI.Codeblock do
  alias PolyglotWatcherV2.FileSystem

  def write_to_lib_file(
        %{
          claude_ai: %{response: {:ok, {:parsed, response}}},
          files: %{lib: %{path: lib_path, contents: old_contents}}
        } = server_state
      ) do
    {:ok, %{raw: response, lib_path: lib_path, old_lib_contents: old_contents}}
    |> and_then(:elixir_codeblock, &find_elixir_codeblock/1)
    |> and_then(:new_contents, &generate_new_lib_contents/1)
    |> and_then(:write_to_file, &write_new_contents_to_file/1)
    |> case do
      {:ok, %{write_to_file: :ok}} ->
        {0, server_state}

      x ->
        IO.inspect(x)
        {1, server_state}
    end
  end

  defp find_elixir_codeblock(%{raw: api_response}) do
    api_response
    |> String.split("\n", trim: true)
    |> Enum.reduce_while(nil, fn line, acc ->
      case {line, acc} do
        {"```elixir", nil} -> {:cont, []}
        {_, nil} -> {:cont, nil}
        {"```", acc} -> {:halt, {:ok, ["" | acc] |> Enum.reverse() |> Enum.join("\n")}}
        {line, acc} -> {:cont, [line | acc]}
      end
    end)
    |> case do
      {:ok, contents} ->
        {:ok, contents}

      x ->
        IO.inspect(1)
        IO.inspect(x)
        :error
    end
  end

  defp generate_new_lib_contents(%{
         elixir_codeblock: elixir_codeblock,
         old_lib_contents: old_lib_contents
       }) do
    commented_old_contents =
      old_lib_contents
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        if String.starts_with?(line, "##") do
          line
        else
          "## #{line}"
        end
      end)
      |> Enum.join("\n")

    new_contents = """
    #{elixir_codeblock}
    ##########################
    ## previous code version
    ##########################
    #{commented_old_contents}
    ##########################
    """

    {:ok, new_contents}
  end

  defp write_new_contents_to_file(%{lib_path: lib_path, new_contents: new_contents}) do
    case FileSystem.write(lib_path, new_contents) do
      :ok ->
        {:ok, :ok}

      x ->
        IO.inspect(2)
        IO.inspect(x)
        {:error, :file_not_written}
    end
  end

  defp and_then({:ok, acc}, key, fun) do
    case fun.(acc) do
      {:ok, result} -> {:ok, Map.put(acc, key, result)}
      error -> error
    end
  end

  defp and_then(error, _key, _fun), do: error
end
