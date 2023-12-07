defmodule PolyglotWatcherV2.Branches do
  def branches(roots, deps) do
    Enum.flat_map(roots, fn root -> branch(root, deps, [root]) end)
  end

  defp branch(node, deps, path) do
    case Map.get(deps, node) do
      nil -> raise KeyError, "KeyError: key #{node} not found"
      [] -> [path]
      direct_deps -> Enum.flat_map(direct_deps, &branch(&1, deps, path ++ [&1]))
    end
  end
end
