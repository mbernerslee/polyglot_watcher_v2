defmodule PolyglotWatcherV2.MCP.PlugRouterTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn
  use Mimic

  alias PolyglotWatcherV2.MCP.PlugRouter
  alias PolyglotWatcherV2.Elixir.{Cache, MixTestArgs}
  alias PolyglotWatcherV2.ShellCommandRunner

  describe "POST /mcp" do
    test "successful tool call returns 200 with JSON result" do
      args = %MixTestArgs{path: :all}

      Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
      Mimic.expect(Cache, :await_or_run, fn ^args -> :not_running end)

      Mimic.expect(ShellCommandRunner, :run, fn "mix test --color" ->
        {"10 tests, 0 failures", 0}
      end)

      Mimic.expect(Cache, :update, fn ^args, "10 tests, 0 failures", 0 -> :ok end)

      body =
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{"name" => "run_tests", "arguments" => %{}}
        })

      conn =
        :post
        |> conn("/mcp", body)
        |> put_req_header("content-type", "application/json")
        |> PlugRouter.call(PlugRouter.init([]))

      assert conn.status == 200

      assert %{"id" => 1, "result" => %{"content" => [%{"text" => text}]}} =
               Jason.decode!(conn.resp_body)

      assert %{"exit_code" => 0} = Jason.decode!(text)
    end

    test "unknown route returns 404" do
      conn =
        conn(:get, "/nonexistent")
        |> PlugRouter.call(PlugRouter.init([]))

      assert conn.status == 404
    end
  end
end
