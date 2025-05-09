import Config

actually_clear_screen? =
  System.get_env("POLYGLOT_WATCHER_DEV_ACTUALLY_CLEAR_SCREEN", "false") == "true"

config :polyglot_watcher_v2, actually_clear_screen: actually_clear_screen?
config :logger, level: String.to_atom(System.get_env("POLYGLOT_WATCHER_DEV_LOG_LEVEL", "debug"))
