defmodule PolyglotWatcherV2.ActionsExecutor do
  @module Application.compile_env(:polyglot_watcher_v2, :actions_executor_module)
  def execute(runnable, server_state), do: @module.execute(runnable, server_state)
end

defmodule PolyglotWatcherV2.ActionsExecutorFake do
  def execute(_runnable, server_state), do: {0, server_state}
end

defmodule PolyglotWatcherV2.ActionsExecutorReal do
  alias PolyglotWatcherV2.{Puts, ShellCommandRunner}
  alias PolyglotWatcherV2.Elixir.Failures
  alias PolyglotWatcherV2.Elm.FileFinder, as: ElmFileFinder

  @actually_clear_screen Application.compile_env(:polyglot_watcher_v2, :actually_clear_screen)

  def execute(:clear_screen, server_state) do
    if @actually_clear_screen do
      execute({:run_sys_cmd, "tput", ["reset"]}, server_state)
    else
      {0, server_state}
    end
  end

  def execute({:run_sys_cmd, cmd, args}, server_state) do
    {_std_out, exit_code} = System.cmd(cmd, args, into: IO.stream(:stdio, :line))
    {exit_code, server_state}
  end

  def execute({:puts, messages}, server_state) do
    {Puts.on_new_line(messages), server_state}
  end

  def execute({:puts, colour, message}, server_state) do
    {Puts.on_new_line(message, colour), server_state}
  end

  def execute({:switch_mode, language, mode}, server_state) do
    {0, put_in(server_state, [language, :mode], mode)}
  end

  def execute({:mix_test, test_path}, server_state) do
    mix_test(test_path, server_state)
  end

  def execute(:mix_test, server_state) do
    mix_test(:all, server_state)
  end

  def execute(:put_insult, server_state) do
    insult = Enum.random(insulting_failure_messages())
    {Puts.on_new_line(insult, :red), server_state}
  end

  def execute(:put_sarcastic_success, server_state) do
    insult = Enum.random(sarcastic_sucesses())
    {Puts.on_new_line(insult, :green), server_state}
  end

  def execute({:file_exists, file_path}, server_state) do
    {File.exists?(file_path), server_state}
  end

  def execute({:find_elm_json, file_path}, server_state) do
    ElmFileFinder.json(file_path, server_state)
  end

  def execute({:find_elm_main, file_path}, server_state) do
    ElmFileFinder.main(file_path, server_state)
  end

  def execute(:elm_make, server_state) do
    %{json_path: json_path, main_path: main_path} = server_state.elm
    File.cd!(json_path)
    {_output, exit_code} = ShellCommandRunner.run("elm make #{main_path}")
    File.cd!(server_state.starting_dir)
    {exit_code, server_state}
  end

  def execute(:noop, server_state) do
    {0, server_state}
  end

  def execute(unknown, server_state) do
    Puts.on_new_line(
      "Unknown runnable action given to ActionsExecutor. It was #{inspect(unknown)}, can't do it",
      :red
    )

    {1, server_state}
  end

  defp mix_test(test_path, server_state) do
    {mix_test_output, exit_code} =
      case test_path do
        :all -> ShellCommandRunner.run("mix test --color")
        path -> ShellCommandRunner.run("mix test #{path} --color")
      end

    failures =
      Failures.update(
        server_state.elixir.failures,
        test_path,
        mix_test_output,
        exit_code
      )

    {exit_code, put_in(server_state, [:elixir, :failures], failures)}
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
end
