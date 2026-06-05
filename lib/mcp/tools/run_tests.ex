defmodule PolyglotWatcherV2.MCP.Tools.RunTests do
  alias PolyglotWatcherV2.Elixir.MixTest
  alias PolyglotWatcherV2.Elixir.MixTestOutputTruncator, as: OutputTruncator
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  @tool_definition %{
    "name" => "mix_test",
    "description" =>
      "MANDATORY: You MUST use this tool instead of running `mix test` via the shell. " <>
        "Never run `mix test` directly — always call this tool. " <>
        "Runs the specified Elixir test(s) and returns the output. " <>
        "If the same test is already running (e.g. triggered by a file save), " <>
        "waits for that run to finish and returns its result instead of running again.",
    "inputSchema" => %{
      "type" => "object",
      "properties" => %{
        "test_path" => %{
          "type" => "string",
          "description" =>
            "Test file path to run, e.g. \"test/my_test.exs\". Omit to run all tests."
        },
        "line_number" => %{
          "type" => "integer",
          "description" =>
            "Optional line number to run a specific test, e.g. 42 for test/my_test.exs:42."
        },
        "extra_args" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" =>
            "Optional extra flags to pass to `mix test`, e.g. [\"--slowest\", \"5\"]. " <>
              "Only use for ad-hoc diagnostics — when present, the watcher does NOT serve a " <>
              "cached result or de-dup against an in-flight run (failures are still recorded), " <>
              "and unrecognized flags are treated as worst-case for cache safety."
        }
      }
    }
  }

  def definition, do: @tool_definition

  def call(arguments) do
    mix_test_args = build_args(arguments)

    {output, exit_code} = MixTest.run(mix_test_args, use_cache: :cached, source: :mcp, pre_message: "MCP request received...")

    Jason.encode!(%{
      command: MixTestArgs.to_shell_command(mix_test_args),
      exit_code: exit_code,
      output: output |> strip_ansi() |> OutputTruncator.truncate(),
      test_path: format_path(mix_test_args.path)
    })
  end

  defp build_args(arguments) do
    arguments
    |> base_args()
    |> Map.put(:extra_args, extra_args(arguments))
  end

  defp base_args(%{"test_path" => test_path, "line_number" => line})
       when is_binary(test_path) and test_path != "" and is_integer(line) do
    file =
      case MixTestArgs.to_path(test_path) do
        {:ok, {file, _embedded_line}} -> file
        {:ok, file} -> file
        :error -> test_path
      end

    %MixTestArgs{path: {file, line}}
  end

  defp base_args(%{"test_path" => test_path})
       when is_binary(test_path) and test_path != "" do
    case MixTestArgs.to_path(test_path) do
      {:ok, parsed} -> %MixTestArgs{path: parsed}
      :error -> %MixTestArgs{path: test_path}
    end
  end

  defp base_args(_), do: %MixTestArgs{path: :all}

  defp extra_args(%{"extra_args" => extra}) when is_list(extra), do: extra
  defp extra_args(_), do: []

  defp strip_ansi(text), do: String.replace(text, ~r/\e\[[0-9;]*m/, "")

  defp format_path({path, line}), do: "#{path}:#{line}"
  defp format_path(:all), do: "all"
  defp format_path(path), do: path
end
