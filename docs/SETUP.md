# Getting Started with bot_army_cc_http_llm_gateway

This guide walks you through setting up CC HTTP LLM Gateway for local development.

## Prerequisites

- **Elixir 1.14+** - Install via [elixir-lang.org](https://elixir-lang.org)
- **Erlang/OTP 25+** - Installed with Elixir
- **PostgreSQL** - For local database (optional for development)
- **Git** - For version control
- **GitHub CLI** (`gh`) - For releasing to GitHub

## Quick Start

### 1. Install Dependencies

```bash
make setup
```

This will:
- Initialize git if needed
- Run `mix deps.get`
- Install git hooks for pre-push validation

### 2. Set Up Environment Variables

Create a `.env` file from the template for local development and testing:

```bash
cp .env.example .env
```

Edit `.env` to match your local setup:

```bash
DATABASE_HOST=localhost          # Should match your local/Kubernetes setup
DATABASE_PORT=30003              # Kubernetes NodePort for postgres-vector
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=bot_army_cc_http_llm_gateway_dev
```

**Important:** `.env` is gitignored and should never be committed. Use `.env.example` to document what variables are needed.

### 3. Set Up Test Database

The `make setup` target automatically sets up the test database with:
```bash
make setup-db
```

This creates the test database and runs migrations, allowing you to run tests immediately.

If you need to reset the database during development:
```bash
make reset-db  # Drops and recreates test database
```

### 4. Verify Setup

```bash
mix compile
mix test
```

Tests require the database to be running. If tests fail with database connection errors:
1. Verify your `.env` file matches your database setup
2. Ensure postgres-vector is running and accessible
3. Run `make reset-db` to recreate the test database

## Development Workflow

### Code Changes

```bash
# Make your changes
edit lib/bot_army_cc_http_llm_gateway.ex

# Format code
make format

# Run linter
make credo

# Run tests
make test
```

### Pushing to GitHub

```bash
git add .
git commit -m "Description of changes"
git push
```

When you push to `main`:
1. Pre-push hook runs `mix compile` and `mix credo`
2. Builds OTP release with `mix release`
3. Creates tarball
4. Publishes release to GitHub
5. Push completes

Jenkins automatically detects the new release and deploys it.

### Manual Release (if needed)

```bash
make release          # Build release locally
make publish-release  # Package and publish to GitHub
```

## Key Commands

```bash
make help             # Show all available commands
make setup            # Install dependencies, git hooks, and set up database
make setup-db         # Create and migrate test database (required for testing)
make reset-db         # Drop and recreate test database (useful for troubleshooting)
make test             # Run tests
make credo            # Run linter
make check            # Run all checks (test, credo, dialyzer)
make format           # Format Elixir code
make clean            # Remove build artifacts
```

## Release Configuration

The OTP release is configured in `mix.exs`:

```elixir
releases: [
  cc_http_llm_gateway: [
    applications: [bot_army_cc_http_llm_gateway: :permanent]
  ]
]
```

This creates a release named `cc_http_llm_gateway` that is deployed to `/opt/ergon/releases/cc_http_llm_gateway/` on the server.

## Configuration

### Development Environment

Create a `.env` file in the project root for local development:

```bash
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=bot_army_cc_http_llm_gateway_dev
```

### Runtime Configuration

In production, configuration comes from Salt pillar via environment variables. See `pillar/common.sls` in `bot_army_infra` for details.

## Dependencies

Key dependencies:
- `bot_army_core` - Core library and NATS decoder
- `bot_army_runtime` - Persistence and messaging foundation
- `nats` - NATS client for message publishing/subscribing
- `jason` - JSON encoding/decoding
- `logger_json` - Structured JSON logging

Development dependencies:
- `credo` - Code linting
- `dialyxir` - Static type checking
- `excoveralls` - Code coverage

## Deployment

Deployment is automated via Jenkins. After you push to `main`:

1. Jenkins detects the new release on GitHub
2. Downloads the pre-built tarball
3. Extracts and deploys to `/opt/ergon/releases/cc_http_llm_gateway/`
4. Restarts the service

No manual deployment steps needed.

## Troubleshooting

### Build Fails: "Release directory not found"

Make sure the release name in `mix.exs` is correct:
```elixir
releases: [
  cc_http_llm_gateway: [
    applications: [bot_army_cc_http_llm_gateway: :permanent]
  ]
]
```

### Database Connection Issues

Check `.env` file and `config/dev.exs`. Environment variables must match your local setup.

To reset the test database and fix migration issues:
```bash
make reset-db
make test
```

This drops the old database, creates a fresh one, runs all migrations, and ensures tests can run.

### Pre-push Hook Fails

The hook validates compilation and builds the release. If it fails:

1. Run `mix deps.get` to ensure dependencies are up to date
2. Run `mix compile` to check for compilation errors
3. Run `mix credo --strict` to check for linting issues
4. Fix errors and try pushing again

### GitHub Release Already Exists

The pre-push hook will warn if a release already exists but will continue with the push. You can safely retry or manually create a new release with a different version.

## Related Documentation

- `../../README.md` - Project overview
- `bot_army_repo_structure_1.md` in `bot_army_schemas` - Full polyrepo context
- `bot_army_infra` - Infrastructure and deployment configuration

## Questions?

Check the Makefile for all available commands or review the `CLAUDE.md` file for development guidelines.
