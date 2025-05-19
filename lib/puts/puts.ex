defmodule PolyglotWatcherV2.Puts do
  alias PolyglotWatcherV2.Puts.StringBuilder

  def on_new_line(message, style) do
    style
    |> StringBuilder.build(message)
    |> IO.puts()
  end

  def on_new_line(messages) do
    messages
    |> StringBuilder.build()
    |> IO.puts()
  end

  def on_new_line_unstyled(message), do: IO.puts(message)
end
