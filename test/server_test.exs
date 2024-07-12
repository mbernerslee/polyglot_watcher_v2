defmodule PolyglotWatcherV2.ServerTest do
  use ExUnit.Case, async: false
  use Mimic
  import ExUnit.CaptureIO

  alias PolyglotWatcherV2.{Server, ServerStateBuilder}
  alias PolyglotWatcherV2.EnvironmentVariables.Stub, as: EnvironmentVariablesStub

  setup :set_mimic_global

  describe "start_link/1" do
    test "can spawn the server process with default starting state" do
      assert {:ok, pid} = Server.start_link([])
      assert is_pid(pid)

      assert %{port: port, elixir: elixir, rust: rust} = :sys.get_state(pid)
      assert is_port(port)
      assert %{failures: [], mode: :default} == elixir
      assert %{mode: :default} == rust
    end

    test "the path from the env vars gets set as the $PATH" do
      %{path: path_read_from_env_var} = EnvironmentVariablesStub.read()

      Mimic.expect(EnvironmentVariablesStub, :put, fn env_key, env_value ->
        assert "PATH" == env_key
        assert env_value == path_read_from_env_var
      end)

      assert {:ok, _pid} = Server.start_link([])
    end

    test "exits if the POLYGLOT_WATCHER_V2_CLI_ARGS Environement Varible is not in the expected format" do
      env_vars = EnvironmentVariablesStub.read()
      Mimic.expect(EnvironmentVariablesStub, :read, fn -> %{env_vars | cli_args: "nope"} end)

      Process.flag(:trap_exit, true)

      capture_io(fn ->
        assert {:error,
                "POLYGLOT_WATCHER_V2_CLI_ARGS environment variable not set properly. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."} ==
                 Server.start_link([])
      end)
    end

    test "exits if the POLYGLOT_WATCHER_V2_CLI_ARGS Environement Varible is missing" do
      env_vars = EnvironmentVariablesStub.read()
      Mimic.expect(EnvironmentVariablesStub, :read, fn -> %{env_vars | cli_args: nil} end)

      Process.flag(:trap_exit, true)

      capture_io(fn ->
        assert {:error,
                "POLYGLOT_WATCHER_V2_CLI_ARGS environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."} ==
                 Server.start_link([])
      end)
    end

    test "exits if the POLYGLOT_WATCHER_V2_PATH Environement Varible is missing" do
      env_vars = EnvironmentVariablesStub.read()
      Mimic.expect(EnvironmentVariablesStub, :read, fn -> %{env_vars | path: nil} end)

      Process.flag(:trap_exit, true)

      capture_io(fn ->
        assert {:error,
                "POLYGLOT_WATCHER_V2_PATH environment variable not set. This should be guarenteed to be set by the packaged application and its a serious bug you're reading this message."} ==
                 Server.start_link([])
      end)
    end
  end

  describe "child_spec/0" do
    test "returns the default genserver options, with the callers pid" do
      assert %{
               id: Server,
               start: {Server, :start_link, [[name: :server]]}
             } == Server.child_spec()
    end
  end

  describe "handle_info/2 - file_event" do
    test "regonises file events from FileSystem, & returns a server_state" do
      server_state = ServerStateBuilder.build()

      assert {:noreply, new_server_state} =
               Server.handle_info(
                 {:port, {:data, ~c"./test/ CLOSE_WRITE,CLOSE server_test.exs\n"}},
                 server_state
               )

      assert new_server_state == server_state
    end
  end
end
