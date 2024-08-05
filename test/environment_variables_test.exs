defmodule PolyglotWatcherV2.EnvironmentVariablesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.{EnvironmentVariables, ServerStateBuilder}
  alias PolyglotWatcherV2.EnvironmentVariables.SystemWrapper

  describe "read_and_persist/2" do
    test "given an env var key which exists on the system & server state, we persist it in the server state" do
      env_var_key = "SOME_ENV_VAR"
      env_var_value = "SOME VALUE"

      Mimic.expect(SystemWrapper, :get_env, fn this_env_var_key ->
        assert this_env_var_key == env_var_key
        env_var_value
      end)

      server_state = ServerStateBuilder.build()

      assert {0, new_server_state} =
               EnvironmentVariables.read_and_persist(env_var_key, server_state)

      assert put_in(server_state, [:env_vars, env_var_key], env_var_value) ==
               new_server_state
    end

    test "given an env var key which DOES NOT exist on the system & server state, we do not persist it in the server state & return exit code 1" do
      env_var_key = "SOME_ENV_VAR"

      Mimic.expect(SystemWrapper, :get_env, fn this_env_var_key ->
        assert this_env_var_key == env_var_key
        nil
      end)

      server_state = ServerStateBuilder.build()

      assert {1, server_state} ==
               EnvironmentVariables.read_and_persist(env_var_key, server_state)
    end

    test "given existing persisted env vars, we can persist another under a different key" do
      old_env_var_key = "EXISTING_ENV_VAR"
      old_env_var_value = "EXISTING VALUE"

      new_env_var_key = "SOME_ENV_VAR"
      new_env_var_value = "SOME VALUE"

      Mimic.expect(SystemWrapper, :get_env, fn this_env_var_key ->
        assert this_env_var_key == new_env_var_key
        new_env_var_value
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var(old_env_var_key, old_env_var_value)

      assert {0, new_server_state} =
               EnvironmentVariables.read_and_persist(new_env_var_key, server_state)

      assert new_server_state.env_vars == %{
               new_env_var_key => new_env_var_value,
               old_env_var_key => old_env_var_value
             }
    end

    test "can overwrite old env var with new value" do
      env_var_key = "KEY"
      old_env_var_value = "OLD"
      new_env_var_value = "NEW"

      Mimic.expect(SystemWrapper, :get_env, fn _ ->
        new_env_var_value
      end)

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_env_var(env_var_key, old_env_var_value)

      assert {0, new_server_state} =
               EnvironmentVariables.read_and_persist(env_var_key, server_state)

      assert new_server_state.env_vars == %{env_var_key => new_env_var_value}
    end
  end

  describe "get_env/1" do
    test "it calls SystemWrapper.get_env/1" do
      Mimic.expect(SystemWrapper, :get_env, fn "key" ->
        "cool"
      end)

      assert EnvironmentVariables.get_env("key") == "cool"
    end
  end
end
