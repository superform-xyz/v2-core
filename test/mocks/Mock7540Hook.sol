// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Mock7540Hook {
    address public immutable assetToken;
    uint256 public lastRequestId;
    mapping(address => uint256) public depositRequests;
    mapping(address => uint256) public canceledDepositRequests;

    constructor(address _assetToken) {
        assetToken = _assetToken;
    }

    function asset() external view returns (address) {
        return assetToken;
    }

    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256) {
        IERC20(assetToken).transferFrom(owner, address(this), assets);
        depositRequests[controller] += assets;
        return assets;
    }

    function cancelDepositRequest(uint256, address controller) external {
        canceledDepositRequests[controller] += depositRequests[controller];
        depositRequests[controller] = 0;
    }

    function claimCancelDepositRequest(uint256, address receiver, address controller) external returns (uint256) {
        IERC20(assetToken).transfer(receiver, canceledDepositRequests[controller]);
        canceledDepositRequests[controller] = 0;
        return canceledDepositRequests[controller];
    }
}
