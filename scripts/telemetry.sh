#!/usr/bin/env bash
# Transparent telemetry — see README for details.
# Only anonymous, non-sensitive metadata is collected.
# Set disable-telemetry: 'true' to opt out.
#
# Cross-platform: runs in bash on both Linux and Windows (Git Bash).
#
# Expected environment variables:
#   TELEMETRY_REPO       - github.repository (hashed before sending)
#   TELEMETRY_ACTION_REF - github.action_ref
#   TELEMETRY_DRY_RUN    - inputs.dry-run value
#   TELEMETRY_SELECTIVE  - inputs.selective value
#   TELEMETRY_HASH_CHECK - inputs.hash-check value

set -euo pipefail

# Detect OS for telemetry payload
case "$(uname -s)" in
  Linux*)   TELEMETRY_OS="Linux" ;;
  Darwin*)  TELEMETRY_OS="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) TELEMETRY_OS="Windows" ;;
  *)        TELEMETRY_OS="Unknown" ;;
esac

# Fetch telemetry config from main branch (allows key rotation without new release)
CONFIG_URL="https://raw.githubusercontent.com/jojitech/fast-synapse-deploy/main/.telemetry.json"
CONFIG=$(curl -s -m 5 "$CONFIG_URL" 2>/dev/null) || exit 0

# Check if telemetry is enabled in config
ENABLED=$(echo "$CONFIG" | grep -o '"enabled"\s*:\s*[a-z]*' | grep -o '[a-z]*$')
if [ "$ENABLED" != "true" ]; then exit 0; fi

# Extract connection string and parse ingestion endpoint + ikey
# (uses sed instead of grep -P for Git Bash / POSIX compatibility)
CONN_STR=$(echo "$CONFIG" | grep -o '"connectionString"\s*:\s*"[^"]*"' | sed 's/"connectionString"\s*:\s*"//;s/"$//')
if [ -z "$CONN_STR" ]; then exit 0; fi

INGESTION_EP=$(echo "$CONN_STR" | sed -n 's/.*IngestionEndpoint=\([^;]*\).*/\1/p')
IKEY=$(echo "$CONN_STR" | sed -n 's/.*InstrumentationKey=\([^;]*\).*/\1/p')
if [ -z "$INGESTION_EP" ] || [ -z "$IKEY" ]; then exit 0; fi

REPO_HASH=$(echo -n "$TELEMETRY_REPO" | sha256sum | cut -d' ' -f1)
ACTION_REF="${TELEMETRY_ACTION_REF}"
EVENT_TYPE=$( [ "$TELEMETRY_DRY_RUN" = "true" ] && echo "dry-run" || echo "deploy" )
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PAYLOAD=$(cat <<EOF
{
  "name": "AppEvents",
  "time": "${TIMESTAMP}",
  "iKey": "${IKEY}",
  "data": {
    "baseType": "EventData",
    "baseData": {
      "name": "ActionRun",
      "properties": {
        "os": "${TELEMETRY_OS}",
        "actionVersion": "${ACTION_REF}",
        "repoHash": "${REPO_HASH}",
        "event": "${EVENT_TYPE}",
        "deploySpeed": "${SYNAPSE_DEPLOYMENT_SPEED:-auto}",
        "selective": "${TELEMETRY_SELECTIVE}",
        "hashCheck": "${TELEMETRY_HASH_CHECK}"
      }
    }
  }
}
EOF
)
# Fire-and-forget: never block or fail the workflow
curl -s -o /dev/null -m 5 \
  -X POST "${INGESTION_EP}v2/track" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" &>/dev/null || true
