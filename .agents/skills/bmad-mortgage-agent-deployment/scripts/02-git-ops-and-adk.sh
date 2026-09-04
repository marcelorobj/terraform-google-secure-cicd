#!/bin/bash

set -e

# This script is responsible for seeding the CI and CD repositories for a given service.
# It uses an OAuth2 access token for authentication.

# Usage:
# export CI_REPO_URL="https://source.developers.google.com/p/your-project/r/your-ci-repo"
# export CD_REPO_URL="https://source.developers.google.com/p/your-project/r/your-cd-repo"
# ./02-git-ops-and-adk.sh <service_name> <git_email> <git_name>

SERVICE_NAME=$1
GIT_USER_EMAIL=$2
GIT_USER_NAME=$3

if [ -z "$SERVICE_NAME" ] || [ -z "$GIT_USER_EMAIL" ] || [ -z "$GIT_USER_NAME" ]; then
  echo "Error: SERVICE_NAME, GIT_USER_EMAIL, and GIT_USER_NAME must be provided as arguments."
  exit 1
fi

if [ -z "$CI_REPO_URL" ] || [ -z "$CD_REPO_URL" ]; then
  echo "Error: CI_REPO_URL and CD_REPO_URL environment variables must be set."
  exit 1
fi

# Get OAuth2 access token
ACCESS_TOKEN=$(gcloud secrets versions access latest --secret="github-pat")

# Construct authenticated URLs
AUTH_CI_REPO_URL="https://oauth2accesstoken:$ACCESS_TOKEN@${CI_REPO_URL#https://}"
AUTH_CD_REPO_URL="https://oauth2accesstoken:$ACCESS_TOKEN@${CD_REPO_URL#https://}"

# --- Seeding CI Repository ---
echo "--- Seeding CI Repository for $SERVICE_NAME ---"
CI_TEMP_DIR=$(mktemp -d)
echo "Using temporary directory for CI: $CI_TEMP_DIR"

cp -r "examples/mortgage-agent/src/$SERVICE_NAME/"* "$CI_TEMP_DIR/"
cp "build/cloudbuild-ci.yaml" "$CI_TEMP_DIR/"
cp -r "build/policies" "$CI_TEMP_DIR/"

cd "$CI_TEMP_DIR"
git init
git config user.email "$GIT_USER_EMAIL"
git config user.name "$GIT_USER_NAME"
git checkout -b main
git add .
git commit -m "Initial commit for $SERVICE_NAME CI"
git remote add origin "$AUTH_CI_REPO_URL"
git push -u origin main
cd - > /dev/null
rm -rf "$CI_TEMP_DIR"
echo "CI Repository for $SERVICE_NAME seeded successfully."

# --- Seeding CD Repository ---
echo "--- Seeding CD Repository for $SERVICE_NAME ---"
CD_TEMP_DIR=$(mktemp -d)
echo "Using temporary directory for CD: $CD_TEMP_DIR"

cp "examples/mortgage-agent/cloud_run/$SERVICE_NAME.yaml" "$CD_TEMP_DIR/"

cd "$CD_TEMP_DIR"
git init
git config user.email "$GIT_USER_EMAIL"
git config user.name "$GIT_USER_NAME"
git checkout -b main
git add .
git commit -m "Initial commit for $SERVICE_NAME CD"
git remote add origin "$AUTH_CD_REPO_URL"
git push -u origin main
cd - > /dev/null
rm -rf "$CD_TEMP_DIR"
echo "CD Repository for $SERVICE_NAME seeded successfully."

echo "Done with $SERVICE_NAME."
