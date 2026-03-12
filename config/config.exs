import Config

config :polyglot_watcher_v2, actually_clear_screen: true
config :polyglot_watcher_v2, actions_executor_module: PolyglotWatcherV2.ActionsExecutorReal
config :polyglot_watcher_v2, mcp_port: 4848

import_config "#{Mix.env()}.exs"
