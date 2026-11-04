#!/usr/bin/env bash
###################################################################################
# Find the Fireblocks assetId for a chain
###################################################################################
# Why this exists:
#   fireblocks-web3-provider resolves assetId from its own chainId map. Chains absent
#   from that map (Katana 747474, Arc 5042, ...) need FIREBLOCKS_ASSET_ID set by hand in
#   add_to_super_ledger_staging_prod.sh, or signing fails. The names follow no derivable
#   rule -- Base is BASECHAIN_ETH, Optimism ETH-OPT, Unichain UNICHAIN_ETH, Plume
#   PLUME_PLUME -- so the value has to come from the workspace itself.
#
# Usage:
#   ./script/run/tooling/find_fireblocks_asset_id.sh 747474
#   ./script/run/tooling/find_fireblocks_asset_id.sh katana      # substring search
#
# Requires: 1Password CLI signed in (op whoami), python3.
###################################################################################
set -euo pipefail
QUERY="${1:-}"
if [[ -z "$QUERY" ]]; then
    echo "Usage: $0 <chain_id|name_substring>" >&2
    exit 1
fi

command -v op >/dev/null || { echo "1Password CLI (op) not found" >&2; exit 1; }
op whoami >/dev/null 2>&1 || { echo "1Password session not active. Run: eval \$(op signin)" >&2; exit 1; }

VENV="${TMPDIR:-/tmp}/fb-assetid-venv"
if [[ ! -x "$VENV/bin/python" ]]; then
    echo "Creating throwaway venv for PyJWT..." >&2
    python3 -m venv "$VENV" >&2
    "$VENV/bin/pip" install -q --disable-pip-version-check "pyjwt[crypto]" >&2
fi

FIREBLOCKS_API_KEY="$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_ACTION/credential)"
FIREBLOCKS_SECRET="$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_SECRET/notesPlain)"
export FIREBLOCKS_API_KEY FIREBLOCKS_SECRET QUERY

"$VENV/bin/python" - <<'PY'
import os, sys, time, json, uuid, hashlib, urllib.request
import jwt

api_key = os.environ["FIREBLOCKS_API_KEY"]
secret  = os.environ["FIREBLOCKS_SECRET"]
query   = os.environ["QUERY"]
if not secret.lstrip().startswith("-----BEGIN") and os.path.exists(secret.strip()):
    secret = open(secret.strip()).read()

def call(path):
    now = int(time.time())
    claims = {
        "uri": path, "nonce": str(uuid.uuid4()), "iat": now, "exp": now + 55,
        "sub": api_key, "bodyHash": hashlib.sha256(b"").hexdigest(),
    }
    tok = jwt.encode(claims, secret, algorithm="RS256")
    req = urllib.request.Request(
        "https://api.fireblocks.io" + path,
        headers={"X-API-Key": api_key, "Authorization": f"Bearer {tok}"},
    )
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)

try:
    assets = call("/v1/supported_assets")
except Exception as e:
    body = getattr(e, "read", lambda: b"")()
    print(f"API call failed: {e}\n{body[:300].decode(errors='replace')}", file=sys.stderr)
    sys.exit(1)

print(f"workspace reports {len(assets)} supported assets\n")
q = query.lower()
hits = [a for a in assets
        if q in json.dumps(a).lower()
        or (q.isdigit() and str(a.get("networkProtocol","")) == q)]
if not hits:
    print(f"NO asset matching '{query}'.")
    print("Katana is likely not onboarded in this workspace -> ask your Fireblocks admin.")
    print("\nNearby native-ETH L2 assets, for reference:")
    for a in assets:
        if "ETH" in a.get("id","") and a.get("type")=="BASE_ASSET":
            print(f"  {a.get('id'):<28} {a.get('name','')}")
    sys.exit(2)

print(f"MATCHES for '{query}':")
for a in hits:
    print(f"  id={a.get('id'):<28} name={a.get('name','')!r:<28} type={a.get('type','')} "
          f"contract={a.get('contractAddress') or '-'}")
print("\nUse the `id` value:")
print(f"  KATANA_FIREBLOCKS_ASSET_ID=<id> ./script/run/config/add_to_super_ledger_staging_prod.sh prod --chains 747474")
PY
