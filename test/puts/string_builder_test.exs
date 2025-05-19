defmodule PolyglotWatcherV2.Puts.StringBuilderTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Puts.StringBuilder

  @styles StringBuilder.styles()

  describe "build/2" do
    test "builds a string with a single style" do
      result = StringBuilder.build(:magenta, "Hello")
      assert String.starts_with?(result, IO.ANSI.magenta())
      assert String.ends_with?(result, IO.ANSI.reset())
      assert String.contains?(result, "Hello")
    end

    test "setting every style works" do
      Enum.each(@styles, fn {style, ansi_code} ->
        result = StringBuilder.build(style, "Hello")
        assert String.starts_with?(result, ansi_code)
        assert String.ends_with?(result, IO.ANSI.reset())
        assert String.contains?(result, "Hello")
      end)
    end

    test "setting arbitrary combinations of styles works" do
      result = StringBuilder.build([:magenta, :bright, :italic], "Hello")

      assert String.starts_with?(
               result,
               IO.ANSI.magenta() <> IO.ANSI.bright() <> IO.ANSI.italic()
             )

      assert String.ends_with?(result, IO.ANSI.reset())
      assert String.contains?(result, "Hello")
    end

    test "works given a list of many messages with many styles" do
      messages = [
        {:magenta, "Hello"},
        {:bright, "World"},
        {[:strikethrough, :italic], "!"},
        {[:yellow, :bright], "Elixir"}
      ]

      result = StringBuilder.build(messages)

      expected =
        IO.ANSI.magenta() <>
          "Hello" <>
          IO.ANSI.reset() <>
          IO.ANSI.bright() <>
          "World" <>
          IO.ANSI.reset() <>
          @styles.strikethrough <>
          IO.ANSI.italic() <>
          "!" <>
          IO.ANSI.reset() <>
          IO.ANSI.yellow() <>
          IO.ANSI.bright() <>
          "Elixir" <> IO.ANSI.reset()

      assert result == expected
    end
  end

  describe "build/1" do
    test "builds a string with default style (magenta)" do
      result = StringBuilder.build("Hello")
      assert String.starts_with?(result, IO.ANSI.magenta())
      assert String.ends_with?(result, IO.ANSI.reset())
      assert String.contains?(result, "Hello")
    end
  end
end
