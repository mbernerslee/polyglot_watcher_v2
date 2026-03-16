defmodule PolyglotWatcherV2.MCP.InstanceCheckerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.InstanceChecker
  alias PolyglotWatcherV2.ShellCommandRunner

  describe "alive?/2" do
    test "returns true when PID is running and port responds to MCP ping" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345 2>/dev/null" -> {"", 0} end)

      Mimic.expect(Req, :post, fn "http://localhost:5123/mcp", opts ->
        assert opts[:json] == %{"jsonrpc" => "2.0", "id" => 0, "method" => "ping"}
        assert opts[:receive_timeout] == 500
        assert opts[:retry] == false
        {:ok, %{status: 200, body: %{"jsonrpc" => "2.0", "result" => %{}}}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == true
    end

    test "returns false when PID is not running" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 99999 2>/dev/null" ->
        {"kill: (99999) - No such process", 1}
      end)

      assert InstanceChecker.alive?(99999, 5123) == false
    end

    test "returns false when PID is running but port doesn't respond" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345 2>/dev/null" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end

    test "returns false when port responds with non-MCP response" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345 2>/dev/null" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"not" => "mcp"}}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end

    test "returns false when port responds with non-200 status" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345 2>/dev/null" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 500, body: "Internal Server Error"}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end

    test "returns false when request times out" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345 2>/dev/null" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:error, %Req.TransportError{reason: :timeout}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end
  end
end
