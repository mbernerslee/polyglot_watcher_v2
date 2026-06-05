defmodule PolyglotWatcherV2.Elixir.Cache.FixedTests do
  alias PolyglotWatcherV2.Elixir.MixTestArgs

  def determine(%MixTestArgs{} = args, 0) do
    case MixTestArgs.category(args) do
      :paranoid -> nil
      :safe -> determine_safe(args)
    end
  end

  def determine(_, _non_zero_exit_code) do
    nil
  end

  defp determine_safe(%MixTestArgs{path: :all}), do: :all
  defp determine_safe(%MixTestArgs{path: {path, line}}), do: {path, line}
  defp determine_safe(%MixTestArgs{path: path}), do: {path, :all}
end
