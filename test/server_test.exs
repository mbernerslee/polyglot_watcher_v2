defmodule PolyglotWatcherV2.ServerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  alias PolyglotWatcherV2.{Server, ServerStateBuilder}

  describe "start_link/2" do
    test "with no command line args given, spawns the server process with default starting state" do
      capture_io(fn ->
        assert {:ok, pid} = Server.start_link([], [])
        assert is_pid(pid)

        assert %{port: port, elixir: elixir, rust: rust, files: files} = :sys.get_state(pid)
        assert files == %{}
        assert is_port(port)
        assert %{failures: [], mode: :default} == elixir
        assert %{mode: :default} == rust
      end)
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
