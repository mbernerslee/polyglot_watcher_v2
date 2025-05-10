defmodule PolyglotWatcherV2.ActionsExecutor do
  def execute(runnable, server_state), do: module().execute(runnable, server_state)

  defp module, do: Application.get_env(:polyglot_watcher_v2, :actions_executor_module)
end

defmodule PolyglotWatcherV2.ActionsExecutorFake do
  def execute(_runnable, server_state), do: {0, server_state}
end

defmodule PolyglotWatcherV2.ActionsExecutorReal do
  require Logger

  alias PolyglotWatcherV2.{
    ClaudeAI,
    EnvironmentVariables,
    FileSystem,
    GitDiff,
    Puts,
    ShellCommandRunner
  }

  alias PolyglotWatcherV2.Elixir.{MixTest, MixTestArgs, MixTestLatest}
  alias PolyglotWatcherV2.Elixir.ClaudeAI.DefaultMode, as: ClaudeAIDefaultMode
  alias PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode, as: ClaudeAIReplaceMode

  def execute(command, server_state) do
    Logger.debug("#{__MODULE__} running: #{inspect(command)}")
    do_execute(command, server_state)
  end

  defp do_execute(:clear_screen, server_state) do
    if actually_clear_screen?() do
      do_execute({:run_sys_cmd, "tput", ["reset"]}, server_state)
    else
      {0, server_state}
    end
  end

  defp do_execute({:run_sys_cmd, cmd, args}, server_state) do
    {_std_out, exit_code} = System.cmd(cmd, args, into: IO.stream(:stdio, :line))
    {exit_code, server_state}
  end

  defp do_execute({:git_diff, file_path, search, replacement}, server_state) do
    GitDiff.run(file_path, search, replacement, server_state)
  end

  defp do_execute({:puts, messages}, server_state) do
    {Puts.on_new_line(messages), server_state}
  end

  defp do_execute({:puts, colour, message}, server_state) do
    {Puts.on_new_line(message, colour), server_state}
  end

  defp do_execute({:switch_mode, language, mode}, server_state) do
    {0, put_in(server_state, [language, :mode], mode)}
  end

  defp do_execute(:mix_test, server_state) do
    MixTest.run(%MixTestArgs{path: :all}, server_state)
  end

  defp do_execute({:mix_test, %MixTestArgs{} = mix_test_args}, server_state) do
    MixTest.run(mix_test_args, server_state)
  end

  defp do_execute(:mix_test_latest_max_failures_1, server_state) do
    MixTestLatest.max_failures_1(server_state)
  end

  defp do_execute(:mix_test_latest_line, server_state) do
    MixTestLatest.line(server_state)
  end

  defp do_execute({:mix_test_latest_line, test_path}, server_state) do
    MixTestLatest.line(test_path, server_state)
  end

  defp do_execute({:persist_env_var, key}, server_state) do
    EnvironmentVariables.read_and_persist(key, server_state)
  end

  defp do_execute({:persist_file, path, key}, server_state) do
    FileSystem.read_and_persist(path, key, server_state)
  end

  defp do_execute(:load_in_memory_prompt, server_state) do
    ClaudeAIDefaultMode.load_in_memory_prompt(server_state)
  end

  defp do_execute({:build_claude_api_request_from_in_memory_prompt, test_path}, server_state) do
    ClaudeAIDefaultMode.build_api_request_from_in_memory_prompt(test_path, server_state)
  end

  defp do_execute({:build_claude_replace_api_request, test_path}, server_state) do
    ClaudeAIReplaceMode.RequestBuilder.build(test_path, server_state)
  end

  defp do_execute(:build_claude_replace_blocks, server_state) do
    ClaudeAIReplaceMode.BlocksBuilder.parse(server_state)
  end

  defp do_execute(:build_claude_replace_actions, server_state) do
    ClaudeAIReplaceMode.ActionsBuilder.build(server_state)
  end

  defp do_execute(:perform_claude_api_request, server_state) do
    ClaudeAI.perform_api_call(server_state)
  end

  defp do_execute({:perform_claude_replace_api_call, test_path}, server_state) do
    ClaudeAIReplaceMode.APICall.perform(server_state)
  end

  defp do_execute(:claude_replace_prepare_file_updates, server_state) do
    ClaudeAIReplaceMode.PrepareFileUpdates.run(server_state)
  end

  defp do_execute(:parse_claude_api_response, server_state) do
    ClaudeAI.parse_claude_api_response(server_state)
  end

  defp do_execute(:put_parsed_claude_api_response, server_state) do
    ClaudeAI.put_parsed_response(server_state)
  end

  defp do_execute(:cargo_build, server_state) do
    {_cargo_build_output, exit_code} = ShellCommandRunner.run("cargo build --color=always")
    {exit_code, server_state}
  end

  defp do_execute(:cargo_test, server_state) do
    {_cargo_build_output, exit_code} =
      ShellCommandRunner.run("cargo test -q --color=always -- --color=always")

    {exit_code, server_state}
  end

  defp do_execute(:put_insult, server_state) do
    insult = Enum.random(insulting_failure_messages())
    {Puts.on_new_line(insult, :red), server_state}
  end

  defp do_execute(:put_sarcastic_success, server_state) do
    insult = Enum.random(sarcastic_sucesses())
    {Puts.on_new_line(insult, :green), server_state}
  end

  defp do_execute({:file_exists, file_path}, server_state) do
    {File.exists?(file_path), server_state}
  end

  defp do_execute(:noop, server_state) do
    {0, server_state}
  end

  defp do_execute(unknown, server_state) do
    Puts.on_new_line(
      "Unknown runnable action given to ActionsExecutor. It was #{inspect(unknown)}, can't do it",
      :red
    )

    {1, server_state}
  end

  defp insulting_failure_messages do
    [
      "OOOPPPPSIE - Somewhat predictably, you've broken something",
      "What is this? Amateur hour?",
      "Oh no, you've broken something... what a surprise...... to nobody",
      "Pretty sure there's an uragutan out that with better software writing skills than you... better looking too",
      "Looks like you wrecked it mate",
      "We're going to lose a $10M deal because of this embarassing failure... unbelievable"
    ]
  end

  defp sarcastic_sucesses do
    [
      "Much like 1000 monkeys could eventually write Shakespeare... you've managed to make some tests pass...",
      "I guess you fluked a test to pass... it's definitely still flakey I bet...",
      "Wow, it actually passed... and with you at the helm... incredible",
      "Congratulations... this particular set of tests... at this particular time... are not broken (yet)"
    ]
  end

  defp actually_clear_screen? do
    Application.get_env(:polyglot_watcher_v2, :actually_clear_screen) |> IO.inspect()
  end
end
