defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ActionsBuilder do
  alias PolyglotWatcherV2.Action

  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.{LibContents, ReplaceBlocks, Diff}

  def build(
        %{
          files: %{lib: %{contents: lib_contents}},
          claude_ai: %{
            response: {:ok, {:replace, %ReplaceBlocks{pre: _, blocks: blocks, post: _}}}
          }
        } = server_state
      ) do
    lib = String.split(lib_contents, "\n")
    IO.puts("********************************")
    IO.puts(hd(blocks).search)
    IO.puts("********************************")
    IO.puts(hd(blocks).replace)
    IO.puts("********************************")

    max = length(blocks)

    {:ok, diff} =
      blocks
      |> Enum.reverse()
      |> Enum.reduce_while(%{block_number: max, lib: lib}, fn block, acc ->
        case build_block_actions(block, acc.lib, acc.block_number) do
          {:ok, _new_lib, diff} -> {:halt, {:ok, diff}}
        end
      end)

    tree = %{
      entry_point: :block_puts_1,
      actions_tree: %{
        block_puts_1: %Action{
          runnable: {:puts, diff},
          next_action: :exit
        }
      }
    }

    {0, put_in(server_state, [:stored_actions], tree)}
  end

  defp build_block_actions(block, lib, _block_number) do
    with {:ok, new_lib} <- LibContents.replace(block, lib),
         {:ok, diff} <- Diff.build(new_lib, lib) do
      {:ok, new_lib, diff}
    end
  end
end
