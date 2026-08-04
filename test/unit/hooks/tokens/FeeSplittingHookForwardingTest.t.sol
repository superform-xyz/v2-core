// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { FeeSplittingHook } from "../../../../src/hooks/tokens/FeeSplittingHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";

/// @dev Minimal previous-hook stub returning a configurable outAmount/outToken.
contract SourceStub {
    uint256 public amt;
    address public tok;

    constructor(uint256 a, address t) {
        amt = a;
        tok = t;
    }

    function getOutAmount(address) external view returns (uint256) {
        return amt;
    }

    function getOutToken(address) external view returns (address) {
        return tok;
    }
}

/// @dev ERC20 whose transfer returns false without reverting and moves nothing (weird-erc20 class).
contract FalseERC20 {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }
}

/// @notice Regression tests for the three FeeSplittingHook PASSTHROUGH forwarding fixes:
///         (1) same-address adjacency, (2) silent transfer-failure detection, (3) post-fee remainder.
/// @dev The test contract plays both the executor role (setExecutionContext/resetExecutionState) and
///      the account role (preExecute/postExecute callers + the token holder that performs transfers).
contract FeeSplittingHookForwardingTest is Test {
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    FeeSplittingHook hook;
    address account;
    address r1;
    address r2;

    function setUp() public {
        hook = new FeeSplittingHook(NATIVE);
        account = address(this);
        r1 = makeAddr("r1");
        r2 = makeAddr("r2");
        vm.deal(account, 100 ether);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encode(
        address[] memory tokens,
        uint256[] memory amounts,
        address[] memory receivers
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), abi.encode(tokens, amounts, receivers));
    }

    /// @dev Performs the transfers the executor would run between preExecute and postExecute, as the account.
    function _performTransfers(address[] memory tokens, uint256[] memory amounts, address[] memory receivers) internal {
        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] == NATIVE) {
                (bool s,) = payable(receivers[i]).call{ value: amounts[i] }("");
                require(s, "native send failed");
            } else {
                IERC20(tokens[i]).transfer(receivers[i], amounts[i]);
            }
        }
    }

    /// @dev Full executor cycle for one hook invocation (setContext -> pre -> transfers -> post -> reset).
    function _cycle(
        address prevHook,
        address[] memory tokens,
        uint256[] memory amounts,
        address[] memory receivers
    )
        internal
    {
        bytes memory data = _encode(tokens, amounts, receivers);
        hook.setExecutionContext(account);
        hook.preExecute(prevHook, account, data);
        _performTransfers(tokens, amounts, receivers);
        hook.postExecute(prevHook, account, data);
        hook.resetExecutionState(account);
    }

    function _one(address token, uint256 amount, address receiver)
        internal
        pure
        returns (address[] memory t, uint256[] memory a, address[] memory r)
    {
        t = new address[](1);
        a = new uint256[](1);
        r = new address[](1);
        t[0] = token;
        a[0] = amount;
        r[0] = receiver;
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fix #1 + #3 (native): two consecutive same-address FeeSplits forward the post-fee remainder.
    ///         Pre-fix, the 2nd instance read the fresh context and forwarded 0.
    function test_Adjacency_ForwardsPostFeeRemainder_Native() public {
        SourceStub src = new SourceStub(10 ether, address(0)); // native flow (outToken == address(0))

        // FeeSplit #1: forward 10 ETH, pay 1 ETH fee -> remainder 9 ETH.
        (address[] memory t1, uint256[] memory a1, address[] memory rr1) = _one(NATIVE, 1 ether, r1);
        _cycle(address(src), t1, a1, rr1);
        assertEq(hook.getOutAmount(account), 9 ether, "1st: 10 - 1 fee");

        // FeeSplit #2 (prevHook == hook): must read 9 ETH from adjacency cache, pay 2 ETH -> remainder 7 ETH.
        (address[] memory t2, uint256[] memory a2, address[] memory rr2) = _one(NATIVE, 2 ether, r2);
        _cycle(address(hook), t2, a2, rr2);
        assertEq(hook.getOutAmount(account), 7 ether, "2nd: 9 - 2 fee (proves adjacency read 9, not 0)");
    }

    /// @notice Fix #2: a token that returns false without moving funds is detected in postExecute.
    function test_SilentTransferFailure_Reverts() public {
        FalseERC20 bad = new FalseERC20();
        bad.mint(account, 1000);

        (address[] memory t, uint256[] memory a, address[] memory r) = _one(address(bad), 100, r1);
        bytes memory data = _encode(t, a, r);

        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);
        _performTransfers(t, a, r); // returns false, moves nothing

        vm.expectRevert(abi.encodeWithSelector(FeeSplittingHook.TRANSFER_NOT_PERFORMED.selector, uint256(0)));
        hook.postExecute(address(0), account, data);
    }

    /// @notice Fix #3 (ERC20): fee paid in the forwarded token decrements the forwarded amount.
    function test_RemainderDecrement_Erc20FlowSameToken() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        usdc.mint(account, 1000e6);
        SourceStub src = new SourceStub(1000e6, address(usdc));

        (address[] memory t, uint256[] memory a, address[] memory r) = _one(address(usdc), 100e6, r1);
        _cycle(address(src), t, a, r);

        assertEq(hook.getOutAmount(account), 900e6, "forwarded 1000 USDC - 100 fee = 900");
        assertEq(hook.getOutToken(account), address(usdc), "outToken preserved");
    }

    /// @notice Fix #3 scoping: a fee in a DIFFERENT token than the flow leaves the forwarded amount unchanged.
    function test_RemainderUnchanged_FeeInDifferentToken() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 other = new MockERC20("OTH", "OTH", 18);
        other.mint(account, 5e18);
        SourceStub src = new SourceStub(1000e6, address(usdc)); // flow token = USDC

        (address[] memory t, uint256[] memory a, address[] memory r) = _one(address(other), 5e18, r1); // fee in OTHER
        _cycle(address(src), t, a, r);

        assertEq(hook.getOutAmount(account), 1000e6, "flow amount unchanged when fee is a different token");
        assertEq(hook.getOutToken(account), address(usdc), "outToken preserved");
    }
}
