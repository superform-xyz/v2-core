// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// WithId hooks
import { CancelDepositRequestWithId7540Hook } from
    "../../../../../src/hooks/vaults/7540/CancelDepositRequestWithId7540Hook.sol";
import { CancelRedeemRequestWithId7540Hook } from
    "../../../../../src/hooks/vaults/7540/CancelRedeemRequestWithId7540Hook.sol";
import { ClaimCancelDepositRequestWithId7540Hook } from
    "../../../../../src/hooks/vaults/7540/ClaimCancelDepositRequestWithId7540Hook.sol";
import { ClaimCancelRedeemRequestWithId7540Hook } from
    "../../../../../src/hooks/vaults/7540/ClaimCancelRedeemRequestWithId7540Hook.sol";
import { RedeemWithId7540VaultHook } from "../../../../../src/hooks/vaults/7540/RedeemWithId7540VaultHook.sol";
import { WithdrawWithId7540VaultHook } from "../../../../../src/hooks/vaults/7540/WithdrawWithId7540VaultHook.sol";

// Original hooks (for comparison)
import { CancelDepositRequest7540Hook } from
    "../../../../../src/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../../../../../src/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";

import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { ISuperHook, ISuperHookAsyncCancelations } from "../../../../../src/interfaces/ISuperHook.sol";
import { IERC7540CancelDeposit, IERC7540CancelRedeem } from
    "../../../../../src/vendor/standards/ERC7540/IERC7540Vault.sol";
import { IERC7540 } from "../../../../../src/vendor/vaults/7540/IERC7540.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { Helpers } from "../../../../../test/utils/Helpers.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { InternalHelpers } from "../../../../../test/utils/InternalHelpers.sol";

contract ERC7540WithIdHookTests is Helpers, InternalHelpers {
    CancelDepositRequestWithId7540Hook public cancelDepositWithIdHook;
    CancelRedeemRequestWithId7540Hook public cancelRedeemWithIdHook;
    ClaimCancelDepositRequestWithId7540Hook public claimCancelDepositWithIdHook;
    ClaimCancelRedeemRequestWithId7540Hook public claimCancelRedeemWithIdHook;
    RedeemWithId7540VaultHook public redeemWithIdHook;
    WithdrawWithId7540VaultHook public withdrawWithIdHook;

    bytes32 yieldSourceOracleId;
    address yieldSource;
    address token;
    uint256 amount;
    uint256 requestId;
    uint256 prevHookAmount;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), 21_929_476);

        yieldSourceOracleId = bytes32(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = address(this);
        token = address(new MockERC20("Token", "TKN", 18));

        amount = 1000e6;
        requestId = 42;
        prevHookAmount = 2000e6;

        cancelDepositWithIdHook = new CancelDepositRequestWithId7540Hook();
        cancelRedeemWithIdHook = new CancelRedeemRequestWithId7540Hook();
        claimCancelDepositWithIdHook = new ClaimCancelDepositRequestWithId7540Hook();
        claimCancelRedeemWithIdHook = new ClaimCancelRedeemRequestWithId7540Hook();
        redeemWithIdHook = new RedeemWithId7540VaultHook();
        withdrawWithIdHook = new WithdrawWithId7540VaultHook();
    }

    /*//////////////////////////////////////////////////////////////
                        MOCK VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function share() public view returns (address) {
        return token;
    }

    function asset() public view returns (address) {
        return token;
    }

    function claimableRedeemRequest(uint256, address) external pure returns (uint256) {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelDepositWithIdHookConstructor() public view {
        assertEq(uint256(cancelDepositWithIdHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_CancelRedeemWithIdHookConstructor() public view {
        assertEq(uint256(cancelRedeemWithIdHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ClaimCancelDepositWithIdHookConstructor() public view {
        assertEq(uint256(claimCancelDepositWithIdHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ClaimCancelRedeemWithIdHookConstructor() public view {
        assertEq(uint256(claimCancelRedeemWithIdHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_RedeemWithIdHookConstructor() public view {
        assertEq(uint256(redeemWithIdHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_WithdrawWithIdHookConstructor() public view {
        assertEq(uint256(withdrawWithIdHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_cancelDepositWithIdHook_InspectorTests() public view {
        bytes memory data = _encodeCancelWithIdData(requestId);
        bytes memory argsEncoded = cancelDepositWithIdHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_cancelRedeemWithIdHook_InspectorTests() public view {
        bytes memory data = _encodeCancelWithIdData(requestId);
        bytes memory argsEncoded = cancelRedeemWithIdHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_claimCancelDepositWithIdHook_InspectorTests() public view {
        bytes memory data = _encodeClaimCancelWithIdData(requestId);
        bytes memory argsEncoded = claimCancelDepositWithIdHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_claimCancelRedeemWithIdHook_InspectorTests() public view {
        bytes memory data = _encodeClaimCancelWithIdData(requestId);
        bytes memory argsEncoded = claimCancelRedeemWithIdHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_redeemWithIdHook_InspectorTests() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        bytes memory argsEncoded = redeemWithIdHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_withdrawWithIdHook_InspectorTests() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        bytes memory argsEncoded = withdrawWithIdHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelDepositWithIdHook_Build() public view {
        bytes memory data = _encodeCancelWithIdData(requestId);
        Execution[] memory executions = cancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelDeposit.cancelDepositRequest, (requestId, address(this)))
        );
    }

    function test_CancelRedeemWithIdHook_Build() public view {
        bytes memory data = _encodeCancelWithIdData(requestId);
        Execution[] memory executions = cancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelRedeem.cancelRedeemRequest, (requestId, address(this)))
        );
    }

    function test_ClaimCancelDepositWithIdHook_Build() public view {
        bytes memory data = _encodeClaimCancelWithIdData(requestId);
        Execution[] memory executions = claimCancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelDeposit.claimCancelDepositRequest, (requestId, address(this), address(this)))
        );
    }

    function test_ClaimCancelRedeemWithIdHook_Build() public view {
        bytes memory data = _encodeClaimCancelWithIdData(requestId);
        Execution[] memory executions = claimCancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelRedeem.claimCancelRedeemRequest, (requestId, address(this), address(this)))
        );
    }

    function test_RedeemWithIdHook_Build() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        Execution[] memory executions = redeemWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC7540.redeem, (amount, address(this), address(this))));
    }

    function test_WithdrawWithIdHook_Build() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        Execution[] memory executions = withdrawWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC7540.withdraw, (amount, address(this), address(this))));
    }

    /*//////////////////////////////////////////////////////////////
                      BUILD WITH REQUESTID ENCODING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelDepositWithIdHook_Build_RequestIdEncoded() public view {
        uint256 testRequestId = 999;
        bytes memory data = _encodeCancelWithIdData(testRequestId);
        Execution[] memory executions = cancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelDeposit.cancelDepositRequest, (testRequestId, address(this)))
        );
    }

    function test_CancelRedeemWithIdHook_Build_RequestIdEncoded() public view {
        uint256 testRequestId = 999;
        bytes memory data = _encodeCancelWithIdData(testRequestId);
        Execution[] memory executions = cancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelRedeem.cancelRedeemRequest, (testRequestId, address(this)))
        );
    }

    function test_ClaimCancelDepositWithIdHook_Build_RequestIdEncoded() public view {
        uint256 testRequestId = 777;
        bytes memory data = _encodeClaimCancelWithIdData(testRequestId);
        Execution[] memory executions = claimCancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IERC7540CancelDeposit.claimCancelDepositRequest, (testRequestId, address(this), address(this))
            )
        );
    }

    function test_ClaimCancelRedeemWithIdHook_Build_RequestIdEncoded() public view {
        uint256 testRequestId = 777;
        bytes memory data = _encodeClaimCancelWithIdData(testRequestId);
        Execution[] memory executions = claimCancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IERC7540CancelRedeem.claimCancelRedeemRequest, (testRequestId, address(this), address(this))
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                      REQUESTID ZERO MATCHES ORIGINAL
    //////////////////////////////////////////////////////////////*/

    function test_CancelDepositWithIdHook_RequestIdZero_MatchesOriginal() public {
        CancelDepositRequest7540Hook original = new CancelDepositRequest7540Hook();

        bytes memory originalData = abi.encodePacked(yieldSourceOracleId, yieldSource);
        bytes memory withIdData = _encodeCancelWithIdData(0);

        Execution[] memory originalExecs = original.build(address(0), address(this), originalData);
        Execution[] memory withIdExecs = cancelDepositWithIdHook.build(address(0), address(this), withIdData);

        assertEq(originalExecs[1].callData, withIdExecs[1].callData);
        assertEq(originalExecs[1].target, withIdExecs[1].target);
    }

    function test_CancelRedeemWithIdHook_RequestIdZero_MatchesOriginal() public {
        CancelRedeemRequest7540Hook original = new CancelRedeemRequest7540Hook();

        bytes memory originalData = abi.encodePacked(yieldSourceOracleId, yieldSource);
        bytes memory withIdData = _encodeCancelWithIdData(0);

        Execution[] memory originalExecs = original.build(address(0), address(this), originalData);
        Execution[] memory withIdExecs = cancelRedeemWithIdHook.build(address(0), address(this), withIdData);

        assertEq(originalExecs[1].callData, withIdExecs[1].callData);
        assertEq(originalExecs[1].target, withIdExecs[1].target);
    }

    /*//////////////////////////////////////////////////////////////
                        PREV HOOK BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemWithIdHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeRedeemWithdrawWithIdData(true, requestId);
        Execution[] memory executions = redeemWithIdHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData, abi.encodeCall(IERC7540.redeem, (prevHookAmount, address(this), address(this)))
        );
    }

    function test_WithdrawWithIdHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeRedeemWithdrawWithIdData(true, requestId);
        Execution[] memory executions = withdrawWithIdHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData, abi.encodeCall(IERC7540.withdraw, (prevHookAmount, address(this), address(this)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                      BUILD REVERTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelDepositWithIdHook_Build_Revert_ZeroAddress() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0), requestId);
        vm.expectRevert();
        cancelDepositWithIdHook.build(address(0), address(this), data);
    }

    function test_CancelRedeemWithIdHook_Build_Revert_ZeroAddress() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0), requestId);
        vm.expectRevert();
        cancelRedeemWithIdHook.build(address(0), address(this), data);
    }

    function test_ClaimCancelDepositWithIdHook_Build_Revert_ZeroYieldSource() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0), address(this), requestId);
        vm.expectRevert();
        claimCancelDepositWithIdHook.build(address(0), address(this), data);
    }

    function test_ClaimCancelDepositWithIdHook_Build_Revert_ZeroReceiver() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(0), requestId);
        vm.expectRevert();
        claimCancelDepositWithIdHook.build(address(0), address(this), data);
    }

    function test_ClaimCancelRedeemWithIdHook_Build_Revert_ZeroYieldSource() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0), address(this), requestId);
        vm.expectRevert();
        claimCancelRedeemWithIdHook.build(address(0), address(this), data);
    }

    function test_ClaimCancelRedeemWithIdHook_Build_Revert_ZeroReceiver() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(0), requestId);
        vm.expectRevert();
        claimCancelRedeemWithIdHook.build(address(0), address(this), data);
    }

    function test_RedeemWithIdHook_Build_Revert_ZeroAmount() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false, requestId);
        vm.expectRevert();
        redeemWithIdHook.build(address(0), address(this), data);
    }

    function test_RedeemWithIdHook_Build_Revert_ZeroAddress() public {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        vm.expectRevert();
        redeemWithIdHook.build(address(0), address(0), data);
    }

    function test_WithdrawWithIdHook_Build_Revert_ZeroAmount() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false, requestId);
        vm.expectRevert();
        withdrawWithIdHook.build(address(0), address(this), data);
    }

    function test_WithdrawWithIdHook_Build_Revert_ZeroAddress() public {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        vm.expectRevert();
        withdrawWithIdHook.build(address(0), address(0), data);
    }

    /*//////////////////////////////////////////////////////////////
                            DECODE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemWithIdHook_DecodeAmount() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        uint256 decodedAmount = redeemWithIdHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_WithdrawWithIdHook_DecodeAmount() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        uint256 decodedAmount = withdrawWithIdHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_RedeemWithIdHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        assertFalse(redeemWithIdHook.decodeUsePrevHookAmount(data));
    }

    function test_RedeemWithIdHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(true, requestId);
        assertTrue(redeemWithIdHook.decodeUsePrevHookAmount(data));
    }

    function test_WithdrawWithIdHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        assertFalse(withdrawWithIdHook.decodeUsePrevHookAmount(data));
    }

    function test_WithdrawWithIdHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(true, requestId);
        assertTrue(withdrawWithIdHook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                        REPLACE CALLDATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemWithIdHook_ReplaceCallData() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        bytes memory replacedData = redeemWithIdHook.replaceCalldataAmount(data, 1);
        assertEq(replacedData.length, data.length);
        uint256 replacedAmount = redeemWithIdHook.decodeAmount(replacedData);
        assertEq(replacedAmount, 1);
    }

    function test_WithdrawWithIdHook_ReplaceCallData() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        bytes memory replacedData = withdrawWithIdHook.replaceCalldataAmount(data, 1);
        assertEq(replacedData.length, data.length);
        uint256 replacedAmount = withdrawWithIdHook.decodeAmount(replacedData);
        assertEq(replacedAmount, 1);
    }

    /*//////////////////////////////////////////////////////////////
                      PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_cancelDepositWithIdHook_PreAndPostExecute() public {
        cancelDepositWithIdHook.preExecute(address(0), address(this), "");
        cancelDepositWithIdHook.postExecute(address(0), address(this), "");
    }

    function test_cancelRedeemWithIdHook_PreAndPostExecute() public {
        cancelRedeemWithIdHook.preExecute(address(0), address(this), "");
        cancelRedeemWithIdHook.postExecute(address(0), address(this), "");
    }

    function test_claimCancelDepositWithIdHook_PreAndPostExecute() public {
        yieldSource = token;
        _getTokens(token, address(this), amount);

        bytes memory data =
            abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), requestId, amount, false, address(this), uint256(1));

        claimCancelDepositWithIdHook.preExecute(address(0), address(this), data);
        assertEq(claimCancelDepositWithIdHook.getOutAmount(address(this)), 1_000_000_000);

        claimCancelDepositWithIdHook.postExecute(address(0), address(this), data);
        assertEq(claimCancelDepositWithIdHook.getOutAmount(address(this)), 0);
    }

    function test_claimCancelRedeemWithIdHook_PreAndPostExecute() public {
        yieldSource = token;
        _getTokens(token, address(this), amount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), requestId);

        claimCancelRedeemWithIdHook.preExecute(address(0), address(this), data);
        assertEq(claimCancelRedeemWithIdHook.getOutAmount(address(this)), 1_000_000_000);

        claimCancelRedeemWithIdHook.postExecute(address(0), address(this), data);
        assertEq(claimCancelRedeemWithIdHook.getOutAmount(address(this)), 0);
    }

    function test_redeemWithIdHook_PreAndPostExecute() public {
        yieldSource = token;
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        redeemWithIdHook.preExecute(address(0), address(this), data);
        assertEq(redeemWithIdHook.getOutAmount(address(this)), amount);

        redeemWithIdHook.postExecute(address(0), address(this), data);
        assertEq(redeemWithIdHook.getOutAmount(address(this)), 0);
    }

    function test_withdrawWithIdHook_PreAndPostExecute() public {
        yieldSource = token;
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        withdrawWithIdHook.preExecute(address(0), address(this), data);
        assertEq(withdrawWithIdHook.getOutAmount(address(this)), amount);

        withdrawWithIdHook.postExecute(address(0), address(this), data);
        assertEq(withdrawWithIdHook.getOutAmount(address(this)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ASYNC HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelDepositWithIdHook_SubType() public view {
        assertEq(cancelDepositWithIdHook.SUB_TYPE(), HookSubTypes.CANCEL_DEPOSIT_REQUEST);
    }

    function test_CancelRedeemWithIdHook_SubType() public view {
        assertEq(cancelRedeemWithIdHook.SUB_TYPE(), HookSubTypes.CANCEL_REDEEM_REQUEST);
    }

    function test_ClaimCancelDepositWithIdHook_SubType() public view {
        assertEq(claimCancelDepositWithIdHook.SUB_TYPE(), HookSubTypes.CLAIM_CANCEL_DEPOSIT_REQUEST);
    }

    function test_ClaimCancelRedeemWithIdHook_SubType() public view {
        assertEq(claimCancelRedeemWithIdHook.SUB_TYPE(), HookSubTypes.CLAIM_CANCEL_REDEEM_REQUEST);
    }

    function test_ClaimCancelDepositWithIdHook_IsAsyncCancelHook() public view {
        assertEq(
            uint256(claimCancelDepositWithIdHook.isAsyncCancelHook()),
            uint256(ISuperHookAsyncCancelations.CancelationType.INFLOW)
        );
    }

    function test_ClaimCancelRedeemWithIdHook_IsAsyncCancelHook() public view {
        assertEq(
            uint256(claimCancelRedeemWithIdHook.isAsyncCancelHook()),
            uint256(ISuperHookAsyncCancelations.CancelationType.OUTFLOW)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CancelDepositWithIdHook_RequestId(uint256 fuzzRequestId) public view {
        bytes memory data = _encodeCancelWithIdData(fuzzRequestId);
        Execution[] memory executions = cancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelDeposit.cancelDepositRequest, (fuzzRequestId, address(this)))
        );
    }

    function testFuzz_CancelRedeemWithIdHook_RequestId(uint256 fuzzRequestId) public view {
        bytes memory data = _encodeCancelWithIdData(fuzzRequestId);
        Execution[] memory executions = cancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelRedeem.cancelRedeemRequest, (fuzzRequestId, address(this)))
        );
    }

    function testFuzz_ClaimCancelDepositWithIdHook_RequestId(uint256 fuzzRequestId) public view {
        bytes memory data = _encodeClaimCancelWithIdData(fuzzRequestId);
        Execution[] memory executions = claimCancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IERC7540CancelDeposit.claimCancelDepositRequest, (fuzzRequestId, address(this), address(this))
            )
        );
    }

    function testFuzz_ClaimCancelRedeemWithIdHook_RequestId(uint256 fuzzRequestId) public view {
        bytes memory data = _encodeClaimCancelWithIdData(fuzzRequestId);
        Execution[] memory executions = claimCancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IERC7540CancelRedeem.claimCancelRedeemRequest, (fuzzRequestId, address(this), address(this))
            )
        );
    }

    function testFuzz_RedeemWithIdHook_DecodeAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, fuzzAmount, false, requestId);
        uint256 decodedAmount = redeemWithIdHook.decodeAmount(data);
        assertEq(decodedAmount, fuzzAmount);
    }

    function testFuzz_WithdrawWithIdHook_DecodeAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, fuzzAmount, false, requestId);
        uint256 decodedAmount = withdrawWithIdHook.decodeAmount(data);
        assertEq(decodedAmount, fuzzAmount);
    }

    function test_RedeemWithIdHook_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        uint256 newAmount = 2e18;
        bytes memory result = redeemWithIdHook.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(redeemWithIdHook.decodeAmount(result), newAmount);
    }

    function testFuzz_RedeemWithIdHook_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        bytes memory result = redeemWithIdHook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(redeemWithIdHook.decodeAmount(result), fuzzAmount);
    }

    function test_WithdrawWithIdHook_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        uint256 newAmount = 2e18;
        bytes memory result = withdrawWithIdHook.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(withdrawWithIdHook.decodeAmount(result), newAmount);
    }

    function testFuzz_WithdrawWithIdHook_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, requestId);
        bytes memory result = withdrawWithIdHook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(withdrawWithIdHook.decodeAmount(result), fuzzAmount);
    }

    /// @dev Fuzz: redeem build with arbitrary amount and requestId
    function testFuzz_RedeemWithIdHook_Build(uint256 fuzzAmount, uint256 fuzzRequestId) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, fuzzAmount, false, fuzzRequestId);
        Execution[] memory executions = redeemWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(
            executions[1].callData, abi.encodeCall(IERC7540.redeem, (fuzzAmount, address(this), address(this)))
        );
    }

    /// @dev Fuzz: withdraw build with arbitrary amount and requestId
    function testFuzz_WithdrawWithIdHook_Build(uint256 fuzzAmount, uint256 fuzzRequestId) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, fuzzAmount, false, fuzzRequestId);
        Execution[] memory executions = withdrawWithIdHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(
            executions[1].callData, abi.encodeCall(IERC7540.withdraw, (fuzzAmount, address(this), address(this)))
        );
    }

    /// @dev Fuzz: cancel deposit build with arbitrary yieldSource (non-zero) and requestId
    function testFuzz_CancelDepositWithIdHook_Build(address fuzzYieldSource, uint256 fuzzRequestId) public view {
        vm.assume(fuzzYieldSource != address(0));
        bytes memory data = abi.encodePacked(yieldSourceOracleId, fuzzYieldSource, fuzzRequestId);
        Execution[] memory executions = cancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(executions[1].target, fuzzYieldSource);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelDeposit.cancelDepositRequest, (fuzzRequestId, address(this)))
        );
    }

    /// @dev Fuzz: cancel redeem build with arbitrary yieldSource (non-zero) and requestId
    function testFuzz_CancelRedeemWithIdHook_Build(address fuzzYieldSource, uint256 fuzzRequestId) public view {
        vm.assume(fuzzYieldSource != address(0));
        bytes memory data = abi.encodePacked(yieldSourceOracleId, fuzzYieldSource, fuzzRequestId);
        Execution[] memory executions = cancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(executions[1].target, fuzzYieldSource);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC7540CancelRedeem.cancelRedeemRequest, (fuzzRequestId, address(this)))
        );
    }

    /// @dev Fuzz: claimCancelDeposit build with arbitrary receiver, yieldSource, and requestId
    function testFuzz_ClaimCancelDepositWithIdHook_Build(
        address fuzzYieldSource,
        address fuzzReceiver,
        uint256 fuzzRequestId
    )
        public
        view
    {
        vm.assume(fuzzYieldSource != address(0));
        vm.assume(fuzzReceiver != address(0));
        bytes memory data = abi.encodePacked(yieldSourceOracleId, fuzzYieldSource, fuzzReceiver, fuzzRequestId);
        Execution[] memory executions = claimCancelDepositWithIdHook.build(address(0), address(this), data);
        assertEq(executions[1].target, fuzzYieldSource);
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IERC7540CancelDeposit.claimCancelDepositRequest, (fuzzRequestId, fuzzReceiver, address(this))
            )
        );
    }

    /// @dev Fuzz: claimCancelRedeem build with arbitrary receiver, yieldSource, and requestId
    function testFuzz_ClaimCancelRedeemWithIdHook_Build(
        address fuzzYieldSource,
        address fuzzReceiver,
        uint256 fuzzRequestId
    )
        public
        view
    {
        vm.assume(fuzzYieldSource != address(0));
        vm.assume(fuzzReceiver != address(0));
        bytes memory data = abi.encodePacked(yieldSourceOracleId, fuzzYieldSource, fuzzReceiver, fuzzRequestId);
        Execution[] memory executions = claimCancelRedeemWithIdHook.build(address(0), address(this), data);
        assertEq(executions[1].target, fuzzYieldSource);
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IERC7540CancelRedeem.claimCancelRedeemRequest, (fuzzRequestId, fuzzReceiver, address(this))
            )
        );
    }

    /// @dev Fuzz: replaceCalldataAmount round-trip for redeem
    function testFuzz_RedeemWithIdHook_ReplaceCallData(uint256 fuzzAmount, uint256 fuzzRequestId) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, fuzzRequestId);
        bytes memory replacedData = redeemWithIdHook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(redeemWithIdHook.decodeAmount(replacedData), fuzzAmount);
        assertEq(replacedData.length, data.length);
    }

    /// @dev Fuzz: replaceCalldataAmount round-trip for withdraw
    function testFuzz_WithdrawWithIdHook_ReplaceCallData(uint256 fuzzAmount, uint256 fuzzRequestId) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, fuzzRequestId);
        bytes memory replacedData = withdrawWithIdHook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(withdrawWithIdHook.decodeAmount(replacedData), fuzzAmount);
        assertEq(replacedData.length, data.length);
    }

    /// @dev Fuzz: inspector output length is always 20 bytes (address) for cancel hooks
    function testFuzz_CancelWithIdHook_InspectLength(uint256 fuzzRequestId) public view {
        bytes memory data = _encodeCancelWithIdData(fuzzRequestId);
        assertEq(cancelDepositWithIdHook.inspect(data).length, 20);
        assertEq(cancelRedeemWithIdHook.inspect(data).length, 20);
    }

    /// @dev Fuzz: inspector output length is always 40 bytes (address + address) for claimCancel hooks
    function testFuzz_ClaimCancelWithIdHook_InspectLength(uint256 fuzzRequestId) public view {
        bytes memory data = _encodeClaimCancelWithIdData(fuzzRequestId);
        assertEq(claimCancelDepositWithIdHook.inspect(data).length, 40);
        assertEq(claimCancelRedeemWithIdHook.inspect(data).length, 40);
    }

    /// @dev Fuzz: inspector output length is always 20 bytes (address) for redeem/withdraw hooks
    function testFuzz_RedeemWithdrawWithIdHook_InspectLength(uint256 fuzzRequestId, uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, fuzzAmount, false, fuzzRequestId);
        assertEq(redeemWithIdHook.inspect(data).length, 20);
        assertEq(withdrawWithIdHook.inspect(data).length, 20);
    }

    /// @dev Fuzz: decodeUsePrevHookAmount is independent of requestId
    function testFuzz_DecodeUsePrevHookAmount_IndependentOfRequestId(uint256 fuzzRequestId) public view {
        bytes memory dataFalse = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, fuzzRequestId);
        bytes memory dataTrue = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, true, fuzzRequestId);
        assertFalse(redeemWithIdHook.decodeUsePrevHookAmount(dataFalse));
        assertTrue(redeemWithIdHook.decodeUsePrevHookAmount(dataTrue));
        assertFalse(withdrawWithIdHook.decodeUsePrevHookAmount(dataFalse));
        assertTrue(withdrawWithIdHook.decodeUsePrevHookAmount(dataTrue));
    }

    function test_RedeemWithId7540_ReplaceCalldataAmount_ThenBuild() public view {
        bytes memory data = _encodeRedeemWithdrawWithIdData(false, 1);
        uint256 newAmount = 500;
        bytes memory replaced = redeemWithIdHook.replaceCalldataAmount(data, newAmount);
        Execution[] memory executions = redeemWithIdHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(redeemWithIdHook.decodeAmount(replaced), newAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Cancel hook data: [placeholder(32), yieldSource(20), requestId(32)]
    function _encodeCancelWithIdData(uint256 reqId) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, reqId);
    }

    /// @dev ClaimCancel hook data: [placeholder(32), yieldSource(20), receiver(20), requestId(32)]
    function _encodeClaimCancelWithIdData(uint256 reqId) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), reqId);
    }

    /// @dev Redeem/Withdraw hook data: [oracleId(32), yieldSource(20), amount(32), usePrevHookAmount(1),
    /// requestId(32)]
    function _encodeRedeemWithdrawWithIdData(bool usePrevHook, uint256 reqId) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHook, reqId);
    }
}
