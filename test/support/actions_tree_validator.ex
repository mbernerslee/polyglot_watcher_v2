defmodule PolyglotWatcherV2.InvalidActionsTreeError do
  defexception [:message]
end

defmodule PolyglotWatcherV2.ActionsTreeValidator do
  alias PolyglotWatcherV2.{Action, InvalidActionsTreeError}

  def validate(%{entry_point: entry_point, actions_tree: actions_tree}) do
    check_entry_point_exists_in_tree(entry_point, actions_tree)
    check_all_actions_are_structs(actions_tree)
    has_at_least_one_exit_point(actions_tree)
    check_all_next_actions_exist(entry_point, actions_tree)
    true
  end

  defmacro assert_exact_keys(tree, expected_keys) do
    quote do
      %{actions_tree: actions_tree} = unquote(tree)
      actual_action_tree_keys = actions_tree |> Map.keys() |> MapSet.new()
      expected_action_tree_keys = MapSet.new(unquote(expected_keys))
      assert actual_action_tree_keys == expected_action_tree_keys
    end
  end

  defp check_all_next_actions_exist(entry_point, actions_tree) do
    actions_that_exist =
      actions_tree
      |> Map.keys()
      |> MapSet.new()

    next_actions =
      actions_tree
      |> Map.values()
      |> Enum.flat_map(fn
        %{next_action: %{} = next_action} -> Map.values(next_action)
        %{next_action: next_action} -> [next_action]
      end)
      |> MapSet.new()
      |> MapSet.delete(:exit)
      |> MapSet.put(entry_point)

    unless actions_that_exist == next_actions do
      raise InvalidActionsTreeError,
            "I require all 'next_actions' in the tree to exist within it, but some 'next_actions' we're pointing to don't exist in the tree #{inspect(MapSet.difference(actions_that_exist, next_actions))}"
    end
  end

  defp check_entry_point_exists_in_tree(entry_point, actions_tree) do
    unless actions_tree |> Map.keys() |> Enum.member?(entry_point) do
      raise InvalidActionsTreeError,
            "I require the entry_point to exist in the action_tree, but '#{entry_point}' was not found in #{inspect(actions_tree)}"
    end
  end

  defp check_all_actions_are_structs(actions_tree) do
    unless actions_tree
           |> Map.values()
           |> Enum.all?(fn action -> match?(%Action{}, action) end) do
      raise InvalidActionsTreeError,
            "I require all actions in the tree to be %Action{} structs, but at least one wasn't in #{inspect(actions_tree)}"
    end
  end

  defp has_at_least_one_exit_point(actions_tree) do
    has_at_least_one_exit_point? =
      actions_tree
      |> Map.values()
      |> Enum.map(fn action -> action.next_action end)
      |> Enum.any?(fn
        :exit -> true
        %{} = map -> map |> Map.values() |> Enum.any?(&(&1 == :exit))
        _ -> false
      end)

    unless has_at_least_one_exit_point? do
      raise InvalidActionsTreeError,
            "I require at least one exit point from the actions tree, but found none in #{inspect(actions_tree)}"
    end
  end
end
