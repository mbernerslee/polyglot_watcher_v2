defmodule PolyglotWatcherV2.Elixir.Cache do
  @moduledoc """
  Holds an in-memory cache of elixir:
  - code files *.ex
  - test files *.exs
  - the line numbers of which tests have failed
  - mix test failure output

  So that they're available to us for actions such as - spicing them into an AI prompt.

  Designed to be updated every time `mix test` is run via the ActionsExecutor

  Also loads the mix test failures from the file that ExUnit writes to.

  (To enable its `mix test --failed` it saves failed test details to a file which we read to known which tests previously failed on startup)
  """
  use GenServer

  alias PolyglotWatcherV2.{ExUnitFailuresManifest, SystemCall}
  alias PolyglotWatcherV2.Elixir.EquivalentPath
  alias PolyglotWatcherV2.FilePath
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @process_name :elixir_cache
  @default_options [name: @process_name]

  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [@default_options]}
    }
  end

  def start_link(genserver_options \\ @default_options) do
    GenServer.start_link(__MODULE__, [], genserver_options)
  end

  @impl GenServer
  def init(_) do
    IO.inspect("starting up...")
    {:ok, %{status: :loading}, {:continue, :load}}
  end

  @impl GenServer
  def handle_continue(:load, state) do
    {path, 0} = SystemCall.cmd("find", [".", "-name", ".mix_test_failures"])

    files =
      path
      |> String.trim()
      |> ExUnitFailuresManifest.read()
      |> parse_failures_manifest()
      |> read_manifest_files()

    state =
      state
      |> Map.replace!(:status, :loaded)
      |> Map.put_new(:files, files)

    {:noreply, state}
  end

  defp parse_failures_manifest(manifest) do
    Enum.reduce(manifest, %{}, fn {{_module, test}, test_path}, acc ->
      Map.update(acc, to_string(test_path), [test], fn tests -> tests ++ [test] end)
    end)
  end

  defp read_manifest_files(manifest) do
    Enum.reduce(manifest, %{}, fn {test_path, tests}, acc ->
      acc
      |> Map.put_new_lazy(test_path, fn ->
        {:ok, test_contents} = FileWrapper.read(test_path)

        {:ok, test_path_struct} = FilePath.build(test_path)
        {:ok, lib_path} = EquivalentPath.determine(test_path_struct)

        {:ok, lib_contents} = FileWrapper.read(lib_path)

        test_lines =
          test_contents
          |> String.split("\n")
          |> Enum.with_index(1)

        %{
          test: %{
            path: test_path,
            contents: test_contents,
            failed_line_numbers: [],
            lines: test_lines
          },
          lib: %{path: lib_path, contents: lib_contents},
          mix_test_output: nil,
          rank: 1
        }
      end)
      |> Map.update!(test_path, fn %{test: test_file} = file ->
        test_file =
          test_file
          |> Map.replace!(:failed_line_numbers, failed_line_numbers(test_file, tests))
          |> Map.delete(:lines)

        %{file | test: test_file}
      end)
    end)
  end

  defp failed_line_numbers(test_file, tests) do
    tests
    |> Enum.reduce(test_file.failed_line_numbers, fn test, acc ->
      test =
        test
        |> to_string()
        |> String.trim_leading("test ")

      test_file.lines
      |> Enum.reduce_while(nil, fn {line, line_number}, _ ->
        if Regex.match?(~r|^\s+test\s\"#{test}\"|, line) do
          {:halt, {:found, line_number}}
        else
          {:cont, :not_found}
        end
      end)
      |> case do
        :not_found -> acc
        {:found, line_number} -> [line_number | acc]
      end
    end)
    |> Enum.uniq()
  end
end
