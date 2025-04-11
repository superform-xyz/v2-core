#!/bin/bash

###################################################################################
# Upload Contract ABIs to S3
###################################################################################
# Description:
#   This script uploads compiled contract JSON files from the 'out' directory
#   to an S3 bucket, only for contracts that are deployed.
#
# Usage:
#   ./export_abis_s3.sh <branch_name>
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
BRANCH_NAME=${1:-${GITHUB_REF_NAME:-}}

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

# Print AWS version and check connectivity
log "INFO" "AWS CLI version: $(aws --version)"
log "INFO" "Testing AWS connectivity..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    log "ERROR" "Failed to connect to AWS. Check your credentials."
    exit 1
fi

# Check if bucket exists and we have permissions
log "INFO" "Checking if bucket exists and we have permissions..."
if ! aws s3api head-bucket --bucket "$S3_BUCKET_NAME_ABIS" 2>/dev/null; then
    # Try to list the bucket to get more specific error
    ERROR_OUTPUT=$(aws s3 ls "s3://$S3_BUCKET_NAME_ABIS" 2>&1 || true)
    
    if [[ "$ERROR_OUTPUT" == *"AccessDenied"* ]]; then
        log "ERROR" "Access denied to the bucket. Check your AWS permissions."
    elif [[ "$ERROR_OUTPUT" == *"NoSuchBucket"* ]]; then
        log "ERROR" "The bucket does not exist."
    else
        log "ERROR" "Could not access the bucket. Error: $(echo "$ERROR_OUTPUT" | tr -d '\n' | sed 's/^.*Error: //')"
    fi
    exit 1
fi

# Determine S3 path prefix based on branch
if [[ "$BRANCH_NAME" == feat/* ]]; then
    # Extract feature name without feat/ prefix
    FEATURE_NAME=${BRANCH_NAME#feat/}
    S3_PREFIX="feat/$FEATURE_NAME"
else
    # For dev, main branches
    S3_PREFIX="$BRANCH_NAME"
fi

log "INFO" "Using S3 prefix: $S3_PREFIX"

# Check if out directory exists
if [ ! -d "out" ]; then
    log "ERROR" "out directory not found. Run 'forge build' first."
    exit 1
fi

# Read deployed contracts from Ethereum-latest.json
ETHEREUM_LATEST="script/output/local/1/Ethereum-latest.json"
if [ ! -f "$ETHEREUM_LATEST" ]; then
    log "ERROR" "Ethereum-latest.json not found at $ETHEREUM_LATEST"
    exit 1
fi

# Extract contract names from Ethereum-latest.json
log "INFO" "Reading deployed contracts from $ETHEREUM_LATEST"
DEPLOYED_CONTRACTS=$(jq -r 'keys[]' "$ETHEREUM_LATEST")
if [ -z "$DEPLOYED_CONTRACTS" ]; then
    log "ERROR" "No deployed contracts found in $ETHEREUM_LATEST"
    exit 1
fi

log "INFO" "Found $(echo "$DEPLOYED_CONTRACTS" | wc -l) deployed contracts"

# Create a temporary directory for organizing files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

log "INFO" "Created temporary directory: $TEMP_DIR"

# Copy only deployed contract files to temp directory
log "INFO" "Copying deployed contract files to temporary directory"
for contract in $DEPLOYED_CONTRACTS; do
    log "DEBUG" "Processing contract: $contract"
    
    # First try to find the contract in its own directory (implementation)
    contract_file=""
    if find out -path "out/${contract}.sol/${contract}.json" -type f 2>/dev/null | grep -q .; then
        contract_file=$(find out -path "out/${contract}.sol/${contract}.json" -type f | head -n 1)
        log "DEBUG" "Found in primary location: $contract_file"
    fi
    
    # If not found, try a more general search but exclude test files
    if [ -z "$contract_file" ]; then
        log "DEBUG" "Contract not found in primary location, trying secondary search"
        if find out -name "${contract}.json" -type f 2>/dev/null | grep -v "\.t\.sol" | grep -q .; then
            contract_file=$(find out -name "${contract}.json" -type f | grep -v "\.t\.sol" | head -n 1)
            log "DEBUG" "Found in secondary location: $contract_file"
        fi
    fi
    
    # If still not found, log a warning
    if [ -z "$contract_file" ]; then
        log "WARN" "Could not find JSON file for $contract"
        continue
    fi
    
    # Copy to temp directory with flattened structure
    log "DEBUG" "Copying from $contract_file to $TEMP_DIR/${contract}.json"
    cp "$contract_file" "$TEMP_DIR/${contract}.json"
    log "INFO" "Copied $contract from $contract_file"
done

# Count filtered JSON files
FILTERED_COUNT=$(find "$TEMP_DIR" -name "*.json" | wc -l)
log "INFO" "Filtered to $FILTERED_COUNT deployed contract JSON files"

# Upload to S3
log "INFO" "Starting S3 sync to s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX"
if ! aws s3 sync "$TEMP_DIR" "s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX"; then
    log "ERROR" "Failed to upload contract JSON files to S3"
    exit 1
fi

# Create a summary file with contract names
log "INFO" "Creating summary file..."

SUMMARY_FILE="$TEMP_DIR/summary.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "{" > "$SUMMARY_FILE"
echo "  \"generated_at\": \"$TIMESTAMP\"," >> "$SUMMARY_FILE"
echo "  \"contracts\": {" >> "$SUMMARY_FILE"

# Find all JSON files and extract contract names
first=true
find "$TEMP_DIR" -name "*.json" | sort | while read -r file; do
    # Extract contract name (filename without extension)
    contract_name=$(basename "$file" .json)
    # Skip if not a contract file or if it's the summary file
    if [[ "$file" == "$SUMMARY_FILE" ]] || ! jq -e '.abi' "$file" > /dev/null 2>&1; then
        continue
    fi
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$SUMMARY_FILE"
    fi
    
    # Add to summary with just the filename
    echo -n "    \"$contract_name\": \"$contract_name.json\"" >> "$SUMMARY_FILE"
done

echo "" >> "$SUMMARY_FILE"
echo "  }" >> "$SUMMARY_FILE"
echo "}" >> "$SUMMARY_FILE"

# Upload summary file
log "INFO" "Uploading summary file to s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/summary.json"
if ! aws s3 cp "$SUMMARY_FILE" "s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/summary.json"; then
    log "ERROR" "Failed to upload summary file to S3"
    exit 1
fi

log "SUCCESS" "All deployed contract ABIs uploaded to s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/"
log "SUCCESS" "Summary file available at s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/summary.json"