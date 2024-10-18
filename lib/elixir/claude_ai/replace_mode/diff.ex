defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.Diff do
  @same " "
  @symbols %{same: @same, add: "+", remove: "-"}

  # TODO this is broken. fixed it. produces horrendously large diffs for small search / replaces
  # see https://hexdocs.pm/elixir/1.12/String.html#myers_difference/2

  def build(new, old) do
    build(%{diff: [], index: 1}, new, Enum.with_index(old, 1))
  end

  defp build(acc, [], []) do
    result =
      acc.diff
      # |> truncate()
      |> Enum.reverse()

    {:ok, result}
  end

  defp build(%{diff: []} = acc, [same | new], [{same, index} | old]) do
    add_same_line(%{acc | index: index}, same, new, old)
  end

  defp build(acc, [same | new], [{same, _} | old]) do
    add_same_line(acc, same, new, old)
  end

  defp build(acc, [], [{old_line, _} | old]) do
    add_removed_line(acc, old_line, [], old)
  end

  defp build(acc, [new_line | new], []) do
    add_added_line(acc, new_line, new, [])
  end

  defp build(acc, [new_line | new], [{old_line, index} | old]) do
    if Enum.find(new, fn line -> old_line == line end) do
      add_added_line(acc, new_line, new, [{old_line, index} | old])
    else
      add_removed_line(acc, old_line, [new_line | new], old)
    end
  end

  defp add_same_line(acc, line, new, old) do
    acc
    |> add_line(line, @symbols.same, [])
    |> build(new, old)
  end

  defp add_added_line(acc, line, new, old) do
    acc
    |> add_line(line, @symbols.add, [:dark_green_background])
    |> build(new, old)
  end

  defp add_removed_line(acc, line, new, old) do
    acc
    |> add_line(line, @symbols.remove, [:dark_red_background])
    |> build(new, old)
  end

  defp add_line(acc, line, symbol, styles) do
    diff =
      [
        {styles, line <> "\n"},
        {styles, symbol},
        {styles, "#{acc.index} "} | acc.diff
      ]

    %{acc | diff: diff, index: acc.index + 1}
  end

  # TODO test this truncation some more
  # TODO add number padding for mixed length numbers e.g. 9, 10; 99, 100; 999, 1000
  # TODO add a divider for when we truncate in the middle?
  # defp truncate(diff) do
  #  truncate([], diff)
  # end

  # defp truncate(acc, []) do
  #  Enum.reverse(acc)
  # end

  # defp truncate(acc, diff) do
  #  if should_truncate?(acc, diff) do
  #    truncate(acc, Enum.drop(diff, 3))
  #  else
  #    {to_add, diff} = Enum.split(diff, 3)
  #    acc = Enum.reduce(to_add, acc, fn item, inner_acc -> [item | inner_acc] end)
  #    truncate(acc, diff)
  #  end
  # end

  # defp should_truncate?(acc, diff) do
  #  last_two_acc_the_same?(acc) && last_two_diff_the_same?(diff)
  # end

  # defp last_two_acc_the_same?([]) do
  #  true
  # end

  # defp last_two_acc_the_same?(acc) do
  #  acc
  #  |> tl()
  #  |> Enum.take_every(3)
  #  |> Enum.take(2)
  #  |> Enum.all?(fn {_, symbol} -> symbol == @same end)
  # end

  # defp last_two_diff_the_same?(_diff = []) do
  #  false
  # end

  # defp last_two_diff_the_same?(diff) do
  #  diff
  #  |> tl()
  #  |> Enum.take_every(3)
  #  |> Enum.take(3)
  #  |> Enum.all?(fn {_, symbol} -> symbol == @same end)
  # end
end
