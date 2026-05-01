defmodule PolyglotWatcherV2.MCP.Tools.MixTestKnownFailures do
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestOutputTruncator, as: OutputTruncator

  @note "Only tests known to be failing appear here. Tests not yet executed in this session are not represented."

  @tool_definition %{
    "name" => "mix_test_known_failures",
    "description" =>
      "Returns failing tests captured in the watcher's in-memory cache from prior `mix_test` runs. " <>
        "Does NOT scan the project — tests that haven't been executed in this session won't appear. " <>
        "If the cache is empty, run `mix_test` first to populate it.",
    "inputSchema" => %{
      "type" => "object",
      "properties" => %{}
    }
  }

  def definition, do: @tool_definition

  def call(_arguments) do
    %{
      failures: failures,
      total_failing_test_files: total_failing_test_files,
      total_failing_lines: total_failing_lines
    } = Cache.get_known_failures()

    payload = %{
      known_failures: Enum.map(failures, &format_failure/1),
      cache_summary: %{
        total_failing_test_files: total_failing_test_files,
        total_failing_lines: total_failing_lines,
        note: @note
      }
    }

    payload
    |> maybe_add_next_action(failures)
    |> Jason.encode!()
  end

  defp maybe_add_next_action(payload, []),
    do: Map.put(payload, :next_action, "Run mix_test (no args) to populate the cache.")

  defp maybe_add_next_action(payload, _failures), do: payload

  defp format_failure(item) do
    %{
      test_path: item.test_path,
      lib_path: item.lib_path,
      failed_lines: item.failed_line_numbers,
      output_snippet: item.mix_test_output |> strip_ansi() |> OutputTruncator.truncate()
    }
  end

  defp strip_ansi(nil), do: nil
  defp strip_ansi(text), do: String.replace(text, ~r/\e\[[0-9;]*m/, "")
end
