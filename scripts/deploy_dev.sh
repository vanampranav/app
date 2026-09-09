#!/usr/bin/env bash
set -e

echo "========================================================"
echo "DEPLOYING ASK ELE BACKEND FUNCTIONS TO DEV"
echo "Target Project: elefit-dev"
echo "========================================================"

# Ensure user is using the dev project alias
npx firebase-tools use dev || {
  echo "Error: 'dev' alias is not configured or project elefit-dev is unavailable."
  exit 1
}

echo "Deploying Ask Ele functions codebase ONLY to DEV..."
npx firebase-tools deploy --project dev --only functions:ask-ele

echo "DEV Ask Ele Deployment Completed Successfully!"
