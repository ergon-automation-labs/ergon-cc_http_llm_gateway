pipeline {
  // Download releases from GitHub and deploy them
  agent { label 'built-in' }

  options {
    timeout(time: 30, unit: 'MINUTES')
    timestamps()
    skipDefaultCheckout()
  }

  triggers {
    // Poll GitHub every 5 minutes for new commits
    pollSCM('H/5 * * * *')
  }

  environment {
    BOT_NAME = 'cc_http_llm_gateway'
    RELEASE_DIR = "/opt/ergon/releases/${BOT_NAME}"
    GITHUB_REPO = "ergon-automation-labs/ergon-cc_http_llm_gateway"
  }

  stages {

    stage('Checkout') {
      steps {
        sh '''
          echo "==============================================="
          echo "Checking out repository via SSH"
          echo "==============================================="

          # Set up SSH environment for bot_army user's deploy key
          export HOME=/var/lib/bot_army
          export GIT_SSH_COMMAND="ssh -i /var/lib/bot_army/.ssh/ergon_deploy -F /var/lib/bot_army/.ssh/config -o StrictHostKeyChecking=no -o IdentitiesOnly=yes"

          /opt/bot_army/scripts/jenkins_checkout.sh ${GITHUB_REPO} ${WORKSPACE}

          echo "Current commit: $(git rev-parse HEAD)"
        '''
      }
    }

    stage('Download Build Artifact') {
      steps {
        sh '''
          echo "==============================================="
          echo "Downloading pre-built release from GitHub"
          echo "==============================================="

          # Get the latest published release (not a draft)
          LATEST_RELEASE=$(gh api repos/${GITHUB_REPO}/releases \
            -q '.[] | select(.draft==false) | .tag_name' | head -1)

          if [ -z "$LATEST_RELEASE" ]; then
            echo "ERROR: No published release found on GitHub"
            exit 1
          fi

          echo "Latest release: $LATEST_RELEASE"

          # Download the tarball asset
          echo "Downloading: ${BOT_NAME}-*.tar.gz"
          mkdir -p ./release-artifact

          gh release download $LATEST_RELEASE \
            --repo ${GITHUB_REPO} \
            --pattern "*.tar.gz" \
            -D ./release-artifact

          echo "✓ Release downloaded successfully"

          # Extract tarball
          cd ./release-artifact
          TARBALL=$(ls -1 *.tar.gz | head -1)
          echo "Extracting: $TARBALL"
          tar -xzf "$TARBALL"
          rm "$TARBALL"
          ls -la
          cd ..
        '''
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          set -euo pipefail

          echo "==============================================="
          echo "Deploying release"
          echo "==============================================="
          echo "Start time: $(date)"

          TIMESTAMP=$(date +%Y%m%d%H%M%S)
          DEST="${RELEASE_DIR}/releases/${TIMESTAMP}"

          echo "Creating release directory..."
          mkdir -p "${DEST}"

          echo "Copying release artifacts..."
          cp -r ./release-artifact/* "${DEST}/"

          echo "Updating current symlink..."
          ln -sfn "${DEST}" "${RELEASE_DIR}/current"

          # Runtime env (including PORT) is managed by Salt/pillar.
          # Jenkins must never override PORT; it only reads and verifies it.
          CONFIG_FILE="/etc/bot_army/${BOT_NAME}.env"
          if [ ! -f "${CONFIG_FILE}" ]; then
            echo "ERROR: Missing ${CONFIG_FILE}. Salt must provision runtime env before Jenkins deploy."
            exit 1
          fi

          GATEWAY_PORT=$(awk -F= '/^PORT=/{print $2; exit}' "${CONFIG_FILE}" | tr -d "[:space:]")
          if [ -z "${GATEWAY_PORT}" ]; then
            echo "ERROR: PORT is not set in ${CONFIG_FILE}. Configure via pillar/air-secrets and re-apply Salt."
            exit 1
          fi
          echo "Using gateway port from Salt-managed env: ${GATEWAY_PORT}"

          echo "Restarting service..."
          SERVICE_ID="system/com.botarmy.${BOT_NAME}"
          PLIST_PATH="/Library/LaunchDaemons/com.botarmy.${BOT_NAME}.plist"
          if launchctl print "${SERVICE_ID}" >/dev/null 2>&1; then
            launchctl kickstart -k "${SERVICE_ID}"
          else
            launchctl bootstrap system "${PLIST_PATH}"
          fi

          echo "Waiting for service to bind localhost:${GATEWAY_PORT}..."
          for i in $(seq 1 20); do
            status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${GATEWAY_PORT}/v1/messages" || true)
            if [ "${status_code}" != "000" ]; then
              echo "✓ Gateway responding on localhost:${GATEWAY_PORT} (HTTP ${status_code})"
              break
            fi

            if [ "${i}" -eq 20 ]; then
              echo "ERROR: Gateway failed to bind localhost:${GATEWAY_PORT}"
              launchctl print "${SERVICE_ID}" || true
              exit 1
            fi

            sleep 1
          done

          echo "Deploy complete!"
          echo "Completion time: $(date)"
        '''
      }
    }

    stage('Publish Deploy Event') {
      steps {
        sh '''
          echo "==============================================="
          echo "Publishing deploy event"
          echo "==============================================="
          echo "Start time: $(date)"

          # Get the release binary path
          RELEASE_BIN="${RELEASE_DIR}/current/llm_gateway/bin/llm_gateway"

          if [ ! -f "$RELEASE_BIN" ]; then
            echo "⚠️  Release binary not found at $RELEASE_BIN"
            echo "Publishing deploy_failed event"
            PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"failed"}
EOF
)
            /opt/bot_army/scripts/nats_publish.sh ops.deploy.llm_gateway "$PAYLOAD" || echo "⚠️  NATS publish failed (non-blocking)"
            exit 1
          fi

          echo "Publishing deploy_started event..."
          PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"started"}
EOF
)
          /opt/bot_army/scripts/nats_publish.sh ops.deploy.llm_gateway "$PAYLOAD" || echo "⚠️  NATS publish failed (non-blocking)"

          echo "Running migrations..."
          $RELEASE_BIN eval 'LlmGateway.Release.migrate()' && {
            echo "✓ Migrations complete"
            echo "Publishing deploy_complete event..."
            VERSION=$(awk '{print $2}' "$RELEASE_DIR/current/llm_gateway/releases/start_erl.data" 2>/dev/null || echo "unknown")
            PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"complete","version":"${VERSION}"}
EOF
)
            /opt/bot_army/scripts/nats_publish.sh ops.deploy.llm_gateway "$PAYLOAD" || echo "⚠️  NATS publish failed (non-blocking)"
          } || {
            echo "⚠️  Migration failed"
            echo "Publishing deploy_failed event..."
            PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"failed"}
EOF
)
            /opt/bot_army/scripts/nats_publish.sh ops.deploy.llm_gateway "$PAYLOAD" || echo "⚠️  NATS publish failed (non-blocking)"
            exit 1
          }

          echo "Publish Deploy Event complete!"
          echo "Completion time: $(date)"
        '''
      }
    }


  }

  post {
    success {
      sh '''
        # Extract version from the deployed release
        if [ -f ./release-artifact/cc_http_llm_gateway/releases/start_erl.data ]; then
          VERSION=$(awk '{print $2}' ./release-artifact/cc_http_llm_gateway/releases/start_erl.data)
        fi
        VERSION=${VERSION:-"0.1.0"}

        # Build JSON payload with proper formatting
        PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"success","version":"${VERSION}"}
EOF
)
        echo "📢 Notifying NATS of successful deployment..."
        /opt/bot_army/scripts/nats_publish.sh ops.deploy.complete "$PAYLOAD" || echo "⚠️  NATS notification failed (non-blocking)"
      '''
    }
    failure {
      sh '''
        # Build JSON payload for failure
        PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"failed"}
EOF
)
        echo "📢 Notifying NATS of failed deployment..."
        /opt/bot_army/scripts/nats_publish.sh ops.deploy.failed "$PAYLOAD" || echo "⚠️  NATS notification failed (non-blocking)"
      '''
    }
    always {
      cleanWs()
    }
  }
}

