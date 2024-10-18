defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.DiffTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.Diff

  describe "build/2" do
    test "simple case" do
      old =
        [
          "defmodule CoolDude do",
          "  def make_cool(dude) do",
          "    dude",
          "  end",
          "end",
          ""
        ]

      new =
        [
          "defmodule CoolDude do",
          "  def make_cool(dude) do",
          "    \"cool \" <> dude",
          "  end",
          "end",
          ""
        ]

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[], "2 "},
        {[], " "},
        {[], "  def make_cool(dude) do\n"},
        {[:dark_red_background], "3 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "    dude\n"},
        {[:dark_green_background], "4 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], ~s|    "cool " <> dude\n|},
        {[], "5 "},
        {[], " "},
        {[], "  end\n"},
        {[], "6 "},
        {[], " "},
        {[], "end\n"}
      ]

      assert Diff.build(new, old) == {:ok, expected}
    end

    test "works with string inputs rather than list" do
      old =
        """
        defmodule CoolDude do
          def make_cool(dude) do
            dude
          end
        end
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
          def make_cool(dude) do
            "cool " <> dude
          end
        end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[], "2 "},
        {[], " "},
        {[], "  def make_cool(dude) do\n"},
        {[:dark_red_background], "3 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "    dude\n"},
        {[:dark_green_background], "4 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], ~s|    "cool " <> dude\n|},
        {[], "5 "},
        {[], " "},
        {[], "  end\n"},
        {[], "6 "},
        {[], " "},
        {[], "end\n"}
      ]

      assert Diff.build(new, old) == {:ok, expected}
    end

    test "a mixture of deletions and additions work ok" do
      old =
        """
        defmodule CoolDude do
          alpha
          beta
          omega
          pi
        end
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
          alpha
          new1
          omega
          new2
        end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[], "2 "},
        {[], " "},
        {[], "  alpha\n"},
        {[:dark_red_background], "3 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  beta\n"},
        {[:dark_green_background], "4 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  new1\n"},
        {[], "5 "},
        {[], " "},
        {[], "  omega\n"},
        {[:dark_red_background], "6 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  pi\n"},
        {[:dark_green_background], "7 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  new2\n"},
        {[], "8 "},
        {[], " "},
        {[], "end\n"},
        {[], "9 "},
        {[], " "},
        {[], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "additions work ok" do
      old =
        """
        defmodule CoolDude do
        end
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
          amazing
          cool
          new
          additions
        end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[:dark_green_background], "2 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  amazing\n"},
        {[:dark_green_background], "3 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  cool\n"},
        {[:dark_green_background], "4 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  new\n"},
        {[:dark_green_background], "5 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  additions\n"},
        {[], "6 "},
        {[], " "},
        {[], "end\n"},
        {[], "7 "},
        {[], " "},
        {[], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "deletions work ok" do
      old =
        """
        defmodule CoolDude do
          some
          nonsense
          to be
          deleted
        end
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
        end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[:dark_red_background], "2 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  some\n"},
        {[:dark_red_background], "3 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  nonsense\n"},
        {[:dark_red_background], "4 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  to be\n"},
        {[:dark_red_background], "5 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  deleted\n"},
        {[], "6 "},
        {[], " "},
        {[], "end\n"},
        {[], "7 "},
        {[], " "},
        {[], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "empty strings may be put in ok" do
      old =
        """
        defmodule CoolDude do
        end
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
          ""
        end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[:dark_green_background], "2 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  \"\"\n"},
        {[], "3 "},
        {[], " "},
        {[], "end\n"},
        {[], "4 "},
        {[], " "},
        {[], "\n"}
      ]

      assert Diff.build(new, old) == {:ok, expected}
    end

    test "deleting lots works" do
      old =
        """
        defmodule CoolDude do
          def apple(apple) do
            apple
          end

          def banana(banana) do
            banana
          end

          def orange(orange) do
            orange
          end
        end
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
        end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[:dark_red_background], "2 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  def apple(apple) do\n"},
        {[:dark_red_background], "3 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "    apple\n"},
        {[:dark_red_background], "4 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  end\n"},
        {[:dark_green_background], "5 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "end\n"},
        {[], "6 "},
        {[], " "},
        {[], "\n"},
        {[:dark_red_background], "7 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  def banana(banana) do\n"},
        {[:dark_red_background], "8 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "    banana\n"},
        {[:dark_red_background], "9 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  end\n"},
        {[:dark_red_background], "10 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "\n"},
        {[:dark_red_background], "11 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  def orange(orange) do\n"},
        {[:dark_red_background], "12 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "    orange\n"},
        {[:dark_red_background], "13 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  end\n"},
        {[:dark_red_background], "14 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "end\n"},
        {[:dark_red_background], "15 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "adding lots works" do
      old =
        """
        defmodule CoolDude do
        end
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
          def apple(apple) do
            apple
          end

          def banana(banana) do
            banana
          end

          def orange(orange) do
            orange
          end
        end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[:dark_green_background], "2 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  def apple(apple) do\n"},
        {[:dark_green_background], "3 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "    apple\n"},
        {[:dark_green_background], "4 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  end\n"},
        {[:dark_green_background], "5 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "\n"},
        {[:dark_green_background], "6 "},
        {[:dark_green_background], "+"},
        {
          [:dark_green_background],
          "  def banana(banana) do\n"
        },
        {[:dark_green_background], "7 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "    banana\n"},
        {[:dark_green_background], "8 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  end\n"},
        {[:dark_green_background], "9 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "\n"},
        {[:dark_green_background], "10 "},
        {[:dark_green_background], "+"},
        {
          [:dark_green_background],
          "  def orange(orange) do\n"
        },
        {[:dark_green_background], "11 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "    orange\n"},
        {[:dark_green_background], "12 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  end\n"},
        {[], "13 "},
        {[], " "},
        {[], "end\n"},
        {[], "14 "},
        {[], " "},
        {[], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "the old file running out of lines is ok" do
      old =
        """
        defmodule CoolDude do
        """
        |> String.split("\n")

      new =
        """
        defmodule CoolDude do
          def apple(apple) do
            apple
          end

          def banana(banana) do
            banana
          end

          def orange(orange) do
            orange
          end
        """
        |> String.split("\n")

      expected = [
        {[], "1 "},
        {[], " "},
        {[], "defmodule CoolDude do\n"},
        {[:dark_green_background], "2 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  def apple(apple) do\n"},
        {[:dark_green_background], "3 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "    apple\n"},
        {[:dark_green_background], "4 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  end\n"},
        {[], "5 "},
        {[], " "},
        {[], "\n"},
        {[:dark_green_background], "6 "},
        {[:dark_green_background], "+"},
        {
          [:dark_green_background],
          "  def banana(banana) do\n"
        },
        {[:dark_green_background], "7 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "    banana\n"},
        {[:dark_green_background], "8 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  end\n"},
        {[:dark_green_background], "9 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "\n"},
        {[:dark_green_background], "10 "},
        {[:dark_green_background], "+"},
        {
          [:dark_green_background],
          "  def orange(orange) do\n"
        },
        {[:dark_green_background], "11 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "    orange\n"},
        {[:dark_green_background], "12 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  end\n"},
        {[:dark_green_background], "13 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "the first lines being different is handled ok" do
      old =
        """
        apple
        """
        |> String.split("\n")

      new =
        """
        orange
        """
        |> String.split("\n")

      expected = [
        {[:dark_red_background], "1 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "apple\n"},
        {[:dark_green_background], "2 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "orange\n"},
        {[], "3 "},
        {[], " "},
        {[], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "lots of the same content either side of the changed lines are removed" do
      old =
        """
        defmodule CoolDude do
          def apple(apple) do
            apple
          end

          def banana(banana) do
            banana
          end

          def orange(orange) do
            orange
          end

          def grape(grape) do
            grape
          end

          def coconut(coconut) do
            coconut
          end

          def blueberries(blueberries) do
            blueberries
          end
        end
        """
        |> String.split("\n")

      # orange turned to mango below
      new =
        """
        defmodule CoolDude do
          def apple(apple) do
            apple
          end

          def banana(banana) do
            banana
          end

          def mango(mango) do
            mango
          end

          def grape(grape) do
            grape
          end

          def coconut(coconut) do
            coconut
          end

          def blueberries(blueberries) do
            blueberries
          end
        end
        """
        |> String.split("\n")

      expected = [
        {[], "8 "},
        {[], " "},
        {[], "  end\n"},
        {[], "9 "},
        {[], " "},
        {[], "\n"},
        {[:dark_red_background], "10 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "  def orange(orange) do\n"},
        {[:dark_red_background], "11 "},
        {[:dark_red_background], "-"},
        {[:dark_red_background], "    orange\n"},
        {[:dark_green_background], "12 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "  def mango(mango) do\n"},
        {[:dark_green_background], "13 "},
        {[:dark_green_background], "+"},
        {[:dark_green_background], "    mango\n"},
        {[], "14 "},
        {[], " "},
        {[], "  end\n"},
        {[], "15 "},
        {[], " "},
        {[], "\n"}
      ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end

    test "same lines are removed when there's more than 1 replacement chunk" do
      old =
        """
        defmodule CoolDude do
          def apple(apple) do
            apple
          end

          def banana(banana) do
            banana
          end

          def orange(orange) do
            orange
          end

          def grape(grape) do
            grape
          end

          def coconut(coconut) do
            coconut
          end

          def blueberries(blueberries) do
            blueberries
          end
        end
        """
        |> String.split("\n")

      # banana -> cool
      # grape -> dude
      new =
        """
        defmodule CoolDude do
          def apple(apple) do
            apple
          end

          def cool(cool) do
            cool
          end

          def orange(orange) do
            orange
          end

          def dude(dude) do
            dude
          end

          def coconut(coconut) do
            coconut
          end

          def blueberries(blueberries) do
            blueberries
          end
        end
        """
        |> String.split("\n")

      expected =
        [
          {[], "4 "},
          {[], " "},
          {[], "  end\n"},
          {[], "5 "},
          {[], " "},
          {[], "\n"},
          {[:dark_red_background], "6 "},
          {[:dark_red_background], "-"},
          {[:dark_red_background], "  def banana(banana) do\n"},
          {[:dark_red_background], "7 "},
          {[:dark_red_background], "-"},
          {[:dark_red_background], "    banana\n"},
          {[:dark_green_background], "8 "},
          {[:dark_green_background], "+"},
          {[:dark_green_background], "  def cool(cool) do\n"},
          {[:dark_green_background], "9 "},
          {[:dark_green_background], "+"},
          {[:dark_green_background], "    cool\n"},
          {[], "10 "},
          {[], " "},
          {[], "  end\n"},
          {[], "11 "},
          {[], " "},
          {[], "\n"},
          {[], "14 "},
          {[], " "},
          {[], "  end\n"},
          {[], "15 "},
          {[], " "},
          {[], "\n"},
          {[:dark_red_background], "16 "},
          {[:dark_red_background], "-"},
          {[:dark_red_background], "  def grape(grape) do\n"},
          {[:dark_red_background], "17 "},
          {[:dark_red_background], "-"},
          {[:dark_red_background], "    grape\n"},
          {[:dark_green_background], "18 "},
          {[:dark_green_background], "+"},
          {[:dark_green_background], "  def dude(dude) do\n"},
          {[:dark_green_background], "19 "},
          {[:dark_green_background], "+"},
          {[:dark_green_background], "    dude\n"},
          {[], "20 "},
          {[], " "},
          {[], "  end\n"},
          {[], "21 "},
          {[], " "},
          {[], "\n"}
        ]

      assert {:ok, result} = Diff.build(new, old)
      assert result == expected
    end
  end
end
