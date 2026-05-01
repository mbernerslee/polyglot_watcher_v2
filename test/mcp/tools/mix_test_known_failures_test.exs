defmodule PolyglotWatcherV2.MCP.Tools.MixTestKnownFailuresTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.Tools.MixTestKnownFailures
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.Cache.CacheItem

  describe "call/1" do
    test "returns known_failures payload built from the cache" do
      Mimic.expect(Cache, :get_known_failures, fn ->
        %{
          failures: [
            %CacheItem{
              test_path: "test/cool_test.exs",
              lib_path: "lib/cool.ex",
              failed_line_numbers: [10, 42],
              mix_test_output: "boom",
              rank: 1
            }
          ],
          total_failing_test_files: 1,
          total_failing_lines: 2
        }
      end)

      result = MixTestKnownFailures.call(%{})
      decoded = Jason.decode!(result)

      assert %{
               "known_failures" => [
                 %{
                   "test_path" => "test/cool_test.exs",
                   "lib_path" => "lib/cool.ex",
                   "failed_lines" => [10, 42],
                   "output_snippet" => "boom"
                 }
               ],
               "cache_summary" => %{
                 "total_failing_test_files" => 1,
                 "total_failing_lines" => 2,
                 "note" => note
               }
             } = decoded

      assert is_binary(note)
      refute Map.has_key?(decoded, "next_action")
    end

    test "strips ANSI from output_snippet and truncates very long output" do
      long_output =
        "header\n\n" <>
          (Enum.map_join(1..50, "\n\n", fn i -> "  #{i}) test foo\n\e[31mline a\e[0m\nline b\nline c" end)) <>
          "\n\n50 tests, 50 failures"

      Mimic.expect(Cache, :get_known_failures, fn ->
        %{
          failures: [
            %CacheItem{
              test_path: "test/big_test.exs",
              lib_path: "lib/big.ex",
              failed_line_numbers: [1],
              mix_test_output: long_output,
              rank: 1
            }
          ],
          total_failing_test_files: 1,
          total_failing_lines: 1
        }
      end)

      result = MixTestKnownFailures.call(%{})
      decoded = Jason.decode!(result)

      [%{"output_snippet" => snippet}] = decoded["known_failures"]

      refute snippet =~ "\e["
      assert String.length(snippet) < String.length(long_output)
      assert snippet =~ "header"
      assert snippet =~ "50 tests, 50 failures"
    end

    test "empty cache returns empty list with next_action hint" do
      Mimic.expect(Cache, :get_known_failures, fn ->
        %{failures: [], total_failing_test_files: 0, total_failing_lines: 0}
      end)

      result = MixTestKnownFailures.call(%{})
      decoded = Jason.decode!(result)

      assert %{
               "known_failures" => [],
               "cache_summary" => %{
                 "total_failing_test_files" => 0,
                 "total_failing_lines" => 0
               },
               "next_action" => next_action
             } = decoded

      assert next_action =~ "mix_test"
    end
  end
end
