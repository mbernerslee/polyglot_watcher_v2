defmodule PolyglotWatcherV2.ServerStateBuilder do
  alias PolyglotWatcherV2.Inotifywait
  alias PolyglotWatcherV2.Elixir.ClaudeAI.DefaultMode, as: ClaudeAIDefaultMode

  def build do
    %{
      port: nil,
      ignore_file_changes: false,
      elixir: %{mode: :default},
      claude_ai: %{},
      rust: %{mode: :default},
      os: :linux,
      watcher: Inotifywait,
      starting_dir: "./",
      files: %{},
      env_vars: %{},
      stored_actions: nil,
      action_error: nil
    }
  end

  def with_elixir_mode(server_state, mode) do
    put_in(server_state, [:elixir, :mode], mode)
  end

  def with_claude_ai_response(server_state, response) do
    put_in(server_state, [:claude_ai, :response], response)
  end

  def with_claude_ai_request(server_state, request) do
    put_in(server_state, [:claude_ai, :request], request)
  end

  def with_rust_mode(server_state, mode) do
    put_in(server_state, [:rust, :mode], mode)
  end

  def with_elixir_claude_prompt(server_state, prompt) do
    put_in(server_state, [:elixir, :claude_prompt], prompt)
  end

  def with_default_claude_prompt(server_state) do
    put_in(server_state, [:elixir, :claude_prompt], ClaudeAIDefaultMode.default_prompt())
  end

  def with_stored_actions(server_state, stored_actions) do
    put_in(server_state, [:stored_actions], stored_actions)
  end

  def with_action_error(server_state, action_error) do
    put_in(server_state, [:action_error], action_error)
  end

  def with_env_var(server_state, key, value) do
    Map.update!(server_state, :env_vars, fn env_vars -> Map.put(env_vars, key, value) end)
  end

  def with_claude_api_key(server_state, api_key) do
    with_env_var(server_state, "ANTHROPIC_API_KEY", api_key)
  end

  def with_file(server_state, key, %{contents: contents, path: path}) do
    Map.update!(server_state, :files, fn files ->
      Map.put(files, key, %{contents: contents, path: path})
    end)
  end

  def with_file(server_state, key, nil) do
    Map.update!(server_state, :files, fn files ->
      Map.put(files, key, nil)
    end)
  end
end
