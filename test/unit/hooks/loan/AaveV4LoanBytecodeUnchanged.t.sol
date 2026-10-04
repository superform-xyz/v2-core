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
///         namespace. Deliberately UNMOVED, and asserted below: the V1 LOAN six (legacy, still on the
///         reserve-key rule), the idle MONEY_MARKET pair (no borrow reserve in its 157-byte layout, and its
///         header is a SuperLedger key), V1 registry, and `AaveV4ReserveOracle` — its source is untouched,
///         because market keys are deliberately never oracle-resolvable. Adding `computeMarketKey` to
///         `AaveV4ReserveKey` moved none of the unmoved eight: being `internal` and unreferenced there it is
///         dead-code-eliminated, which `test_LoanV1_BytecodePinned` / `test_IdleHooks_BytecodePinned` prove
///         empirically. The previously deployed V2 hook addresses stay live for roots signed under the old
///         rule; a NEW address paired with an old reserve-keyed header reverts `MARKET_KEY_MISMATCH`
///         (fail-closed, the inverse of a silently-accepted stale header).
contract AaveV4LoanBytecodeUnchangedTest is Helpers {
    function _locked(string memory name) internal returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/locked-bytecode/", name, ".json"))));
    }

    function _generated(string memory name) internal returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/generated-bytecode/", name, ".json"))));
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
    }

    /// @notice The merged oracle is under the same locked-bytecode release model as everything else here, so
    ///         its artifacts must track its source too. Without this, an edit to `AaveV4ReserveOracle` would
    ///         silently desync source from the locked artifact a prod deploy actually uses.
    function test_ReserveOracle_BytecodePinned() public {
        bytes32 fresh = keccak256(type(AaveV4ReserveOracle).creationCode);
        assertEq(fresh, _generated("AaveV4ReserveOracle"), "oracle generated artifact matches source");
        assertEq(fresh, _locked("AaveV4ReserveOracle"), "oracle locked artifact matches source");
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

    function test_IdleHooks_BytecodePinned() public {
        assertEq(keccak256(type(AaveV4LendHook).creationCode), _locked("AaveV4LendHook"));
        assertEq(keccak256(type(AaveV4RedeemHook).creationCode), _locked("AaveV4RedeemHook"));
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
        assertEq(uint256(new AaveV4LendHook().hookType()), uint256(ISuperHook.HookType.INFLOW));
        assertEq(uint256(new AaveV4RedeemHook().hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_LoanV2Standalone_BytecodePinned() public {
        assertEq(keccak256(type(AaveV4SupplyHookV2).creationCode), _locked("AaveV4SupplyHookV2"));
        assertEq(keccak256(type(AaveV4BorrowHookV2).creationCode), _locked("AaveV4BorrowHookV2"));
        assertEq(keccak256(type(AaveV4WithdrawHookV2).creationCode), _locked("AaveV4WithdrawHookV2"));
    }
}
