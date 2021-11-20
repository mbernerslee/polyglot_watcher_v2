defmodule PolyglotWatcherV2.ActionsExecutor do
  alias PolyglotWatcherV2.{Puts, ShellCommandRunner}

  # def execute({:run_sys_cmd, _cmd, _args}, server_state) do
  #  {0, server_state}
  # end

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
    insult = Enum.random(insults())
    {Puts.on_new_line(insult, :red), server_state}
  end

  defp insults do
    [
      "OOOPPPPSIE - Somewhat predictably, you've broken something",
      "What is this? Amateur hour?",
      "Oh no, you've broken something... what a surprise...... to nobody",
      "Pretty sure there's an uragutan out that with better software than you... better looking too"
    ]
  end
end
