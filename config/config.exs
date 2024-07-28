import Config

config :polyglot_watcher_v2, actually_clear_screen: true
config :polyglot_watcher_v2, put_watcher_startup_message: false
config :polyglot_watcher_v2, actions_executor_module: PolyglotWatcherV2.ActionsExecutorReal
config :polyglot_watcher_v2, log_executor_commands: false

import_config "#{Mix.env()}.exs"
