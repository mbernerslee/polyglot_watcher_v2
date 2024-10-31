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
          """
          I failed to decode the Claude response.
          My regex capture to grab JSON between two lines of asterisks didn't work.
          The raw response was:

          #{response}
          """

        {1, %{server_state | action_error: error}}
    end
  end

  defp finalise(json, pre, post, server_state) do
    case parse_json(json) do
      {:ok, blocks} ->
        pre = String.trim(pre)
        post = String.trim(post)
        response = {:ok, {:replace, %ReplaceBlocks{pre: pre, blocks: blocks, post: post}}}
        {0, put_in(server_state, [:claude_ai, :response], response)}

      {:error, error} ->
        {1, %{server_state | action_error: error}}
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
         I failed to parse the JSON that I asked Claude to return
         The root element was requested to be "BLOCKS" in the prompt, but instead it gave us the JSON below.

         This a terminal error sadly. Claude failed us :-(

         #{encoded}
         """}

      {:error, error} ->
        {:error,
         """
         I failed to decode the JSON that I asked Claude to return, because it was invalid.
         This a terminal error sadly. Claude failed us :-(

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
