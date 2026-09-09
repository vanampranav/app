#!/usr/bin/env bash
set -e

echo "========================================================"
echo "⚠️  WARNING: PRODUCTION ASK ELE DEPLOYMENT TARGET ⚠️"
echo "Target Project: getfit-with-elefit (PRODUCTION)"
echo "========================================================"

read -p "Are you ABSOLUTELY sure you want to deploy Ask Ele to PRODUCTION? (type 'yes-deploy-prod' to proceed): " confirm

if [ "$confirm" != "yes-deploy-prod" ]; then
  echo "Production deployment cancelled."
  exit 1
fi

npx firebase-tools use prod || npx firebase-tools use getfit-with-elefit

echo "Deploying Ask Ele functions codebase ONLY to PRODUCTION..."
npx firebase-tools deploy --project prod --only functions:ask-ele

echo "PRODUCTION Ask Ele Deployment Completed Successfully!"
