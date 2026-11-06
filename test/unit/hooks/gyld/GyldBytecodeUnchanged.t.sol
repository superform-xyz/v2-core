// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

/// @title GyldBytecodeUnchangedTest
/// @notice Pins the shipping bytecode artifacts to the current source.
/// @dev WHY THIS MATTERS MORE THAN IT LOOKS. The deploy path builds from `script/locked-bytecode/`, while
///      every behavioural Gyld suite builds from source with `new X(...)`. So a fix landing in `src/`
///      leaves every other test green AND silently desynchronises the shipping artifact from the audited
///      source: the contracts that would actually be deployed are the OLD ones. Several high-severity
///      findings against these five contracts are open, so a fix landing without a re-lock is a live
///      scenario rather than a hypothetical.
/// @dev Same purpose as `AaveV4LoanBytecodeUnchanged.t.sol` and `ValidatorBytecodeUnchanged.t.sol`.
///      `foundry.toml` sets `bytecode_hash = "none"`, so creation code is a deterministic function of the
///      source and this comparison is stable across machines.
/// @dev Requires a current `forge build`, since it reads the fresh artifact from `out/`.
contract GyldBytecodeUnchangedTest is Test {
    /// @dev Keyed by contract NAME, which is also the artifact filename. The trade hook ships under two
    ///      deploy keys from this one artifact, so five names cover six deploy entries.
    /// @dev `GyldTradePolicy` was MISSING from this list when it was introduced, which meant this suite
    ///      passed 4/4 while never looking at the one contract every trade now depends on. It is pinned in
    ///      both trade hooks' immutables and carries several open review findings, so a fix landing there
    ///      without a re-lock is exactly the scenario this file exists to prevent.
    function _names() internal pure returns (string[5] memory) {
        return [
            "GyldBondRegistry",
            "GyldBondYieldSourceOracle",
            "GyldTradePolicy",
            "GyldTradeGuardHook",
            "ApproveAndTradeGyldBondHook"
        ];
    }

    /// @dev The FRESH compile of the current source. Deliberately read from `out/` rather than via
    ///      `type(X).creationCode`: that expression makes forge inject a global `vm.getCode` rewrite which
    ///      breaks an unrelated pre-existing `pure` helper in `test/script/`. Reading the artifact gives the
    ///      same guarantee with no side effect on other files.
    function _freshCode(string memory name) internal view returns (bytes memory) {
        return vm.getCode(string.concat("out/", name, ".sol/", name, ".json"));
    }

    /// @dev The deploy path reads this directory for EVERY environment, so this is the one that ships.
    function test_LockedBytecodeMatchesSource() public {
        string[5] memory names = _names();
        for (uint256 i; i < names.length; ++i) {
            bytes memory locked = vm.getCode(string.concat("script/locked-bytecode/", names[i], ".json"));
            assertEq(
                keccak256(locked),
                keccak256(_freshCode(names[i])),
                string.concat("locked-bytecode is STALE for ", names[i], ": re-run regenerate_bytecode.sh")
            );
        }
    }

    function test_DevLockedBytecodeMatchesSource() public {
        string[5] memory names = _names();
        for (uint256 i; i < names.length; ++i) {
            bytes memory dev = vm.getCode(string.concat("script/locked-bytecode-dev/", names[i], ".json"));
            assertEq(
                keccak256(dev),
                keccak256(_freshCode(names[i])),
                string.concat("locked-bytecode-dev is STALE for ", names[i])
            );
        }
    }

    function test_GeneratedBytecodeMatchesSource() public {
        string[5] memory names = _names();
        for (uint256 i; i < names.length; ++i) {
            bytes memory generated = vm.getCode(string.concat("script/generated-bytecode/", names[i], ".json"));
            assertEq(
                keccak256(generated),
                keccak256(_freshCode(names[i])),
                string.concat("generated-bytecode is STALE for ", names[i])
            );
        }
    }

    /// @dev All three directories must agree with each other too, so a partial copy is caught even if every
    ///      individual comparison above were somehow satisfied.
    function test_AllThreeArtifactDirectoriesAgree() public {
        string[5] memory names = _names();
        for (uint256 i; i < names.length; ++i) {
            bytes32 prod = keccak256(vm.getCode(string.concat("script/locked-bytecode/", names[i], ".json")));
            bytes32 dev = keccak256(vm.getCode(string.concat("script/locked-bytecode-dev/", names[i], ".json")));
            bytes32 gen = keccak256(vm.getCode(string.concat("script/generated-bytecode/", names[i], ".json")));
            assertEq(prod, dev, string.concat("prod and dev artifacts differ for ", names[i]));
            assertEq(prod, gen, string.concat("prod and generated artifacts differ for ", names[i]));
        }
    }
}
