#!/bin/bash

###################################################################################
# Upload Contract ABIs to S3
###################################################################################
# Description:
#   This script uploads compiled contract JSON files from the 'out' directory
#   to an S3 bucket, preserving the directory structure.
#
# Usage:
#   ./upload_abis_to_s3.sh <branch_name>
#   
#   Parameters:
#     branch_name: Name of the branch (required)
#
# Requirements:
#   - aws: For S3 operations
#   - jq: For JSON processing
#
# Environment Variables:
#   - S3_BUCKET_NAME_ABIS: S3 bucket name for storing ABIs (required)
#   - GITHUB_REF_NAME: Branch name (used in CI)
#
# Author: Superform Team
###################################################################################

set -euo pipefail  # Exit on error, undefined var, pipe failure

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Script Arguments
BRANCH_NAME=${1:-$GITHUB_REF_NAME}

if [ -z "$BRANCH_NAME" ]; then
    log "ERROR" "Branch name is required"
    echo "Usage: $0 <branch_name>"
    exit 1
fi

# Validate S3 bucket name
if [ -z "${S3_BUCKET_NAME_ABIS:-}" ]; then
    log "ERROR" "S3_BUCKET_NAME_ABIS environment variable is required"
    exit 1
fi

# Determine S3 path prefix based on branch
if [[ "$BRANCH_NAME" == feat/* ]]; then
    # Extract feature name without feat/ prefix
    FEATURE_NAME=${BRANCH_NAME#feat/}
    S3_PREFIX="feat/$FEATURE_NAME/abis"
else
    # For dev, main branches
    S3_PREFIX="$BRANCH_NAME/abis"
fi

log "INFO" "Using S3 prefix: $S3_PREFIX"

# Check if out directory exists
if [ ! -d "out" ]; then
    log "ERROR" "out directory not found. Run 'forge build' first."
    exit 1
fi

# Count JSON files
JSON_COUNT=$(find out -name "*.json" | wc -l)
log "INFO" "Found $JSON_COUNT JSON files to upload"

# Upload JSON files to S3
log "INFO" "Uploading contract JSON files to S3..."

# Create a temporary directory for organizing files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Copy files to temp directory with proper structure
find out -name "*.json" | while read -r file; do
    # Get relative path from out directory
    rel_path=${file#out/}
    # Create directory structure in temp dir
    mkdir -p "$TEMP_DIR/$(dirname "$rel_path")"
    # Copy file
    cp "$file" "$TEMP_DIR/$rel_path"
done

# Upload to S3
if aws s3 sync "$TEMP_DIR" "s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX" --quiet; then
    log "SUCCESS" "Successfully uploaded contract JSON files to S3"
else
    log "ERROR" "Failed to upload contract JSON files to S3"
    exit 1
fi

# Create a summary file with contract names and paths
log "INFO" "Creating summary file..."

SUMMARY_FILE="$TEMP_DIR/summary.json"
echo "{" > "$SUMMARY_FILE"
echo "  \"contracts\": {" >> "$SUMMARY_FILE"

# Find all JSON files and extract contract names
first=true
find "$TEMP_DIR" -name "*.json" | sort | while read -r file; do
    # Get relative path from temp directory
    rel_path=${file#$TEMP_DIR/}
    # Extract contract name (filename without extension)
    contract_name=$(basename "$rel_path" .json)
    # Skip if not a contract file
    if ! jq -e '.abi' "$file" > /dev/null 2>&1; then
        continue
    fi
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$SUMMARY_FILE"
    fi
    
    # Add to summary
    echo -n "    \"$contract_name\": \"$rel_path\"" >> "$SUMMARY_FILE"
done

echo "" >> "$SUMMARY_FILE"
echo "  }" >> "$SUMMARY_FILE"
echo "}" >> "$SUMMARY_FILE"

# Upload summary file
if aws s3 cp "$SUMMARY_FILE" "s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/summary.json" --quiet; then
    log "SUCCESS" "Successfully uploaded summary file to S3"
else
    log "ERROR" "Failed to upload summary file to S3"
    exit 1
fi

log "INFO" "All files uploaded to s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/"
log "INFO" "Summary file available at s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/summary.json"