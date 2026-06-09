// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../../utils/Helpers.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { IDETHAsyncRedeemer } from "../../../../../src/vendor/vaults/deth/IDETHAsyncRedeemer.sol";

// Hooks
import { RequestRedeemDETHHook } from "../../../../../src/hooks/vaults/deth/RequestRedeemDETHHook.sol";
import { ApproveAndRequestRedeemDETHHook } from
    "../../../../../src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol";
import { ClaimAssetsDETHHook } from "../../../../../src/hooks/vaults/deth/ClaimAssetsDETHHook.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal mock of the AsyncRedeemer for testing
contract MockAsyncRedeemer {
    address public machine;
    uint256 public lastRequestId;
    uint256 public nextRequestId = 1;

    constructor(address machine_) {
        machine = machine_;
    }

    function requestRedeem(uint256, address, uint256) external returns (uint256) {
        lastRequestId = nextRequestId;
        return nextRequestId++;
    }

    function claimAssets(uint256 requestId) external returns (uint256) {
        lastRequestId = requestId;
        return 0;
    }
}

/// @dev Minimal mock of Machine for testing
contract MockMachine {
    address public shareToken;
    address public accountingToken;

    constructor(address shareToken_, address accountingToken_) {
        shareToken = shareToken_;
        accountingToken = accountingToken_;
    }
}

contract DETHHooksTests is Helpers {
    RequestRedeemDETHHook requestRedeemHook;
    ApproveAndRequestRedeemDETHHook approveAndRequestHook;
    ClaimAssetsDETHHook claimHook;

    MockERC20 dethToken;
    MockERC20 weth;
    MockMachine machine;
    MockAsyncRedeemer asyncRedeemer;
    bytes32 yieldSourceOracleId;
    uint256 amount;
    uint256 prevHookAmount;
    uint256 minAssets;

    function setUp() public {
        requestRedeemHook = new RequestRedeemDETHHook();
        approveAndRequestHook = new ApproveAndRequestRedeemDETHHook();
        claimHook = new ClaimAssetsDETHHook();

        dethToken = new MockERC20("Dialectic ETH", "DETH", 18);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        machine = new MockMachine(address(dethToken), address(weth));
        asyncRedeemer = new MockAsyncRedeemer(address(machine));
        yieldSourceOracleId = bytes32(keccak256("YIELD_SOURCE_ORACLE_ID"));
        amount = 1000e18;
        prevHookAmount = 2000e18;
        minAssets = 900e18;
    }

    /*//////////////////////////////////////////////////////////////
                      CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_Constructor() public view {
        assertEq(uint256(requestRedeemHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(requestRedeemHook.SUB_TYPE(), HookSubTypes.ERC4626);
    }

    function test_ApproveAndRequestRedeemDETHHook_Constructor() public view {
        assertEq(uint256(approveAndRequestHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(approveAndRequestHook.SUB_TYPE(), HookSubTypes.ERC4626);
    }

    function test_ClaimAssetsDETHHook_Constructor() public view {
        assertEq(uint256(claimHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
        assertEq(claimHook.SUB_TYPE(), HookSubTypes.ERC4626);
    }

    /*//////////////////////////////////////////////////////////////
                            BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_build() public view {
        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        Execution[] memory executions = requestRedeemHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(asyncRedeemer));
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (amount, address(this), minAssets))
        );
    }

    function test_ApproveAndRequestRedeemDETHHook_build() public view {
        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        Execution[] memory executions = approveAndRequestHook.build(address(0), address(this), data);

        assertEq(executions.length, 6); // pre + approve(0) + approve(shares) + requestRedeem + approve(0) + post
        // approve(0)
        assertEq(executions[1].target, address(dethToken));
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(asyncRedeemer), 0)));
        // approve(shares)
        assertEq(executions[2].target, address(dethToken));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(asyncRedeemer), amount)));
        // requestRedeem
        assertEq(executions[3].target, address(asyncRedeemer));
        assertEq(
            executions[3].callData,
            abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (amount, address(this), minAssets))
        );
        // approve(0) cleanup
        assertEq(executions[4].target, address(dethToken));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(asyncRedeemer), 0)));
    }

    function test_ClaimAssetsDETHHook_build() public view {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);
        Execution[] memory executions = claimHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(asyncRedeemer));
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IDETHAsyncRedeemer.claimAssets, (requestId)));
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD REVERT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_BuildRevert_ZeroShares() public {
        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), 0, minAssets, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        requestRedeemHook.build(address(0), address(this), data);
    }

    function test_RequestRedeemDETHHook_BuildRevert_ZeroYieldSource() public {
        bytes memory data = _encodeRequestRedeemData(address(0), amount, minAssets, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        requestRedeemHook.build(address(0), address(this), data);
    }

    function test_RequestRedeemDETHHook_BuildRevert_ZeroAccount() public {
        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        requestRedeemHook.build(address(0), address(0), data);
    }

    function test_ApproveAndRequestRedeemDETHHook_BuildRevert_ZeroShares() public {
        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), 0, minAssets, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndRequestHook.build(address(0), address(this), data);
    }

    function test_ApproveAndRequestRedeemDETHHook_BuildRevert_ZeroYieldSource() public {
        bytes memory data = _encodeApproveAndRequestData(address(0), address(dethToken), amount, minAssets, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndRequestHook.build(address(0), address(this), data);
    }

    function test_ApproveAndRequestRedeemDETHHook_BuildRevert_ZeroDethToken() public {
        bytes memory data = _encodeApproveAndRequestData(address(asyncRedeemer), address(0), amount, minAssets, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndRequestHook.build(address(0), address(this), data);
    }

    function test_ClaimAssetsDETHHook_BuildRevert_ZeroYieldSource() public {
        bytes memory data = _encodeClaimData(address(0), 1, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        claimHook.build(address(0), address(this), data);
    }

    function test_ClaimAssetsDETHHook_BuildRevert_ZeroAccount() public {
        bytes memory data = _encodeClaimData(address(asyncRedeemer), 1, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        claimHook.build(address(0), address(0), data);
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD WITH PREVIOUS HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_BuildWithPrevHook() public {
        address mockPrevHook =
            address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(asyncRedeemer)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, true);
        Execution[] memory executions = requestRedeemHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (prevHookAmount, address(this), minAssets))
        );
    }

    function test_ApproveAndRequestRedeemDETHHook_BuildWithPrevHook() public {
        address mockPrevHook =
            address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(asyncRedeemer)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, true);
        Execution[] memory executions = approveAndRequestHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 6);
        assertEq(
            executions[2].callData, abi.encodeCall(IERC20.approve, (address(asyncRedeemer), prevHookAmount))
        );
        assertEq(
            executions[3].callData,
            abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (prevHookAmount, address(this), minAssets))
        );
    }

    function test_ClaimAssetsDETHHook_BuildWithPrevHook() public {
        uint256 prevRequestId = 99;
        address mockPrevHook =
            address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(asyncRedeemer)));
        MockHook(mockPrevHook).setOutAmount(prevRequestId, address(this));

        bytes memory data = _encodeClaimData(address(asyncRedeemer), 0, true);
        Execution[] memory executions = claimHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData, abi.encodeCall(IDETHAsyncRedeemer.claimAssets, (prevRequestId))
        );
    }

    /*//////////////////////////////////////////////////////////////
                          DECODE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_DecodeAmount() public view {
        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        uint256 decodedAmount = requestRedeemHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_ApproveAndRequestRedeemDETHHook_DecodeAmount() public view {
        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        uint256 decodedAmount = approveAndRequestHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_ClaimAssetsDETHHook_DecodeAmount() public view {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);
        uint256 decodedAmount = claimHook.decodeAmount(data);
        assertEq(decodedAmount, requestId);
    }

    /*//////////////////////////////////////////////////////////////
                    REPLACE CALLDATA AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        uint256 newAmount = 2e18;
        bytes memory result = requestRedeemHook.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(requestRedeemHook.decodeAmount(result), newAmount);
    }

    function testFuzz_RequestRedeemDETHHook_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        bytes memory result = requestRedeemHook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(requestRedeemHook.decodeAmount(result), fuzzAmount);
    }

    function test_ApproveAndRequestRedeemDETHHook_ReplaceCalldataAmount() public view {
        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndRequestHook.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(approveAndRequestHook.decodeAmount(result), newAmount);
    }

    function testFuzz_ApproveAndRequestRedeemDETHHook_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        bytes memory result = approveAndRequestHook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(approveAndRequestHook.decodeAmount(result), fuzzAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataTrue = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, true);
        assertTrue(requestRedeemHook.decodeUsePrevHookAmount(dataTrue));

        bytes memory dataFalse = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        assertFalse(requestRedeemHook.decodeUsePrevHookAmount(dataFalse));
    }

    function test_ApproveAndRequestRedeemDETHHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataTrue =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, true);
        assertTrue(approveAndRequestHook.decodeUsePrevHookAmount(dataTrue));

        bytes memory dataFalse =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        assertFalse(approveAndRequestHook.decodeUsePrevHookAmount(dataFalse));
    }

    function test_ClaimAssetsDETHHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataTrue = _encodeClaimData(address(asyncRedeemer), 42, true);
        assertTrue(claimHook.decodeUsePrevHookAmount(dataTrue));

        bytes memory dataFalse = _encodeClaimData(address(asyncRedeemer), 42, false);
        assertFalse(claimHook.decodeUsePrevHookAmount(dataFalse));
    }

    /*//////////////////////////////////////////////////////////////
                    PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_PrePostExecute() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        requestRedeemHook.preExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.usedShares(), amount, "preExecute should capture DETH balance");

        requestRedeemHook.postExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.usedShares(), 0, "postExecute should show 0 delta (no shares burned in mock)");
    }

    function test_RequestRedeemDETHHook_PrePostExecute_TracksBurn() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        requestRedeemHook.preExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.usedShares(), amount);

        // Simulate share burn by reducing balance
        uint256 burnAmount = 500e18;
        deal(address(dethToken), address(this), amount - burnAmount);

        requestRedeemHook.postExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.usedShares(), burnAmount, "usedShares should equal burned amount");
    }

    function test_ApproveAndRequestRedeemDETHHook_PrePostExecute() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        approveAndRequestHook.preExecute(address(0), address(this), data);
        assertEq(approveAndRequestHook.getOutAmount(address(this)), amount, "preExecute should capture DETH balance");

        // Simulate share burn
        uint256 burnAmount = 500e18;
        deal(address(dethToken), address(this), amount - burnAmount);

        approveAndRequestHook.postExecute(address(0), address(this), data);
        assertEq(
            approveAndRequestHook.getOutAmount(address(this)), burnAmount, "outAmount should equal burned amount"
        );
    }

    function test_ClaimAssetsDETHHook_PrePostExecute() public {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);

        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.asset(), address(weth), "asset should be WETH");
        assertEq(claimHook.getOutAmount(address(this)), 0, "initial WETH balance should be 0");

        // Simulate WETH received after claimAssets
        uint256 claimedAmount = 800e18;
        deal(address(weth), address(this), claimedAmount);

        claimHook.postExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), claimedAmount, "outAmount should equal WETH received");
    }

    function test_ClaimAssetsDETHHook_PrePostExecute_WithExistingBalance() public {
        uint256 requestId = 42;
        uint256 existingBalance = 300e18;
        uint256 claimedAmount = 800e18;

        // Account already has some WETH
        deal(address(weth), address(this), existingBalance);

        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);
        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), existingBalance, "should capture existing balance");

        // After claim, balance increases
        deal(address(weth), address(this), existingBalance + claimedAmount);

        claimHook.postExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), claimedAmount, "outAmount should be delta only");
    }

    function test_ClaimAssetsDETHHook_PostExecute_NoDelta() public {
        uint256 requestId = 42;
        uint256 existingBalance = 500e18;

        deal(address(weth), address(this), existingBalance);

        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);
        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), existingBalance);

        // Balance unchanged after claim (e.g. request not yet claimable)
        claimHook.postExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), 0, "outAmount should be 0 when no WETH received");
    }

    /*//////////////////////////////////////////////////////////////
                     INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestRedeemDETHHook_Inspector() public view {
        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        bytes memory argsEncoded = requestRedeemHook.inspect(data);
        assertEq(argsEncoded, abi.encodePacked(address(asyncRedeemer)));
    }

    function test_ApproveAndRequestRedeemDETHHook_Inspector() public view {
        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        bytes memory argsEncoded = approveAndRequestHook.inspect(data);
        assertEq(argsEncoded, abi.encodePacked(address(asyncRedeemer), address(dethToken)));
    }

    function test_ClaimAssetsDETHHook_Inspector() public view {
        bytes memory data = _encodeClaimData(address(asyncRedeemer), 42, false);
        bytes memory argsEncoded = claimHook.inspect(data);
        assertEq(argsEncoded, abi.encodePacked(address(asyncRedeemer)));
    }

    /*//////////////////////////////////////////////////////////////
                     BUILD EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ClaimAssetsDETHHook_build_RequestIdZero() public view {
        bytes memory data = _encodeClaimData(address(asyncRedeemer), 0, false);
        Execution[] memory executions = claimHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(asyncRedeemer));
        assertEq(executions[1].callData, abi.encodeCall(IDETHAsyncRedeemer.claimAssets, (0)));
    }

    function test_RequestRedeemDETHHook_BuildRevert_PrevHookZeroAmount() public {
        address mockPrevHook =
            address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(asyncRedeemer)));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        requestRedeemHook.build(mockPrevHook, address(this), data);
    }

    function test_ApproveAndRequestRedeemDETHHook_BuildRevert_ZeroAccount() public {
        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndRequestHook.build(address(0), address(0), data);
    }

    function test_ApproveAndRequestRedeemDETHHook_BuildRevert_PrevHookZeroAmount() public {
        address mockPrevHook =
            address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(asyncRedeemer)));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndRequestHook.build(mockPrevHook, address(this), data);
    }

    function test_RequestRedeemDETHHook_PrePostExecute_FullBurn() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        requestRedeemHook.preExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.usedShares(), amount);

        // Full burn — all shares consumed
        deal(address(dethToken), address(this), 0);

        requestRedeemHook.postExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.usedShares(), amount, "usedShares should equal full balance when all burned");
    }

    function test_ApproveAndRequestRedeemDETHHook_PrePostExecute_FullBurn() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        approveAndRequestHook.preExecute(address(0), address(this), data);
        assertEq(approveAndRequestHook.getOutAmount(address(this)), amount);

        // Full burn — all shares consumed
        deal(address(dethToken), address(this), 0);

        approveAndRequestHook.postExecute(address(0), address(this), data);
        assertEq(
            approveAndRequestHook.getOutAmount(address(this)), amount, "outAmount should equal full balance when all burned"
        );
    }

    function test_ApproveAndRequestRedeemDETHHook_PrePostExecute_NoDelta() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data =
            _encodeApproveAndRequestData(address(asyncRedeemer), address(dethToken), amount, minAssets, false);
        approveAndRequestHook.preExecute(address(0), address(this), data);
        assertEq(approveAndRequestHook.getOutAmount(address(this)), amount);

        // Balance unchanged
        approveAndRequestHook.postExecute(address(0), address(this), data);
        assertEq(approveAndRequestHook.getOutAmount(address(this)), 0, "outAmount should be 0 when no shares burned");
    }

    function test_ClaimAssetsDETHHook_PreExecute_SetsSpToken() public {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);

        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.spToken(), address(dethToken), "spToken should be set to DETH share token");
    }

    function test_ClaimAssetsDETHHook_UsedSharesRemainsZero() public {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);

        claimHook.preExecute(address(0), address(this), data);

        uint256 claimedAmount = 800e18;
        deal(address(weth), address(this), claimedAmount);

        claimHook.postExecute(address(0), address(this), data);

        // usedShares intentionally NOT set in ClaimAssetsDETHHook — shares consumed in prior RequestRedeem step
        assertEq(claimHook.usedShares(), 0, "usedShares should remain 0 - shares consumed in prior step");
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY FIX COVERAGE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev P3-5: RequestRedeemDETHHook now caches shareToken in spToken transient storage
    function test_RequestRedeemDETHHook_PreExecute_SetsSpToken() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        requestRedeemHook.preExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.spToken(), address(dethToken), "spToken should be cached to DETH share token");
    }

    /// @dev P3-5: _postExecute uses cached spToken from _preExecute (no redundant external calls)
    function test_RequestRedeemDETHHook_PostExecute_UsesCachedSpToken() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        requestRedeemHook.preExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.spToken(), address(dethToken));

        // Simulate share burn
        uint256 burnAmount = 400e18;
        deal(address(dethToken), address(this), amount - burnAmount);

        // postExecute uses cached spToken — no re-derivation of shareToken
        requestRedeemHook.postExecute(address(0), address(this), data);
        assertEq(requestRedeemHook.usedShares(), burnAmount, "usedShares correct via cached spToken");
        assertEq(requestRedeemHook.spToken(), address(dethToken), "spToken still cached after postExecute");
    }

    /// @dev P2-1: ClaimAssetsDETHHook.asset (WETH) and spToken (DETH) are distinct tokens
    function test_ClaimAssetsDETHHook_PreExecute_AssetAndSpTokenAreDifferent() public {
        uint256 requestId = 42;
        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);

        claimHook.preExecute(address(0), address(this), data);
        assertEq(claimHook.asset(), address(weth), "asset should be WETH");
        assertEq(claimHook.spToken(), address(dethToken), "spToken should be DETH");
        assertTrue(claimHook.asset() != claimHook.spToken(), "asset and spToken must be different tokens");
    }

    /// @dev P2-1: ClaimAssetsDETHHook full flow with spToken = shareToken fix
    function test_ClaimAssetsDETHHook_PrePostExecute_SpTokenIsShareToken() public {
        uint256 requestId = 42;
        uint256 claimedAmount = 500e18;

        bytes memory data = _encodeClaimData(address(asyncRedeemer), requestId, false);
        claimHook.preExecute(address(0), address(this), data);

        // spToken is DETH, asset is WETH — both set in preExecute
        assertEq(claimHook.spToken(), address(dethToken));
        assertEq(claimHook.asset(), address(weth));

        // Simulate WETH claim
        deal(address(weth), address(this), claimedAmount);

        claimHook.postExecute(address(0), address(this), data);
        assertEq(claimHook.getOutAmount(address(this)), claimedAmount, "outAmount tracks WETH delta correctly");
        // spToken remains DETH throughout
        assertEq(claimHook.spToken(), address(dethToken), "spToken unchanged after postExecute");
    }

    /// @dev P3-5: RequestRedeemDETHHook discovers DETH via machine().shareToken() chain
    function test_RequestRedeemDETHHook_PreExecute_MachineDiscoveryChain() public {
        _getTokens(address(dethToken), address(this), amount);

        bytes memory data = _encodeRequestRedeemData(address(asyncRedeemer), amount, minAssets, false);
        requestRedeemHook.preExecute(address(0), address(this), data);

        // Verify the full discovery chain: asyncRedeemer -> machine -> shareToken
        assertEq(asyncRedeemer.machine(), address(machine));
        assertEq(machine.shareToken(), address(dethToken));
        assertEq(requestRedeemHook.spToken(), address(dethToken));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encodes RequestRedeemDETHHook data
    /// Layout: bytes32 oracleId | address asyncRedeemer | uint256 shares | uint256 minAssets | bool usePrevHook
    function _encodeRequestRedeemData(
        address _asyncRedeemer,
        uint256 shares,
        uint256 _minAssets,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, _asyncRedeemer, shares, _minAssets, usePrevHook);
    }

    /// @dev Encodes ApproveAndRequestRedeemDETHHook data
    /// Layout: bytes32 oracleId | address asyncRedeemer | address dethToken | uint256 shares | uint256 minAssets |
    /// bool usePrevHook
    function _encodeApproveAndRequestData(
        address _asyncRedeemer,
        address _dethToken,
        uint256 shares,
        uint256 _minAssets,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, _asyncRedeemer, _dethToken, shares, _minAssets, usePrevHook);
    }

    /// @dev Encodes ClaimAssetsDETHHook data
    /// Layout: bytes32 oracleId | address asyncRedeemer | uint256 requestId | bool usePrevHook
    function _encodeClaimData(
        address _asyncRedeemer,
        uint256 requestId,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, _asyncRedeemer, requestId, usePrevHook);
    }
}
