defmodule PolyglotWatcherV2.ElixirLangDeterminer do
  alias PolyglotWatcherV2.FilePath
  @ex "ex"
  @exs "exs"
  @extensions [@ex, @exs]

  def determine_actions(file_path, server_state) do
    if file_path.extension in @extensions do
      do_determine_actions(file_path, server_state)
    else
      :none
    end
  end

  defp do_determine_actions(%{extension: @exs} = file_path, server_state) do
    test_path = FilePath.stringify(file_path)
    IO.inspect("I will run mix test #{test_path}")
    {%{}, server_state}
  end

  defp do_determine_actions(%{extension: @ex} = file_path, server_state) do
    case equivalent_test_file_path(file_path, server_state) do
      :doesnt_exist ->
        IO.inspect("You don't have tests for #{FilePath.stringify(file_path)} do you?")
        {%{}, server_state}

      {:ok, test_file_path} ->
        do_determine_actions(test_file_path, server_state)
    end
  end

  defp equivalent_test_file_path(file_path, server_state) do
    case String.split(file_path.path, "lib") do
      ["", middle_part_of_path] ->
        {:ok, test_file_path} =
          FilePath.build("test#{middle_part_of_path}_test.exs", server_state.starting_dir)

        if FilePath.exists?(test_file_path) do
          {:ok, test_file_path}
        else
          :doesnt_exist
        end

      _ ->
        :doesnt_exist
    end
  end
end
