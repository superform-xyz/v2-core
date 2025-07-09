// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { BatchTransferFromHook } from "../../../../../src/hooks/tokens/permit2/BatchTransferFromHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPermit2Batch, IAllowanceTransfer } from "../../../../../src/vendor/uniswap/permit2/IPermit2Batch.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @notice Mock Permit2Batch that only bumps nonce for the first detail.
contract MockLeakyPermit2 is IPermit2Batch {
    mapping(address => mapping(address => mapping(address => uint256))) public nonces;
    mapping(address => mapping(address => mapping(address => uint256))) public allowance;

    function permit(address owner, IAllowanceTransfer.PermitBatch calldata batch, bytes calldata) external override {
        // validate and bump only the first token’s nonce
        IAllowanceTransfer.PermitDetails calldata d0 = batch.details[0];
        require(nonces[owner][batch.spender][d0.token] == d0.nonce, "Bad nonce for token 0");
        nonces[owner][batch.spender][d0.token]++;

        // reset allowance for all tokens
        for (uint256 i; i < batch.details.length; i++) {
            allowance[owner][batch.spender][batch.details[i].token] = batch.details[i].amount;
        }
    }

    function transferFrom(IAllowanceTransfer.AllowanceTransferDetails[] calldata details) external override {
        for (uint256 i; i < details.length; i++) {
            IAllowanceTransfer.AllowanceTransferDetails calldata dt = details[i];
            uint256 allowed = allowance[dt.from][dt.to][dt.token];
            require(allowed >= dt.amount, "Insufficient allowance");
            allowance[dt.from][dt.to][dt.token] = allowed - dt.amount;
            IERC20(dt.token).transferFrom(dt.from, dt.to, dt.amount);
        }
    }
}

/// @notice Minimal ERC20.
contract MockToken is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
    }

    function transfer(address to, uint256 amt) external override returns (bool) {
        require(balanceOf[msg.sender] >= amt, "balance");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function approve(address sp, uint256 amt) external override returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external override returns (bool) {
        require(allowance[f][msg.sender] >= a, "allowance");
        allowance[f][msg.sender] -= a;
        require(balanceOf[f] >= a, "balance");
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

/// @notice Forge test showing the replay on the first token only.
contract BatchTransferFromReplayTest is Test {
    MockToken tokenA;
    MockLeakyPermit2 permit2;
    BatchTransferFromHook hook;

    function setUp() public {
        tokenA = new MockToken();
        permit2 = new MockLeakyPermit2();
        hook = new BatchTransferFromHook(address(permit2));
        tokenA.mint(address(this), 500);
        tokenA.mint(address(permit2), 500);
    }

    function testReplayOnSingleTokenBatch() public {
        // Build hook data for 1 token
        bytes memory data = abi.encodePacked(
            address(this),
            uint256(1),
            block.timestamp + 1 days,
            abi.encodePacked(address(tokenA)),
            abi.encodePacked(uint256(100)),
            new bytes(65)
        );
        Execution[] memory execs = hook.build(address(0), address(this), data);

        // First permit should pass
        (bool ok,) = address(permit2).call(execs[1].callData);
        assertTrue(ok, "first permit must pass");

        // Second permit MUST revert on reused nonce
        vm.expectRevert("Bad nonce for token 0");
        (ok,) = address(permit2).call(execs[1].callData);
    }
}
