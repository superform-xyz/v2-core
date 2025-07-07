#!/bin/bash

###################################################################################
# Superform V2 Hooks Upload Script
###################################################################################
# Description:
#   This script aggregates hooks deployment information from the production output
#   directory and uploads it to an S3 bucket. It is designed to be run after
#   the main deployment script has completed for the 'prod' environment.
#
# Directory Structure Assumption:
#   script/output/prod/
#   ├── 1/
#   │   └── Ethereum-latest.json
#   ├── 10/
#   │   └── Optimism-latest.json
#   └── 8453/
#       └── Base-latest.json
#
# Output:
#   A single `latest_deployment.json` file uploaded to s3://<S3_BUCKET_NAME>/prod/latest_deployment.json
#
# Usage:
#   ./upload_prod_hooks_to_s3.sh
#
# Requirements:
#   - jq: For JSON processing
#   - aws: For S3 operations
#
# Environment Variables:
#   - S3_BUCKET_NAME: The S3 bucket to upload the hooks file to.
#
###################################################################################

set -euo pipefail # Exit on error, undefined var, pipe failure

###################################################################################
# Helper Functions
###################################################################################

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

###################################################################################
# Configuration
###################################################################################

PROD_OUTPUT_DIR="script/output/prod"
# Default S3 bucket name if the environment variable is not set
S3_BUCKET_NAME="${S3_BUCKET_NAME:-v2-prod-deployments}"
BRANCH_NAME="prod"
FINAL_JSON_FILE="latest_deployment.json"
TEMP_JSON_PATH="/tmp/$FINAL_JSON_FILE"

###################################################################################
# Script Logic
###################################################################################

# Validate that the production output directory exists
if [ ! -d "$PROD_OUTPUT_DIR" ]; then
    log "ERROR" "Production output directory not found at: $PROD_OUTPUT_DIR"
    exit 1
fi

# Initialize an empty JSON object to store all hooks
combined_hooks="{}"
log "INFO" "Starting hooks aggregation from $PROD_OUTPUT_DIR"

# Iterate through each network directory in the production output directory
for network_dir in "$PROD_OUTPUT_DIR"/*; do
    if [ -d "$network_dir" ]; then
        network_id=$(basename "$network_dir")
        log "INFO" "Processing network ID: $network_id"

        # Find the deployment JSON file (e.g., Ethereum-latest.json)
        json_file=$(find "$network_dir" -maxdepth 1 -name '*-latest.json' -print -quit)

        if [ -z "$json_file" ]; then
            log "WARN" "No '*-latest.json' file found in $network_dir. Skipping."
            continue
        fi

        log "INFO" "Found deployment file: $json_file"

        # Read the entire JSON file.
        hooks_data=$(jq '.' "$json_file")

        # Check if the file was empty or contained invalid JSON
        if [ -z "$hooks_data" ]; then
            log "WARN" "File $json_file is empty or contains invalid JSON. Skipping."
            continue
        fi

        # Add the extracted hooks data to the main JSON object, keyed by the network ID
        combined_hooks=$(echo "$combined_hooks" | jq \
            --arg network_id "$network_id" \
            --argjson hooks "$hooks_data" \
            '. + {($network_id): $hooks}')

        log "INFO" "Successfully aggregated hooks for network $network_id"
    fi
done

# If no hooks were found in any of the files, exit gracefully.
if [ "$combined_hooks" = "{}" ]; then
    log "WARN" "No hooks were found across any network. Exiting without uploading."
    exit 0
fi

# Write the final aggregated JSON to a temporary file for inspection and upload
echo "$combined_hooks" | jq '.' > "$TEMP_JSON_PATH"
log "INFO" "Final aggregated hooks JSON created at $TEMP_JSON_PATH:"
# Output the final JSON to the console
cat "$TEMP_JSON_PATH"

# Upload the final latest_deployment.json file to S3
s3_path="s3://$S3_BUCKET_NAME/$BRANCH_NAME/$FINAL_JSON_FILE"
log "INFO" "Uploading $FINAL_JSON_FILE to $s3_path"

if aws s3 cp "$TEMP_JSON_PATH" "$s3_path" --quiet; then
    log "SUCCESS" "Successfully uploaded $FINAL_JSON_FILE to S3."
else
    log "ERROR" "Failed to upload $FINAL_JSON_FILE to S3."
    exit 1
fi
