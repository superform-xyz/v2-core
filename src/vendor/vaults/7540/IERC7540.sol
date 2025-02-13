// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IERC7575 {
    /// @notice Get the balance of the account
    /// @param account The address of the account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Get the address of the underlying asset
    function asset() external view returns (address);

    /// @notice Get the address of the share token
    function share() external view returns (address);

    /// @notice Convert assets to shares
    /// @param assets The amount of assets to convert
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @notice Convert shares to assets
    /// @param shares The amount of shares to convert
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @notice Get the maximum amount of assets that can be deposited
    /// @param receiver The address of the receiver
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /// @notice Get the maximum amount of shares that can be minted
    /// @param receiver The address of the receiver
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /// @notice Get the maximum amount of assets that can be withdrawn
    /// @param owner The address of the owner
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /// @notice Get the maximum amount of shares that can be redeemed
    /// @param owner The address of the owner
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /// @notice Preview the amount of shares that would be received for a given amount of assets
    /// @param assets The amount of assets to deposit
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /// @notice Preview the amount of assets that would be received for a given amount of shares
    /// @param shares The amount of shares to mint
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /// @notice Preview the amount of shares that would be received for a given amount of assets
    /// @param assets The amount of assets to withdraw
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
}
// As defined by https://eips.ethereum.org/EIPS/eip-7540#request-flows

interface IERC7540 is IERC7575 {
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );

    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if the contract supports an interface
    /// @param interfaceId The selector of the interface to check
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /// @notice Preview the amount of assets that would be received for a given amount of shares
    /// @param shares The amount of shares to redeem
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /// @notice Check if a deposit request is pending
    /// @param requestId The id of the request to check
    /// @param controller The address of the controller
    function pendingDepositRequest(uint256 requestId, address controller) external view returns (bool);

    /// @notice Check if a deposit request is pending cancellation
    /// @param requestId The id of the request to check
    /// @param controller The address of the controller
    function pendingCancelDepositRequest(uint256 requestId, address controller) external view returns (bool);

    /// @notice Get the amount of assets that can be claimed from a deposit request
    /// @param requestId The id of the request to check
    /// @param controller The address of the controller
    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256);

    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256);

    /// @notice Check if a redeem request is pending cancellation
    /// @param requestId The id of the request to check
    /// @param controller The address of the controller
    function pendingCancelRedeemRequest(uint256 requestId, address controller) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mints amount of shares by claiming the controller's request
    /// @dev sender must be the controller or an operator approved by the controller
    /// @param assets The amount of assets to deposit
    /// @param receiver The address of the receiver
    /// @param controller The address of the controller
    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares);

    /// @notice Mint exact amount of shares into the vault by claiming the controller's request
    /// @param shares The amount of shares to mint
    /// @param receiver The address of the receiver
    /// @param controller The address of the controller
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    /// @notice Burn shares from the vault and sends exact amount of assets to the receiver
    /// @param assets The amount of assets to withdraw
    /// @param receiver The address of the receiver
    /// @param owner The address of the owner
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /// @notice Burns exact shares from the vault and sends assets to the receiver
    /// @param shares The amount of shares to redeem
    /// @param receiver The address of the receiver
    /// @param owner The address of the owner
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /// @notice Request a deposit of assets
    /// @param assets The amount of assets to deposit
    /// @param controller The address of the controller
    /// @param owner The address of the owner
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);

    /// @notice Request a redeem of shares
    /// @param shares The amount of shares to redeem
    /// @param controller The address of the controller
    /// @param owner The address of the owner
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);

    /// @notice Cancel a deposit request
    /// @param requestId The id of the request to cancel
    /// @param controller The address of the controller
    function cancelDepositRequest(uint256 requestId, address controller) external;

    /// @notice Claims the canceled deposit assets, and removes the pending cancelation Request
    /// @dev sender must be the controller
    /// @param requestId The id of the request to claim
    /// @param receiver The address of the receiver
    /// @param controller The address of the controller
    function claimCancelDepositRequest(
        uint256 requestId,
        address receiver,
        address controller
    )
        external
        returns (uint256 assets);

    /// @notice Cancel a redeem request
    /// @param requestId The id of the request to cancel
    /// @param controller The address of the controller
    function cancelRedeemRequest(uint256 requestId, address controller) external;

    /// @notice Claims the canceled redeem shares, and removes the pending cancelation Request
    /// @dev sender must be the controller
    /// @param requestId The id of the request to claim
    /// @param receiver The address of the receiver
    /// @param controller The address of the controller
    function claimCancelRedeemRequest(
        uint256 requestId,
        address receiver,
        address controller
    )
        external
        returns (uint256 shares);

    /// @notice Get the pool id
    function poolId() external view returns (uint64);

    /// @notice Get the tranche id
    function trancheId() external view returns (bytes16);

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    function setOperator(address operator, bool approved) external returns (bool);
    function isOperator(address controller, address operator) external view returns (bool status);
}
