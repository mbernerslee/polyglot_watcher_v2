defmodule PolyglotWatcherV2.ServerStateBuilder do
  alias PolyglotWatcherV2.FileSystemWatchers.Inotifywait
  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.Config
  alias PolyglotWatcherV2.Config.AI
  alias PolyglotWatcherV2.ServerState

  @claude_sonnet Const.claude_3_5_sonnet_20240620()
  @default_prompt Const.default_prompt()
  @anthropic_api_key_env_var_name Const.anthropic_api_key_env_var_name()

  def build do
    %ServerState{
      port: nil,
      ignore_file_changes: false,
      elixir: %{mode: :default},
      ai_state: %{},
      rust: %{mode: :default},
      os: :linux,
      watcher: Inotifywait,
      starting_dir: "./",
      files: %{},
      env_vars: %{},
      stored_actions: nil,
      action_error: nil,
      file_patches: nil,
      ai_prompt: @default_prompt,
      config: %Config{
        ai: %AI{
          adapter: InstructorLite.Adapters.Anthropic,
          model: @claude_sonnet,
          api_key_env_var_name: @anthropic_api_key_env_var_name
        }
      }
    }
  end

  def with_elixir_mode(server_state, mode) do
    put_in(server_state, [:elixir, :mode], mode)
  end

  def with_ai_state_response(server_state, response) do
    put_in(server_state, [:ai_state, :response], response)
  end

  def with_ai_state_request(server_state, request) do
    put_in(server_state, [:ai_state, :request], request)
  end

  def with_ignore_file_changes(server_state, bool) do
    Map.replace!(server_state, :ignore_file_changes, bool)
  end

  def with_ai_state_phase(server_state, phase) do
    put_in(server_state, [:ai_state, :phase], phase)
  end

  def with_rust_mode(server_state, mode) do
    put_in(server_state, [:rust, :mode], mode)
  end

  def with_default_ai_prompt(server_state) do
    with_ai_prompt(server_state, @default_prompt)
  end

  def with_ai_prompt(server_state, prompt) do
    Map.replace!(server_state, :ai_prompt, prompt)
  end

  def with_stored_actions(server_state, stored_actions) do
    put_in(server_state, [:stored_actions], stored_actions)
  end

  def with_action_error(server_state, action_error) do
    put_in(server_state, [:action_error], action_error)
  end

  def with_ai_config(server_state, ai_config) do
    put_in(server_state, [:config, :ai], ai_config)
  end

  def with_config_ai_api_key_env_var_name(server_state, api_key_env_var_name) do
    put_in(server_state, [:config, :ai, :api_key_env_var_name], api_key_env_var_name)
  end

  def with_env_var(server_state, key, value) do
    Map.update!(server_state, :env_vars, fn env_vars -> Map.put(env_vars, key, value) end)
  end

  def with_anthropic_api_key(server_state, api_key) do
    with_env_var(server_state, @anthropic_api_key_env_var_name, api_key)
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

  def with_file_patches(server_state, file_patches) do
    %{server_state | file_patches: file_patches}
  end
end
