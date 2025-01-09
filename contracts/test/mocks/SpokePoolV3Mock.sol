// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AcrossBridgeGateway} from "src/bridges/AcrossBridgeGateway.sol";

contract SpokePoolV3Mock {
    AcrossBridgeGateway public acrossBridgeGateway;

    function setAcrossBridgeGateway(address acrossBridgeGateway_) external {
        acrossBridgeGateway = AcrossBridgeGateway(acrossBridgeGateway_);
    }

    function depositV3Now(
        address, //depositor
        address recipient,
        address inputToken,
        address, //outputToken
        uint256 inputAmount,
        uint256, //outputAmount
        uint256, //destinationChainId
        address exclusiveRelayer,
        uint32, //fillDeadlineOffset
        uint32, //exclusivityDeadline
        bytes calldata message
    ) external payable {
        IERC20(inputToken).transferFrom(recipient, address(acrossBridgeGateway), inputAmount);
        acrossBridgeGateway.handleV3AcrossMessage(inputToken, inputAmount, exclusiveRelayer, message);
    }
}
