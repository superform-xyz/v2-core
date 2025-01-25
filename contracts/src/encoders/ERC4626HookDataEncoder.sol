// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IHookDataEncoder } from "../interfaces/IHookDataEncoder.sol";

contract ERC4626HookDataEncoder is IHookDataEncoder {
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
        return abi.encodePacked(vault, receiver, assets, false);
    }

    /// @inheritdoc IHookDataEncoder
    function encodeWithdrawData(
        address vault,
        address receiver,
        address owner,
        uint256 shares,
        bytes memory
    ) external pure override returns (bytes memory) {
        return abi.encodePacked(vault, receiver, owner, shares, false);
    }

    /// @inheritdoc IHookDataEncoder
    function getStandard() external pure override returns (string memory) {
        return "ERC4626";
    }
} 