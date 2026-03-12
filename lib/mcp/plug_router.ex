defmodule PolyglotWatcherV2.MCP.PlugRouter do
  use Plug.Router

  alias PolyglotWatcherV2.MCP.Handler

  require Logger

  plug(:log_request)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  defp log_request(conn, _opts) do
    Logger.debug("MCP: #{conn.method} #{conn.request_path}")
    conn
  end

  # --- MCP endpoint ---

  post "/mcp" do
    case Handler.handle_message(conn.body_params) do
      {:ok, response} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))

      :accepted ->
        send_resp(conn, 202, "")

      {:error, response} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
