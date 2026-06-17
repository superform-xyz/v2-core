#!/usr/bin/env bash
###################################################################################
# Deploy SuperSponsorshipPaymaster on Stable (chain 988) via cast send
# forge doesn't support chain 988, so we use cast directly
#
# Usage: ./script/run/deploy_ssp_stable.sh <account>
#   account: foundry account name (e.g., v2-deployer)
###################################################################################

set -euo pipefail

DEPLOYER="0x4e59b44847b379578588920cA78FbF26c0B4956C"
PREDICTED="0xe043d74dc4eCDe253FdFE3725162ED0AcbC13c5C"
CALLDATA_FILE="$(dirname "$0")/ssp_calldata.txt"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <account>"
    exit 1
fi

ACCOUNT=$1

# Load RPC
if [ -z "${STABLE_MAINNET:-}" ]; then
    echo "Loading Stable RPC from 1Password..."
    export STABLE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/STABLE_RPC_URL/credential 2>/dev/null | tr -d '\n')
fi

if [ -z "${STABLE_MAINNET:-}" ]; then
    echo "❌ STABLE_MAINNET not set. Export it or ensure 1Password CLI is available."
    exit 1
fi

# Check if already deployed
echo "Checking if SuperSponsorshipPaymaster is already deployed..."
CODE_SIZE=$(cast codesize "$PREDICTED" --rpc-url "$STABLE_MAINNET" 2>/dev/null || echo "0")
if [ "$CODE_SIZE" != "0" ]; then
    echo "✅ Already deployed at $PREDICTED (code size: $CODE_SIZE)"
    exit 0
fi

echo "============================================================"
echo "  Deploy SuperSponsorshipPaymaster on Stable (988)"
echo "  Account: $ACCOUNT"
echo "  Predicted address: $PREDICTED"
echo "============================================================"
echo ""

read -rp "Deploy? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

CALLDATA=$(cat "$CALLDATA_FILE")

echo "Sending transaction..."
if cast send --account "$ACCOUNT" --rpc-url "$STABLE_MAINNET" "$DEPLOYER" "$CALLDATA"; then
    echo ""
    echo "Verifying deployment..."
    CODE_SIZE=$(cast codesize "$PREDICTED" --rpc-url "$STABLE_MAINNET" 2>/dev/null || echo "0")
    if [ "$CODE_SIZE" != "0" ]; then
        echo "✅ SuperSponsorshipPaymaster deployed at $PREDICTED (code size: $CODE_SIZE)"
    else
        echo "⚠️  Transaction succeeded but no code at predicted address. Check tx receipt."
    fi
else
    echo "❌ Deployment failed"
    exit 1
fi
