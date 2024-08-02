defmodule PolyglotWatcherV2.EnvironmentVariables.SystemWrapper do
  def get_env(key), do: System.get_env(key)
end

defmodule PolyglotWatcherV2.EnvironmentVariables do
  alias PolyglotWatcherV2.EnvironmentVariables.SystemWrapper

  def read_and_persist(key, server_state) do
    case SystemWrapper.get_env(key) do
      nil -> {1, server_state}
      env_var -> {0, put_in(server_state, [:env_vars, key], env_var)}
    end
  end
end
