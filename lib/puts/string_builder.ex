defmodule PolyglotWatcherV2.Puts.StringBuilder do
  @styles %{
    magenta: IO.ANSI.magenta(),
    light_magenta: IO.ANSI.light_magenta(),
    light_green: IO.ANSI.light_green(),
    green: IO.ANSI.green(),
    dark_green_background: IO.ANSI.color_background(0, 1, 0),
    dark_red_background: IO.ANSI.color_background(1, 0, 0),
    red: IO.ANSI.red(),
    cyan: IO.ANSI.cyan(),
    light_cyan: IO.ANSI.light_cyan(),
    white: IO.ANSI.white(),
    light_white: IO.ANSI.light_white(),
    yellow: IO.ANSI.yellow(),
    italic: IO.ANSI.italic(),
    bright: IO.ANSI.bright(),
    strikethrough: "\e[9m",
    previous_line: "\e[1A\e[K"
  }

  if Mix.env() == :test do
    def styles, do: @styles
  end

  def build(styles, message) when is_list(styles) do
    style_codes =
      Enum.map(styles, fn style ->
        case @styles[style] do
          nil -> raise "I don't recognise the style '#{style}'"
          code -> code
        end
      end)

    Enum.join(style_codes) <> message <> IO.ANSI.reset()
  end

  def build(style, message) do
    build([style], message)
  end

  def build(messages) when is_list(messages) do
    build_many(messages, "")
  end

  def build(message) do
    build(:magenta, message)
  end

  defp build_many([], acc), do: acc

  defp build_many([{style, message} | rest], acc) do
    build_many(rest, acc <> build(style, message))
  end
end
