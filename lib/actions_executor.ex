defmodule PolyglotWatcherV2.ActionsExecutor do
  def execute(runnable, server_state), do: module().execute(runnable, server_state)

  defp module, do: Application.get_env(:polyglot_watcher_v2, :actions_executor_module)
end

defmodule PolyglotWatcherV2.ActionsExecutorFake do
  def execute(_runnable, server_state), do: {0, server_state}
end

defmodule PolyglotWatcherV2.ActionsExecutorReal do
  alias PolyglotWatcherV2.{Puts, ShellCommandRunner}
  alias PolyglotWatcherV2.Elixir.{ClaudeAIMode, Failures}
  alias HTTPoison.{Request, Response}

  @actually_clear_screen Application.compile_env(:polyglot_watcher_v2, :actually_clear_screen)
  @log Application.compile_env(:polyglot_watcher_v2, :log_executor_commands)

  def execute(command, server_state) do
    log(command)
    do_execute(command, server_state)
  end

  def do_execute(:clear_screen, server_state) do
    if @actually_clear_screen do
      do_execute({:run_sys_cmd, "tput", ["reset"]}, server_state)
    else
      {0, server_state}
    end
  end

  def do_execute({:run_sys_cmd, cmd, args}, server_state) do
    {_std_out, exit_code} = System.cmd(cmd, args, into: IO.stream(:stdio, :line))
    {exit_code, server_state}
  end

  def do_execute({:puts, messages}, server_state) do
    {Puts.on_new_line(messages), server_state}
  end

  def do_execute({:puts, colour, message}, server_state) do
    {Puts.on_new_line(message, colour), server_state}
  end

  def do_execute({:switch_mode, language, mode}, server_state) do
    {0, put_in(server_state, [language, :mode], mode)}
  end

  def do_execute({:mix_test_persist_output, test_path}, server_state) do
    mix_test(test_path, server_state, persist_output: true)
  end

  def do_execute({:mix_test, test_path}, server_state) do
    mix_test(test_path, server_state)
  end

  def do_execute(:mix_test, server_state) do
    mix_test(:all, server_state)
  end

  def do_execute({:persist_env_var, key, accessor}, server_state) do
    case System.get_env(key) do
      nil -> {1, server_state}
      env_var -> {0, put_in(server_state, accessor, env_var) |> IO.inspect()}
    end
  end

  def do_execute({:persist_file, path, key}, server_state) do
    IO.inspect(path)

    case File.read(path) do
      {:ok, contents} ->
        files = Map.put(server_state.files, key, contents)
        {0, put_in(server_state, [:files], files)}

      error ->
        {error, server_state}
    end
  end

  def do_execute(:build_claude_api_call, server_state) do
    case ClaudeAIMode.build_api_call(server_state) do
      {:ok, request} ->
        {0, put_in(server_state, [:elixir, :claude_api_request], request)}

      _error ->
        {1, server_state}
    end
  end

  def do_execute(
        :perform_claude_api_request,
        %{elixir: %{claude_api_request: %Request{} = request}} = server_state
      ) do
    response = HTTPoison.request(request)
    {0, put_in(server_state, [:elixir, :claude_api_response], response)}
  end

  def do_execute(:perform_claude_api_request, server_state) do
    {{:error, :missing_or_invalid_request}, server_state}
  end

  def do_execute(
        :put_claude_api_response,
        %{elixir: %{claude_api_response: response}} = server_state
      ) do
    case response do
      {:ok, %Response{status_code: 200, body: body}} ->
        resp =
          body
          |> Jason.decode!()
          |> Map.fetch!("content")
          |> hd()
          |> Map.fetch!("text")

        IO.puts(resp)

        # File.write!("claude", resp)

        {0, server_state}

      error ->
        IO.inspect("****************************")
        IO.inspect("ERROR :-(")
        IO.inspect("****************************")
        IO.inspect(error, limit: :infinity)
        IO.inspect("****************************")
        {1, server_state}
    end
  end

  def do_execute(:put_claude_api_response, server_state) do
    {{:error, :missing_or_invalid_response}, server_state}
  end

  def do_execute(:cargo_build, server_state) do
    {_cargo_build_output, exit_code} = ShellCommandRunner.run("cargo build --color=always")
    {exit_code, server_state}
  end

  def do_execute(:cargo_test, server_state) do
    {_cargo_build_output, exit_code} =
      ShellCommandRunner.run("cargo test -q --color=always -- --color=always")

    {exit_code, server_state}
  end

  def do_execute(:put_insult, server_state) do
    insult = Enum.random(insulting_failure_messages())
    {Puts.on_new_line(insult, :red), server_state}
  end

  def do_execute(:put_sarcastic_success, server_state) do
    insult = Enum.random(sarcastic_sucesses())
    {Puts.on_new_line(insult, :green), server_state}
  end

  def do_execute({:file_exists, file_path}, server_state) do
    {File.exists?(file_path), server_state}
  end

  def do_execute(:noop, server_state) do
    {0, server_state}
  end

  def do_execute({:put_elixir_failures_count, all_or_filename}, server_state) do
    server_state.elixir.failures
    |> Failures.count(all_or_filename)
    |> Failures.count_message()
    |> Puts.on_new_line()

    {server_state.elixir.mix_test_exit_code, server_state}
  end

  def do_execute(unknown, server_state) do
    Puts.on_new_line(
      "Unknown runnable action given to ActionsExecutor. It was #{inspect(unknown)}, can't do it",
      :red
    )

    {1, server_state}
  end

  defp mix_test(test_path, server_state, opts \\ []) do
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

    server_state =
      server_state
      |> put_in([:elixir, :failures], failures)
      |> put_in([:elixir, :mix_test_exit_code], exit_code)

    if Keyword.get(opts, :persist_output, false) do
      server_state = put_in(server_state, [:elixir, :mix_test_output], mix_test_output)
      {exit_code, server_state}
    else
      {exit_code, server_state}
    end
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

  defp log(message) do
    if @log do
      do_log(message)
    else
      message
    end
  end

  defp do_log(message) when is_binary(message) do
    Puts.on_new_line(message, :yellow)
    message
  end

  defp do_log(message) do
    message |> inspect() |> do_log()
    message
  end
end
