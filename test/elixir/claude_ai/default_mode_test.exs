defmodule PolyglotWatcherV2.Elixir.ClaudeAI.DefaultModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{ActionsTreeValidator, FilePath, Puts, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Cache, Determiner, DefaultMode}
  alias PolyglotWatcherV2.Elixir.ClaudeAI.DefaultMode
  alias PolyglotWatcherV2.SystemWrapper
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool_test", extension: @exs}

  describe "switch/1" do
    test "given a valid server state, switches to ClaudeAI mode" do
      assert {tree, @server_state_normal_mode} = DefaultMode.switch(@server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_switch_mode_msg,
        :switch_mode,
        :persist_api_key,
        :no_api_key_fail_msg,
        :put_awaiting_file_save_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end
  end

  describe "determine_actions/1" do
    test "given a lib file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        DefaultMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :load_in_memory_prompt,
        :build_claude_api_request,
        :put_calling_claude_msg,
        :perform_claude_api_request,
        :parse_claude_api_response,
        :put_parsed_claude_api_response,
        :fallback_placeholder_error,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a test file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        DefaultMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :load_in_memory_prompt,
        :build_claude_api_request,
        :put_calling_claude_msg,
        :perform_claude_api_request,
        :parse_claude_api_response,
        :put_parsed_claude_api_response,
        :fallback_placeholder_error,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a lib file, but in an invalid format, returns an error actions tree" do
      {tree, @server_state_normal_mode} =
        DefaultMode.determine_actions(
          %FilePath{path: "not_lib/not_cool", extension: @ex},
          @server_state_normal_mode
        )

      expected_action_tree_keys = [
        :clear_screen,
        :cannot_find_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end
  end

  describe "build_api_request_from_in_memory_prompt/2" do
    test "given server_state that contains the required info to build the API call, then it is built and stored in the server_state" do
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"
      prompt = "cool prompt dude"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_elixir_claude_prompt(prompt)

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"

        {:ok,
         %{
           test: %{path: "test/cool_test.exs", contents: "cool test"},
           lib: %{path: "lib/cool.ex", contents: "cool lib"},
           mix_test_output: mix_test_output
         }}
      end)

      assert {0, new_server_state} =
               DefaultMode.build_api_request_from_in_memory_prompt(
                 "test/cool_test.exs",
                 server_state
               )

      assert %{claude_ai: %{request: api_request}} = new_server_state

      assert put_in(server_state, [:claude_ai, :request], api_request) == new_server_state

      assert %{body: body} = api_request

      assert %{
               "messages" => [%{"role" => "user", "content" => ^prompt}]
             } = Jason.decode!(body)
    end

    test "prompt placeholders get populated" do
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      prompt_with_placeholders = """
        Hello
        $LIB_PATH_PLACEHOLDER
        mother
        $LIB_CONTENT_PLACEHOLDER
        how
        $TEST_PATH_PLACEHOLDER
        are
        $TEST_CONTENT_PLACEHOLDER
        you
        $MIX_TEST_OUTPUT_PLACEHOLDER
        today?
      """

      prompt_without_placeholders = """
        Hello
        lib/cool.ex
        mother
        cool lib
        how
        test/cool_test.exs
        are
        cool test
        you
        it failed mate. get good.
        today?
      """

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"

        {:ok,
         %{
           test: %{path: "test/cool_test.exs", contents: "cool test"},
           lib: %{path: "lib/cool.ex", contents: "cool lib"},
           mix_test_output: mix_test_output
         }}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_elixir_claude_prompt(prompt_with_placeholders)

      {0, new_server_state} =
        DefaultMode.build_api_request_from_in_memory_prompt("test/cool_test.exs", server_state)

      %{claude_ai: %{request: api_request}} = new_server_state

      %{body: body} = api_request

      assert %{
               "messages" => [%{"role" => "user", "content" => ^prompt_without_placeholders}]
             } = Jason.decode!(body)
    end

    test "prompt placeholders get populated, even when there are multiple" do
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      prompt_with_placeholders = """
        Hello
        $LIB_PATH_PLACEHOLDER
        $LIB_CONTENT_PLACEHOLDER
        mother
        $LIB_CONTENT_PLACEHOLDER
        $TEST_CONTENT_PLACEHOLDER
        how
        $MIX_TEST_OUTPUT_PLACEHOLDER
        $TEST_PATH_PLACEHOLDER
        are
        $LIB_PATH_PLACEHOLDER
        $TEST_CONTENT_PLACEHOLDER
        you
        $MIX_TEST_OUTPUT_PLACEHOLDER
        today?
      """

      prompt_without_placeholders = """
        Hello
        lib/cool.ex
        cool lib
        mother
        cool lib
        cool test
        how
        it failed mate. get good.
        test/cool_test.exs
        are
        lib/cool.ex
        cool test
        you
        it failed mate. get good.
        today?
      """

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"

        {:ok,
         %{
           test: %{path: "test/cool_test.exs", contents: "cool test"},
           lib: %{path: "lib/cool.ex", contents: "cool lib"},
           mix_test_output: mix_test_output
         }}
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_elixir_claude_prompt(prompt_with_placeholders)

      {0, new_server_state} =
        DefaultMode.build_api_request_from_in_memory_prompt("test/cool_test.exs", server_state)

      %{claude_ai: %{request: api_request}} = new_server_state

      %{body: body} = api_request

      assert %{
               "messages" => [%{"role" => "user", "content" => ^prompt_without_placeholders}]
             } = Jason.decode!(body)
    end

    test "given server_state that is missing an ANTHROPIC_API_KEY, return error" do
      mix_test_output = "it failed mate. get good."

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", nil)
        |> ServerStateBuilder.with_default_claude_prompt()

      Mimic.expect(Cache, :get_files, fn this_test_path ->
        assert this_test_path == "test/cool_test.exs"

        {:ok,
         %{
           test: %{path: "test/cool_test.exs", contents: "cool test"},
           lib: %{path: "lib/cool.ex", contents: "cool lib"},
           mix_test_output: mix_test_output
         }}
      end)

      assert {1, server_state} ==
               DefaultMode.build_api_request_from_in_memory_prompt(
                 "test/cool_test.exs",
                 server_state
               )
    end
  end

  describe "load_in_memory_prompt/1" do
    test "when there's a custom file, we read the HOME env var to read the file" do
      home_path = "/home/el_dude"
      prompt = "cool prompt"

      server_state = ServerStateBuilder.build()

      Mimic.expect(SystemWrapper, :get_env, fn "HOME" ->
        home_path
      end)

      Mimic.expect(FileWrapper, :read, fn path ->
        assert path == home_path <> "/.config/polyglot_watcher_v2/prompt"
        {:ok, prompt}
      end)

      Mimic.expect(Puts, :on_new_line, fn msg, style ->
        assert msg == "Loading custom prompt from ~/.config/polyglot_watcher_v2/prompt ..."
        assert style == :magenta
      end)

      assert {0, new_server_state} = DefaultMode.load_in_memory_prompt(server_state)

      assert put_in(server_state, [:elixir, :claude_prompt], prompt) == new_server_state
    end

    test "when the HOME env var is missing, return error, & put error msg on the screen" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(SystemWrapper, :get_env, fn "HOME" ->
        nil
      end)

      Mimic.expect(Puts, :on_new_line, fn msg, style ->
        assert msg ==
                 "I can't check if you've got a custom prompt, because $HOME doesn't exist... sort your system out to have $HOME, then try again?"

        assert style == :red
      end)

      assert {1, server_state} == DefaultMode.load_in_memory_prompt(server_state)
    end

    test "when there's no custom file, then we load the custom prompt, and put a msg saying so" do
      home_path = "/home/el_dude"
      server_state = ServerStateBuilder.build()

      Mimic.expect(SystemWrapper, :get_env, fn "HOME" ->
        home_path
      end)

      Mimic.expect(FileWrapper, :read, fn _path ->
        {:error, :enoent}
      end)

      Mimic.expect(Puts, :on_new_line, fn msg, style ->
        assert msg == "No custom prompt file found, using default..."
        assert style == :magenta
      end)

      assert {0, new_server_state} = DefaultMode.load_in_memory_prompt(server_state)

      assert put_in(server_state, [:elixir, :claude_prompt], DefaultMode.default_prompt()) ==
               new_server_state
    end
  end
end
