defmodule PolyglotWatcherV2.MCP.Tools.RunTests do
  alias PolyglotWatcherV2.Elixir.MixTest
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  @tool_definition %{
    "name" => "run_tests",
    "description" =>
      "Runs the specified Elixir test(s) via mix test and returns the output. " <>
        "If the same test is already running (e.g. triggered by a file save), " <>
        "waits for that run to finish and returns its result instead of running again. " <>
        "Use this instead of running mix test directly.",
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
        }
      }
    }
  }

  def definition, do: @tool_definition

  def call(arguments) do
    mix_test_args = build_args(arguments)
    {output, exit_code} = MixTest.run(mix_test_args)

    Jason.encode!(%{
      exit_code: exit_code,
      output: strip_ansi(output),
      test_path: format_path(mix_test_args.path)
    })
  end

  defp build_args(%{"test_path" => test_path, "line_number" => line})
       when is_binary(test_path) and test_path != "" and is_integer(line) do
    %MixTestArgs{path: {test_path, line}}
  end

  defp build_args(%{"test_path" => test_path})
       when is_binary(test_path) and test_path != "" do
    %MixTestArgs{path: test_path}
  end

  defp build_args(_), do: %MixTestArgs{path: :all}

  defp strip_ansi(text), do: String.replace(text, ~r/\e\[[0-9;]*m/, "")

  defp format_path({path, line}), do: "#{path}:#{line}"
  defp format_path(:all), do: "all"
  defp format_path(path), do: path
end
