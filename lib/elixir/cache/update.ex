defmodule PolyglotWatcherV2.Elixir.Cache.Update do
  alias PolyglotWatcherV2.Elixir.Cache.{File, LibFile, TestFile}
  alias PolyglotWatcherV2.Elixir.EquivalentPath
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  # TODO test this here
  # TODO deal with test_path = :all
  # TODO we don't need test_path ... except for knowing which failed tests we can delete or sth
  #TODO continue here - wire in MixTestOutputParser to find failed tests lines etc etc
  def run(files, :all, _mix_test_output, _exit_code) do
    files
  end

  def run(files, test_path, mix_test_output, _exit_code) do
    {test_path, line_number} = parse_test_path(test_path)

    existing_line_numbers = existing_line_numbers(files, test_path)

    files
    |> update_files(test_path, mix_test_output, line_number, existing_line_numbers)
    |> increment_ranks()
  end

  defp existing_line_numbers(files, test_path) do
    case Map.get(files, test_path) do
      %{test: %TestFile{failed_line_numbers: failed_line_numbers}} -> failed_line_numbers
      nil -> []
    end
  end

  defp update_files(files, test_path, mix_test_output, line_number, existing_line_numbers) do
    case read_test_file(test_path) do
      {:ok, test_contents} ->
        lib_path = equivalent_lib_path(test_path)
        lib_contents = read_lib_file(lib_path)

        file =
          %File{
            test: %TestFile{
              path: test_path,
              contents: test_contents,
              failed_line_numbers: Enum.uniq([line_number | existing_line_numbers])
            },
            lib: %LibFile{path: lib_path, contents: lib_contents},
            mix_test_output: mix_test_output,
            rank: 0
          }

        Map.put(files, test_path, file)

      {:error, :no_test_file} ->
        files
    end
  end

  defp increment_ranks(files) do
    Map.new(files, fn {test_path, file} ->
      {test_path, Map.update!(file, :rank, &(&1 + 1))}
    end)
  end

  ###############################
  #### copied from init.ex
  ###############################
  defp read_test_file(path) do
    case FileWrapper.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, _error} -> {:error, :no_test_file}
    end
  end

  defp equivalent_lib_path(test_path) do
    case EquivalentPath.determine(test_path) do
      {:ok, lib_path} -> lib_path
      :error -> nil
    end
  end

  defp read_lib_file(nil) do
    nil
  end

  defp read_lib_file(path) do
    case FileWrapper.read(path) do
      {:ok, contents} -> contents
      {:error, _error} -> nil
    end
  end

  ###############################
  #### copied from failures.ex
  ###############################
  defp test_path_parsers do
    [
      &test_without_color_parser/1,
      &test_with_colon_then_line_number_parser/1,
      &max_failures_for_file_parser/1,
      &max_failures_all_parser/1
    ]
  end

  defp parse_test_path(test_path) do
    Enum.reduce_while(test_path_parsers(), nil, fn parser, _acc ->
      case parser.(test_path) do
        {:ok, result} -> {:halt, result}
        _ -> {:cont, nil}
      end
    end)
  end

  defp test_without_color_parser(test) do
    case Regex.named_captures(~r|^.*(?<test>test/[^ :]+)$|, test) do
      %{"test" => test_path} ->
        {:ok, {test_path, :all}}

      _ ->
        :error
    end
  end

  defp max_failures_for_file_parser(test) do
    case Regex.named_captures(~r|^.*(?<test>test/.+) --max-failures [0-9]+$|, test) do
      %{"test" => test_path} ->
        {:ok, {test_path, :all}}

      _ ->
        :error
    end
  end

  defp max_failures_all_parser(test) do
    if Regex.match?(~r|[^test] --max-failures [0-9]+$|, test) do
      {:ok, {:all, :all}}
    else
      :error
    end
  end

  defp test_with_colon_then_line_number_parser(test) do
    case Regex.named_captures(~r|^.*(?<test>test/.+):(?<line>[0-9]+).*|, test) do
      %{"test" => test_path, "line" => line} ->
        {:ok, {test_path, String.to_integer(line)}}

      _ ->
        :error
    end
  end
end
