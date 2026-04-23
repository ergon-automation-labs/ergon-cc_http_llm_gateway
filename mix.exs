defmodule BotArmyCcHttpLlmGateway.MixProject do
  use Mix.Project

  def project do
    [
      app: :bot_army_cc_http_llm_gateway,
      version: "0.1.4",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        cc_http_llm_gateway: [
          applications: [bot_army_cc_http_llm_gateway: :permanent]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {BotArmyCcHttpLlmGateway.Application, []}
    ]
  end

  defp deps do
    [
      {:bot_army_core, path: "../bot_army_core"},
      {:bot_army_runtime, path: "../bot_army_runtime"},
      {:bandit, "~> 1.0"},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:elixir_uuid, "~> 1.2"},

      # Development/Test
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.17", only: :test, runtime: false}
    ]
  end
end
