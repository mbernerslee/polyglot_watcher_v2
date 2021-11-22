defmodule PolyglotWatcherV2.FilePath do
  defstruct path: nil, extension: nil

  def build(relative_path) do
    # case String.split(relative_path, ".", trim: true) do
    case split_by_final_full_stop(relative_path) do
      %{path: ""} ->
        :ignore

      %{path: path, extension: extension} ->
        extension = trim_extension(extension)
        {:ok, %__MODULE__{path: path, extension: extension}}
    end
  end

  def exists?(%__MODULE__{} = file_path) do
    file_path |> stringify() |> exists?()
  end

  def exists?(file_path) do
    File.exists?(file_path)
  end

  def stringify(%__MODULE__{path: path, extension: extension}) do
    Enum.join([path, ".", extension])
  end

  def stringify(string) when is_binary(string) do
    string
  end

  defp split_by_final_full_stop(string) do
    %{path: path, extension: extension} =
      string
      |> String.codepoints()
      |> Enum.reverse()
      |> Enum.reduce(%{extension: [], path: [], found_full_stop?: false}, fn char, acc ->
        case {acc.found_full_stop?, char == "."} do
          {true, true} ->
            %{acc | path: [char | acc.path]}

          {false, true} ->
            %{acc | found_full_stop?: true}

          {true, _} ->
            %{acc | path: [char | acc.path]}

          {false, _} ->
            %{acc | extension: [char | acc.extension]}
        end
      end)

    %{path: Enum.join(path), extension: Enum.join(extension)}
  end

  defp trim_extension(extension) do
    String.trim(extension, "~")
  end
end
