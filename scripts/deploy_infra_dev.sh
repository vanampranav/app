#!/usr/bin/env bash
set -e

echo "========================================================"
echo "DEPLOYING FIRESTORE & STORAGE INFRASTRUCTURE RULES TO DEV"
echo "Target Project: elefit-dev"
echo "========================================================"

npx firebase-tools use dev || {
  echo "Error: 'dev' alias is not configured or project elefit-dev is unavailable."
  exit 1
}

echo "Deploying Firestore rules/indexes and Storage rules to DEV..."
npx firebase-tools deploy --project dev --only firestore,storage

echo "DEV Infrastructure Rules Deployment Completed Successfully!"
