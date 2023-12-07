defmodule PolyglotWatcherV2.Stacktrace do
  def find_files(test_output) do
    find_files([], :test, String.split(test_output, "\n"))
  end

  defp find_files(acc, _, []) do
    Enum.reverse(acc)
  end

  defp find_files(acc, :test, [line | lines]) do
    case Regex.named_captures(~r|^\s+(?<test>[0-9]+\) test .*$)|, line) do
      %{"test" => test} ->
        find_files(acc, {:stacktrace, test}, lines)

      _ ->
        find_files(acc, :test, lines)
    end
  end

  defp find_files(acc, {:stacktrace, test}, [line | lines]) do
    case Regex.named_captures(~r|(?<stacktrace>stacktrace:)|, line) do
      %{"stacktrace" => _stackrace} ->
        find_files(acc, {:stacktrace, test, %{raw: "", files: []}}, lines)

      _ ->
        find_files(acc, {:stacktrace, test}, lines)
    end
  end

  defp find_files(acc, {:stacktrace, test, stacktrace}, [line | lines]) do
    %{raw: raw, files: files} = stacktrace

    case Regex.named_captures(~r/(?<stacktrace_file>[a-z\/_\.]+):/, line) do
      %{"stacktrace_file" => file} ->
        raw = raw <> line <> "\n"
        files = [file | files]
        stacktrace = %{raw: raw, files: files}
        find_files(acc, {:stacktrace, test, stacktrace}, lines)

      _ ->
        stacktrace = %{raw: raw, files: Enum.reverse(files)}

        find_files([{test, stacktrace} | acc], :test, lines)
    end
  end
end
