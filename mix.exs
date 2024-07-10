defmodule PolyglotWatcherV2.MixProject do
  use Mix.Project

  @app_name :polyglot_watcher_v2

  def project do
    [
      app: @app_name,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: PolyglotWatcherV2, name: escript_name(Mix.env())],
      releases: [
        polyglot_watcher_v2: [
          include_erts: true
          # platform release steps
          #   steps: [:assemble, :tar],
          #   include_executables_for: [:unix],
          #   applications: [
          #     runtime_tools: :permanent,
          #     fun_with_flags: :load,
          #     fun_with_flags_ui: :load,
          #     stardust_phoenix: :load
          #   ],
          #   include_erts: true
        ]
      ]
    ]
  end

  def application do
    [
      mod: {PolyglotWatcherV2, []},
      extra_applications: []
    ]
  end

  defp escript_name(:prod) do
    @app_name
  end

  defp escript_name(env) do
    :"#{@app_name}_#{to_string(env)}"
  end

  defp elixirc_paths(:test) do
    ["lib", "test/builders", "test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  defp deps do
    [{:mimic, "~> 1.7", only: :test}]
  end
end
