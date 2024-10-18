defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.LibContentsTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.{LibContents, ReplaceBlock}

  describe "replace/2" do
    test "simple case" do
      lib =
        """
        defmodule CoolDude do
          def make_cool(dude) do
            dude
          end
        end
        """
        |> String.split("\n")

      search =
        """
          def make_cool(dude) do
            dude
          end
        """

      replace =
        """
          def make_cool(dude) do
            "cool " <> dude
          end
        """

      expected =
        """
        defmodule CoolDude do
          def make_cool(dude) do
            "cool " <> dude
          end
        end
        """
        |> String.split("\n")

      block = %ReplaceBlock{
        search: search,
        replace: replace,
        explanation: "n/a"
      }

      assert {:ok, expected} == LibContents.replace(block, lib)
    end

    test "simple replacement with larger file" do
      lib =
        """
        defmodule CoolDude do
          def one(n) do
            n + 1
          end

          def two(n) do
            n
          end

          def three(n) do
            n + 3
          end
        end
        """
        |> String.split("\n")

      search =
        """
          def two(n) do
            n
          end
        """

      replace =
        """
          def two(n) do
            n + 2
          end
        """

      expected =
        """
        defmodule CoolDude do
          def one(n) do
            n + 1
          end

          def two(n) do
            n + 2
          end

          def three(n) do
            n + 3
          end
        end
        """
        |> String.split("\n")

      block = %ReplaceBlock{
        search: search,
        replace: replace,
        explanation: "n/a"
      }

      assert {:ok, expected} == LibContents.replace(block, lib)
    end

    test "complex multi-line replacements, with lines left as-is in the middle" do
      lib =
        """
        defmodule CoolDude do
          def one(n) do
            raise "no"
          end

          def two(n) do
            n + 2
          end

          kJSsdk"

          def three(n) do, asdkj
            n + 4
          end
        end
        """
        |> String.split("\n")

      search =
        """
        defmodule CoolDude do
          def one(n) do
            raise "no"
          end

          def two(n) do
            n + 2
          end

          kJSsdk"

          def three(n) do, asdkj
            n + 4
          end
        end
        """

      replace =
        """
        defmodule CoolDude do
          def one(n) do
            n + 1
          end

          def two(n) do
            n + 2
          end

          def three(n) do
            n + 3
          end
        end
        """

      expected =
        """
        defmodule CoolDude do
          def one(n) do
            n + 1
          end

          def two(n) do
            n + 2
          end

          def three(n) do
            n + 3
          end
        end
        """
        |> String.split("\n")

      block = %ReplaceBlock{
        search: search,
        replace: replace,
        explanation: "n/a"
      }

      assert {:ok, expected} == LibContents.replace(block, lib)
    end

    test "Joining into a string with newline forms the expected result" do
      lib =
        """
        defmodule CoolDude do
          def one(n) do
            raise "no"
          end

          def two(n) do
            n + 2
          end

          kJSsdk"

          def three(n) do, asdkj
            n + 4
          end
        end
        """
        |> String.split("\n")

      search =
        """
        defmodule CoolDude do
          def one(n) do
            raise "no"
          end

          def two(n) do
            n + 2
          end

          kJSsdk"

          def three(n) do, asdkj
            n + 4
          end
        end
        """

      replace =
        """
        defmodule CoolDude do
          def one(n) do
            n + 1
          end

          def two(n) do
            n + 2
          end

          def three(n) do
            n + 3
          end
        end
        """

      expected =
        """
        defmodule CoolDude do
          def one(n) do
            n + 1
          end

          def two(n) do
            n + 2
          end

          def three(n) do
            n + 3
          end
        end
        """

      block = %ReplaceBlock{
        search: search,
        replace: replace,
        explanation: "n/a"
      }

      assert {:ok, result} = LibContents.replace(block, lib)

      assert Enum.join(result, "\n") == expected
    end
  end
end
