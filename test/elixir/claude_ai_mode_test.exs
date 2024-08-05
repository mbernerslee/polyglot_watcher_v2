defmodule PolyglotWatcherV2.Elixir.ClaudeAIModeTest do
  use ExUnit.Case, async: true
  use Mimic
  require PolyglotWatcherV2.ActionsTreeValidator

  alias PolyglotWatcherV2.{ActionsTreeValidator, FilePath, Puts, ServerStateBuilder}
  alias PolyglotWatcherV2.Elixir.{Determiner, ClaudeAIMode}
  alias HTTPoison.{Request, Response}
  alias PolyglotWatcherV2.EnvironmentVariables.SystemWrapper
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @ex Determiner.ex()
  @exs Determiner.exs()
  @server_state_normal_mode ServerStateBuilder.build()
  @lib_ex_file_path %FilePath{path: "lib/cool", extension: @ex}
  @test_exs_file_path %FilePath{path: "test/cool_test", extension: @exs}

  describe "switch/1" do
    test "given a valid server state, switches to ClaudeAI mode" do
      assert {tree, @server_state_normal_mode} = ClaudeAIMode.switch(@server_state_normal_mode)

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
        ClaudeAIMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_claude_init_msg,
        :put_perist_files_msg,
        :persist_lib_file,
        :persist_test_file,
        :load_prompt,
        :build_claude_api_request,
        :put_calling_claude_msg,
        :perform_claude_api_request,
        :parse_claude_api_response,
        :put_parsed_claude_api_response,
        :missing_file_msg,
        :fallback_placeholder_error,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a lib file, puts the correct test file path" do
      {%{actions_tree: actions_tree}, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(@lib_ex_file_path, @server_state_normal_mode)

      assert actions_tree.persist_test_file.runnable ==
               {:persist_file, "test/cool_test.exs", :test}
    end

    test "given a test file, puts the correct lib file path" do
      {%{actions_tree: actions_tree}, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(
          %FilePath{path: "test/elixir/claude_ai_mode_test", extension: @exs},
          @server_state_normal_mode
        )

      assert actions_tree.persist_lib_file.runnable ==
               {:persist_file, "lib/elixir/claude_ai_mode.ex", :lib}
    end

    test "given a test file, returns a valid action tree" do
      {tree, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(@test_exs_file_path, @server_state_normal_mode)

      expected_action_tree_keys = [
        :clear_screen,
        :put_intent_msg,
        :mix_test,
        :put_claude_init_msg,
        :put_perist_files_msg,
        :persist_lib_file,
        :persist_test_file,
        :load_prompt,
        :build_claude_api_request,
        :put_calling_claude_msg,
        :perform_claude_api_request,
        :parse_claude_api_response,
        :put_parsed_claude_api_response,
        :missing_file_msg,
        :fallback_placeholder_error,
        :put_success_msg,
        :put_failure_msg
      ]

      ActionsTreeValidator.assert_exact_keys(tree, expected_action_tree_keys)

      assert ActionsTreeValidator.validate(tree)
    end

    test "given a lib file, but in an invalid format, returns an error actions tree" do
      {tree, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(
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

    test "given a test file, but in an invalid format, returns an error actions tree" do
      {tree, @server_state_normal_mode} =
        ClaudeAIMode.determine_actions(
          %FilePath{path: "not_test/not_cool", extension: @exs},
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

  describe "build_api_request/2" do
    test "given server_state that contains the required info to build the API call, then it is built and stored in the server_state" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"
      prompt = "cool prompt dude"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_claude_prompt(prompt)

      assert {0, new_server_state} = ClaudeAIMode.build_api_request(server_state)

      assert %{elixir: %{claude_api_request: api_request}} = new_server_state

      assert put_in(server_state, [:elixir, :claude_api_request], api_request) == new_server_state

      assert %Request{
               method: :post,
               url: "https://api.anthropic.com/v1/messages",
               headers: [
                 {"x-api-key", ^api_key},
                 {"anthropic-version", "2023-06-01"},
                 {"content-type", "application/json"}
               ],
               body: body,
               options: [recv_timeout: 30_000]
             } = api_request

      assert %{
               "max_tokens" => 2048,
               "model" => "claude-3-5-sonnet-20240620",
               "messages" => [%{"role" => "user", "content" => ^prompt}]
             } = Jason.decode!(body)
    end

    test "prompt placeholders get populated" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
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

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_claude_prompt(prompt_with_placeholders)

      {0, new_server_state} = ClaudeAIMode.build_api_request(server_state)

      %{elixir: %{claude_api_request: api_request}} = new_server_state

      %Request{
        method: :post,
        url: "https://api.anthropic.com/v1/messages",
        headers: [
          {"x-api-key", ^api_key},
          {"anthropic-version", "2023-06-01"},
          {"content-type", "application/json"}
        ],
        body: body,
        options: [recv_timeout: 30_000]
      } = api_request

      assert %{
               "max_tokens" => 2048,
               "model" => "claude-3-5-sonnet-20240620",
               "messages" => [%{"role" => "user", "content" => ^prompt_without_placeholders}]
             } = Jason.decode!(body)
    end

    test "prompt placeholders get populated, even when there are multiple" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
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

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_claude_prompt(prompt_with_placeholders)

      {0, new_server_state} = ClaudeAIMode.build_api_request(server_state)

      %{elixir: %{claude_api_request: api_request}} = new_server_state

      %Request{
        method: :post,
        url: "https://api.anthropic.com/v1/messages",
        headers: [
          {"x-api-key", ^api_key},
          {"anthropic-version", "2023-06-01"},
          {"content-type", "application/json"}
        ],
        body: body,
        options: [recv_timeout: 30_000]
      } = api_request

      assert %{
               "max_tokens" => 2048,
               "model" => "claude-3-5-sonnet-20240620",
               "messages" => [%{"role" => "user", "content" => ^prompt_without_placeholders}]
             } = Jason.decode!(body)
    end

    test "given server_state that is missing any of the required info to build the API call, then we return exit_code 1 and leave the server_state unchanged" do
      lib_file = %{path: "lib/cool.ex", contents: "cool lib"}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_default_claude_prompt()

      assert {0, _} = ClaudeAIMode.build_api_request(server_state)

      bad_server_states = [
        ServerStateBuilder.with_file(server_state, :lib, nil),
        ServerStateBuilder.with_file(server_state, :test, nil),
        ServerStateBuilder.with_mix_test_output(server_state, nil),
        ServerStateBuilder.with_env_var(server_state, "ANTHROPIC_API_KEY", nil)
      ]

      Enum.each(bad_server_states, fn bad_server_state ->
        assert {1, bad_server_state} == ClaudeAIMode.build_api_request(bad_server_state)
      end)
    end
  end

  describe "parse_api_response/2" do
    test "given some server state containing a happy api response, put the parsed response into the server state" do
      response_text = "some text"
      body = Jason.encode!(%{"content" => [%{"text" => response_text}]})

      response = {:ok, %Response{status_code: 200, body: body}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_claude_api_response(response)

      assert {0, new_server_state} = ClaudeAIMode.parse_api_response(server_state)

      parsed = {:ok, {:parsed, response_text}}

      assert put_in(server_state, [:elixir, :claude_api_response], parsed) ==
               new_server_state
    end

    test "given some server state containing a sad api response with an unparsable HTTP 200 body, put the parsed response into the server state" do
      body = Jason.encode!(%{"nope" => [%{"sad" => "times"}]})

      response = {:ok, %Response{status_code: 200, body: body}}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_claude_api_response(response)

      assert {1, new_server_state} = ClaudeAIMode.parse_api_response(server_state)

      parsed =
        {:error,
         {:parsed,
          """
          I failed to decode the Claude API HTTP 200 response :-(
          It was:

          #{body}
          """}}

      assert put_in(server_state, [:elixir, :claude_api_response], parsed) ==
               new_server_state
    end

    test "given some server state containing a sad api response with a non HTTP 200 response, put the parsed response into the server state" do
      body = Jason.encode!(%{"its" => "wrecked"})

      response = %Response{status_code: 500, body: body}

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_elixir_claude_api_response(response)

      assert {1, new_server_state} = ClaudeAIMode.parse_api_response(server_state)

      parsed =
        {:error,
         {:parsed,
          """
          Claude API did not return a HTTP 200 response :-(
          It was:

          #{inspect(response)}
          """}}

      assert put_in(server_state, [:elixir, :claude_api_response], parsed) ==
               new_server_state
    end

    test "given some server state NOT containing a response whatsoever, return an error" do
      server_state = ServerStateBuilder.build()

      assert {1, new_server_state} = ClaudeAIMode.parse_api_response(server_state)

      parsed = {:error, {:parsed, "I have no Claude API response in my memory..."}}

      assert put_in(server_state, [:elixir, :claude_api_response], parsed) ==
               new_server_state
    end
  end

  describe "load_prompt/1" do
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
        assert msg == "Loading custom prompt from file..."
        assert style == :magenta
      end)

      assert {0, new_server_state} = ClaudeAIMode.load_prompt(server_state)

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

      assert {1, server_state} == ClaudeAIMode.load_prompt(server_state)
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

      assert {0, new_server_state} = ClaudeAIMode.load_prompt(server_state)

      assert put_in(server_state, [:elixir, :claude_prompt], ClaudeAIMode.default_prompt()) ==
               new_server_state
    end
  end
end
