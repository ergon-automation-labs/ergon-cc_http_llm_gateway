.PHONY: setup help deps test credo dialyzer coverage check format clean release publish-release setup-hooks start logs

help:
	@echo "CC HTTP LLM Gateway"
	@echo ""
	@echo "Setup commands:"
	@echo "  make setup           - Set up project (deps.get + install git hooks + grc config)"
	@echo "  make setup-hooks     - Install git hooks for pre-push validation + grc config"
	@echo ""
	@echo "Development commands:"
	@echo "  make test            - Run all tests"
	@echo "  make credo           - Run linter"
	@echo "  make dialyzer        - Run static analysis"
	@echo "  make coverage        - Run tests with coverage"
	@echo "  make check           - Run all checks (test, credo, dialyzer)"
	@echo "  make format          - Format Elixir code"
	@echo "  make clean           - Clean build artifacts"
	@echo ""
	@echo "Gateway commands:"
	@echo "  make run-local       - Build and run gateway locally on port 9090 (dev)"
	@echo "  make test-gateway    - Send test request to running gateway (requires make run-local)"
	@echo "  make start           - Start the HTTP gateway (PORT=9090 by default, 39090 in production)"
	@echo "  make logs            - Tail today's log with grc colorization"
	@echo ""
	@echo "Release commands (normally automatic via git hook):"
	@echo "  make release         - Build OTP release locally (manual, if needed)"
	@echo "  make publish-release - Build, package, and publish to GitHub (manual, if needed)"
	@echo ""
	@echo "Normal workflow:"
	@echo "  git push             - Pre-push hook validates, builds, and publishes automatically"
	@echo ""

setup: init deps setup-hooks
	@echo "✓ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run: make test"
	@echo "  2. Start developing!"
	@echo ""

setup-hooks:
	@git config core.hooksPath git-hooks
	@mkdir -p ~/.grc
	@cp grc/conf.cc_http_llm_gateway ~/.grc/
	@echo "✓ Git hooks installed (core.hooksPath = git-hooks)"
	@echo "✓ grc config installed to ~/.grc/conf.cc_http_llm_gateway"

init:
	@if [ ! -d .git ]; then git init; echo "Git initialized."; else echo "Git already initialized."; fi

deps:
	mix deps.get

test:
	mix test

credo:
	mix credo

dialyzer: deps
	mix dialyzer

coverage:
	mix coveralls

check: test credo dialyzer
	@echo "All checks passed!"

format:
	mix format

clean:
	mix clean
	rm -rf _build cover

release: check
	@echo "==============================================="
	@echo "Building OTP release"
	@echo "==============================================="
	MIX_ENV=prod mix release --overwrite
	@echo ""
	@echo "✓ Release built successfully"
	@echo "Location: _build/prod/rel/cc_http_llm_gateway/"
	@echo ""

publish-release: release
	@echo "==============================================="
	@echo "Publishing release to GitHub"
	@echo "==============================================="
	@echo ""

	# Get version from release metadata
	VERSION=$$(cat _build/prod/rel/cc_http_llm_gateway/releases/RELEASES | tail -1 | cut -d' ' -f2); \
	echo "Version: $$VERSION"; \
	\
	# Create tarball
	echo "Creating release tarball..."; \
	tar -czf cc_http_llm_gateway-$$VERSION.tar.gz -C _build/prod/rel cc_http_llm_gateway/; \
	echo "✓ Tarball created: cc_http_llm_gateway-$$VERSION.tar.gz"; \
	echo ""; \
	\
	# Create GitHub release
	echo "Creating GitHub release v$$VERSION..."; \
	gh release create v$$VERSION cc_http_llm_gateway-$$VERSION.tar.gz \
		--title "Release v$$VERSION" \
		--notes "CC HTTP LLM Gateway Elixir release v$$VERSION. Download and deploy with Jenkins." \
		--draft=false; \
	echo "✓ Release published to GitHub"; \
	echo ""; \
	echo "Next steps:"; \
	echo "1. Jenkins will automatically detect the new release"; \
	echo "2. Trigger deployment in Jenkins UI or wait for auto-deployment"; \
	echo "3. Check deployment status: make jenkins-logs"; \
	echo ""

start:  ## Start the gateway HTTP server (uses PORT env var, default 9090)
	@PORT=$${PORT:-9090} ./_build/prod/rel/cc_http_llm_gateway/bin/cc_http_llm_gateway start

logs:  ## Tail today's log with grc colorization
	@grc --config=cc_http_llm_gateway tail -f /var/log/bot_army/cc_http_llm_gateway/$$(date +%Y-%m-%d).log

# Local testing targets

run-local:  ## Build release and start gateway locally on port 9090
	@echo "==============================================="
	@echo "Building release..."
	@echo "==============================================="
	@$(MAKE) release > /dev/null 2>&1
	@echo ""
	@echo "✓ Release built"
	@echo ""
	@echo "Starting gateway on http://localhost:9090"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@PORT=9090 ./_build/prod/rel/cc_http_llm_gateway/bin/cc_http_llm_gateway foreground

test-gateway:  ## Test gateway with curl (requires gateway running on port 9090)
	@echo "Testing Claude Code HTTP LLM Gateway..."
	@echo ""
	@echo "Sending test request to http://localhost:9090/v1/messages"
	@echo ""
	@curl -s -X POST http://localhost:9090/v1/messages \
		-H "Content-Type: application/json" \
		-H "x-api-key: test-key-ignored" \
		-H "anthropic-version: 2023-06-01" \
		-d '{"model":"claude-haiku-4-5-20251001","messages":[{"role":"user","content":"Hello, what is 1+1?"}],"max_tokens":100}' | \
		jq . 2>/dev/null || curl -X POST http://localhost:9090/v1/messages \
		-H "Content-Type: application/json" \
		-H "x-api-key: test-key-ignored" \
		-H "anthropic-version: 2023-06-01" \
		-d '{"model":"claude-haiku-4-5-20251001","messages":[{"role":"user","content":"Hello, what is 1+1?"}],"max_tokens":100}'
	@echo ""
	@echo ""
	@echo "Request completed. Check /var/log/bot_army/cc_http_llm_gateway/$(date +%Y-%m-%d).log for logs."
