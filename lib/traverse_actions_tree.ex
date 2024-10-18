defmodule PolyglotWatcherV2.TraverseActionsTree do
  alias PolyglotWatcherV2.{Action, ActionsExecutor}

  def execute_all({:none, server_state}) do
    server_state
  end

  def execute_all({%{entry_point: entry_point, actions_tree: actions_tree}, server_state}) do
    execute_all(entry_point, actions_tree, server_state)
  end

  defp execute_all(action_name, actions_tree, server_state) do
    action_name = Map.fetch!(actions_tree, action_name)
    {next_action_name, server_state} = execute_one(action_name, server_state)

    case next_action_name do
      :exit -> server_state
      :quit_the_program -> System.stop(0)
      # TODO test this or remove it
      :execute_stored_actions -> execute_stored_actions(server_state)
      next_action_name -> execute_all(next_action_name, actions_tree, server_state)
    end
  end

  # TODO test this or remove it
  defp execute_stored_actions(server_state) do
    case server_state[:stored_actions] do
      nil -> {1, server_state}
      tree -> execute_all({tree, server_state})
    end
  end

  defp execute_one(%Action{runnable: runnable, next_action: next_action}, server_state) do
    {exit_code, server_state} = ActionsExecutor.execute(runnable, server_state)

    next_action_name =
      case next_action do
        %{fallback: fallback} ->
          Map.get(next_action, exit_code, fallback)

        action_name ->
          action_name
      end

    {next_action_name, server_state}
  end
end
