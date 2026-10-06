// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";

import { AaveV4SupplyHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4BorrowHook } from "../../../../src/hooks/loan/aave-v4/AaveV4BorrowHook.sol";
import { AaveV4RepayHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHook.sol";
import { AaveV4SupplyAndBorrowHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol";
import { AaveV4RepayAndWithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";
import { AaveV4LendHook } from "../../../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { AaveV4SupplyHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyHookV2.sol";
import { AaveV4BorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4BorrowHookV2.sol";
import { AaveV4WithdrawHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4WithdrawHookV2.sol";
import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveRegistry } from "../../../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4ReserveOracle } from "../../../../src/accounting/oracles/AaveV4ReserveOracle.sol";

/// @title AaveV4LoanBytecodeUnchangedTest
/// @notice Every Aave V4 hook's creation code is pinned to its locked artifact. With `bytecode_hash = "none"`
///         the creation code is a deterministic function of the sources, so equality is an exact proof.
///         SUP-21143 (header = reserve key) deliberately re-pinned the 12 LOAN hooks (V1 six, composite V2
///         trio, standalone V2 trio) to new artifacts — new deterministic addresses; the previously deployed
///         Ethereum addresses stay live for old roots. Its final review then consolidated the reserve-key hash
///         and `RESERVE_KEY_MISMATCH` into `AaveV4ReserveKey`, which the idle MONEY_MARKET pair (SUP-21142, not
///         yet deployed) and `AaveV4ReserveRegistryV2` now share — so the idle pair is re-pinned as well.
///         SUP-21239 (header = MARKET key) then re-pinned exactly SEVEN artifacts: the six V2 LOAN hooks
///         (composite trio + standalone trio) and `AaveV4ReserveRegistryV2`, which gained the market
///         namespace.
///         SUP-21254 then moved the idle MONEY_MARKET pair onto the market key too — its layout grew
///         157 -> 189 bytes (`borrowReserveId` appended, every prior offset unchanged) and its header became
///         both a market key and a SuperLedger key — and SUP-21255 / SUP-21256 moved `AaveV4ReserveOracle`
///         (market-key resolution, `getMarketPosition`, market-keyed `getOwnerSnapshot`). So TEN artifacts
///         have moved in total across the three tickets: registry V2, the six V2 LOAN hooks, the idle pair
///         and the oracle.
///         Deliberately UNMOVED, and asserted below: the V1 LOAN six (legacy, still on the reserve-key rule
///         via `AaveV4ReserveKey.requireHeaderKey`) and the V1 registry. Adding `computeMarketKey` to
///         `AaveV4ReserveKey` moved neither: being `internal` and unreferenced by them it is
///         dead-code-eliminated, which `test_LoanV1_BytecodePinned` proves empirically.
///         SUP-21263 then re-pinned the idle pair AGAIN: its layout shrank 189 -> 157 bytes (the appended
///         `borrowReserveId` deleted, offset 92 reinterpreted as `targetReserveId`, which may be EITHER leg
///         of the header market) and it gained ONE constructor argument — the registry it resolves market
///         keys through, the first constructor dependency in this hook family. The six V2 LOAN hooks keep
///         their 241-byte layout and take no registry, which `test_LoanV2_BytecodePinned` /
///         `test_LoanV2Standalone_BytecodePinned` prove by staying green untouched.
///         The previously deployed addresses stay live for roots signed under the old rules. FAIL-CLOSED IN
///         ALL FOUR DIRECTIONS — and note that after SUP-21263 the idle length 157 is AGAIN the length the
///         pre-SUP-21254 revision used, so length alone no longer separates them; the HEADER does:
///           - stale 157-byte reserve-keyed body -> new hook: `MARKET_NOT_REGISTERED` (a reserve key can
///             never be registered as a market — the registry's own `KEY_NAMESPACE_COLLISION` guard — so
///             this cannot fail open);
///           - new 157-byte market-keyed body -> pre-SUP-21254 hook: `RESERVE_KEY_MISMATCH`;
///           - new 157-byte body -> SUP-21254 189-byte hook: `INVALID_DATA_LENGTH`;
///           - stale 189-byte body -> new hook: `INVALID_DATA_LENGTH`.
///         For the LOAN hooks a stale key still reverts `MARKET_KEY_MISMATCH`.
contract AaveV4LoanBytecodeUnchangedTest is Helpers {
    function _locked(string memory name) internal returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/locked-bytecode/", name, ".json"))));
    }

    function _generated(string memory name) internal returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/generated-bytecode/", name, ".json"))));
    }

    /// @dev What an env 1 (vnet) / env 2 (staging) deploy consumes, per `DeployV2Base.__getBytecodeArtifactPath`.
    ///      Only contracts deployed through `DeployV2Core` are read from here — `DeployV2OtherHooks`
    ///      hardcodes `locked-bytecode/` for every env, so the LOAN hooks' dev artifacts are never consulted.
    function _lockedDev(string memory name) internal returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/locked-bytecode-dev/", name, ".json"))));
    }

    /// @dev V2 is a NEW contract under a new deploy name, not an edit to the deployed V1 — the struct gained
    ///      `side` and `getReserveInfo` went 4->5 returns, which moves the creation code and therefore the
    ///      CREATE2 address. Pinned against BOTH artifacts: `_generated` is what a vnet/dev deploy consumes
    ///      and `_locked` is what a prod deploy consumes, and a mismatch between them is exactly how a prod
    ///      run would deploy different code than was reviewed.
    function test_ReserveRegistryV2_BytecodePinned() public {
        bytes32 fresh = keccak256(type(AaveV4ReserveRegistryV2).creationCode);
        assertEq(fresh, _generated("AaveV4ReserveRegistryV2"), "V2 generated artifact matches source");
        assertEq(fresh, _locked("AaveV4ReserveRegistryV2"), "V2 locked artifact matches source");
        // The registry is the one moved artifact deployed via `DeployV2Core`, so its env 1/2 copy is live
        // code, not a dead file. Without this a re-pin could update prod + generated, leave dev stale, keep
        // this suite green, and have a staging run deploy the OLD registry at a different CREATE2 address —
        // which silently moves `AaveV4ReserveOracle` too, since the registry is its constructor argument.
        assertEq(fresh, _lockedDev("AaveV4ReserveRegistryV2"), "V2 locked-dev artifact matches source");
    }

    /// @notice The merged oracle is under the same locked-bytecode release model as everything else here, so
    ///         its artifacts must track its source too. Without this, an edit to `AaveV4ReserveOracle` would
    ///         silently desync source from the locked artifact a prod deploy actually uses.
    function test_ReserveOracle_BytecodePinned() public {
        bytes32 fresh = keccak256(type(AaveV4ReserveOracle).creationCode);
        assertEq(fresh, _generated("AaveV4ReserveOracle"), "oracle generated artifact matches source");
        assertEq(fresh, _locked("AaveV4ReserveOracle"), "oracle locked artifact matches source");
        // the oracle IS deployed through `DeployV2Core`, so its env 1/2 copy is live code
        assertEq(fresh, _lockedDev("AaveV4ReserveOracle"), "oracle locked-dev artifact matches source");
    }

    /// @notice V1 is kept in-repo unmodified so the deployed, seeded registry stays reproducible. This fails
    ///         if anyone edits it.
    /// @dev Pinned against the GENERATED artifact, not the locked one, because they DIVERGE on `dev` and
    ///      always have: generated matches this source, `locked-bytecode/AaveV4ReserveRegistry.json` does
    ///      not. That divergence pre-dates this change (it is why the original version of this test also
    ///      used `_generated`), but it is worth naming: `locked-bytecode/` is what an env-0 PROD deploy
    ///      consumes, so for V1 the artifact prod would deploy is not the artifact this repo's source
    ///      produces. V2 is held to the stricter standard — `test_ReserveRegistryV2_BytecodePinned` asserts
    ///      source == generated == locked — so the new contract cannot inherit the same drift.
    function test_ReserveRegistryV1_StillMatchesItsGeneratedArtifact() public {
        assertEq(
            keccak256(type(AaveV4ReserveRegistry).creationCode),
            _generated("AaveV4ReserveRegistry"),
            "V1 source must still reproduce its generated artifact"
        );
    }

    function test_LoanV1_BytecodePinned() public {
        assertEq(keccak256(type(AaveV4SupplyHook).creationCode), _locked("AaveV4SupplyHook"));
        assertEq(keccak256(type(AaveV4WithdrawHook).creationCode), _locked("AaveV4WithdrawHook"));
        assertEq(keccak256(type(AaveV4BorrowHook).creationCode), _locked("AaveV4BorrowHook"));
        assertEq(keccak256(type(AaveV4RepayHook).creationCode), _locked("AaveV4RepayHook"));
        assertEq(keccak256(type(AaveV4SupplyAndBorrowHook).creationCode), _locked("AaveV4SupplyAndBorrowHook"));
        assertEq(keccak256(type(AaveV4RepayAndWithdrawHook).creationCode), _locked("AaveV4RepayAndWithdrawHook"));
    }

    function test_LoanV2_BytecodePinned() public {
        assertEq(keccak256(type(AaveV4SupplyAndBorrowHookV2).creationCode), _locked("AaveV4SupplyAndBorrowHookV2"));
        assertEq(keccak256(type(AaveV4RepayHookV2).creationCode), _locked("AaveV4RepayHookV2"));
        assertEq(keccak256(type(AaveV4RepayAndWithdrawHookV2).creationCode), _locked("AaveV4RepayAndWithdrawHookV2"));
    }

    /// @dev All three directories, not just `locked-bytecode/`: SUP-21254 and then SUP-21263 moved this
    ///      pair, and a re-pin that
    ///      updated prod but forgot `generated` or `locked-bytecode-dev` would leave this suite green while a
    ///      vnet/staging run deployed different code. (The idle pair deploys via `DeployV2OtherHooks`, which
    ///      hardcodes `locked-bytecode/` for every env — so the dev copy is belt-and-braces for this family,
    ///      and load-bearing only for contracts `DeployV2Core` deploys.)
    function test_IdleHooks_BytecodePinned() public {
        bytes32 lend = keccak256(type(AaveV4LendHook).creationCode);
        bytes32 redeem = keccak256(type(AaveV4RedeemHook).creationCode);
        assertEq(lend, _locked("AaveV4LendHook"), "lend locked");
        assertEq(lend, _generated("AaveV4LendHook"), "lend generated");
        assertEq(lend, _lockedDev("AaveV4LendHook"), "lend locked-dev");
        assertEq(redeem, _locked("AaveV4RedeemHook"), "redeem locked");
        assertEq(redeem, _generated("AaveV4RedeemHook"), "redeem generated");
        assertEq(redeem, _lockedDev("AaveV4RedeemHook"), "redeem locked-dev");
    }

    /// @dev SUP-21143 guard: LOAN hooks do not validate `yieldSourceOracleId` because the executor never reads the
    ///      header for NONACCOUNTING hooks. Re-typing any of the 12 to INFLOW / OUTFLOW would make the signed oracle
    ///      id select the ledger + oracle and MUST come with the idle base's `ORACLE_ID_NOT_VALID` check — this test
    ///      makes such a re-type a visible change. The idle pair is INFLOW / OUTFLOW by design.
    function test_HookTypes_LoanNonAccounting_IdleAccounting() public {
        address[12] memory loan = [
            address(new AaveV4SupplyHook()),
            address(new AaveV4WithdrawHook()),
            address(new AaveV4BorrowHook()),
            address(new AaveV4RepayHook()),
            address(new AaveV4SupplyAndBorrowHook()),
            address(new AaveV4RepayAndWithdrawHook()),
            address(new AaveV4SupplyAndBorrowHookV2()),
            address(new AaveV4RepayHookV2()),
            address(new AaveV4RepayAndWithdrawHookV2()),
            address(new AaveV4SupplyHookV2()),
            address(new AaveV4BorrowHookV2()),
            address(new AaveV4WithdrawHookV2())
        ];
        for (uint256 i; i < loan.length; ++i) {
            assertEq(uint256(BaseHook(loan[i]).hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        }
        // SUP-21263: a nonzero registry is all the constructor requires; this test only reads hookType.
        assertEq(uint256(new AaveV4LendHook(address(0xA4E4)).hookType()), uint256(ISuperHook.HookType.INFLOW));
        assertEq(uint256(new AaveV4RedeemHook(address(0xA4E4)).hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_LoanV2Standalone_BytecodePinned() public {
        assertEq(keccak256(type(AaveV4SupplyHookV2).creationCode), _locked("AaveV4SupplyHookV2"));
        assertEq(keccak256(type(AaveV4BorrowHookV2).creationCode), _locked("AaveV4BorrowHookV2"));
        assertEq(keccak256(type(AaveV4WithdrawHookV2).creationCode), _locked("AaveV4WithdrawHookV2"));
    }
}
