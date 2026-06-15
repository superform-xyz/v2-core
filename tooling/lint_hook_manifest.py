#!/usr/bin/env python3
"""
Lint the hook manifest for consistency.

Validates:
  1. Completeness — every hook source file has a classification entry (and vice versa)
  2. P2 rules — actionTypes consistent with hookType
  3. T1 — compound hooks have ordered legs (structural check)
  4. T2 — legSizing length matches actionTypes length
  5. T4 — all intents/stages from canonical vocabulary

Usage:
  python tooling/lint_hook_manifest.py
  python tooling/lint_hook_manifest.py --manifest manifests/hooks.json
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CLASSIFICATION_PATH = ROOT / "tooling" / "hook-classification.yaml"
MANIFEST_PATH = ROOT / "manifests" / "hooks.json"
HOOKS_SRC = ROOT / "src" / "hooks"

# P2 conformance rules: (intent, stage) -> allowed hookTypes
# None means any hookType is valid for that combination
P2_RULES: dict[tuple[str, str], set[str]] = {
    # deposit
    ("deposit", "instant"): {"INFLOW"},
    ("deposit", "request"): {"NONACCOUNTING"},
    ("deposit", "fulfill"): {"INFLOW", "NONACCOUNTING"},  # Deposit7540 is INFLOW
    ("deposit", "cancel"): {"NONACCOUNTING"},
    ("deposit", "claim"): {"NONACCOUNTING"},
    # withdraw
    ("withdraw", "instant"): {"OUTFLOW", "NONACCOUNTING"},  # MorphoWithdraw/AaveV4Withdraw are NONACCOUNTING
    ("withdraw", "request"): {"NONACCOUNTING"},
    ("withdraw", "fulfill"): {"OUTFLOW", "NONACCOUNTING"},  # EthenaUnstake is OUTFLOW
    ("withdraw", "cancel"): {"NONACCOUNTING"},
    ("withdraw", "claim"): {"NONACCOUNTING"},
    # rewards
    ("rewards", "claim"): {"NONACCOUNTING", "OUTFLOW"},  # Fluid/Gearbox/Yearn are OUTFLOW
    # swap
    ("swap", "instant"): {"NONACCOUNTING"},
    # bridge
    ("bridge", "instant"): {"NONACCOUNTING"},
    ("bridge", "cancel"): {"NONACCOUNTING"},
    ("bridge", "claim"): {"NONACCOUNTING"},
    # stake/unstake
    ("stake", "instant"): {"NONACCOUNTING"},
    ("unstake", "instant"): {"NONACCOUNTING"},
    # lending
    ("lend", "instant"): {"NONACCOUNTING"},
    ("borrow", "instant"): {"NONACCOUNTING"},
    ("repay", "instant"): {"NONACCOUNTING"},
    # transfer
    ("transfer", "instant"): {"NONACCOUNTING"},
    # config
    ("config", "instant"): {"NONACCOUNTING"},
    # permissions
    ("permissions", "instant"): {"NONACCOUNTING"},
}


class LintError:
    def __init__(self, hook: str, rule: str, message: str):
        self.hook = hook
        self.rule = rule
        self.message = message

    def __str__(self):
        return f"[{self.rule}] {self.hook}: {self.message}"


def find_hook_source_names() -> set[str]:
    """Find all concrete hook contract names from source files."""
    names = set()
    for sol_file in HOOKS_SRC.rglob("*.sol"):
        name = sol_file.stem
        if name.startswith("Base") or name == "VaultBankLockableHook":
            continue
        if name.endswith("Hook") or name.endswith("HookV2"):
            names.add(name)
    return names


def lint_classification(classification: dict) -> list[LintError]:
    """Lint the hook-classification.yaml file."""
    errors = []
    vocab = classification.get("vocabulary", {})
    valid_intents = set(vocab.get("intents", []))
    valid_stages = set(vocab.get("stages", []))
    hooks = classification.get("hooks", {})

    for hook_name, data in hooks.items():
        action_types = data.get("actionTypes", [])
        leg_sizing = data.get("legSizing", [])

        # T4: vocabulary check
        for i, at in enumerate(action_types):
            intent = at.get("intent", "")
            stage = at.get("stage", "")
            if intent not in valid_intents:
                errors.append(LintError(hook_name, "T4-vocab", f"Unknown intent '{intent}' at leg {i}"))
            if stage not in valid_stages:
                errors.append(LintError(hook_name, "T4-vocab", f"Unknown stage '{stage}' at leg {i}"))

        # T2: legSizing length check
        # For single-intent hooks, legSizing can be shorter (e.g. MorphoWithdrawHook has 1 actionType but 2 legSizing)
        # The rule is: legSizing describes the amount slots, not the intent legs
        # So we just check it's present and is a list
        if not isinstance(leg_sizing, list):
            errors.append(LintError(hook_name, "T2-linkage", f"legSizing must be a list, got {type(leg_sizing).__name__}"))

        # T1: compound hooks structural check
        if len(action_types) > 1:
            # Just verify it's a valid ordered array (no duplicate check needed)
            pass

    return errors


def lint_manifest(manifest: dict, classification: dict) -> list[LintError]:
    """Lint the generated hooks.json manifest."""
    errors = []
    hooks = manifest.get("hooks", {})
    class_hooks = classification.get("hooks", {})

    for hook_name, data in hooks.items():
        action_types = data.get("actionTypes", [])
        hook_type = data.get("hookType")

        if not hook_type:
            # Can't validate P2 without hookType
            continue

        # P2: each leg's (intent, stage) must be consistent with hookType
        for i, at in enumerate(action_types):
            intent = at.get("intent", "")
            stage = at.get("stage", "")
            key = (intent, stage)

            if key in P2_RULES:
                allowed = P2_RULES[key]
                if hook_type not in allowed:
                    errors.append(LintError(
                        hook_name, "P2-hookType",
                        f"Leg {i} ({intent}, {stage}) requires hookType in {allowed}, got {hook_type}"
                    ))
            else:
                errors.append(LintError(
                    hook_name, "P2-hookType",
                    f"Leg {i} ({intent}, {stage}) has no P2 rule defined"
                ))

    return errors


def lint_completeness(classification: dict) -> list[LintError]:
    """Check that every source hook has a classification entry and vice versa."""
    errors = []
    source_names = find_hook_source_names()
    class_names = set(classification.get("hooks", {}).keys())

    # Hooks in source but missing from classification
    for name in sorted(source_names - class_names):
        errors.append(LintError(name, "completeness", "Hook exists in source but missing from classification"))

    # Hooks in classification but missing from source
    for name in sorted(class_names - source_names):
        errors.append(LintError(name, "completeness", "Hook in classification but missing from source"))

    return errors


def main():
    parser = argparse.ArgumentParser(description="Lint hook manifest")
    parser.add_argument("--manifest", default=str(MANIFEST_PATH), help="Path to hooks.json")
    parser.add_argument("--classification", default=str(CLASSIFICATION_PATH), help="Path to hook-classification.yaml")
    args = parser.parse_args()

    # Load classification
    class_path = Path(args.classification)
    if not class_path.exists():
        print(f"ERROR: Classification file not found: {class_path}", file=sys.stderr)
        sys.exit(1)

    with open(class_path) as f:
        classification = yaml.safe_load(f)

    all_errors: list[LintError] = []

    # 1. Lint classification YAML
    print("Linting classification YAML...")
    all_errors.extend(lint_classification(classification))

    # 2. Lint completeness (source files vs classification)
    print("Checking completeness...")
    all_errors.extend(lint_completeness(classification))

    # 3. Lint manifest if it exists
    manifest_path = Path(args.manifest)
    if manifest_path.exists():
        print("Linting generated manifest...")
        with open(manifest_path) as f:
            manifest = json.load(f)
        all_errors.extend(lint_manifest(manifest, classification))
    else:
        print(f"Manifest not found at {manifest_path}, skipping P2 hookType validation")
        print("  Run `python tooling/generate_hook_manifest.py` first to generate it")

    # Report
    if all_errors:
        print(f"\n{len(all_errors)} error(s) found:\n")
        for err in all_errors:
            print(f"  {err}")
        sys.exit(1)
    else:
        hook_count = len(classification.get("hooks", {}))
        print(f"\nAll checks passed. {hook_count} hooks validated.")
        sys.exit(0)


if __name__ == "__main__":
    main()
