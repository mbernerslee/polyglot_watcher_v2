defmodule PolyglotWatcherV2.FilePath do
  defstruct path: nil, extension: nil

  def build(relative_path) do
    case String.split(relative_path, ".", trim: true) do
      [path, extension] ->
        extension = trim_extension(extension)
        {:ok, %__MODULE__{path: path, extension: extension}}

      _ ->
        :ignore
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

  defp trim_extension(extension) do
    String.trim(extension, "~")
  end
end
