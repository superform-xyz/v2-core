// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

contract SuperBridge {
    address public relayer;

    event Msg(
        uint256 indexed destinationChainId,
        address indexed destinationContract,
        bytes data
    );

    // Only the relayer (off-chain component) can call this contract
    modifier onlyRelayer() {
        require(msg.sender == relayer, "Only relayer can call this function");
        _;
    }

    constructor(address _relayer) {
        relayer = _relayer;
    }

    // Relayer calls this function, forwarding calldata to the destination contract
    function release(address addr, bytes memory data) public onlyRelayer {
        (bool success, ) = addr.call(data);
        require(success, "Call to destination contract failed");
    }

    function send(uint256 dstChainId, address addr, bytes memory data) public {
        emit Msg(dstChainId, addr, data);
    }
}
