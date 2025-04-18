#!/bin/bash

###################################################################################
# Upload Contract ABIs to S3
###################################################################################
# Description:
#   This script uploads compiled contract JSON files from the 'out' directory
#   to an S3 bucket, organizing them by:
#   1. All ABIs in a "latest" folder
#   2. ABIs categorized according to their location in src/core and src/periphery
#
# Usage:
#   ./export_abis_s3.sh <branch_name> [options]
#   
#   Parameters:
#     branch_name: Name of the branch (required)
#
#   Options:
#     -v, --verbose: Show all log messages (default: only INFO and above)
#     -q, --quiet: Show only ERROR messages
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

# Default log level
# 0 = ERROR only, 1 = WARN and above, 2 = INFO and above, 3 = DEBUG and above
LOG_LEVEL=2

# Parse command line options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -v|--verbose)
            LOG_LEVEL=3
            shift
            ;;
        -q|--quiet)
            LOG_LEVEL=0
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done
set -- "${POSITIONAL[@]}"  # Restore positional parameters

# Logging function for consistent output
log() {
    local level=$1
    local level_num=2  # Default to INFO level
    shift
    
    case $level in
        "ERROR") level_num=0 ;;
        "WARN")  level_num=1 ;;
        "INFO")  level_num=2 ;;
        "DEBUG") level_num=3 ;;
    esac
    
    # Only log if the message level is less than or equal to the current log level
    if [ $level_num -le $LOG_LEVEL ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
    fi
}

# Script Arguments
BRANCH_NAME=${1:-${GITHUB_REF_NAME:-}}

if [ -z "$BRANCH_NAME" ]; then
    log "ERROR" "Branch name is required"
    echo "Usage: $0 <branch_name> [options]"
    echo "Options:"
    echo "  -v, --verbose: Show all log messages"
    echo "  -q, --quiet: Show only ERROR messages"
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

# Check if src directory exists
if [ ! -d "src" ]; then
    log "ERROR" "src directory not found. Source code is required for organizing ABIs."
    exit 1
fi

# Create a temporary directory for organizing files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

log "INFO" "Created temporary directory: $TEMP_DIR"

# Create the "latest" directory for all ABIs
mkdir -p "$TEMP_DIR/latest"

# Find all contract JSON files in the out directory (excluding test files)
log "INFO" "Finding all contract JSON files in the out directory"
CONTRACT_FILES=$(find out -name "*.json" -type f | grep -v "\.t\.sol" | sort)
CONTRACT_COUNT=$(echo "$CONTRACT_FILES" | wc -l)
log "INFO" "Found $CONTRACT_COUNT contract JSON files"

# Process each contract file
for contract_file in $CONTRACT_FILES; do
    # Extract contract name from the JSON file path
    filename=$(basename "$contract_file")
    contract_name="${filename%.json}"
    
    # Skip if not a valid contract file
    if ! jq -e '.abi' "$contract_file" > /dev/null 2>&1; then
        log "DEBUG" "Skipping $contract_file - not a valid contract ABI file"
        continue
    fi
    
    log "DEBUG" "Processing contract: $contract_name from $contract_file"
    
    # Copy to latest directory with flattened structure
    cp "$contract_file" "$TEMP_DIR/latest/${contract_name}.json"
    log "DEBUG" "Copied to latest/${contract_name}.json"
    
    # Find the source file for this contract
    src_file=""
    
    # Look in src/core
    if find src/core -name "${contract_name}.sol" -type f 2>/dev/null | grep -q .; then
        src_file=$(find src/core -name "${contract_name}.sol" -type f | head -n 1)
        src_dir="core"
    # Look in src/periphery
    elif find src/periphery -name "${contract_name}.sol" -type f 2>/dev/null | grep -q .; then
        src_file=$(find src/periphery -name "${contract_name}.sol" -type f | head -n 1)
        src_dir="periphery"
    # Look in src/interfaces
    elif find src -path "*/interfaces/*" -name "${contract_name}.sol" -type f 2>/dev/null | grep -q .; then
        src_file=$(find src -path "*/interfaces/*" -name "${contract_name}.sol" -type f | head -n 1)
        src_dir="interfaces"
    # Check if it's an interface by name
    elif [[ "$contract_name" == I* ]]; then
        src_dir="interfaces"
    else
        src_dir=""
    fi
    
    # If source file found, organize by directory structure
    if [ -n "$src_file" ]; then
        if [ "$src_dir" == "core" ]; then
            # Extract the relative path from src/core
            rel_path=$(dirname "${src_file#src/core/}")
            # Create the directory structure
            mkdir -p "$TEMP_DIR/core/$rel_path"
            # Copy the ABI to the appropriate directory
            cp "$contract_file" "$TEMP_DIR/core/$rel_path/${contract_name}.json"
            log "DEBUG" "Organized $contract_name in core/$rel_path"
        elif [ "$src_dir" == "periphery" ]; then
            # Extract the relative path from src/periphery
            rel_path=$(dirname "${src_file#src/periphery/}")
            # Create the directory structure
            mkdir -p "$TEMP_DIR/periphery/$rel_path"
            # Copy the ABI to the appropriate directory
            cp "$contract_file" "$TEMP_DIR/periphery/$rel_path/${contract_name}.json"
            log "DEBUG" "Organized $contract_name in periphery/$rel_path"
        elif [ "$src_dir" == "interfaces" ]; then
            # Create interfaces directory
            mkdir -p "$TEMP_DIR/interfaces"
            # Copy the ABI to the interfaces directory
            cp "$contract_file" "$TEMP_DIR/interfaces/${contract_name}.json"
            log "DEBUG" "Organized $contract_name in interfaces"
        fi
    elif [ "$src_dir" == "interfaces" ]; then
        # Create interfaces directory for interface contracts without source files
        mkdir -p "$TEMP_DIR/interfaces"
        # Copy the ABI to the interfaces directory
        cp "$contract_file" "$TEMP_DIR/interfaces/${contract_name}.json"
        log "DEBUG" "Organized $contract_name in interfaces (by naming convention)"
    else
        log "WARN" "Could not find source location for $contract_name, only in latest folder"
    fi
done

# Count organized JSON files
LATEST_COUNT=$(find "$TEMP_DIR/latest" -name "*.json" | wc -l)
CORE_COUNT=$(find "$TEMP_DIR/core" -name "*.json" 2>/dev/null | wc -l || echo 0)
PERIPHERY_COUNT=$(find "$TEMP_DIR/periphery" -name "*.json" 2>/dev/null | wc -l || echo 0)
INTERFACES_COUNT=$(find "$TEMP_DIR/interfaces" -name "*.json" 2>/dev/null | wc -l || echo 0)

log "INFO" "Organized $LATEST_COUNT contracts in latest folder"
log "INFO" "Organized $CORE_COUNT contracts in core folders"
log "INFO" "Organized $PERIPHERY_COUNT contracts in periphery folders"
log "INFO" "Organized $INTERFACES_COUNT contracts in interfaces folder"

# Create a summary file with contract names and their organized locations
log "INFO" "Creating summary file..."

SUMMARY_FILE="$TEMP_DIR/summary.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "{" > "$SUMMARY_FILE"
echo "  \"generated_at\": \"$TIMESTAMP\"," >> "$SUMMARY_FILE"
echo "  \"contracts\": {" >> "$SUMMARY_FILE"

# Find all JSON files in the latest directory and extract contract names
first=true
find "$TEMP_DIR/latest" -name "*.json" | sort | while read -r file; do
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
    
    # Find all locations where this contract ABI exists
    locations=("latest/${contract_name}.json")
    
    # Check if it exists in core
    core_path=$(find "$TEMP_DIR/core" -name "${contract_name}.json" 2>/dev/null || echo "")
    if [ -n "$core_path" ]; then
        rel_path=${core_path#$TEMP_DIR/}
        locations+=("$rel_path")
    fi
    
    # Check if it exists in periphery
    periphery_path=$(find "$TEMP_DIR/periphery" -name "${contract_name}.json" 2>/dev/null || echo "")
    if [ -n "$periphery_path" ]; then
        rel_path=${periphery_path#$TEMP_DIR/}
        locations+=("$rel_path")
    fi
    
    # Check if it exists in interfaces
    interface_path=$(find "$TEMP_DIR/interfaces" -name "${contract_name}.json" 2>/dev/null || echo "")
    if [ -n "$interface_path" ]; then
        rel_path=${interface_path#$TEMP_DIR/}
        locations+=("$rel_path")
    fi
    
    # Add to summary with all locations
    echo -n "    \"$contract_name\": [" >> "$SUMMARY_FILE"
    loc_first=true
    for loc in "${locations[@]}"; do
        if [ "$loc_first" = true ]; then
            loc_first=false
        else
            echo -n ", " >> "$SUMMARY_FILE"
        fi
        echo -n "\"$loc\"" >> "$SUMMARY_FILE"
    done
    echo -n "]" >> "$SUMMARY_FILE"
done

echo "" >> "$SUMMARY_FILE"
echo "  }" >> "$SUMMARY_FILE"
echo "}" >> "$SUMMARY_FILE"

# Upload to S3
log "INFO" "Starting S3 sync to s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX"
if ! aws s3 sync "$TEMP_DIR" "s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX"; then
    log "ERROR" "Failed to upload contract JSON files to S3"
    exit 1
fi

log "SUCCESS" "All contract ABIs uploaded to s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/"
log "SUCCESS" "Summary file available at s3://$S3_BUCKET_NAME_ABIS/$S3_PREFIX/summary.json"