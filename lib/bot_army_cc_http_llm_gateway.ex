defmodule BotArmyCcHttpLlmGateway do
  @moduledoc """
  HTTP gateway for Claude Code to access the LLM proxy.

  Claude Code can be configured to use a custom API endpoint via ANTHROPIC_BASE_URL.
  This gateway listens on HTTP and forwards requests through the NATS-based LLM proxy.

  ## Configuration

  PORT - HTTP server port (default: 9090)
  NATS_PORT - NATS server port (default: 4222)
  """

  @version "0.1.0"

  def version, do: @version
end
