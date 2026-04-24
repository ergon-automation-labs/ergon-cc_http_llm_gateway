defmodule BotArmyCcHttpLlmGateway.Router do
  @moduledoc """
  HTTP router for Claude Code LLM requests.

  Accepts Anthropic Messages API format requests at POST /v1/messages,
  forwards them through the LLM proxy via NATS request/reply pattern,
  and returns responses in Anthropic Messages API format.
  """

  use Plug.Router
  require Logger

  alias BotArmyCcHttpLlmGateway.RequestLogger

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  post "/v1/messages" do
    handle_claude_code_request(conn)
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{"error" => "Not found"}))
  end

  # Private functions

  defp handle_claude_code_request(conn) do
    start_time = System.monotonic_time(:millisecond)
    body = conn.body_params  # already parsed JSON via Plug.Parsers

    Logger.debug("Claude Code request received", model: body["model"])

    # Build NATS envelope
    envelope = %{
      "event" => "llm.claude_code.complete",
      "event_id" => UUID.uuid4(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "cc_http_llm_gateway",
      "source_node" => node() |> Atom.to_string(),
      "triggered_by" => "claude_code",
      "schema_version" => "1.0",
      "payload" => body  # full Anthropic Messages API body, passed through
    }

    timeout_ms = 120_000  # 2 minutes for slow LLM calls

    case BotArmyRuntime.NATS.Publisher.request("llm.claude_code.complete", envelope, timeout_ms) do
      {:ok, response_body} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time
        response_json = encode_response_body(response_body)
        RequestLogger.log_response(body, response_json, latency_ms)
        conn
        |> put_resp_header("content-type", "application/json; charset=utf-8")
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> send_resp(200, response_json)

      {:error, :timeout} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time
        RequestLogger.log_error(body, :timeout, latency_ms)
        error_response = Jason.encode!(%{
          "error" => %{
            "type" => "timeout",
            "message" => "LLM request timed out after #{timeout_ms}ms"
          }
        })
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(408, error_response)

      {:error, reason} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time
        RequestLogger.log_error(body, reason, latency_ms)
        error_response = Jason.encode!(%{
          "error" => %{
            "type" => "upstream_error",
            "message" => "LLM proxy error: #{inspect(reason)}"
          }
        })
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(502, error_response)
    end
  rescue
    e ->
      Logger.error("Request processing failed: #{inspect(e)}")
      error_response = Jason.encode!(%{
        "error" => %{
          "type" => "internal_error",
          "message" => "Request processing error"
        }
      })
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(500, error_response)
  end

  defp encode_response_body(response_body) when is_binary(response_body), do: response_body
  defp encode_response_body(response_body), do: Jason.encode!(response_body)
end
