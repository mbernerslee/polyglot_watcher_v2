defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ActionsBuilder do
  alias PolyglotWatcherV2.Action

  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ReplaceBlocks

  @first_block_action_key :git_diff_1

  # TODO continue here - there's a bug here because files lib path pattern match
  def build(
        %{
          files: %{lib: %{path: lib_path}},
          claude_ai: %{
            response: {:ok, {:replace, %ReplaceBlocks{pre: pre, blocks: blocks, post: _post}}}
          }
        } = server_state
      ) do
    actions_tree = actions(blocks, lib_path, pre)

    {0, put_in(server_state, [:stored_actions], actions_tree)}
  end

  def build(server_state) do
    {1, Map.put(server_state, :action_error, error_msg())}
  end

  defp error_msg do
    """
    ClaudeAI ReplaceMode Actions Builder was called with some expected data missing.

    If you see this message it's due to a serious bug in the code and should be reported and fixed.

    Please raise a github issue.
    """
  end

  defp actions([], _lib_path, pre) do
    message =
      """
      Claude offered no code changes, only some words of advice:

      #{pre}
      """

    %{
      entry_point: :put_no_blocks_message,
      actions_tree: %{
        put_no_blocks_message: %Action{
          runnable: {:puts, :magenta, message},
          next_action: :exit
        }
      }
    }
  end

  defp actions(blocks, lib_path, pre) do
    block_actions(%{tree: [], index: 1, lib_path: lib_path, pre: pre}, blocks)
  end

  defp block_actions(acc, [last_block]) do
    block_actions =
      acc
      |> add_block_action(last_block, :exit)
      |> Map.fetch!(:tree)
      |> Map.new()

    wrapper_actions = %{
      put_pre: %Action{
        runnable: {:puts, [], format_pre(acc.pre)},
        next_action: @first_block_action_key
      }
    }

    %{entry_point: :put_pre, actions_tree: Map.merge(wrapper_actions, block_actions)}
  end

  defp block_actions(acc, [block, next_block | rest]) do
    acc
    |> add_block_action(block, :"git_diff_#{acc.index + 1}")
    |> block_actions([next_block | rest])
  end

  defp add_block_action(acc, block, next_explanation_action_key) do
    %{tree: tree, index: index, lib_path: lib_path} = acc
    explanation_key = :"put_explanation_#{index}"

    git_diff =
      {:"git_diff_#{index}",
       %Action{
         runnable: {:git_diff, lib_path, block.search, block.replace},
         next_action: %{0 => explanation_key, :fallback => :exit}
       }}

    explanation =
      {explanation_key,
       %Action{
         runnable: {:puts, :magenta, block.explanation},
         next_action: next_explanation_action_key
       }}

    %{acc | tree: [git_diff, explanation | tree], index: index + 1}
  end

  defp format_pre(pre) do
    """
    *******************************
    ******* Claude Response *******
    *******************************
    #{pre}
    """
  end
end
