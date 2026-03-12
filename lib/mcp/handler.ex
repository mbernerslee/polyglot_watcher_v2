defmodule PolyglotWatcherV2.MCP.Handler do
  alias PolyglotWatcherV2.MCP.Tools.RunTests

  require Logger

  @server_info %{
    "name" => "polyglot-watcher",
    "version" => "0.1.0"
  }

  @supported_protocol_version "2025-03-26"

  # JSON-RPC 2.0 standard error codes
  @invalid_request -32600
  @method_not_found -32601

  def handle_message(%{"method" => "initialize", "id" => id} = msg) do
    Logger.debug("MCP initialize: #{inspect(msg["params"])}")
    {:ok,
     json_rpc_result(id, %{
       "protocolVersion" => @supported_protocol_version,
       "capabilities" => %{"tools" => %{}},
       "serverInfo" => @server_info
     })}
  end

  def handle_message(%{"method" => "notifications/initialized"}) do
    :accepted
  end

  def handle_message(%{"method" => "ping", "id" => id}) do
    {:ok, json_rpc_result(id, %{})}
  end

  def handle_message(%{"method" => "tools/list", "id" => id}) do
    {:ok, json_rpc_result(id, %{"tools" => [RunTests.definition()]})}
  end

  def handle_message(%{"method" => "tools/call", "id" => id, "params" => params}) do
    tool_name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})
    Logger.debug("MCP tools/call: #{tool_name} args=#{inspect(arguments)}")

    case call_tool(tool_name, arguments) do
      {:ok, text} ->
        {:ok,
         json_rpc_result(id, %{
           "content" => [%{"type" => "text", "text" => text}]
         })}

      {:error, msg} ->
        {:ok,
         json_rpc_result(id, %{
           "content" => [%{"type" => "text", "text" => msg}],
           "isError" => true
         })}
    end
  end

  def handle_message(%{"method" => method, "id" => id}) do
    Logger.debug("MCP unknown method: #{method}")
    {:ok, json_rpc_error(id, @method_not_found, "Method not found")}
  end

  def handle_message(%{"method" => _method}) do
    :accepted
  end

  def handle_message(_) do
    {:error, json_rpc_error(nil, @invalid_request, "Invalid request")}
  end

  defp call_tool("run_tests", arguments) do
    {:ok, RunTests.call(arguments)}
  end

  defp call_tool(name, _arguments) do
    {:error, "Unknown tool: #{name}"}
  end

  defp json_rpc_result(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp json_rpc_error(id, code, message) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
  end
end
