defmodule PolyglotWatcherV2.Branches do
  def branches(paths, tree) do
  end

  # def branches(roots, deps) do
  #  roots
  #  |> Enum.flat_map(&walk(&1, [], deps))
  # end

  # defp walk(node, path, deps) do
  #  new_path = [node | path]

  #  case deps[node] do
  #    [] -> [Enum.reverse(new_path)]
  #    children -> children |> Enum.flat_map(&walk(&1, new_path, deps))
  #  end
  # end
end
