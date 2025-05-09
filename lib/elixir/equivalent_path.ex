defmodule PolyglotWatcherV2.Elixir.EquivalentPath do
  alias PolyglotWatcherV2.FilePath
  alias PolyglotWatcherV2.Elixir.Determiner

  @ex Determiner.ex()
  @exs Determiner.exs()

  def determine(%FilePath{path: "lib/" <> rest, extension: @ex}) do
    test_path = "test/#{rest}_test.#{@exs}"
    {:ok, test_path}
  end

  def determine(%FilePath{path: "test/" <> rest, extension: @exs}) do
    lib_path = "lib/#{String.replace_suffix(rest, "_test", "")}.#{@ex}"
    {:ok, lib_path}
  end

  def determine(%FilePath{path: path, extension: @ex}) do
    case Regex.run(~r|^(.*)\/lib\/(.*)$|, path) do
      [_, prefix, suffix] ->
        {:ok, "#{prefix}/test/#{suffix}_test.#{@exs}"}

      _ ->
        :error
    end
  end

  def determine(%FilePath{path: path, extension: @exs}) do
    case Regex.run(~r|^(.*)\/test\/(.*)_test$|, path) do
      [_, prefix, suffix] ->
        {:ok, "#{prefix}/lib/#{suffix}.#{@ex}"}

      _ ->
        :error
    end
  end

  def determine(path) when is_binary(path) do
    case FilePath.build(path) do
      {:ok, path} -> determine(path)
      _ -> :error
    end
  end

  def determine(_) do
    :error
  end
end
