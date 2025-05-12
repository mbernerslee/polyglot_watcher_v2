Mimic.copy(PolyglotWatcherV2.ShellCommandRunner)
Mimic.copy(PolyglotWatcherV2.EnvironmentVariables.SystemWrapper)
Mimic.copy(PolyglotWatcherV2.FileSystem.FileWrapper)
# TODO remove this & call it only via the ActionsExecutor instead
# TODO do it for many others too??
Mimic.copy(PolyglotWatcherV2.Puts)
Mimic.copy(PolyglotWatcherV2.SystemCall)
Mimic.copy(PolyglotWatcherV2.ExUnitFailuresManifest)
Mimic.copy(PolyglotWatcherV2.ActionsExecutor)
Mimic.copy(PolyglotWatcherV2.Elixir.Cache)
Mimic.copy(PolyglotWatcherV2.InstructorLiteWrapper)
Mimic.copy(HTTPoison)
ExUnit.start()
