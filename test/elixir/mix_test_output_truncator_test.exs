defmodule PolyglotWatcherV2.Elixir.MixTestOutputTruncatorTest do
  use ExUnit.Case, async: true

  alias PolyglotWatcherV2.Elixir.MixTestOutputTruncator, as: OutputTruncator

  @real_failed_output """
  Compiling 1 file (.ex)
  Generated polyglot_watcher_v2 app
  Running ExUnit with seed: 364029, max_cases: 28

  ...................................

    1) test determine/1 given a string rather than a %FilePath{}, it still works (PolyglotWatcherV2.Elixir.EquivalentPathTest)
       test/elixir/equivalent_path_test.exs:10
       ** (RuntimeError) x
       code: assert EquivalentPath.determine("lib/cool.ex") == {:ok, "test/cool_test.exs"}
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/equivalent_path.ex:9: PolyglotWatcherV2.Elixir.EquivalentPath.determine/1
         test/elixir/equivalent_path_test.exs:11: (test)

  ....

    2) test determine/1 - relative paths starting in lib or test given a lib path, returns the test path (PolyglotWatcherV2.Elixir.EquivalentPathTest)
       test/elixir/equivalent_path_test.exs:52
       ** (RuntimeError) x
       code: assert EquivalentPath.determine(%FilePath{path: "lib/cool", extension: @ex}) ==
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/equivalent_path.ex:9: PolyglotWatcherV2.Elixir.EquivalentPath.determine/1
         test/elixir/equivalent_path_test.exs:53: (test)

  ............

    3) test actions/2 given a file path that nobody understands, returns no actions (PolyglotWatcherV2.DetermineTest)
       test/determine_test.exs:13
       ** (RuntimeError) x
       code: Determine.actions({:ok, %FilePath{path: "cool", extension: "crazy"}}, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/determine.ex:10: PolyglotWatcherV2.Determine.actions/2
         test/determine_test.exs:17: (test)

  ...

    4) test actions/2 given a rust file path, returns some actions (PolyglotWatcherV2.DetermineTest)
       test/determine_test.exs:28
       ** (RuntimeError) x
       code: Determine.actions({:ok, %FilePath{path: "cool", extension: rs}}, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/determine.ex:10: PolyglotWatcherV2.Determine.actions/2
         test/determine_test.exs:33: (test)



    5) test actions/2 given a file path that somebody understands, returns some actions (PolyglotWatcherV2.DetermineTest)
       test/determine_test.exs:20
       ** (RuntimeError) x
       code: Determine.actions({:ok, %FilePath{path: "cool", extension: ex}}, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/determine.ex:10: PolyglotWatcherV2.Determine.actions/2
         test/determine_test.exs:25: (test)

  .....................................

    6) test determine_actions/2 can read rust (rs) actions, returning an actions tree thats a map (PolyglotWatcherV2.UserInputTest)
       test/user_input_test.exs:16
       ** (RuntimeError) x
       code: UserInput.determine_actions("\#{RustDeterminer.rs()} d", server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/user_input.ex:13: PolyglotWatcherV2.UserInput.determine_actions/2
         test/user_input_test.exs:20: (test)



    7) test determine_actions/2 can read elixir (ex) actions, returning an actions tree thats a map (PolyglotWatcherV2.UserInputTest)
       test/user_input_test.exs:9
       ** (RuntimeError) x
       code: UserInput.determine_actions("\#{ElixirDeterminer.ex()} d", server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/user_input.ex:13: PolyglotWatcherV2.UserInput.determine_actions/2
         test/user_input_test.exs:13: (test)



    8) test determine_actions/2 given nonsense input returns help (PolyglotWatcherV2.UserInputTest)
       test/user_input_test.exs:23
       ** (RuntimeError) x
       code: UserInput.determine_actions("nonesense dude", server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/user_input.ex:13: PolyglotWatcherV2.UserInput.determine_actions/2
         test/user_input_test.exs:27: (test)

  .....

    9) test truncate/1 truncates middle blocks when over line limit, keeping first and last (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
       test/elixir/mix_test/output_truncator_test.exs:12
       ** (RuntimeError) x
       code: result = OutputTruncator.truncate(text)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
         test/elixir/mix_test/output_truncator_test.exs:33: (test)



   10) test truncate/1 returns text unchanged when under line limit (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
       test/elixir/mix_test/output_truncator_test.exs:7
       ** (RuntimeError) x
       code: assert OutputTruncator.truncate(text) == text
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
         test/elixir/mix_test/output_truncator_test.exs:9: (test)



   11) test truncate/1 uses generic omitted message when no failure count found (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
       test/elixir/mix_test/output_truncator_test.exs:59
       ** (RuntimeError) x
       code: result = OutputTruncator.truncate(text)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
         test/elixir/mix_test/output_truncator_test.exs:65: (test)



   12) test truncate/1 includes failure count message when failures are detected (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
       test/elixir/mix_test/output_truncator_test.exs:42
       ** (RuntimeError) x
       code: result = OutputTruncator.truncate(text)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
         test/elixir/mix_test/output_truncator_test.exs:54: (test)



   13) test truncate/1 keeps as many complete failure blocks as fit within limit (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
       test/elixir/mix_test/output_truncator_test.exs:77
       ** (RuntimeError) x
       code: result = OutputTruncator.truncate(text)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
         test/elixir/mix_test/output_truncator_test.exs:86: (test)



   14) test truncate/1 preserves all blocks when exactly at the line limit (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
       test/elixir/mix_test/output_truncator_test.exs:70
       ** (RuntimeError) x
       code: assert OutputTruncator.truncate(text) == text
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
         test/elixir/mix_test/output_truncator_test.exs:74: (test)

  .

   15) test determine_actions/2 - in normal mode given an ex file from a lib dir, returns the expected actions_tree & entry point (PolyglotWatcherV2.Elixir.DefaultModeTest)
       test/elixir/default_mode_test.exs:16
       ** (RuntimeError) x
       code: DefaultMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/equivalent_path.ex:9: PolyglotWatcherV2.Elixir.EquivalentPath.determine/1
         (polyglot_watcher_v2 0.1.0) lib/elixir/default_mode.ex:30: PolyglotWatcherV2.Elixir.DefaultMode.determine_actions/2
         test/elixir/default_mode_test.exs:18: (test)



   16) test determine_actions/2 - in normal mode given an ex file from a test dir, it says it doesn't know what to run (PolyglotWatcherV2.Elixir.DefaultModeTest)
       test/elixir/default_mode_test.exs:49
       ** (RuntimeError) x
       code: DefaultMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/default_mode.ex:11: PolyglotWatcherV2.Elixir.DefaultMode.determine_actions/2
         test/elixir/default_mode_test.exs:51: (test)

  ............................

   17) test read/1 when a valid file exists, it is read (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:51
       ** (RuntimeError) x
       code: }} == ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:63: (test)

  ............

   18) test patch/2 - :all when a file does not exist, but another does, make no file changes and removed all file_patches from the server_state (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:70
       ** (RuntimeError) x
       code: }} == FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:116: (test)

  ..

   19) test run/1 when already running, returns awaited result (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:26
       ** (RuntimeError) x
       code: assert {awaited_output, 0} == MixTest.run(mix_test_args)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:34: (test)

  .

   20) test default_config_contents returns a valid config (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:35
       ** (RuntimeError) x
       code: }} == ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:47: (test)



   21) test determine_actions/2 returns the run_all actions when in that mode (PolyglotWatcherV2.Elixir.DeterminerTest)
       test/elixir/determiner_test.exs:33
       ** (RuntimeError) x
       code: assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/determiner.ex:26: PolyglotWatcherV2.Elixir.Determiner.determine_actions/2
         test/elixir/determiner_test.exs:38: (test)

  ..

   22) test determine_actions/1 given a lib file, returns a valid action tree (PolyglotWatcherV2.Elixir.AI.ReplaceModeTest)
       test/elixir/ai/replace_mode_test.exs:134
       ** (RuntimeError) x
       code: ReplaceMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/equivalent_path.ex:9: PolyglotWatcherV2.Elixir.EquivalentPath.determine/1
         (polyglot_watcher_v2 0.1.0) lib/elixir/ai/replace_mode.ex:58: PolyglotWatcherV2.Elixir.AI.ReplaceMode.determine_actions/2
         test/elixir/ai/replace_mode_test.exs:136: (test)

  ..........

   23) test read/1 when the config file does not exist, return error (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:81
       ** (RuntimeError) x
       code: \"\"\"} == ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:97: (test)

  ......

   24) test run/1 when not running, executes and returns {output, exit_code} (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:9
       ** (RuntimeError) x
       code: assert {mock_output, 0} == MixTest.run(mix_test_args)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:23: (test)



   25) test patch/2 - :all given 2 files, which both exist, patches to them are written to file (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:11
       ** (RuntimeError) x
       code: FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:67: (test)

  ......

   26) test POST /mcp successful tool call returns 200 with JSON result (PolyglotWatcherV2.MCP.PlugRouterTest)
       test/mcp/plug_router_test.exs:12
       ** (Plug.Conn.WrapperError) ** (RuntimeError) x
       code: |> PlugRouter.call(PlugRouter.init([]))
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/tools/run_tests.ex:36: PolyglotWatcherV2.MCP.Tools.RunTests.call/1
         (polyglot_watcher_v2 0.1.0) lib/mcp/handler.ex:74: PolyglotWatcherV2.MCP.Handler.call_tool/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/handler.ex:44: PolyglotWatcherV2.MCP.Handler.handle_message/1
         (polyglot_watcher_v2 0.1.0) lib/mcp/plug_router.ex:21: anonymous fn/2 in PolyglotWatcherV2.MCP.PlugRouter.do_match/4
         (polyglot_watcher_v2 0.1.0) deps/plug/lib/plug/router.ex:263: anonymous fn/4 in PolyglotWatcherV2.MCP.PlugRouter.dispatch/2
         (telemetry 1.3.0) /Users/berners/src/polyglot_watcher_v2/deps/telemetry/src/telemetry.erl:324: :telemetry.span/3
         (polyglot_watcher_v2 0.1.0) deps/plug/lib/plug/router.ex:259: PolyglotWatcherV2.MCP.PlugRouter.dispatch/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/plug_router.ex:1: PolyglotWatcherV2.MCP.PlugRouter.plug_builder_call/2
         test/mcp/plug_router_test.exs:36: (test)



   27) test call/1 runs test with line_number (PolyglotWatcherV2.MCP.Tools.RunTestsTest)
       test/mcp/tools/run_tests_test.exs:31
       ** (RuntimeError) x
       code: result = RunTests.call(%{"test_path" => "test/cool_test.exs", "line_number" => 42})
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/tools/run_tests.ex:36: PolyglotWatcherV2.MCP.Tools.RunTests.call/1
         test/mcp/tools/run_tests_test.exs:43: (test)

  ..

   28) test read/1 when no model is specified, thats ok and we put model = nil (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:66
       ** (RuntimeError) x
       code: }} == ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:78: (test)



   29) test determine_actions/2 can find the expected normal mode actions (PolyglotWatcherV2.Elixir.DeterminerTest)
       test/elixir/determiner_test.exs:16
       ** (RuntimeError) x
       code: assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/determiner.ex:26: PolyglotWatcherV2.Elixir.Determiner.determine_actions/2
         test/elixir/determiner_test.exs:19: (test)

  ......

   30) test run/2 with use_cache use_cache: :no_cache always runs (does not check cache) (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:146
       ** (RuntimeError) x
       code: assert {mock_output, 0} == MixTest.run(mix_test_args, use_cache: :no_cache)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:159: (test)

  ......

   31) test patch/2 - subset given a list of integers, only applies those patches, and keeps the rest (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:344
       ** (RuntimeError) x
       code: FilePatches.patch([1, 3], server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:425: (test)



   32) test read/1 when the config file is valid YAML but does not contain the expected mandatory fields, return error (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:126
       ** (RuntimeError) x
       code: \"\"\"} == ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:156: (test)

  .

   33) test call/1 runs test for given test_path (PolyglotWatcherV2.MCP.Tools.RunTestsTest)
       test/mcp/tools/run_tests_test.exs:10
       ** (RuntimeError) x
       code: result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/tools/run_tests.ex:36: PolyglotWatcherV2.MCP.Tools.RunTests.call/1
         test/mcp/tools/run_tests_test.exs:22: (test)

  .....

   34) test determine_actions/2 returns the fix_all_for_file_actions when in that state (PolyglotWatcherV2.Elixir.DeterminerTest)
       test/elixir/determiner_test.exs:60
       ** (RuntimeError) x
       code: assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/determiner.ex:26: PolyglotWatcherV2.Elixir.Determiner.determine_actions/2
         test/elixir/determiner_test.exs:65: (test)



   35) test call/1 returns cached result when cache hit (PolyglotWatcherV2.MCP.Tools.RunTestsTest)
       test/mcp/tools/run_tests_test.exs:68
       ** (RuntimeError) x
       code: result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/tools/run_tests.ex:36: PolyglotWatcherV2.MCP.Tools.RunTests.call/1
         test/mcp/tools/run_tests_test.exs:75: (test)



   36) test read/1 when the config file returns something that is not YAML, return error (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:109
       ** (RuntimeError) x
       code: ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:123: (test)

  ....

   37) test run/2 given :all & server state, runs all the tests (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:61
       ** (RuntimeError) x
       code: assert {0, server_state} == MixTest.run(mix_test_args, server_state: server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:79: (test)

  ...

   38) test patch/2 - :all given 2 files, when one contains the search text multiple times, allow it & update both places (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:168
       ** (RuntimeError) x
       code: }} == FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:220: (test)



   39) test determine_actions/2 returns the fix_all actions when in that state (PolyglotWatcherV2.Elixir.DeterminerTest)
       test/elixir/determiner_test.exs:50
       ** (RuntimeError) x
       code: assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/determiner.ex:26: PolyglotWatcherV2.Elixir.Determiner.determine_actions/2
         test/elixir/determiner_test.exs:55: (test)

  ......

   40) test read/1 given an invalid AI vendor, return error (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:159
       ** (RuntimeError) x
       code: ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:172: (test)

  ....

   41) test run/2 given a test path & server state, runs the mix test command with the test path (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:39
       ** (RuntimeError) x
       code: assert {0, server_state} == MixTest.run(mix_test_args, server_state: server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:58: (test)

  .

   42) test call/1 runs all tests when no test_path given (PolyglotWatcherV2.MCP.Tools.RunTestsTest)
       test/mcp/tools/run_tests_test.exs:49
       ** (RuntimeError) x
       code: result = RunTests.call(%{})
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/tools/run_tests.ex:36: PolyglotWatcherV2.MCP.Tools.RunTests.call/1
         test/mcp/tools/run_tests_test.exs:61: (test)

  .

   43) test patch/2 - :all given 2 files, when one does not contain any search text, make no file changes and return error (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:119
       ** (RuntimeError) x
       code: }} == FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:165: (test)

  ..

   44) test read/1 when there's an error opening the config file, return error (PolyglotWatcherV2.ConfigFileTest)
       test/config_file_test.exs:100
       ** (RuntimeError) x
       code: ConfigFile.read()
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
         test/config_file_test.exs:106: (test)

  ..

   45) test handle_message/1 - tools/call mix_test calls mix_test and returns result (PolyglotWatcherV2.MCP.HandlerTest)
       test/mcp/handler_test.exs:52
       ** (RuntimeError) x
       code: Handler.handle_message(%{
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/tools/run_tests.ex:36: PolyglotWatcherV2.MCP.Tools.RunTests.call/1
         (polyglot_watcher_v2 0.1.0) lib/mcp/handler.ex:74: PolyglotWatcherV2.MCP.Handler.call_tool/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/handler.ex:44: PolyglotWatcherV2.MCP.Handler.handle_message/1
         test/mcp/handler_test.exs:69: (test)

  ..

   46) test run/2 with use_cache use_cache: :cached falls through to run on miss (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:130
       ** (RuntimeError) x
       code: assert {mock_output, 0} == MixTest.run(mix_test_args, use_cache: :cached)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:143: (test)

  .

   47) test patch/2 - :all handles replacements of nil (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:316
       ** (RuntimeError) x
       code: FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:339: (test)

  .

   48) test call/1 returns awaited result when test is already running (PolyglotWatcherV2.MCP.Tools.RunTestsTest)
       test/mcp/tools/run_tests_test.exs:83
       ** (RuntimeError) x
       code: result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         (polyglot_watcher_v2 0.1.0) lib/mcp/tools/run_tests.ex:36: PolyglotWatcherV2.MCP.Tools.RunTests.call/1
         test/mcp/tools/run_tests_test.exs:89: (test)

  .....

   49) test run/2 with use_cache use_cache: :cached with source: :mcp puts cache hit message on hit (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:106
       ** (RuntimeError) x
       code: assert {"1 test, 0 failures", 0} == MixTest.run(mix_test_args, use_cache: :cached, source: :mcp)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:115: (test)

  ..

   50) test patch/2 - :all when writing to a file fails, return an error (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:258
       ** (RuntimeError) x
       code: FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:288: (test)

  ...

   51) test run/2 with use_cache with server_state option returns {exit_code, server_state} (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:162
       ** (RuntimeError) x
       code: assert {0, ^server_state} = MixTest.run(mix_test_args, server_state: server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:175: (test)

  ...

   52) test patch/2 - subset when every index is asked for, return ok done because no patches are left (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:428
       ** (RuntimeError) x
       code: FilePatches.patch([1, 2, 3, 4], server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:484: (test)

  .

   53) test run/2 with use_cache use_cache: :cached returns cached result on hit (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:96
       ** (RuntimeError) x
       code: assert {"1 test, 0 failures", 0} == MixTest.run(mix_test_args, use_cache: :cached)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:103: (test)

  ....

   54) test run/2 with use_cache use_cache: :cached without source: :mcp does not put cache hit message (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:118
       ** (RuntimeError) x
       code: assert {"1 test, 0 failures", 0} == MixTest.run(mix_test_args, use_cache: :cached)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:127: (test)



   55) test patch/2 - :all given a file with an empty patch list, no changes are made (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:235
       ** (RuntimeError) x
       code: FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:255: (test)

  ...

   56) test run/2 when already running, returns exit_code from awaited result (PolyglotWatcherV2.Elixir.MixTestTest)
       test/elixir/mix_test_test.exs:82
       ** (RuntimeError) x
       code: assert {2, server_state} == MixTest.run(mix_test_args, server_state: server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test.ex:8: PolyglotWatcherV2.Elixir.MixTest.run/2
         test/elixir/mix_test_test.exs:91: (test)

  ......

   57) test patch/2 - :all given a file with multiple patches, all patches are applied (PolyglotWatcherV2.FilePatchesTest)
       test/file_patches_test.exs:291
       ** (RuntimeError) x
       code: FilePatches.patch(:all, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/file_patches.ex:8: PolyglotWatcherV2.FilePatches.patch/2
         test/file_patches_test.exs:313: (test)

  ........

   58) test determine_actions/2 returns the AI Replace Mode actions when in that state (PolyglotWatcherV2.Elixir.DeterminerTest)
       test/elixir/determiner_test.exs:80
       ** (RuntimeError) x
       code: assert {tree, ^server_state} = Determiner.determine_actions(@ex_file_path, server_state)
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/elixir/determiner.ex:26: PolyglotWatcherV2.Elixir.Determiner.determine_actions/2
         test/elixir/determiner_test.exs:86: (test)

  .....................................................

   59) test start_link/2 when the config file reading fails, we stop (PolyglotWatcherV2.ServerTest)
       test/server_test.exs:44
       Assertion failed, no matching message after 100ms
       The following variables were pinned:
         pid = #PID<0.1209.0>
       Showing 1 of 1 message in the mailbox
       code: assert_receive {:EXIT, ^pid, "Error reading config" <> _}
       mailbox:
         pattern: {:EXIT, ^pid, "Error reading config" <> _}
         value:   {
                    :EXIT,
                    #PID<0.1209.0>,
                    {%RuntimeError{message: "x"}, [{PolyglotWatcherV2.ConfigFile, :read, 0, [file: ~c"lib/config_file.ex", line: 17, error_info: %{module: Exception}]}, {PolyglotWatcherV2.Server, :init, 1, [file: ~c"lib/server.ex", line: 72]}, {:gen_server, :init_it, 2, [file: ~c"gen_server.erl", line: 2229]}, {:gen_server, :init_it, 6, [file: ~c"gen_server.erl", line: 2184]}, {:proc_lib, :init_p_do_apply, 3, [file: ~c"proc_lib.erl", line: 329]}]}
                  }
       stacktrace:
         test/server_test.exs:51: anonymous fn/0 in PolyglotWatcherV2.ServerTest."test start_link/2 when the config file reading fails, we stop"/1
         (ex_unit 1.18.3) lib/ex_unit/capture_io.ex:315: ExUnit.CaptureIO.do_capture_gl/2
         (ex_unit 1.18.3) lib/ex_unit/capture_io.ex:273: ExUnit.CaptureIO.do_with_io/3
         (ex_unit 1.18.3) lib/ex_unit/capture_io.ex:142: ExUnit.CaptureIO.capture_io/1
         test/server_test.exs:49: (test)



   60) test start_link/2 with no command line args given, spawns the server process with default starting state (PolyglotWatcherV2.ServerTest)
       test/server_test.exs:23
       ** (EXIT from #PID<0.1212.0>) an exception was raised:
           ** (RuntimeError) x
               (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
               (polyglot_watcher_v2 0.1.0) lib/server.ex:72: PolyglotWatcherV2.Server.init/1
               (stdlib 6.2.2) gen_server.erl:2229: :gen_server.init_it/2
               (stdlib 6.2.2) gen_server.erl:2184: :gen_server.init_it/6
               (stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3



   61) test start_link/2 overwrites $PATH with the contents of $POLYGLOT_WATCHER_V2_PATH (PolyglotWatcherV2.ServerTest)
       test/server_test.exs:68
       ** (EXIT from #PID<0.1216.0>) an exception was raised:
           ** (RuntimeError) x
               (polyglot_watcher_v2 0.1.0) lib/config_file.ex:17: PolyglotWatcherV2.ConfigFile.read/0
               (polyglot_watcher_v2 0.1.0) lib/server.ex:72: PolyglotWatcherV2.Server.init/1
               (stdlib 6.2.2) gen_server.erl:2229: :gen_server.init_it/2
               (stdlib 6.2.2) gen_server.erl:2184: :gen_server.init_it/6
               (stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3

  ..

   62) test handle_info/2 - file_event regonises file events from FileSystem, & returns a server_state (PolyglotWatcherV2.ServerTest)
       test/server_test.exs:100
       ** (RuntimeError) x
       code: Server.handle_info(
       stacktrace:
         (polyglot_watcher_v2 0.1.0) lib/determine.ex:10: PolyglotWatcherV2.Determine.actions/2
         (polyglot_watcher_v2 0.1.0) lib/server.ex:124: PolyglotWatcherV2.Server.handle_info/2
         test/server_test.exs:104: (test)

  ...
  Finished in 2.9 seconds (2.8s async, 0.1s sync)
  366 tests, 62 failures
  """

  describe "truncate/1" do
    test "returns text unchanged when under line limit" do
      text = "Running ExUnit\n\n  1) test foo\n     error\n\nFinished\n1 test, 1 failure"
      assert OutputTruncator.truncate(text) == text
    end

    test "truncates real mix test output with 62 failures" do
      expected =
        """
        Compiling 1 file (.ex)
        Generated polyglot_watcher_v2 app
        Running ExUnit with seed: 364029, max_cases: 28

        ...................................

          1) test determine/1 given a string rather than a %FilePath{}, it still works (PolyglotWatcherV2.Elixir.EquivalentPathTest)
             test/elixir/equivalent_path_test.exs:10
             ** (RuntimeError) x
             code: assert EquivalentPath.determine("lib/cool.ex") == {:ok, "test/cool_test.exs"}
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/elixir/equivalent_path.ex:9: PolyglotWatcherV2.Elixir.EquivalentPath.determine/1
               test/elixir/equivalent_path_test.exs:11: (test)

        ....

          2) test determine/1 - relative paths starting in lib or test given a lib path, returns the test path (PolyglotWatcherV2.Elixir.EquivalentPathTest)
             test/elixir/equivalent_path_test.exs:52
             ** (RuntimeError) x
             code: assert EquivalentPath.determine(%FilePath{path: "lib/cool", extension: @ex}) ==
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/elixir/equivalent_path.ex:9: PolyglotWatcherV2.Elixir.EquivalentPath.determine/1
               test/elixir/equivalent_path_test.exs:53: (test)

        ............

          3) test actions/2 given a file path that nobody understands, returns no actions (PolyglotWatcherV2.DetermineTest)
             test/determine_test.exs:13
             ** (RuntimeError) x
             code: Determine.actions({:ok, %FilePath{path: "cool", extension: "crazy"}}, server_state)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/determine.ex:10: PolyglotWatcherV2.Determine.actions/2
               test/determine_test.exs:17: (test)

        ...

          4) test actions/2 given a rust file path, returns some actions (PolyglotWatcherV2.DetermineTest)
             test/determine_test.exs:28
             ** (RuntimeError) x
             code: Determine.actions({:ok, %FilePath{path: "cool", extension: rs}}, server_state)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/determine.ex:10: PolyglotWatcherV2.Determine.actions/2
               test/determine_test.exs:33: (test)



          5) test actions/2 given a file path that somebody understands, returns some actions (PolyglotWatcherV2.DetermineTest)
             test/determine_test.exs:20
             ** (RuntimeError) x
             code: Determine.actions({:ok, %FilePath{path: "cool", extension: ex}}, server_state)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/determine.ex:10: PolyglotWatcherV2.Determine.actions/2
               test/determine_test.exs:25: (test)

        .....................................

          6) test determine_actions/2 can read rust (rs) actions, returning an actions tree thats a map (PolyglotWatcherV2.UserInputTest)
             test/user_input_test.exs:16
             ** (RuntimeError) x
             code: UserInput.determine_actions("\#{RustDeterminer.rs()} d", server_state)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/user_input.ex:13: PolyglotWatcherV2.UserInput.determine_actions/2
               test/user_input_test.exs:20: (test)



          7) test determine_actions/2 can read elixir (ex) actions, returning an actions tree thats a map (PolyglotWatcherV2.UserInputTest)
             test/user_input_test.exs:9
             ** (RuntimeError) x
             code: UserInput.determine_actions("\#{ElixirDeterminer.ex()} d", server_state)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/user_input.ex:13: PolyglotWatcherV2.UserInput.determine_actions/2
               test/user_input_test.exs:13: (test)



          8) test determine_actions/2 given nonsense input returns help (PolyglotWatcherV2.UserInputTest)
             test/user_input_test.exs:23
             ** (RuntimeError) x
             code: UserInput.determine_actions("nonesense dude", server_state)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/user_input.ex:13: PolyglotWatcherV2.UserInput.determine_actions/2
               test/user_input_test.exs:27: (test)

        .....

          9) test truncate/1 truncates middle blocks when over line limit, keeping first and last (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
             test/elixir/mix_test/output_truncator_test.exs:12
             ** (RuntimeError) x
             code: result = OutputTruncator.truncate(text)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
               test/elixir/mix_test/output_truncator_test.exs:33: (test)



         10) test truncate/1 returns text unchanged when under line limit (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
             test/elixir/mix_test/output_truncator_test.exs:7
             ** (RuntimeError) x
             code: assert OutputTruncator.truncate(text) == text
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
               test/elixir/mix_test/output_truncator_test.exs:9: (test)



         11) test truncate/1 uses generic omitted message when no failure count found (PolyglotWatcherV2.Elixir.MixTest.OutputTruncatorTest)
             test/elixir/mix_test/output_truncator_test.exs:59
             ** (RuntimeError) x
             code: result = OutputTruncator.truncate(text)
             stacktrace:
               (polyglot_watcher_v2 0.1.0) lib/elixir/mix_test/output_truncator.ex:15: PolyglotWatcherV2.Elixir.MixTest.OutputTruncator.truncate/1
               test/elixir/mix_test/output_truncator_test.exs:65: (test)



        ... (62 tests failed, showing 11 failure outputs) ...

        ...
        Finished in 2.9 seconds (2.8s async, 0.1s sync)
        366 tests, 62 failures
        """

      assert OutputTruncator.truncate(@real_failed_output) == expected
    end

    test "includes failure count message when failures are detected" do
      first = "Running ExUnit"
      last = "5 tests, 5 failures"

      failures =
        for i <- 1..5 do
          lines = for j <- 1..25, do: "  line #{j} of failure #{i}"

          "  #{i}) test thing #{i} (Mod)\n" <> Enum.join(lines, "\n")
        end

      text = Enum.join([first] ++ failures ++ [last], "\n\n")
      result = OutputTruncator.truncate(text)

      assert result =~ "... (5 tests failed, showing 3 failure outputs) ..."
    end

    test "uses generic omitted message when no failure count found" do
      first = "Compiling 5 files"
      last = "done"
      blocks = for i <- 1..20, do: String.duplicate("line #{i}\n", 10)

      text = Enum.join([first] ++ blocks ++ [last], "\n\n")
      result = OutputTruncator.truncate(text)

      assert result =~ "... (12 blocks omitted) ..."
    end

    test "preserves all blocks when under the line limit" do
      blocks = ["block1", "block2", "block3"]
      text = Enum.join(blocks, "\n\n")

      assert OutputTruncator.truncate(text) == text
    end

    test "keeps as many complete failure blocks as fit within limit" do
      first = "Running ExUnit"
      last = "3 tests, 3 failures"

      small_failure = "  1) test small (Mod)\n     test/foo.exs:1\n     ** error\n     stack"
      big_failure = "  2) test big (Mod)\n" <> String.duplicate("     long line\n", 95)
      another_small = "  3) test small2 (Mod)\n     test/foo.exs:3\n     ** error\n     stack"

      text = Enum.join([first, small_failure, big_failure, another_small, last], "\n\n")
      result = OutputTruncator.truncate(text)

      assert result =~ "1) test small"
      refute result =~ "2) test big"
      assert result =~ "... (3 tests failed, showing 1 failure outputs) ..."
    end
  end

end
