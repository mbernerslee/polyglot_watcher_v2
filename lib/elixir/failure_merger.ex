defmodule PolyglotWatcherV2.Elixir.FailureMerger do
  def merge(old, new) do
    ordered_paths = order_paths(old, new)

    merge([], [], ordered_paths, Enum.reverse(old) ++ Enum.reverse(new), [])
  end

  def merge(acc, fail_path_group, [], [], []) do
    fail_path_group ++ acc
  end

  def merge(acc, fail_path_group, [_path | paths], [], discards) do
    merge(fail_path_group ++ acc, [], paths, Enum.reverse(discards), [])
  end

  def merge(acc, fail_path_group, [path | paths], [fail | failures], discards) do
    {fail_path, _} = fail

    if fail_path == path do
      merge(acc, [fail | fail_path_group], [path | paths], failures, discards)
    else
      merge(acc, fail_path_group, [path | paths], failures, [fail | discards])
    end
  end

  defp order_paths(old, new), do: do_order_paths([], new ++ old)

  defp do_order_paths(ordered, []) do
    ordered
  end

  defp do_order_paths(ordered, [{path, _} | rest]) do
    if Enum.member?(ordered, path) do
      do_order_paths(ordered, rest)
    else
      do_order_paths([path | ordered], rest)
    end
  end
end
