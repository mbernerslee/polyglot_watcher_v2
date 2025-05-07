import Config

config :polyglot_watcher_v2, actually_clear_screen: false
config :polyglot_watcher_v2, put_watcher_startup_message: true

config :polyglot_watcher_v2,
  log_executor_commands:
    System.get_env("POLYGLOT_WATCHER_LOG_EXECUTOR_COMMANDS", "true") == "true"

config :logger, level: String.to_atom(System.get_env("POLYGLOT_WATCHER_DEV_LOG_LEVEL", "debug"))
