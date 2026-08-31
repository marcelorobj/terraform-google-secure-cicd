#!/bin/bash

set -e

# This script is responsible for the following:
# 1. Templating manifests using envsubst
# 2. Seeding the 3 CI repositories
# 3. Deploying the ADK agent
# 4. Configuring IAP IAM egress policies

# The terraform outputs are passed as environment variables.

# Example for one service (legacy-dms)

# Template the manifests
export CI_REPO_URL_LEGACY_DMS
export CD_REPO_URL_LEGACY_DMS

TEMP_DIR=$(mktemp -d)

# Copy source files
cp -r src/legacy-dms/* $TEMP_DIR

# Template and copy manifests
envsubst < examples/mortgage-agent/cloud_run/legacy-dms.yaml > $TEMP_DIR/legacy-dms.yaml
envsubst < skaffold.yaml > $TEMP_DIR/skaffold.yaml # Assuming a skaffold template is available

# Copy build files
cp build/cloudbuild-ci.yaml $TEMP_DIR
cp -r build/policies $TEMP_DIR

# Git operations
cd $TEMP_DIR
git init
git checkout -b main
git add .
git commit -m "Initial commit"
git remote add origin $CI_REPO_URL_LEGACY_DMS
git push origin main

cd -
rm -rf $TEMP_DIR

# ... (Repeat for other 2 services)

# Deploy ADK
# python scripts/deploy_adk.py # Assuming this script exists

# Configure IAM
# ./scripts/configure_iam.sh # Assuming this script exists
