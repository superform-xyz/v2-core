#!/usr/bin/env bash
# Re-scan deployed other hooks and update output JSONs (no broadcast)
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/networks-production.sh"
load_rpc_urls
export CI=true
export GITHUB_REF_NAME=prod

for chain in 1:ETH_MAINNET 56:BSC_MAINNET 8453:BASE_MAINNET 42161:ARBITRUM_MAINNET; do
    id="${chain%%:*}"
    rpc="${chain##*:}"
    echo "=== Chain $id ==="
    forge script script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks \
        --sig 'run(uint256,uint64)' 0 "$id" \
        --rpc-url "${!rpc}" \
        --chain "$id" \
        -vv || true
    echo ""
done
