import Config

config :polyglot_watcher_v2, actions_executor_module: PolyglotWatcherV2.ActionsExecutorFake

config :polyglot_watcher_v2,
  environment_variables_module: PolyglotWatcherV2.EnvironmentVariables.Stub

config :polyglot_watcher_v2, listen_for_user_input: false
