defmodule PolyglotWatcherV2.MCP.InstanceChecker do
  alias PolyglotWatcherV2.ShellCommandRunner

  def alive?(pid, port) do
    pid_running?(pid) && mcp_responds?(port)
  end

  defp pid_running?(pid) do
    {_output, exit_code} = ShellCommandRunner.run("kill -0 #{pid}")
    exit_code == 0
  end

  defp mcp_responds?(port) do
    case Req.post("http://localhost:#{port}/mcp",
           json: %{"jsonrpc" => "2.0", "id" => 0, "method" => "ping"},
           receive_timeout: 2_000,
           connect_options: [timeout: 2_000],
           retry: false
         ) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        body["jsonrpc"] == "2.0" && Map.has_key?(body, "result")

      _ ->
        false
    end
  end
end
