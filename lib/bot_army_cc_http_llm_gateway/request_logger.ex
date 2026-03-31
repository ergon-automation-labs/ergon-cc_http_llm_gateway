defmodule BotArmyCcHttpLlmGateway.RequestLogger do
  @moduledoc """
  File-based logging for Claude Code requests/responses.

  Logs to /var/log/bot_army/cc_http_llm_gateway/YYYY-MM-DD.log (one per day).
  Format: [ISO8601] [REQUEST|RESPONSE|ERROR] key=value ...
  """

  require Logger

  @log_dir "/var/log/bot_army/cc_http_llm_gateway"

  @doc """
  Log a successful LLM response.
  """
  def log_response(request_payload, response_body, latency_ms) do
    model = request_payload["model"] || "unknown"
    messages_count = length(request_payload["messages"] || [])
    has_tools = if request_payload["tools"], do: "true", else: "false"

    # Extract model from response (best effort)
    model_used = extract_model_used(response_body)

    log_message(
      "RESPONSE status=200 latency_ms=#{latency_ms} model=#{model} model_used=#{model_used} " <>
        "messages=#{messages_count} has_tools=#{has_tools}"
    )
  end

  @doc """
  Log an error response.
  """
  def log_error(request_payload, reason, latency_ms) do
    model = request_payload["model"] || "unknown"
    reason_str = inspect(reason)

    status_code = case reason do
      :timeout -> 408
      :rate_limited -> 429
      _ -> 502
    end

    log_message(
      "ERROR status=#{status_code} latency_ms=#{latency_ms} model=#{model} reason=#{reason_str}"
    )
  end

  # Private functions

  defp log_message(message) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    line = "[#{timestamp}] #{message}\n"

    log_dir = Application.get_env(:bot_army_cc_http_llm_gateway, :log_dir, @log_dir)
    date = Date.utc_today() |> Date.to_iso8601()
    log_file = "#{log_dir}/#{date}.log"

    case File.write(log_file, line, [:append]) do
      :ok -> :ok
      {:error, reason} ->
        Logger.warning("Failed to write log: #{inspect(reason)}")
        :ok
    end
  end

  defp extract_model_used(response_body) do
    response_json =
      case response_body do
        body when is_binary(body) -> body
        body -> Jason.encode!(body)
      end

    case Jason.decode(response_json) do
      {:ok, response} -> response["model"] || "unknown"
      {:error, _} -> "unknown"
    end
  rescue
    _ -> "unknown"
  end
end
