// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { INativeFeeSponsorship } from "../interfaces/INativeFeeSponsorship.sol";

/// @title NativeFeeSponsorship
/// @author Superform Labs
/// @notice Ledger contract for sponsoring native ETH for smart account operations (e.g., Stargate messaging fees)
/// @dev Open balance model: no signatures or nonces. Sponsors deposit ETH keyed by (sponsor, account),
///      and smart accounts withdraw via hooks. Sponsors can reclaim unused deposits.
contract NativeFeeSponsorship is INativeFeeSponsorship, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of sponsored native ETH balances: sponsor => account => amount
    mapping(address sponsor => mapping(address account => uint256 amount)) internal sponsoredNative;

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INativeFeeSponsorship
    function depositForAccount(address sponsor, address account) external payable nonReentrant {
        if (sponsor == address(0)) revert ZERO_ADDRESS();
        if (account == address(0)) revert ZERO_ADDRESS();
        if (msg.value == 0) revert ZERO_AMOUNT();
        if (msg.sender != sponsor) revert UNAUTHORIZED_DEPOSITOR();

        sponsoredNative[sponsor][account] += msg.value;

        emit NativeDeposited(sponsor, account, msg.value);
    }

    /// @inheritdoc INativeFeeSponsorship
    function withdrawSponsoredNative(address sponsor, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = sponsoredNative[sponsor][msg.sender];
        if (available < amount) revert INSUFFICIENT_SPONSORED_BALANCE();

        sponsoredNative[sponsor][msg.sender] = available - amount;

        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();

        emit NativeWithdrawnByAccount(sponsor, msg.sender, amount);
    }

    /// @inheritdoc INativeFeeSponsorship
    function withdrawSponsorDeposit(address account, address payable to, uint256 amount) external nonReentrant {
        if (account == address(0)) revert ZERO_ADDRESS();
        if (to == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = sponsoredNative[msg.sender][account];
        if (available < amount) revert INSUFFICIENT_SPONSORED_BALANCE();

        sponsoredNative[msg.sender][account] = available - amount;

        (bool success,) = to.call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();

        emit NativeWithdrawnBySponsor(msg.sender, account, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INativeFeeSponsorship
    function sponsoredAmount(address sponsor, address account) external view returns (uint256) {
        return sponsoredNative[sponsor][account];
    }
}
