defmodule PolyglotWatcherV2.InvalidActionsTreeError do
  defexception [:message]
end

defmodule PolyglotWatcherV2.ActionsTreeValidator do
  alias PolyglotWatcherV2.ServerStateBuilder
  alias PolyglotWatcherV2.ActionsExecutor
  alias PolyglotWatcherV2.{Action, InvalidActionsTreeError}

  def validate(%{entry_point: entry_point, actions_tree: actions_tree}) do
    check_entry_point_exists_in_tree(entry_point, actions_tree)
    check_all_actions_are_structs(actions_tree)
    has_at_least_one_exit_point(actions_tree)
    check_all_next_actions_exist(entry_point, actions_tree)
    validate_all_runnables_exist(actions_tree)
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
        %{next_action: %{fallback: _} = next_action} ->
          Map.values(next_action)

        %{next_action: %{} = next_action} ->
          error =
            """
            I require next_actions to be either:

            - an atom
                Signifying that no matter what happened, run the action with this key
            - a map
                Which MUST contain the :fallback key, signifying what to do if there is no matching exit_code found in the next_actions map

            And sadly I found a map which did not contain :fallback as a next action in the tree!

            The bad next_action was #{inspect(next_action)}
            """

          raise InvalidActionsTreeError, error

        %{next_action: next_action} ->
          [next_action]
      end)
      |> MapSet.new()
      |> MapSet.delete(:exit)
      |> MapSet.delete(:execute_stored_actions)
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

  defp validate_all_runnables_exist(actions_tree) do
    actions_tree
    |> Enum.map(fn {_, %{runnable: runnable}} -> runnable end)
    |> Enum.each(fn runnable ->
      {_, _} = ActionsExecutor.execute(runnable, ServerStateBuilder.build())
    end)
  end
end
