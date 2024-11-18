// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { DlnOrderLib } from "src/libraries/vendors/deBridge/DlnOrderLib.sol";

import "forge-std/console.sol";

contract DlnSourceMock {
    function createOrder(
        DlnOrderLib.OrderCreation calldata,
        bytes calldata,
        uint32,
        bytes calldata
    )
        external
        payable
        returns (bytes32)
    {
        console.log("--- DlnSourceMock: order created");
        return keccak256("mockOrder");
    }
}
