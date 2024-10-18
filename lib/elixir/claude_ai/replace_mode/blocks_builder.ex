defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.BlocksBuilder do
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.{ReplaceBlocks, ReplaceBlock}
  @ten_asterisks "(\\*){10}"
  @regex ~r|(?<pre>.*)#{@ten_asterisks}(?<json>.*)#{@ten_asterisks}(?<post>.*)|s

  def parse(%{claude_ai: %{response: {:ok, {:parsed, response}}}} = server_state) do
    @regex
    |> Regex.named_captures(response, capture: :all)
    |> case do
      %{"json" => json, "pre" => pre, "post" => post} ->
        finalise(json, pre, post, server_state)

      nil ->
        error =
          {:error,
           {:replace,
            """
            Failed to decode the Claude response.
            My regex capture to grab JSON between two lines of asterisks didn't work.
            The raw response was:

            #{response}
            """}}

        {1, put_in(server_state, [:claude_ai, :response], error)}
    end
  end

  defp finalise(json, pre, post, server_state) do
    case parse_json(json) do
      {:ok, blocks} ->
        pre = String.trim(pre)
        post = String.trim(post)
        response = {:ok, {:replace, %ReplaceBlocks{pre: pre, blocks: blocks, post: post}}}
        {0, put_in(server_state, [:claude_ai, :response], response)}

      {:error, reason} ->
        response = {:error, {:replace, reason}}
        {1, put_in(server_state, [:claude_ai, :response], response)}
    end
  end

  defp parse_json(encoded) do
    encoded
    |> Jason.Formatter.minimize()
    |> String.replace("\n", "\\n")
    |> Jason.decode()
    |> case do
      {:ok, %{"BLOCKS" => decoded}} ->
        parse_blocks(decoded, encoded)

      {:ok, _} ->
        {:error,
         """
         Failed to parse JSON.
         The root element was not "BLOCKS"

         #{encoded}
         """}

      error ->
        {:error,
         """
         Failed to decode JSON.
         The decoding error was:

         #{inspect(error)}

         The raw response was:

         #{encoded}
         """}
    end
  end

  defp parse_blocks(decoded, encoded) do
    decoded
    |> Enum.reduce_while({:ok, []}, fn block, {:ok, acc} ->
      case block do
        %{"SEARCH" => search, "REPLACE" => replace, "EXPLANATION" => explanation} ->
          {:cont,
           {:ok,
            [%ReplaceBlock{search: search, replace: replace, explanation: explanation} | acc]}}

        _ ->
          {:halt,
           {:error,
            """
            Failed to parse JSON.
            At least one of the "BLOCKS" was missing a mandatory key.
            The raw response was:

            #{encoded}
            """}}
      end
    end)
    |> case do
      {:error, _} = error -> error
      {:ok, blocks} -> {:ok, Enum.reverse(blocks)}
    end
  end
end
