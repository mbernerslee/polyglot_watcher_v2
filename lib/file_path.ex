defmodule PolyglotWatcherV2.FilePath do
  defstruct path: nil, extension: nil

  @type t() :: %__MODULE__{
          path: String.t(),
          extension: String.t()
        }

  def build(relative_path) do
    case split_by_final_full_stop(relative_path) do
      %{path: ""} ->
        :ignore

      %{path: path, extension: extension} ->
        extension = String.trim(extension, "~")
        {:ok, %__MODULE__{path: path, extension: extension}}
    end
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
end
