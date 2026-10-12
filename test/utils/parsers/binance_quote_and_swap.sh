#!/usr/bin/env bash
###################################################################################
# Binance Web3 Trading API — GET /api/v1/dex/aggregator/quote-and-swap (LiquidMesh)
###################################################################################
# Called from BinanceAPIParser.sol through `vm.ffi`. Prints the raw JSON body to stdout.
#
# Args: <binanceChainId> <fromTokenAddress> <toTokenAddress> <amount> <userWalletAddress> <slippagePercent>
# Env:  BINANCE_WEB3_API_KEY, BINANCE_WEB3_SECRET_KEY (required)
#       BINANCE_WEB3_API_BASE (optional, default https://web3.binance.com/build)
#
# Signing follows binance-web3-connector-python (`binance_common.utils.web3_signature`):
#   X-OC-APIKEY, X-OC-TIMESTAMP (ISO-8601 UTC ms), X-OC-SIGN = HMAC-SHA256(secret, payload),
#   X-OC-RECV-WINDOW. See SIGNING_PAYLOAD below — keep in sync with the SDK.
###################################################################################
set -euo pipefail

CHAIN_ID="${1:?binanceChainId}"
FROM_TOKEN="${2:?fromTokenAddress}"
TO_TOKEN="${3:?toTokenAddress}"
AMOUNT="${4:?amount}"
WALLET="${5:?userWalletAddress}"
SLIPPAGE="${6:?slippagePercent}"

API_KEY="${BINANCE_WEB3_API_KEY:?BINANCE_WEB3_API_KEY not set}"
SECRET_KEY="${BINANCE_WEB3_SECRET_KEY:?BINANCE_WEB3_SECRET_KEY not set}"
BASE_URL="${BINANCE_WEB3_API_BASE:-https://web3.binance.com/build}"
RECV_WINDOW="${BINANCE_WEB3_RECV_WINDOW:-15000}"

# Every argument is interpolated into BOTH the signed pre-hash and the URL, so reject anything that is
# not the exact shape expected (no `&`, `=`, `/` or whitespace can ever reach the query string).
[[ "$CHAIN_ID" =~ ^[0-9]{1,12}$ ]] || { echo "bad binanceChainId: $CHAIN_ID" >&2; exit 2; }
[[ "$FROM_TOKEN" =~ ^0x[0-9a-fA-F]{40}$ ]] || { echo "bad fromTokenAddress: $FROM_TOKEN" >&2; exit 2; }
[[ "$TO_TOKEN" =~ ^0x[0-9a-fA-F]{40}$ ]] || { echo "bad toTokenAddress: $TO_TOKEN" >&2; exit 2; }
[[ "$AMOUNT" =~ ^[0-9]{1,78}$ ]] || { echo "bad amount: $AMOUNT" >&2; exit 2; }
[[ "$WALLET" =~ ^0x[0-9a-fA-F]{40}$ ]] || { echo "bad userWalletAddress: $WALLET" >&2; exit 2; }
[[ "$SLIPPAGE" =~ ^[0-9]{1,3}(\.[0-9]{1,4})?$ ]] || { echo "bad slippagePercent: $SLIPPAGE" >&2; exit 2; }
[[ "$RECV_WINDOW" =~ ^[0-9]{1,6}$ ]] || { echo "bad recvWindow: $RECV_WINDOW" >&2; exit 2; }

# The signed request carries the API key; never let a stray env var redirect it off binance.com.
if [[ "$BASE_URL" != https://web3.binance.com/* && "${BINANCE_WEB3_API_ALLOW_CUSTOM_BASE:-}" != "1" ]]; then
    echo "refusing non-Binance BINANCE_WEB3_API_BASE=$BASE_URL (set BINANCE_WEB3_API_ALLOW_CUSTOM_BASE=1 for a local stub)" >&2
    exit 2
fi

API_PATH="/api/v1/dex/aggregator/quote-and-swap"
# Alphabetical key order (matches the SDK's url-encoded query string).
QUERY="amount=${AMOUNT}&binanceChainId=${CHAIN_ID}&enableRfq=false&fromTokenAddress=${FROM_TOKEN}&slippagePercent=${SLIPPAGE}&toTokenAddress=${TO_TOKEN}&userWalletAddress=${WALLET}&vendor=LiquidMesh"

if date --version >/dev/null 2>&1; then
    TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"            # GNU
else
    TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S).000Z"            # BSD/macOS
fi

# SIGNING_PAYLOAD — the string the SDK HMACs. Mirrors binance_common.utils.web3_signature:
#   pre_hash = f"{timestamp}{METHOD}/build{path}?{encoded_query}"   (note the literal "/build" base path)
#   X-OC-SIGN = base64(HMAC-SHA256(api_secret, pre_hash))
SIGNING_PAYLOAD="${TIMESTAMP}GET/build${API_PATH}?${QUERY}"

SIGNATURE="$(printf '%s' "${SIGNING_PAYLOAD}" | openssl dgst -sha256 -hmac "${SECRET_KEY}" -binary | base64 | tr -d '\n')"

# No --fail: HTTP errors carry a JSON body ({"code":40101,"msg":"Invalid API Key"}) that the
# Solidity parser surfaces verbatim; a non-zero exit here would hide it behind vm.ffi.
curl -sS --max-time 30 \
    -H "Accept: application/json" \
    -H "X-OC-APIKEY: ${API_KEY}" \
    -H "X-OC-TIMESTAMP: ${TIMESTAMP}" \
    -H "X-OC-SIGN: ${SIGNATURE}" \
    -H "X-OC-RECV-WINDOW: ${RECV_WINDOW}" \
    "${BASE_URL}${API_PATH}?${QUERY}"
