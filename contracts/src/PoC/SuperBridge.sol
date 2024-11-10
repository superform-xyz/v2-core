// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/console.sol";
/*
    SuperBridge represents a message bridge contract that forwards messages from one chain to another.
    The relayer (off-chain component) calls the release function to forward calldata to the destination contract.
The send function is called by the source chain to emit an event containing the destination chain ID, destination
contract address, and data.
    !!! ONLY FOR POC PURPOSES !!!*/

contract SuperBridge {
    address public relayer;

    event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data);

    // Only the relayer (off-chain component) can call this contract
    modifier onlyRelayer() {
        require(msg.sender == relayer, "Only relayer can call this function");
        _;
    }

    constructor(address _relayer) {
        relayer = _relayer;
    }

    function setRelayer(address _relayer) public {
        relayer = _relayer;
    }

    // release forwards the calldata to the destination contract.
    // Can be executed only by the relayer.
    function release(address addr, bytes memory data) public onlyRelayer {
        (bool success,) = addr.call(data);
        require(success, "Call to destination contract failed");
    }

    // send emits an event containing the destination chain ID, destination contract address, and data.
    function send(uint256 dstChainId, address addr, bytes memory data) public {
        console.log(
            "                   SuperBridge: sending message. Event emitted with dstChainId: %s, addr: %s, data size: %s",
            dstChainId,
            addr,
            data.length
        );
        emit Msg(dstChainId, addr, data);
    }
}
