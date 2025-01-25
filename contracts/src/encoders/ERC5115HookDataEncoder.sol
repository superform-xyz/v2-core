// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IHookDataEncoder } from "../interfaces/IHookDataEncoder.sol";
import { IERC5115 } from "../interfaces/vendors/vaults/5115/IERC5115.sol";

contract ERC5115HookDataEncoder is IHookDataEncoder {
    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHookDataEncoder
    function encodeDepositData(
        address vault,
        address receiver,
        uint256 assets,
        bytes memory extraData
    ) external view override returns (bytes memory) {
        // For ERC5115, we need:
        // - vault address
        // - receiver address
        // - tokenIn (asset) address
        // - amount
        // - minSharesOut (calculated by oracle)
        // - depositFromInternalBalance
        // - usePrevHookAmount
        return abi.encodePacked(
            vault,
            receiver,
            IERC5115(vault).asset(),
            assets,
            uint256(0), // minSharesOut - calculated by oracle
            false, // depositFromInternalBalance
            false // usePrevHookAmount
        );
    }

    /// @inheritdoc IHookDataEncoder
    function encodeWithdrawData(
        address vault,
        address receiver,
        address owner,
        uint256 shares,
        bytes memory extraData
    ) external view override returns (bytes memory) {
        // For ERC5115, we need:
        // - vault address
        // - receiver address
        // - tokenOut (asset) address
        // - shares
        // - minTokenOut (calculated by oracle)
        // - burnFromInternalBalance
        // - usePrevHookAmount
        return abi.encodePacked(
            vault,
            receiver,
            IERC5115(vault).asset(),
            shares,
            uint256(0), // minTokenOut - calculated by oracle
            false, // burnFromInternalBalance
            false // usePrevHookAmount
        );
    }

    /// @inheritdoc IHookDataEncoder
    function getStandard() external pure override returns (string memory) {
        return "ERC5115";
    }
} 