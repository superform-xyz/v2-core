// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../../utils/Helpers.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { IFirelightVault } from "../../../../../src/vendor/vaults/firelight/IFirelightVault.sol";

// Hooks
import { RedeemFirelightVaultHook } from
    "../../../../../src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol";
import { ClaimWithdrawFirelightVaultHook } from
    "../../../../../src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol";

/// @dev Minimal mock of the Firelight vault for testing the claim hook
contract MockFirelightVault {
    address public asset;
    uint256 public lastRequestId;

    constructor(address asset_) {
        asset = asset_;
    }

    function redeem(uint256, address, address) external pure returns (uint256) {
        return 0;
    }

    function claimWithdraw(uint256 requestId) external {
        lastRequestId = requestId;
        // Simulate transferring FXRP to caller by minting via deal (handled externally in tests)
    }
}

contract FirelightHooksTests is Helpers {
    RedeemFirelightVaultHook redeemHook;
    ClaimWithdrawFirelightVaultHook claimHook;

    MockERC20 stXRP;
    MockERC20 fxrp;
    MockFirelightVault vault;
    bytes32 yieldSourceOracleId;
    uint256 amount;
    uint256 prevHookAmount;

    function setUp() public {
        redeemHook = new RedeemFirelightVaultHook();
        claimHook = new ClaimWithdrawFirelightVaultHook();

        stXRP = new MockERC20("Staked XRP", "stXRP", 18);
        fxrp = new MockERC20("FXRP", "FXRP", 18);
        vault = new MockFirelightVault(address(fxrp));
        yieldSourceOracleId = bytes32(keccak256("YIELD_SOURCE_ORACLE_ID"));
        amount = 1000e18;
        prevHookAmount = 2000e18;
    }

    /*//////////////////////////////////////////////////////////////
                      CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_Constructor() public view {
        assertEq(uint256(redeemHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(redeemHook.SUB_TYPE(), HookSubTypes.ERC4626);
    }

    function test_ClaimWithdrawFirelightVaultHook_Constructor() public view {
        assertEq(uint256(claimHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
        assertEq(claimHook.SUB_TYPE(), HookSubTypes.ERC4626);
    }

    /*//////////////////////////////////////////////////////////////
                            BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_build() public view {
        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        Execution[] memory executions = redeemHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(stXRP));
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IFirelightVault.redeem, (amount, address(this), address(this)))
        );
    }

    function test_ClaimWithdrawFirelightVaultHook_build() public view {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(vault), requestId, false);
        Execution[] memory executions = claimHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(vault));
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IFirelightVault.claimWithdraw, (requestId)));
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD REVERT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_BuildRevert_ZeroShares() public {
        bytes memory data = _encodeRedeemData(address(stXRP), 0, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        redeemHook.build(address(0), address(this), data);
    }

    function test_RedeemFirelightVaultHook_BuildRevert_ZeroYieldSource() public {
        bytes memory data = _encodeRedeemData(address(0), amount, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        redeemHook.build(address(0), address(this), data);
    }

    function test_RedeemFirelightVaultHook_BuildRevert_ZeroAccount() public {
        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        redeemHook.build(address(0), address(0), data);
    }

    function test_ClaimWithdrawFirelightVaultHook_BuildRevert_ZeroYieldSource() public {
        bytes memory data = _encodeClaimData(address(0), 1, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        claimHook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD WITH PREVIOUS HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_BuildWithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(stXRP)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeRedeemData(address(stXRP), amount, true);
        Execution[] memory executions = redeemHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(stXRP));
        assertEq(
            executions[1].callData,
            abi.encodeCall(IFirelightVault.redeem, (prevHookAmount, address(this), address(this)))
        );
    }

    function test_ClaimWithdrawFirelightVaultHook_BuildWithPrevHook() public {
        uint256 prevRequestId = 99;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(vault)));
        MockHook(mockPrevHook).setOutAmount(prevRequestId, address(this));

        bytes memory data = _encodeClaimData(address(vault), 0, true);
        Execution[] memory executions = claimHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(vault));
        assertEq(executions[1].callData, abi.encodeCall(IFirelightVault.claimWithdraw, (prevRequestId)));
    }

    /*//////////////////////////////////////////////////////////////
                          DECODE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_DecodeAmounts() public view {
        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        uint256 decodedAmount = redeemHook.decodeAmounts(data)[0];
        assertEq(decodedAmount, amount);
    }

    function test_RedeemFirelightVaultHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        uint256 newAmount = 2e18;
        bytes memory result = redeemHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(redeemHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_RedeemFirelightVaultHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        bytes memory result = redeemHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(redeemHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ClaimWithdrawFirelightVaultHook_DecodeAmounts() public view {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(vault), requestId, false);
        // ClaimWithdrawFirelight returns empty — requestId is not a sizable amount
        assertEq(claimHook.decodeAmounts(data).length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataTrue = _encodeRedeemData(address(stXRP), amount, true);
        assertTrue(redeemHook.decodeUsePrevHookAmount(dataTrue));

        bytes memory dataFalse = _encodeRedeemData(address(stXRP), amount, false);
        assertFalse(redeemHook.decodeUsePrevHookAmount(dataFalse));
    }

    function test_ClaimWithdrawFirelightVaultHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataTrue = _encodeClaimData(address(vault), 42, true);
        assertTrue(claimHook.decodeUsePrevHookAmount(dataTrue));

        bytes memory dataFalse = _encodeClaimData(address(vault), 42, false);
        assertFalse(claimHook.decodeUsePrevHookAmount(dataFalse));
    }

    /*//////////////////////////////////////////////////////////////
                    PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_PrePostExecute() public {
        _getTokens(address(stXRP), address(this), amount);

        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        redeemHook.preExecute(address(0), address(this), data);
        assertEq(redeemHook.usedShares(), amount, "preExecute should capture stXRP balance");

        redeemHook.postExecute(address(0), address(this), data);
        assertEq(redeemHook.usedShares(), 0, "postExecute should show 0 delta (no shares burned in mock)");
    }

    function test_RedeemFirelightVaultHook_PrePostExecute_TracksBurn() public {
        _getTokens(address(stXRP), address(this), amount);

        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        redeemHook.preExecute(address(0), address(this), data);
        assertEq(redeemHook.usedShares(), amount);

        // Simulate share burn by reducing balance
        uint256 burnAmount = 500e18;
        deal(address(stXRP), address(this), amount - burnAmount);

        redeemHook.postExecute(address(0), address(this), data);
        assertEq(redeemHook.usedShares(), burnAmount, "usedShares should equal burned amount");
    }

    function test_ClaimWithdrawFirelightVaultHook_PrePostExecute() public {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(vault), requestId, false);

        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.asset(), address(fxrp), "asset should be FXRP");
        assertEq(claimHook.getOutAmount(address(this)), 0, "initial FXRP balance should be 0");

        // Simulate FXRP received after claimWithdraw
        uint256 claimedAmount = 800e18;
        deal(address(fxrp), address(this), claimedAmount);

        claimHook.postExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), claimedAmount, "outAmount should equal FXRP received");
    }

    function test_ClaimWithdrawFirelightVaultHook_PrePostExecute_WithExistingBalance() public {
        uint256 requestId = 42;
        uint256 existingBalance = 300e18;
        uint256 claimedAmount = 800e18;

        // Account already has some FXRP
        deal(address(fxrp), address(this), existingBalance);

        bytes memory data = _encodeClaimData(address(vault), requestId, false);
        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), existingBalance, "should capture existing balance");

        // After claim, balance increases
        deal(address(fxrp), address(this), existingBalance + claimedAmount);

        claimHook.postExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), claimedAmount, "outAmount should be delta only");
    }

    /*//////////////////////////////////////////////////////////////
                  ADDITIONAL BUILD REVERT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ClaimWithdrawFirelightVaultHook_BuildRevert_ZeroAccount() public {
        bytes memory data = _encodeClaimData(address(vault), 1, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        claimHook.build(address(0), address(0), data);
    }

    function test_RedeemFirelightVaultHook_BuildRevert_PrevHookZeroAmount() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(stXRP)));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        bytes memory data = _encodeRedeemData(address(stXRP), amount, true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        redeemHook.build(mockPrevHook, address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                  ADDITIONAL BUILD EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ClaimWithdrawFirelightVaultHook_build_RequestIdZero() public view {
        bytes memory data = _encodeClaimData(address(vault), 0, false);
        Execution[] memory executions = claimHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(vault));
        assertEq(executions[1].callData, abi.encodeCall(IFirelightVault.claimWithdraw, (0)));
    }

    /*//////////////////////////////////////////////////////////////
                ADDITIONAL PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_PrePostExecute_ZeroStartingBalance() public {
        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);

        redeemHook.preExecute(address(0), address(this), data);
        assertEq(redeemHook.usedShares(), 0, "preExecute should capture 0 balance");

        redeemHook.postExecute(address(0), address(this), data);
        assertEq(redeemHook.usedShares(), 0, "postExecute should show 0 delta");
    }

    function test_ClaimWithdrawFirelightVaultHook_PostExecute_NoDelta() public {
        uint256 requestId = 42;
        uint256 existingBalance = 500e18;

        deal(address(fxrp), address(this), existingBalance);

        bytes memory data = _encodeClaimData(address(vault), requestId, false);
        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), existingBalance);

        // Balance unchanged after claim (e.g. request not yet claimable)
        claimHook.postExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), 0, "outAmount should be 0 when no FXRP received");
    }

    /*//////////////////////////////////////////////////////////////
                     INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RedeemFirelightVaultHook_Inspector() public view {
        bytes memory data = _encodeRedeemData(address(stXRP), amount, false);
        bytes memory argsEncoded = redeemHook.inspect(data);
        assertEq(argsEncoded, abi.encodePacked(address(stXRP)));
    }

    function test_ClaimWithdrawFirelightVaultHook_Inspector() public view {
        bytes memory data = _encodeClaimData(address(vault), 42, false);
        bytes memory argsEncoded = claimHook.inspect(data);
        assertEq(argsEncoded, abi.encodePacked(address(vault)));
    }

    function test_RedeemFirelight_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeRedeemData(address(vault), 1000, false);
        uint256 newAmount = 500;
        bytes memory replaced = redeemHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = redeemHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(redeemHook.decodeAmounts(replaced)[0], newAmount);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/
    function _encodeRedeemData(
        address yieldSource,
        uint256 shares,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, shares, usePrevHook);
    }

    function _encodeClaimData(
        address yieldSource,
        uint256 requestId,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, requestId, usePrevHook);
    }
}
