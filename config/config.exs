import Config

config :polyglot_watcher_v2, actually_clear_screen: true
config :polyglot_watcher_v2, put_watcher_startup_message: false
config :polyglot_watcher_v2, actions_executor_module: PolyglotWatcherV2.ActionsExecutorReal

config :polyglot_watcher_v2,
  environment_variables_module: PolyglotWatcherV2.EnvironmentVariables.Real

import_config "#{Mix.env()}.exs"
