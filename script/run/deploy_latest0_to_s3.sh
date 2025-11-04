#!/usr/bin/env bash

###################################################################################
# Deploy latest0.json to S3 for dev branch
# This is a temporary script to restore the original state
###################################################################################

set -euo pipefail

log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Configuration
S3_BUCKET_NAME="vnet-state"
BRANCH_NAME="dev"
SOURCE_FILE="script/output/latest0.json"

log "INFO" "Deploying latest0.json to S3 for dev branch..."

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    log "ERROR" "Source file not found: $SOURCE_FILE"
    exit 1
fi

# Validate JSON
if ! jq '.' "$SOURCE_FILE" >/dev/null 2>&1; then
    log "ERROR" "Source file is not valid JSON"
    exit 1
fi

# Upload to S3
log "INFO" "Uploading $SOURCE_FILE to s3://$S3_BUCKET_NAME/$BRANCH_NAME/latest.json"

if aws s3 cp "$SOURCE_FILE" "s3://$S3_BUCKET_NAME/$BRANCH_NAME/latest.json" --quiet; then
    log "SUCCESS" "Successfully uploaded latest0.json to S3 for dev branch"
else
    log "ERROR" "Failed to upload to S3"
    exit 1
fi

log "INFO" "Deployment complete. You can now delete this script."