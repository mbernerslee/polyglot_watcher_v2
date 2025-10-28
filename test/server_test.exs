defmodule PolyglotWatcherV2.ServerTest do
  use ExUnit.Case, async: false
  use Mimic
  import ExUnit.CaptureIO

  alias PolyglotWatcherV2.{
    Config,
    OSWrapper,
    Server,
    ServerState,
    ServerStateBuilder,
    SystemWrapper
  }

  alias PolyglotWatcherV2.Support.Mocks.ConfigFileMock

  setup :set_mimic_global

  describe "start_link/2" do
    test "with no command line args given, spawns the server process with default starting state" do
      Mimic.expect(OSWrapper, :type, fn -> {:unix, :linux} end)
      ConfigFileMock.read_valid()

      assert {:ok, pid} = Server.start_link([], [])
      assert is_pid(pid)

      assert %ServerState{
               port: port,
               elixir: elixir,
               rust: rust,
               config: %Config{},
               ai_prompts: %{}
             } =
               :sys.get_state(pid)

      assert is_port(port)
      assert %{mode: :default} == elixir
      assert %{mode: :default} == rust
    end

    test "when the config file reading fails, we stop" do
      Mimic.expect(OSWrapper, :type, fn -> {:unix, :linux} end)
      ConfigFileMock.read_failed()
      Process.flag(:trap_exit, true)

      capture_io(fn ->
        pid = spawn_link(fn -> Server.start_link([], []) end)
        assert_receive {:EXIT, ^pid, "Error reading config" <> _}
      end)
    end

    test "when its an os we don't support, we stop" do
      Mimic.expect(OSWrapper, :type, fn -> :windows_95 end)

      Process.flag(:trap_exit, true)

      capture_io(fn ->
        pid = spawn_link(fn -> Server.start_link([], []) end)

        assert_receive {:EXIT, ^pid,
                        "I don't support your operating system ':windows_95', so I'm exiting"}
      end)
    end

    test "overwrites $PATH with the contents of $POLYGLOT_WATCHER_V2_PATH" do
      expected_path = "COOL_PATH"

      ConfigFileMock.read_valid()

      Mimic.expect(SystemWrapper, :get_env, fn "POLYGLOT_WATCHER_V2_PATH", "" -> expected_path end)

      Mimic.expect(SystemWrapper, :put_env, fn "PATH", ^expected_path -> :ok end)

      Server.start_link([], [])
    end
  end

  describe "child_spec/0" do
    test "returns the default genserver options, with the callers pid" do
      assert %{
               id: Server,
               start: {Server, :start_link, [[], [name: :server]]}
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
