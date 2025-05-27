defmodule PolyglotWatcherV2.Elixir.AI.ReplaceMode.UserInputActions do
  alias PolyglotWatcherV2.Action

  @yes "y\n"
  @no "n\n"

  def determine(
        user_input,
        %{elixir: %{mode: :ai_replace}, ai_state: %{phase: :waiting}} = server_state
      ) do
    do_determine(user_input, server_state)
  end

  def determine(_, server_state) do
    {false, server_state}
  end

  defp do_determine(@yes, server_state) do
    {%{
       entry_point: :patch_files,
       actions_tree: %{
         patch_files: %Action{
           runnable: {:patch_files, :all},
           next_action: :exit
         }
       }
     }, %{server_state | ai_state: %{}, ignore_file_changes: false}}
  end

  defp do_determine(@no, server_state) do
    {%{
       entry_point: :put_msg,
       actions_tree: %{
         put_msg: %Action{
           runnable: {:puts, :magenta, "Ok, ignoring the rest of the suggestion(s)..."},
           next_action: :exit
         }
       }
     }, %{server_state | ai_state: %{}, file_patches: nil, ignore_file_changes: false}}
  end

  defp do_determine(user_input, server_state) do
    user_input
    |> String.trim_trailing("\n")
    |> String.split(",")
    |> Enum.reduce_while([], fn patch_index, acc ->
      case Integer.parse(patch_index) do
        {int, ""} -> {:cont, [int | acc]}
        _ -> {:halt, :error}
      end
    end)
    |> case do
      :error -> bad_input_actions(server_state)
      patch_indices -> patch_indices |> Enum.reverse() |> patch_with_indices_actions(server_state)
    end
  end

  defp patch_with_indices_actions(patch_indices, server_state) do
    if patch_indices_valid?(patch_indices, server_state[:file_patches]) do
      valid_patch_with_indices_actions(patch_indices, server_state)
    else
      invalid_patch_indices_actions(server_state)
    end
  end

  defp patch_indices_valid?(provided, file_patches) do
    real = real_patch_indices(file_patches)
    MapSet.subset?(MapSet.new(provided), MapSet.new(real))
  end

  defp real_patch_indices(file_patches) do
    Enum.flat_map(file_patches, fn {_, %{patches: patches}} -> Enum.map(patches, & &1.index) end)
  end

  defp valid_patch_with_indices_actions(patch_indices, server_state) do
    {%{
       entry_point: :patch_files,
       actions_tree: %{
         patch_files: %Action{
           runnable: {:patch_files, patch_indices},
           next_action: %{
             {:ok, :cont} => :put_cont_msg,
             {:ok, :done} => :put_done_msg,
             :fallback => :reset_server_state
           }
         },
         put_cont_msg: %Action{
           runnable: {:puts, :magenta, "Ok, what about the other suggestions?"},
           next_action: :exit
         },
         put_done_msg: %Action{
           runnable: {:puts, :magenta, "Finished processing suggestions"},
           next_action: :reset_server_state
         },
         reset_server_state: %Action{
           runnable: {:update_server_state, &reset_server_state/1},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp reset_server_state(server_state) do
    server_state
    |> Map.replace!(:ai_state, %{})
    |> Map.replace!(:ignore_file_changes, false)
  end

  defp invalid_patch_indices_actions(server_state) do
    {%{
       entry_point: :put_bad_patch_index_error,
       actions_tree: %{
         put_bad_patch_index_error: %Action{
           runnable:
             {:puts, :magenta,
              """
              You have me invalid suggestion number(s). Try again, providing any of:

              y - yes, write all suggestions
              n - no, write all suggestions
              1 - suggestion number to take
              1,2 - comma separated list of suggestion numbers to take

              You can give one number at a time, or all at once. We'll go again if you select one at a time.
              """},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp bad_input_actions(server_state) do
    {%{
       entry_point: :put_error_msg,
       actions_tree: %{
         put_error_msg: %Action{
           runnable:
             {:puts, :magenta,
              """
              I don't understand. Please supply one of:

              y - yes, write all suggestions
              n - no, write all suggestions
              1 - suggestion number to take
              1,2 - comma separated list of suggestion numbers to take

              You can give one number at a time, or all at once. We'll go again if you select one at a time.
              """},
           next_action: :exit
         }
       }
     }, server_state}
  end
end
