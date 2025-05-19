defmodule PolyglotWatcherV2.EnvironmentVariables do
  alias PolyglotWatcherV2.SystemWrapper

  def read_and_persist(key, server_state) do
    case SystemWrapper.get_env(key) do
      nil -> {1, server_state}
      env_var -> {0, put_in(server_state, [:env_vars, key], env_var)}
    end
  end

  def get_env(key), do: SystemWrapper.get_env(key)
end
