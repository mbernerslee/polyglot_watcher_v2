defmodule PolyglotWatcherV2.Elixir.MixTestArgs do
  @moduledoc """
  This module may seem like overkill,
  but it serves a purpose because later we determine which tests passed based on
  - the mix test args
  - the mix test exit code

  (that code currently lives in PolyglotWatcherV2.Elixir.Cache.FixedTests, this comment subject to being very wrong as code changes and this doc is not)

  So its actually very important to know which tests actually ran based on the args,
  which is very difficult if not impossible if the args we give to `mix test` is a free for all string, and could include flags like --failed or --stale.

  So locking it down to just the variants we actually use by encoding it this way helps our logic be more trustworthy on determining what preciscely we ran and therefore which tests passed.
  """
  use PolyglotWatcherV2.AccessBehaviour
  @enforce_keys [:path]
  defstruct [:path, :max_failures]

  @type t() :: %__MODULE__{
          path: String.t() | {String.t(), integer()} | :all,
          max_failures: integer() | nil
        }

  def to_shell_command(%__MODULE__{} = args) do
    formatters()
    |> Enum.reduce("", fn {key, formatter}, acc ->
      addition =
        args
        |> Map.fetch!(key)
        |> then(formatter)

      acc <> addition
    end)
    |> splice_together()
  end

  def to_path(path) do
    trimmed = String.trim(path)

    if String.contains?(trimmed, " ") do
      :error
    else
      case String.split(trimmed, ":") do
        [test_path, line] -> path_line_tuple(test_path, line)
        [test_path] -> {:ok, test_path}
        _ -> :error
      end
    end
  end

  defp path_line_tuple(test_path, line) do
    case Integer.parse(line) do
      {line, ""} -> {:ok, {test_path, line}}
      _ -> :error
    end
  end

  defp formatters do
    [{:path, &path/1}, {:max_failures, &max_failures/1}]
  end

  defp path(:all), do: ""
  defp path({file, line}), do: "#{file}:#{line} "

  defp path(path) when is_binary(path) do
    if String.contains?(path, ":") do
      raise ArgumentError,
            "Invalid path format of #{inspect(path)}. Use a tuple {file, line} instead"
    end

    path <> " "
  end

  defp max_failures(nil), do: ""
  defp max_failures(count), do: "--max-failures #{count} "

  defp splice_together(""), do: "mix test --color"
  defp splice_together(middle), do: "mix test #{String.trim(middle)} --color"
end
