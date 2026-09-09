#!/usr/bin/env bash
set -e

echo "========================================================"
echo "⚠️  WARNING: DEPLOYING INFRASTRUCTURE RULES TO PRODUCTION ⚠️"
echo "Target Project: getfit-with-elefit (PRODUCTION)"
echo "========================================================"

read -p "Are you ABSOLUTELY sure you want to deploy Firestore/Storage rules to PRODUCTION? (type 'yes-deploy-prod-infra' to proceed): " confirm

if [ "$confirm" != "yes-deploy-prod-infra" ]; then
  echo "Production infrastructure rules deployment cancelled."
  exit 1
fi

npx firebase-tools use prod || npx firebase-tools use getfit-with-elefit

echo "Deploying Firestore rules/indexes and Storage rules to PRODUCTION..."
npx firebase-tools deploy --project prod --only firestore,storage

echo "PRODUCTION Infrastructure Rules Deployment Completed Successfully!"
