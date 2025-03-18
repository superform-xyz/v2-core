// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IMinimalEntryPoint, PackedUserOperation } from "../../../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IDeBridgeGate } from "../../../src/vendor/bridges/debridge/IDeBridgeGate.sol";

/// @title DeBridgeReceiveFundsAndExecuteGateway
/// @author Superform Labs
/// @notice This contract acts as a gateway for receiving funds from the DeBridge Protocol
/// @notice and executing associated user operations.
contract DeBridgeReceiveFundsAndExecuteGateway {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable deBridgeGate;
    address public immutable entryPointAddress;
    address payable public immutable superBundler;

    struct DeBridgeClaimData {
        bytes32 debridgeId;
        uint256 amount;
        uint256 chainIdFrom;
        address receiver;
        uint256 nonce;
        bytes signatures;
        bytes autoParams;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event GatewayClaimed(bytes32 debridgeId, uint256 amount, uint256 chainIdFrom, address receiver, uint256 nonce);
    event DeBridgeFundsReceivedAndExecuted(PackedUserOperation[] userOps);

    constructor(address deBridgeGate_, address entryPointAddress_, address superBundler_) {
        if (deBridgeGate_ == address(0)) revert ADDRESS_NOT_VALID();
        if (entryPointAddress_ == address(0)) revert ADDRESS_NOT_VALID();
        deBridgeGate = deBridgeGate_;
        entryPointAddress = entryPointAddress_;
        superBundler = payable(superBundler_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function claim(DeBridgeClaimData[] memory batch, PackedUserOperation[] memory userOps) external {
        uint256 len = batch.length;
        for (uint256 i; i < len; ++i) {
            DeBridgeClaimData memory claimData = batch[i];

            IDeBridgeGate(deBridgeGate).claim(
                claimData.debridgeId,
                claimData.amount,
                claimData.chainIdFrom,
                claimData.receiver,
                claimData.nonce,
                claimData.signatures,
                claimData.autoParams
            );
            emit GatewayClaimed(
                claimData.debridgeId, claimData.amount, claimData.chainIdFrom, claimData.receiver, claimData.nonce
            );
        }

        IMinimalEntryPoint(entryPointAddress).handleOps(userOps, superBundler);
        emit DeBridgeFundsReceivedAndExecuted(userOps);
    }
}
