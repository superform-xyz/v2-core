#!/bin/bash

###################################################################################
# Superform V2 Contracts Upload Script
###################################################################################
# Description:
#   This script aggregates contract deployment information from the production output
#   directory and uploads it to an S3 bucket. It is designed to be run after
#   the main deployment script has completed for the 'prod' environment.
#
# Directory Structure Assumption:
#   script/output/prod/
#   ├── 1/
#   │   └─── Ethereum-latest.json
#   ├── 10/
#   │   └── Optimism-latest.json
#   └── 8453/
#       └── Base-latest.json
#
# Output:
#   A single `latest_deployment.json` file uploaded to s3://<S3_BUCKET_NAME>/prod/latest_deployment.json
#
# Usage:
#   ./upload_prod_contracts.sh
#
# Requirements:
#   - jq: For JSON processing
#   - aws: For S3 operations
#
# Environment Variables:
#   - S3_BUCKET_NAME: The S3 bucket to upload the contracts file to.
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

# Initialize an empty JSON object for the networks
networks_obj="{}"
log "INFO" "Starting contract aggregation from $PROD_OUTPUT_DIR"

# Get the current timestamp
current_timestamp=$(date +%s)
updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

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

        # Extract network name from the filename (e.g., "Ethereum" from "Ethereum-latest.json")
        network_name=$(basename "$json_file" | sed 's/-latest.json//')

        # Read the contracts data from the JSON file
        contracts_data=$(jq '.' "$json_file")

        # Check if the file was empty or contained invalid JSON
        if [ -z "$contracts_data" ] || [ "$contracts_data" = "null" ]; then
            log "WARN" "File $json_file is empty, does not contain a 'contracts' key, or has invalid JSON. Skipping."
            continue
        fi

        # Create the network-specific object with timestamp and contracts
        network_entry=$(jq -n \
            --argjson timestamp "$current_timestamp" \
            --argjson contracts "$contracts_data" \
            '{ "timestamp": $timestamp, "contracts": $contracts }')

        # Add this entry to the main networks object
        networks_obj=$(echo "$networks_obj" | jq \
            --arg network_name "$network_name" \
            --argjson network_data "$network_entry" \
            '. + {($network_name): $network_data}')

        log "INFO" "Successfully aggregated contracts for network $network_name"
    fi
done

# If no networks were found, exit gracefully.
if [ "$networks_obj" = "{}" ]; then
    log "WARN" "No contract data was found across any network. Exiting without uploading."
    exit 0
fi

# Create the final JSON structure
final_json=$(jq -n \
    --argjson networks "$networks_obj" \
    --arg updated_at "$updated_at" \
    '{ "networks": $networks, "updated_at": $updated_at }')

# Write the final aggregated JSON to a temporary file for inspection and upload
echo "$final_json" | jq '.' > "$TEMP_JSON_PATH"
log "INFO" "Final aggregated contracts JSON created at $TEMP_JSON_PATH:"
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
