// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IHookDataEncoder } from "../interfaces/IHookDataEncoder.sol";

contract ERC7540HookDataEncoder is IHookDataEncoder {
    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHookDataEncoder
    function encodeDepositData(
        address vault,
        address receiver,
        uint256 assets,
        bytes memory
    ) external pure override returns (bytes memory) {
        // For ERC7540 requestDeposit, we need:
        // - vault address
        // - receiver address
        // - amount
        // - usePrevHookAmount
        return abi.encodePacked(
            vault,
            receiver,
            assets,
            false // usePrevHookAmount
        );
    }

    /// @inheritdoc IHookDataEncoder
    function encodeWithdrawData(
        address vault,
        address receiver,
        address owner,
        uint256 shares,
        bytes memory
    ) external pure override returns (bytes memory) {
        // For ERC7540 requestRedeem, we need:
        // - vault address
        // - receiver address
        // - owner address
        // - shares
        // - usePrevHookAmount
        return abi.encodePacked(
            vault,
            receiver,
            owner,
            shares,
            false // usePrevHookAmount
        );
    }

    /// @inheritdoc IHookDataEncoder
    function getStandard() external pure override returns (string memory) {
        return "ERC7540";
    }
} 