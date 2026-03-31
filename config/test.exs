import Config

# Use non-standard port for testing to avoid conflicts
config :bot_army_cc_http_llm_gateway, :http_port, 19090

# Use test log directory
config :bot_army_cc_http_llm_gateway, :log_dir, "/tmp/bot_army_cc_http_llm_gateway_test"

# Use dev NATS port for testing
config :bot_army_runtime, :nats,
  servers: [{"localhost", 4223}]

# Quiet logging in tests
config :logger,
  level: :warning
