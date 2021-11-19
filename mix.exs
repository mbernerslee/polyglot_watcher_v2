defmodule PolyglotWatcherV2.MixProject do
  use Mix.Project

  def project do
    [
      app: :polyglot_watcher_v2,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: PolyglotWatcherV2]
    ]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/builders"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  defp deps do
    []
  end
end
