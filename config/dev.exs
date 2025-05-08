import Config

config :polyglot_watcher_v2, actually_clear_screen: false
config :logger, level: String.to_atom(System.get_env("POLYGLOT_WATCHER_DEV_LOG_LEVEL", "debug"))
