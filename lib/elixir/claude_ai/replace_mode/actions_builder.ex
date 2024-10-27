defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ActionsBuilder do
  alias PolyglotWatcherV2.Action

  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.ReplaceBlocks

  @first_block_action_key :git_diff_1

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
        runnable: {:puts, :magenta, acc.pre},
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

  ## functioning hack to get a git diff working
  # TODO remove this later once the real thing is done

  # tmp_dir = "/tmp/polyglot_watcher_v2"
  # lib_path = tmp_dir <> "/lib"
  # new_lib_path = tmp_dir <> "/new_lib"
  # File.mkdir_p(tmp_dir)
  # File.write!(lib_path, Enum.join(lib, "\n"))
  # File.write!(new_lib_path, Enum.join(new_lib, "\n"))

  # {std_out, exit_code} =
  #  System.cmd("git", ["diff", "--no-index", "--color", lib_path, new_lib_path],
  #    stderr_to_stdout: true
  #  )

  ## IO.inspect "exit code #{exit_code}"
  # IO.puts(std_out)
  # IO.puts(" Explanation ****************************")
  # IO.puts(block.explanation)

  # defp build_block_actions(block, lib, _block_number) do
  #  with {:ok, new_lib} <- LibContents.replace(block, lib),
  #       {:ok, diff} <- Diff.build(new_lib, lib) do
  #    {:ok, new_lib, diff}
  #  end
  # end
end
