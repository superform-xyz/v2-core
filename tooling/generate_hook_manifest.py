#!/usr/bin/env python3
"""
Generate manifests/hooks.json from:
  1. tooling/hook-classification.yaml  (actionTypes + legSizing)
  2. script/output/{staging,prod}/{chainId}/*-latest.json  (deployed addresses)
  3. src/hooks/**/*Hook.sol  (on-chain fields parsed from source)

Usage:
  python tooling/generate_hook_manifest.py
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CLASSIFICATION_PATH = ROOT / "tooling" / "hook-classification.yaml"
ENRICHMENT_PATH = ROOT / "tooling" / "hook-enrichment.yaml"
OUTPUT_PATH = ROOT / "manifests" / "hooks.json"
HOOKS_SRC = ROOT / "src" / "hooks"
DEPLOY_OUTPUT = ROOT / "script" / "output"

# Map HookSubTypes constant names to human-readable strings
SUBTYPE_MAP = {
    "ERC4626": "ERC4626",
    "ERC5115": "ERC5115",
    "ERC7540": "ERC7540",
    "SWAP": "SWAP",
    "BRIDGE": "BRIDGE",
    "TRANSFER": "TRANSFER",
    "CLAIM": "CLAIM",
    "STAKING": "STAKING",
    "MORPHO": "MORPHO",
    "AAVE_V4": "AAVE_V4",
    "METAMORPHO": "METAMORPHO",
    "SUPERFORM": "SUPERFORM",
    "SPONSORSHIP": "SPONSORSHIP",
    "DETH": "DETH",
    "ETHENA": "ETHENA",
    "FIRELIGHT": "FIRELIGHT",
    "VAULT_BANK": "VAULT_BANK",
    "PENDLE_PT_YS_ORACLE": "PENDLE_PT_YS_ORACLE",
    "SPECTRA": "SPECTRA",
    "PENDLE": "PENDLE",
    "FLARE": "FLARE",
}

HOOK_TYPE_MAP = {
    "HookType.NONACCOUNTING": "NONACCOUNTING",
    "HookType.INFLOW": "INFLOW",
    "HookType.OUTFLOW": "OUTFLOW",
}


def load_classification() -> dict:
    """Load hook-classification.yaml."""
    with open(CLASSIFICATION_PATH) as f:
        return yaml.safe_load(f)


def load_enrichment() -> dict:
    """Load hook-enrichment.yaml."""
    if not ENRICHMENT_PATH.exists():
        return {}
    with open(ENRICHMENT_PATH) as f:
        return yaml.safe_load(f) or {}


def find_hook_source_files() -> dict[str, Path]:
    """Find all concrete hook .sol files, returning {ContractName: Path}."""
    hooks = {}
    for sol_file in HOOKS_SRC.rglob("*Hook.sol"):
        name = sol_file.stem
        # Skip base/abstract hooks
        if name.startswith("Base") or name == "VaultBankLockableHook":
            continue
        hooks[name] = sol_file
    # Also catch *HookV2.sol pattern
    for sol_file in HOOKS_SRC.rglob("*HookV2.sol"):
        name = sol_file.stem
        if name.startswith("Base"):
            continue
        hooks[name] = sol_file
    return hooks


def parse_hook_source(path: Path) -> dict:
    """Extract on-chain metadata from a hook source file."""
    content = path.read_text()
    result = {}

    # Extract name() return value
    name_match = re.search(r'function name\(\).*?return\s+"([^"]+)"', content, re.DOTALL)
    if name_match:
        result["name"] = name_match.group(1)

    # Extract description() return value
    desc_match = re.search(r'function description\(\).*?return\s+"([^"]+)"', content, re.DOTALL)
    if desc_match:
        result["description"] = desc_match.group(1)

    # Extract hookType from constructor — check direct BaseHook call or inheritance
    # Direct: BaseHook(HookType.INFLOW, HookSubTypes.ERC4626)
    hook_type_match = re.search(r'BaseHook\(HookType\.(\w+)', content)
    if hook_type_match:
        result["hookType"] = hook_type_match.group(1)
    else:
        # Check if it extends BaseLoanHook (always NONACCOUNTING)
        if "BaseLoanHook" in content or "BaseAaveV4LoanHook" in content or "BaseMorphoLoanHook" in content:
            result["hookType"] = "NONACCOUNTING"
        # Check BaseClaimRewardHook
        elif "BaseClaimRewardHook" in content:
            result["hookType"] = "NONACCOUNTING"
        # Aerodrome concrete hooks inherit all on-chain metadata from their shared base
        elif "BaseAerodromeUniversalRouterHook" in content:
            result["hookType"] = "NONACCOUNTING"
        # HyperCore CoreWriter leaves inherit NONACCOUNTING/HYPERCORE from BaseHyperCoreWriterHook
        elif "BaseHyperCoreWriterHook" in content:
            result["hookType"] = "NONACCOUNTING"
            result["subtype"] = "HYPERCORE"

    # Extract subtype from constructor usage (not from import path which contains HookSubTypes.sol)
    for m in re.finditer(r'HookSubTypes\.(\w+)', content):
        if m.group(1) != "sol":
            result["subtype"] = m.group(1)
            break
    if "BaseAerodromeUniversalRouterHook" in content:
        result["subtype"] = "SWAP"

    return result


def load_deployment_addresses(env: str) -> dict[str, dict[str, str]]:
    """
    Load deployed hook addresses from script/output/{env}/{chainId}/*-latest.json.
    Returns {HookName: {chainId: address}}.
    """
    addresses: dict[str, dict[str, str]] = {}
    env_dir = DEPLOY_OUTPUT / env

    if not env_dir.exists():
        return addresses

    for chain_dir in env_dir.iterdir():
        if not chain_dir.is_dir():
            continue
        chain_id = chain_dir.name
        # Skip non-numeric directories
        if not chain_id.isdigit():
            continue

        for json_file in chain_dir.glob("*-latest.json"):
            try:
                with open(json_file) as f:
                    data = json.load(f)
            except (json.JSONDecodeError, IOError):
                continue

            for contract_name, address in data.items():
                if contract_name.endswith("Hook") or contract_name.endswith("HookV2"):
                    if contract_name not in addresses:
                        addresses[contract_name] = {}
                    addresses[contract_name][chain_id] = address

    return addresses


def enrich_hook(hook_name: str, entry: dict, enrichment: dict) -> dict:
    """Add enrichment fields to a hook entry."""
    protocols = enrichment.get("compatibleProtocols", {})
    approve_pairs = enrichment.get("approvePairs", {})
    approve_reverse = {v: k for k, v in approve_pairs.items()}
    lifecycle_map = enrichment.get("asyncLifecycleMap", {})
    lifecycles = enrichment.get("asyncLifecycles", {})
    amount_meta_overrides = enrichment.get("amountMeta", {})
    sizeless = set(enrichment.get("sizelessHooks", []))
    leg_sizing = entry.get("legSizing", [])

    # amountMeta
    if hook_name in amount_meta_overrides:
        entry["amountMeta"] = amount_meta_overrides[hook_name]
    else:
        entry["amountMeta"] = [{"direction": "IN", "denomination": "TOKEN"}]

    # sized
    if hook_name in sizeless:
        entry["sized"] = False
    else:
        entry["sized"] = len(leg_sizing) > 0 and any(s == "sized" for s in leg_sizing)

    # erc165
    if hook_name in sizeless or hook_name in ("ClaimAssetsDETHHook", "ClaimWithdrawFirelightVaultHook"):
        entry["erc165"] = ["ISuperHookInflowOutflow"]
    elif len(leg_sizing) > 0:
        entry["erc165"] = ["ISuperHookInflowOutflow", "ISuperHookOutflow"]
    else:
        entry["erc165"] = []

    # V2 loan hooks additionally advertise ISuperHookLoans through ERC-165
    # (legacy deployed loan hook addresses keep their old bytecode and do NOT advertise it)
    if hook_name in set(enrichment.get("loanInterfaceHooks", [])):
        entry["erc165"] = entry["erc165"] + ["ISuperHookLoans"]

    # requiresApproval
    if hook_name.startswith("ApproveAnd"):
        entry["requiresApproval"] = False
    elif hook_name in approve_pairs:
        entry["requiresApproval"] = True
    else:
        entry["requiresApproval"] = False

    # approveVariant
    if hook_name in approve_pairs:
        entry["approveVariant"] = approve_pairs[hook_name]
    elif hook_name in approve_reverse:
        entry["approveVariant"] = approve_reverse[hook_name]
    else:
        entry["approveVariant"] = None

    # asyncLifecycle
    if hook_name in lifecycle_map:
        group_name = lifecycle_map[hook_name]
        entry["asyncLifecycle"] = lifecycles.get(group_name)
    else:
        entry["asyncLifecycle"] = None

    # compatibleProtocols
    entry["compatibleProtocols"] = protocols.get(hook_name, [])

    return entry


def generate_manifest() -> dict:
    """Generate the full hook manifest."""
    classification = load_classification()
    enrichment = load_enrichment()
    hook_sources = find_hook_source_files()
    staging_addresses = load_deployment_addresses("staging")
    prod_addresses = load_deployment_addresses("prod")

    manifest = {
        "$schema": "hook-manifest-v1",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "vocabulary": classification["vocabulary"],
        "hooks": {},
    }

    instances_map = enrichment.get("instances", {}) if enrichment else {}

    for hook_name, class_data in classification["hooks"].items():
        base = {}

        # On-chain fields from source parsing
        if hook_name in hook_sources:
            source_meta = parse_hook_source(hook_sources[hook_name])
            if "name" in source_meta:
                base["name"] = source_meta["name"]
            if "description" in source_meta:
                base["description"] = source_meta["description"]
            if "hookType" in source_meta:
                base["hookType"] = source_meta["hookType"]
            if "subtype" in source_meta:
                base["subtype"] = source_meta["subtype"]

        # Classification fields
        base["actionTypes"] = class_data["actionTypes"]
        base["legSizing"] = class_data["legSizing"]

        # A contract may deploy under several registration keys (one per token + destinationDex,
        # e.g. ApproveAndHyperCoreDepositUsdcPerpHook). The manifest keys by the REGISTRATION KEY
        # so addresses resolve by what was actually deployed and registered; the classification and
        # source entry stay under the contract name (lint completeness keys on those). Contracts
        # without instances keep one entry under the contract name (address lookup key == name).
        instances = instances_map.get(hook_name)
        targets = (
            [(inst["key"], inst["key"], inst) for inst in instances]
            if instances
            else [(hook_name, hook_name, None)]
        )

        for manifest_key, lookup_key, inst in targets:
            entry = dict(base)

            # Deployment addresses per environment, resolved by the registration key
            staging_addrs = staging_addresses.get(lookup_key, {})
            prod_addrs = prod_addresses.get(lookup_key, {})
            entry["addresses"] = {
                "staging": {k: staging_addrs[k] for k in sorted(staging_addrs.keys(), key=int)},
                "prod": {k: prod_addrs[k] for k in sorted(prod_addrs.keys(), key=int)},
            }
            entry["availableChains"] = {
                "staging": sorted(staging_addrs.keys(), key=int),
                "prod": sorted(prod_addrs.keys(), key=int),
            }

            # For an instance entry, record the contract it came from and its resolution tag
            if inst is not None:
                entry["contract"] = hook_name
                if "tag" in inst:
                    entry["tag"] = inst["tag"]

            # Enrichment fields keyed by the contract name (shared across a contract's instances)
            if enrichment:
                entry = enrich_hook(hook_name, entry, enrichment)

            manifest["hooks"][manifest_key] = entry

    return manifest


def main():
    parser = argparse.ArgumentParser(description="Generate hook manifest JSON")
    parser.add_argument(
        "--output",
        default=str(OUTPUT_PATH),
        help=f"Output path (default: {OUTPUT_PATH})",
    )
    args = parser.parse_args()

    manifest = generate_manifest()

    # Count stats
    total = len(manifest["hooks"])
    staging_count = sum(1 for h in manifest["hooks"].values() if h.get("addresses", {}).get("staging"))
    prod_count = sum(1 for h in manifest["hooks"].values() if h.get("addresses", {}).get("prod"))
    with_name = sum(1 for h in manifest["hooks"].values() if h.get("name"))

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    # Enrichment stats
    approve_count = sum(1 for h in manifest["hooks"].values() if h.get("requiresApproval"))
    async_count = sum(1 for h in manifest["hooks"].values() if h.get("asyncLifecycle"))
    sized_count = sum(1 for h in manifest["hooks"].values() if h.get("sized"))
    proto_count = sum(1 for h in manifest["hooks"].values() if h.get("compatibleProtocols"))

    print(f"Generated {output_path}")
    print(f"  Total hooks: {total}")
    print(f"  With staging addresses: {staging_count}")
    print(f"  With prod addresses: {prod_count}")
    print(f"  With name(): {with_name}")
    print(f"  requiresApproval: {approve_count}")
    print(f"  asyncLifecycle: {async_count}")
    print(f"  sized: {sized_count}")
    print(f"  compatibleProtocols: {proto_count}")


if __name__ == "__main__":
    main()
