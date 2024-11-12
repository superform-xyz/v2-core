// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { CounterMock } from "test/mocks/CounterMock.sol";
import { IncrementMock } from "test/mocks/IncrementMock.sol";
import { IDeBridgeGate } from "src/interfaces/vendors/IDeBridgeGate.sol";
import { ModulesShared } from "test/shared/ModulesShared.t.sol";

contract DeBridgeMockTests is ModulesShared {
    address public constant DEBRIDGE_GATE = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    uint256 public constant MAINNET_CHAIN_ID = 1;
    uint256 public constant ARBITRUM_CHAIN_ID = 42_161;

    CounterMock public counterMock;
    IncrementMock public incrementMock;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork(arbitrumFork);
        incrementMock = new IncrementMock();
        incrementMock.setGate(DEBRIDGE_GATE);

        vm.selectFork(mainnetFork);
        counterMock = new CounterMock();
        counterMock.setGate(DEBRIDGE_GATE);

        vm.selectFork(arbitrumFork);
        incrementMock.registerCounter(MAINNET_CHAIN_ID, address(incrementMock));
    }

    function test_increment() public {
        vm.selectFork(arbitrumFork);

        vm.expectRevert(IncrementMock.INSUFFICIENT_FEE.selector);
        incrementMock.increment(10);

        incrementMock.increment{ value: 1 ether }(10);

        //todo: add claim
    }
}
