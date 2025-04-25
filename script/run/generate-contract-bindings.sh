#!/usr/bin/env bash

set -e

# Create the base directory if it doesn't exist
mkdir -p contract_bindings

# Find all ABI files directly
find ./out -name "*.abi" | while read abi_file; do
  # Extract contract name and directory from the ABI file path
  dir_path=$(dirname "$abi_file")
  base_name=$(basename "$abi_file" .abi)
  
  # Extract directory name to check if it's a test file
  dir_name=$(basename "$dir_path")
  
  # Convert to lowercase for comparison
  base_name_lower=$(echo "$base_name" | tr '[:upper:]' '[:lower:]')
  dir_name_lower=$(echo "$dir_name" | tr '[:upper:]' '[:lower:]')
  
  
  # Only process contracts that start with Super and don't end with hook
  if [[ "$base_name" != Super* || "$base_name_lower" == *hook || "$dir_name" == *.t.sol ]]; then
    continue
  fi
  
  # Create directory for this contract
  mkdir -p "contract_bindings/${base_name}"
  

    abigen --abi "$abi_file" \
        --pkg "$base_name" \
        --type "$base_name" \
        --out "contract_bindings/${base_name}/${base_name}.go"
done

# Disable debugging
set +x

echo "Contract bindings generated successfully" 