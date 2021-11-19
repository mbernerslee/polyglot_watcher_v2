defmodule PolyglotWatcherV2.FilePath do
  defstruct path: nil, extension: nil

  def build(absolute_path, relative_to) do
    case String.split(absolute_path, ".", trim: true) do
      [path, extension] ->
        relative_path = Path.relative_to(path, relative_to)
        extension = trim_extension(extension)
        {:ok, %__MODULE__{path: relative_path, extension: extension}}

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
