// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAerodromeUniversalRouter } from "../../src/vendor/aerodrome/IAerodromeUniversalRouter.sol";
import { MockERC20 } from "./MockERC20.sol";

contract MockAerodromeUniversalRouter is IAerodromeUniversalRouter {
    address public inputToken;
    address public outputToken;
    uint256 public outputAmount;
    uint256 public outputBurnAmount;

    bytes public lastCommands;
    address public lastRecipient;
    uint256 public lastAmountIn;
    uint256 public lastAmountOutMin;
    bytes public lastPackedPath;
    bool public lastPayerIsUser;
    bool public lastIsUni;
    uint256 public lastDeadline;

    function configure(
        address inputToken_,
        address outputToken_,
        uint256 outputAmount_,
        uint256 outputBurnAmount_
    )
        external
    {
        inputToken = inputToken_;
        outputToken = outputToken_;
        outputAmount = outputAmount_;
        outputBurnAmount = outputBurnAmount_;
    }

    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    )
        external
        payable
        override
    {
        require(msg.value == 0, "unexpected value");
        require(commands.length == 1 && inputs.length == 1, "invalid plan");

        (
            address recipient,
            uint256 amountIn,
            uint256 amountOutMin,
            bytes memory packedPath,
            bool payerIsUser,
            bool isUni
        ) = abi.decode(inputs[0], (address, uint256, uint256, bytes, bool, bool));

        require(payerIsUser && !isUni, "invalid mode");

        lastCommands = commands;
        lastRecipient = recipient;
        lastAmountIn = amountIn;
        lastAmountOutMin = amountOutMin;
        lastPackedPath = packedPath;
        lastPayerIsUser = payerIsUser;
        lastIsUni = isUni;
        lastDeadline = deadline;

        require(IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn), "input transfer failed");

        if (outputBurnAmount != 0) MockERC20(outputToken).burn(recipient, outputBurnAmount);
        if (outputAmount != 0) MockERC20(outputToken).mint(recipient, outputAmount);
    }
}
