defmodule PolyglotWatcherV2.Elm.FileFinder do
  alias PolyglotWatcherV2.FilePath

  def json(saved_file_path, server_state) do
    starting_dir = server_state.starting_dir

    File.cd!(starting_dir)

    saved_file_dir =
      saved_file_path
      |> FilePath.stringify()
      |> Path.dirname()

    find_json(saved_file_dir, starting_dir)

    {0, server_state}
  end

  defp find_json(dir_to_search, starting_dir) do
    if dir_to_search |> File.ls!() |> Enum.member?("elm.json") do
      {:ok, dir_to_search}
    else
      find_json
    end
  end
end
