defmodule PolyglotWatcherV2.ActionsExecutor do
  @module Application.compile_env(:polyglot_watcher_v2, :actions_executor_module)
  def execute(runnable, server_state), do: @module.execute(runnable, server_state)
end

defmodule PolyglotWatcherV2.ActionsExecutorFake do
  def execute(_runnable, server_state), do: {0, server_state}
end

defmodule PolyglotWatcherV2.ActionsExecutorReal do
  alias PolyglotWatcherV2.{Puts, ShellCommandRunner}

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

  def execute({:puts, colour, message}, server_state) do
    {Puts.on_new_line(message, colour), server_state}
  end

  def execute({:mix_test, test_path}, server_state) do
    {_mix_test_output, exit_code} = ShellCommandRunner.run("mix test #{test_path} --color")

    # {exit_code, Language.add_mix_test_history(server_state, mix_test_output)}
    {exit_code, server_state}
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
      "I guess you fluked a test to pass... it's definitily still flakey I bet...",
      "Wow, it actually passed... and with you at the helm... incredible",
      "Congratulations... this particular set of tests... at this particlar time... are not broken (yet)"
    ]
  end
end
