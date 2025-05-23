defmodule PolyglotWatcherV2.Elixir.AI.DefaultModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{
    Action,
    ActionsTreeValidator,
    FilePath,
    Puts,
    ServerStateBuilder
  }

  alias PolyglotWatcherV2.Config.AI
  alias PolyglotWatcherV2.Elixir.{Cache, Determiner, DefaultMode}
  alias PolyglotWatcherV2.Elixir.AI.DefaultMode
  alias PolyglotWatcherV2.SystemWrapper
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool_test", extension: @exs}

  describe "switch/1" do
    test "given a valid server state, switches to AI mode" do
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

    test "respects the API key name from the server_state config" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_config_ai_api_key_env_var_name("FUNKY_API_KEY")

      assert {%{actions_tree: actions_tree}, _} =
               DefaultMode.switch(server_state)

      assert %{
               persist_api_key: %Action{runnable: {:persist_env_var, "FUNKY_API_KEY"}},
               no_api_key_fail_msg: %PolyglotWatcherV2.Action{
                 runnable:
                   {:puts, :red,
                    "I read the environment variable 'FUNKY_API_KEY', but nothing was there, so I'm giving up! Try setting it and running me again..."},
                 next_action: :exit
               }
             } =
               actions_tree
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
        :build_api_request,
        :put_calling_ai_msg,
        :perform_ai_api_request,
        :parse_ai_api_response,
        :put_parsed_ai_api_response,
        :put_success_msg
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
        :build_api_request,
        :put_calling_ai_msg,
        :perform_ai_api_request,
        :parse_ai_api_response,
        :put_parsed_ai_api_response,
        :put_success_msg
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
      prompt = "cool prompt dude"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")
        |> ServerStateBuilder.with_ai_prompt(prompt)
        |> ServerStateBuilder.with_ai_config(%AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")

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

      assert %{ai_state: %{request: {_params, _opts}}} = new_server_state
    end

    test "prompt placeholders get populated" do
      mix_test_output = "it failed mate. get good."

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
        |> ServerStateBuilder.with_ai_prompt(prompt_with_placeholders)
        |> ServerStateBuilder.with_ai_config(%AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")

      {0, new_server_state} =
        DefaultMode.build_api_request_from_in_memory_prompt("test/cool_test.exs", server_state)

      %{ai_state: %{request: {%{messages: [%{content: content}]}, _opts}}} = new_server_state

      assert content == prompt_without_placeholders
    end

    test "prompt placeholders get populated, even when there are multiple" do
      mix_test_output = "it failed mate. get good."

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
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")
        |> ServerStateBuilder.with_ai_config(%AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_ai_prompt(prompt_with_placeholders)

      {0, new_server_state} =
        DefaultMode.build_api_request_from_in_memory_prompt("test/cool_test.exs", server_state)

      %{ai_state: %{request: {%{messages: [%{content: content}]}, _opts}}} = new_server_state

      assert content == prompt_without_placeholders
    end

    test "when there is no prompt in the server_state, we return an error" do
      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")
        |> ServerStateBuilder.with_ai_config(%AI{
          adapter: InstructorLite.Adapters.Anthropic,
          api_key_env_var_name: "API_KEY_NAME",
          model: "cool-model"
        })
        |> ServerStateBuilder.with_env_var("API_KEY_NAME", "COOL_API_KEY")
        |> Map.delete(:ai_prompt)

      assert {1, new_server_state} =
               DefaultMode.build_api_request_from_in_memory_prompt(
                 "test/cool_test.exs",
                 server_state
               )

      expected_action_error =
        """
        I failed to build an AI API request because I have no AI prompt in my memory which shouldn't happen.
        This means there's a bug in my code sadly :-(
        """

      assert new_server_state.action_error == expected_action_error

      assert %{server_state | action_error: expected_action_error} == new_server_state
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

      assert put_in(server_state, [:ai_prompt], prompt) == new_server_state
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

    test "when there's no custom file, then we put a msg saying so (and use the default prompt that was already loaded into the server_state when the server started up)" do
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

      assert {0, server_state} == DefaultMode.load_in_memory_prompt(server_state)
    end
  end
end
