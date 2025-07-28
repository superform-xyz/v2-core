// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVaultBank, IVaultBankSource, IVaultBankDestination } from "../../src/vendor/superform/IVaultBank.sol";

contract MockVaultBank {
    function lockAsset(
        bytes32 yieldSourceOracleId,
        address account,
        address token,
        address,
        uint256 amount,
        uint64 toChainId
    )
        external
    {
        IERC20(token).transferFrom(account, address(this), amount);

        emit IVaultBankSource.SharesLocked(yieldSourceOracleId, account, token, amount, uint64(block.chainid), toChainId, 0);
    }

    function burnSuperPosition(
        uint256 amount_,
        address,
        uint64,
        bytes32
    )
        external
    {   
        emit IVaultBank.SuperpositionsBurned(address(0), address(this), address(0), amount_, uint64(block.chainid), 0);
    }

    function unlockAsset(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes32 yieldSourceOracleId,
        bytes calldata
    )
        external
    {
        IERC20(token).transfer(account, amount);

        emit IVaultBankSource.SharesUnlocked( yieldSourceOracleId, account, token, amount, uint64(block.chainid), fromChainId, 0);
    }
}
