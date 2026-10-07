// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Test } from "forge-std/Test.sol";

// Superform
import { SuperValidator } from "../../../src/validators/SuperValidator.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { SuperValidatorV2 } from "../../../src/validators/SuperValidatorV2.sol";

/// @title ValidatorBytecodeUnchangedTest
/// @author Superform Labs
/// @notice Pins `SuperValidator` and `SuperDestinationValidator` creation code to their locked artifacts.
/// @dev Why this exists: both validators inherit `SuperValidatorBase`, so ANY edit to the base — or to any
///      library it imports — silently re-pins BOTH. With `bytecode_hash = "none"` (foundry.toml) the creation
///      code is a deterministic function of the sources, so equality here is an exact proof and inequality is
///      an exact proof of movement. Because the CREATE2 salt is derived only from the deploy name
///      (`keccak256("SuperformV2" || namespace || name || "v2.0")`) and NOT from the bytecode, moved code does
///      not get a new address automatically: a redeploy under the same name is impossible at the old address,
///      every chain needs a fresh deployment under a NEW name, and every account that installed the old
///      module must install the new one. That operational cost is the thing this test makes visible at review
///      time instead of at deploy time.
///
///      All three artifact copies are asserted, because they are consumed by different deploy environments
///      (`DeployV2Base.__getBytecodeArtifactPath`): `generated-bytecode/` and `locked-bytecode-dev/` for
///      vnet/staging, `locked-bytecode/` for prod. A re-pin that updates only some of them keeps a
///      single-artifact test green while making a staging run deploy different code than prod — which for a
///      validator means a different signature-acceptance rule on different chains.
contract ValidatorBytecodeUnchangedTest is Test {
    /// @dev The canonical deterministic-deployment proxy, which every Superform deploy goes through.
    address internal constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /// @dev `ConfigBase.PRODUCTION_SALT_NAMESPACE` / `STAGING_SALT_NAMESPACE`.
    string internal constant PROD_NAMESPACE = "PROD1.0.0";
    string internal constant STAGING_NAMESPACE = "STAGING1.0.0";

    function _locked(string memory name) internal view returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/locked-bytecode/", name, ".json"))));
    }

    function _lockedDev(string memory name) internal view returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/locked-bytecode-dev/", name, ".json"))));
    }

    function _generated(string memory name) internal view returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/generated-bytecode/", name, ".json"))));
    }

    function _assertPinned(bytes32 fresh, string memory name) internal view {
        assertEq(fresh, _locked(name), string(abi.encodePacked(name, ": locked artifact matches source")));
        assertEq(fresh, _lockedDev(name), string(abi.encodePacked(name, ": locked-dev artifact matches source")));
        assertEq(fresh, _generated(name), string(abi.encodePacked(name, ": generated artifact matches source")));
    }

    /// @dev `SuperValidator` is the source-chain ERC-4337 validator, deployed on every supported network
    ///      (prod Base `0xB46b4773C5F53FF941533F5dfEFFD0713f5f9f8E`).
    function test_SuperValidator_BytecodePinned() public {
        _assertPinned(keccak256(type(SuperValidator).creationCode), "SuperValidator");
    }

    /// @dev `SuperDestinationValidator` is the cross-chain counterpart (prod Base
    ///      `0xADEFF5A0684392C4c273a9C638d1dB8c5dfd0098`). It shares `SuperValidatorBase` with
    ///      `SuperValidator`, which is precisely why it must be pinned separately: a base-only change shows up
    ///      in both, and a reviewer reading a diff that touches no file named `SuperDestinationValidator` has
    ///      no other signal that it moved.
    function test_SuperDestinationValidator_BytecodePinned() public {
        _assertPinned(keccak256(type(SuperDestinationValidator).creationCode), "SuperDestinationValidator");
    }

    /// @dev `SuperValidatorV2` (SUP-17924) is NOT yet deployed anywhere; it is pinned from its first commit so
    ///      that the artifact the deploy scripts consume is provably the reviewed source, and so that any
    ///      later edit to it — or to `SuperValidatorBase`, or to
    ///      `ChainAgnosticCoinbaseSmartWalletValidation` — shows up here before a deploy rather than after.
    /// @dev Its presence is also what proves the separation works: V2 inherits the same base as the two tests
    ///      above, and all three pass, so adding V2 moved neither deployed validator. The lever is the deploy
    ///      NAME: the CREATE2 salt is `keccak256("SuperformV2" || namespace || name || "v2.0")`, so
    ///      "SuperValidatorV2" lands at a fresh address while "SuperValidator" keeps its own.
    function test_SuperValidatorV2_BytecodePinned() public {
        _assertPinned(keccak256(type(SuperValidatorV2).creationCode), "SuperValidatorV2");
    }

    /*//////////////////////////////////////////////////////////////
                      THE DEPLOY NAME IS THE LEVER
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the deploy wiring does what it claims, arithmetically rather than by assertion in a
    ///         comment: `SuperValidator` still lands on its LIVE production address, and `SuperValidatorV2`
    ///         lands somewhere else.
    /// @dev The first half is the strong check. `0xB46b4773…9f8E` is the deployed production `SuperValidator`
    ///         on Base (and every other chain — the address is chain-independent). Reproducing it from
    ///         `type(SuperValidator).creationCode` and the salt rule proves three things at once that are
    ///         otherwise only asserted in prose: the salt formula in `DeployV2Base.__getSalt` is what was
    ///         actually used, the locked artifact matches today's source, and adding V2 plus the `virtual` on
    ///         the base did not move V1 by a single byte. If any of those were false this equality would
    ///         fail.
    function test_DeployName_SeparatesV2WithoutMovingV1() public pure {
        address liveProdSuperValidator = 0xB46b4773C5F53FF941533F5dfEFFD0713f5f9f8E;
        address liveProdDestinationValidator = 0xADEFF5A0684392C4c273a9C638d1dB8c5dfd0098;

        assertEq(
            _create2(_salt(PROD_NAMESPACE, "SuperValidator"), type(SuperValidator).creationCode),
            liveProdSuperValidator,
            "SuperValidator no longer deploys to its live address"
        );
        assertEq(
            _create2(_salt(PROD_NAMESPACE, "SuperDestinationValidator"), type(SuperDestinationValidator).creationCode),
            liveProdDestinationValidator,
            "SuperDestinationValidator no longer deploys to its live address"
        );

        address v2Prod = _create2(_salt(PROD_NAMESPACE, "SuperValidatorV2"), type(SuperValidatorV2).creationCode);
        assertTrue(v2Prod != liveProdSuperValidator, "V2 must not collide with V1");
        assertTrue(v2Prod != liveProdDestinationValidator, "V2 must not collide with the destination validator");
        assertTrue(v2Prod != address(0));

        // Staging uses a different namespace, so the same name is a different address there.
        assertTrue(
            _create2(_salt(STAGING_NAMESPACE, "SuperValidatorV2"), type(SuperValidatorV2).creationCode) != v2Prod,
            "staging and prod must not share an address"
        );
    }

    /// @dev `keccak256("SuperformV2" || namespace || name || "v2.0")`, mirroring `DeployV2Base.__getSalt`.
    function _salt(string memory namespace, string memory name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("SuperformV2", namespace, name, "v2.0"));
    }

    function _create2(bytes32 salt, bytes memory creationCode) internal pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), DETERMINISTIC_DEPLOYER, salt, keccak256(creationCode)))
                )
            )
        );
    }

    /// @dev The three validators must not share creation code. If V2 ever compiled to the same bytes as V1 it
    ///      would mean the override was silently dropped (an `internal virtual` that nothing overrides is
    ///      dead-code-eliminated), and every passkey test would still pass against V1's logic.
    function test_Validators_HaveDistinctCreationCode() public pure {
        bytes32 a = keccak256(type(SuperValidator).creationCode);
        bytes32 b = keccak256(type(SuperDestinationValidator).creationCode);
        bytes32 c = keccak256(type(SuperValidatorV2).creationCode);
        assertTrue(a != b && b != c && a != c, "validators must not share creation code");
    }
}
