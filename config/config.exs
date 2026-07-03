import Config

# HTTP port configuration
config :bot_army_cc_http_llm_gateway,
       :http_port,
       String.to_integer(System.get_env("PORT", "8080"))

# Log directory configuration
config :bot_army_cc_http_llm_gateway, :log_dir, System.get_env("LOG_DIR", "./logs")

# NATS configuration (inherited from bot_army_library_runtime)
config :bot_army_library_runtime, :nats,
  servers: [
    {System.get_env("NATS_HOST", "localhost"),
     String.to_integer(System.get_env("NATS_PORT", "4222"))}
  ]

# Logger configuration
config :logger,
  level: :info,
  format: "[$level] $message\n"

# Import environment-specific configuration
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
