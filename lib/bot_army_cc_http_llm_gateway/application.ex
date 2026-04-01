defmodule BotArmyCcHttpLlmGateway.Application do
  @moduledoc """
  OTP Application supervisor for the CC HTTP LLM Gateway.

  Starts:
  - Bandit HTTP server on the configured PORT
  - bot_army_runtime (NATS connection) via dependency
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting CC HTTP LLM Gateway")

    port = http_port()

    children = [
      {Bandit, plug: BotArmyCcHttpLlmGateway.Router, port: port, scheme: :http}
    ]

    Logger.info("HTTP server listening on port #{port}")

    opts = [strategy: :one_for_one, name: BotArmyCcHttpLlmGateway.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp http_port do
    case System.get_env("PORT") do
      nil -> Application.get_env(:bot_army_cc_http_llm_gateway, :http_port, 9090)
      port_str -> String.to_integer(port_str)
    end
  end
end
