defmodule PolyglotWatcherV2.MCP.HandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.Handler
  alias PolyglotWatcherV2.Elixir.{Cache, MixTestArgs}
  alias PolyglotWatcherV2.ShellCommandRunner

  describe "handle_message/1 - initialize" do
    test "returns protocol version, capabilities, and server info" do
      assert {:ok,
              %{
                "jsonrpc" => "2.0",
                "id" => 1,
                "result" => %{
                  "protocolVersion" => "2025-03-26",
                  "capabilities" => %{"tools" => %{}},
                  "serverInfo" => %{"name" => "polyglot-watcher"}
                }
              }} = Handler.handle_message(%{"method" => "initialize", "id" => 1, "params" => %{}})
    end
  end

  describe "handle_message/1 - notifications/initialized" do
    test "returns :accepted" do
      assert :accepted == Handler.handle_message(%{"method" => "notifications/initialized"})
    end
  end

  describe "handle_message/1 - ping" do
    test "returns empty result" do
      assert {:ok, %{"jsonrpc" => "2.0", "id" => 2, "result" => %{}}} =
               Handler.handle_message(%{"method" => "ping", "id" => 2})
    end
  end

  describe "handle_message/1 - tools/list" do
    test "returns the mix_test tool definition" do
      assert {:ok,
              %{
                "id" => 3,
                "result" => %{
                  "tools" => [%{"name" => "mix_test", "description" => description}]
                }
              }} = Handler.handle_message(%{"method" => "tools/list", "id" => 3})

      assert is_binary(description)
    end
  end

  describe "handle_message/1 - tools/call mix_test" do
    test "calls mix_test and returns result" do
      args = %MixTestArgs{path: "test/cool_test.exs"}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs --color" ->
        {"1 test, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "1 test, 0 failures", 0 -> :ok end)

      assert {:ok,
              %{
                "id" => 4,
                "result" => %{"content" => [%{"type" => "text", "text" => text}]}
              }} =
               Handler.handle_message(%{
                 "method" => "tools/call",
                 "id" => 4,
                 "params" => %{"name" => "mix_test", "arguments" => %{"test_path" => "test/cool_test.exs"}}
               })

      assert %{"exit_code" => 0, "output" => "1 test, 0 failures"} = Jason.decode!(text)
    end

    test "unknown tool returns error content" do
      assert {:ok,
              %{
                "id" => 5,
                "result" => %{
                  "isError" => true,
                  "content" => [%{"text" => text}]
                }
              }} =
               Handler.handle_message(%{
                 "method" => "tools/call",
                 "id" => 5,
                 "params" => %{"name" => "nonexistent_tool", "arguments" => %{}}
               })

      assert text =~ "Unknown tool"
    end
  end

  describe "handle_message/1 - unknown method with id" do
    test "returns method not found error" do
      assert {:ok, %{"id" => 6, "error" => %{"code" => -32601, "message" => "Method not found"}}} =
               Handler.handle_message(%{"method" => "something/weird", "id" => 6})
    end
  end

  describe "handle_message/1 - unknown notification (no id)" do
    test "returns :accepted" do
      assert :accepted == Handler.handle_message(%{"method" => "some/notification"})
    end
  end

  describe "handle_message/1 - invalid request" do
    test "returns invalid request error" do
      assert {:error, %{"error" => %{"code" => -32600, "message" => "Invalid request"}}} =
               Handler.handle_message(%{"garbage" => true})
    end
  end
end
