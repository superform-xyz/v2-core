pragma solidity =0.8.28;

// External
import { ERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Interfaces
import { ISuperVault } from "./interfaces/ISuperVault.sol";
import { ISuperVaultStrategy } from "./interfaces/ISuperVaultStrategy.sol";
import {
    IERC7540Vault,
    IERC7540Operator,
    IERC7540Deposit,
    IERC7540Redeem,
    IERC7741
} from "../vendor/standards/ERC7540/IERC7540Vault.sol";
import { IERC7575 } from "../vendor/standards/ERC7575/IERC7575.sol";
import { ISuperVaultEscrow } from "./interfaces/ISuperVaultEscrow.sol";

/// @title SuperVault
/// @notice SuperVault vault contract implementing ERC7540 and ERC4626 standards
/// @author SuperForm Labs
contract SuperVault is ERC20, IERC7540Vault, IERC4626, ISuperVault {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant REQUEST_ID = 0;

    // EIP712 TypeHash
    bytes32 public constant AUTHORIZE_OPERATOR_TYPEHASH =
        keccak256("AuthorizeOperator(address controller,address operator,bool approved,bytes32 nonce,uint256 deadline)");

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    bool public initialized;

    // Token metadata
    string private vaultName;
    string private vaultSymbol;

    address public share;

    // Domain separator
    bytes32 private _DOMAIN_SEPARATOR;
    bytes32 private _NAME_HASH;
    bytes32 private _VERSION_HASH;
    uint256 public deploymentChainId;

    // 4626
    IERC20 private _asset;
    uint8 private _underlyingDecimals;

    // Strategy
    ISuperVaultStrategy public strategy;
    address public escrow;

    /// @inheritdoc IERC7540Operator
    mapping(address owner => mapping(address operator => bool)) public isOperator;

    // Authorization tracking
    mapping(address controller => mapping(bytes32 nonce => bool used)) private _authorizations;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("", "") {
        // Empty constructor for proxy initialization
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the vault with required parameters
    /// @param asset_ The underlying asset token address
    /// @param name_ The name of the vault token
    /// @param symbol_ The symbol of the vault token
    /// @param strategy_ The strategy contract address
    /// @param escrow_ The escrow contract address
    function initialize(
        address asset_,
        string memory name_,
        string memory symbol_,
        address strategy_,
        address escrow_
    )
        external
    {
        if (initialized) revert ALREADY_INITIALIZED();
        if (asset_ == address(0)) revert INVALID_ASSET();
        if (strategy_ == address(0)) revert INVALID_STRATEGY();
        if (escrow_ == address(0)) revert INVALID_ESCROW();

        initialized = true;

        // Store name and symbol
        vaultName = name_;
        vaultSymbol = symbol_;

        // Initialize asset and decimals
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = success ? assetDecimals : 18;
        _asset = IERC20(asset_);
        share = address(this);
        strategy = ISuperVaultStrategy(strategy_);
        escrow = escrow_;

        // Initialize EIP712 domain separator
        _NAME_HASH = keccak256(bytes(name_));
        _VERSION_HASH = keccak256(bytes("1"));
        deploymentChainId = block.chainid;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the token
    function name() public view virtual override(IERC20Metadata, ERC20) returns (string memory) {
        return vaultName;
    }

    /// @notice Returns the symbol of the token
    function symbol() public view virtual override(IERC20Metadata, ERC20) returns (string memory) {
        return vaultSymbol;
    }

    /*//////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    //--ERC7540--

    /// @inheritdoc IERC7540Deposit
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256) {
        if (assets == 0) revert ZERO_AMOUNT();
        if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert INVALID_OWNER_OR_OPERATOR();

        if (_asset.balanceOf(owner) < assets) revert INVALID_AMOUNT();

        // Transfer assets to vault
        _asset.safeTransferFrom(owner, address(this), assets);

        // Forward to strategy
        _asset.forceApprove(address(strategy), assets);
        strategy.handleOperation(controller, assets, ISuperVaultStrategy.Operation.DepositRequest);
        _asset.forceApprove(address(strategy), 0);

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    /// @notice Cancel a pending deposit request and return assets to the user
    /// @param controller The controller address
    function cancelDeposit(address controller) external {
        _validateController(controller);

        // Get assets from strategy
        uint256 assets = strategy.pendingDepositRequest(controller);
        if (assets == 0) revert REQUEST_NOT_FOUND();

        // Forward to strategy
        strategy.handleOperation(controller, assets, ISuperVaultStrategy.Operation.CancelDeposit);

        // Return assets to user
        _asset.safeTransfer(msg.sender, assets);

        emit DepositRequestCancelled(controller, msg.sender);
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256) {
        if (shares == 0) revert ZERO_AMOUNT();
        if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert INVALID_OWNER_OR_OPERATOR();

        if (balanceOf(owner) < shares) revert INVALID_AMOUNT();

        // If msg.sender is operator of owner, the transfer is executed as if
        // the sender is the owner, to bypass the allowance check
        address sender = isOperator[owner][msg.sender] ? owner : msg.sender;

        // Transfer shares to escrow for temporary locking
        _approve(sender, escrow, shares);
        ISuperVaultEscrow(escrow).escrowShares(sender, shares);

        // Forward to strategy
        strategy.handleOperation(controller, shares, ISuperVaultStrategy.Operation.RedeemRequest);

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /// @notice Cancel a pending redeem request and return shares to the user
    /// @param controller The controller address
    function cancelRedeem(address controller) external {
        _validateController(controller);

        uint256 shares = strategy.pendingRedeemRequest(controller);
        if (shares == 0) revert REQUEST_NOT_FOUND();

        // Forward to strategy
        strategy.handleOperation(controller, shares, ISuperVaultStrategy.Operation.CancelRedeem);

        // Return shares to user
        ISuperVaultEscrow(escrow).returnShares(msg.sender, shares);

        emit RedeemRequestCancelled(controller, msg.sender);
    }

    //--Operator Management--

    /// @inheritdoc IERC7540Operator
    function setOperator(address operator, bool approved) public returns (bool success) {
        if (msg.sender == operator) revert UNAUTHORIZED();
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    /// @inheritdoc IERC7741
    function authorizeOperator(
        address controller,
        address operator,
        bool approved,
        bytes32 nonce,
        uint256 deadline,
        bytes memory signature
    )
        external
        returns (bool)
    {
        if (controller == operator) revert UNAUTHORIZED();
        if (block.timestamp > deadline) revert TIMELOCK_NOT_EXPIRED();
        if (_authorizations[controller][nonce]) revert UNAUTHORIZED();

        _authorizations[controller][nonce] = true;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(AUTHORIZE_OPERATOR_TYPEHASH, controller, operator, approved, nonce, deadline))
            )
        );

        if (!_isValidSignature(controller, digest, signature)) revert INVALID_SIGNATURE();

        isOperator[controller][operator] = approved;
        emit OperatorSet(controller, operator, approved);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                    USER EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //--ERC7540--

    function pendingDepositRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 pendingAssets)
    {
        return strategy.pendingDepositRequest(controller);
    }

    function claimableDepositRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 claimableAssets)
    {
        return maxDeposit(controller);
    }

    function pendingRedeemRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 pendingShares)
    {
        return strategy.pendingRedeemRequest(controller);
    }

    function claimableRedeemRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 claimableShares)
    {
        return maxRedeem(controller);
    }

    //--Operator Management--

    /// @inheritdoc IERC7741
    function authorizations(address controller, bytes32 nonce) external view returns (bool used) {
        return _authorizations[controller][nonce];
    }

    /// @inheritdoc IERC7741
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator();
    }

    /// @inheritdoc IERC7741
    function invalidateNonce(bytes32 nonce) external {
        if (nonce == bytes32(0)) revert INVALID_NONCE();
        _authorizations[msg.sender][nonce] = true;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return _underlyingDecimals;
    }

    /// @inheritdoc IERC4626
    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256) {
        (uint256 totalAssets_,) = strategy.totalAssets();
        return totalAssets_;
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : Math.mulDiv(assets, supply, totalAssets(), Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : Math.mulDiv(shares, totalAssets(), supply, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function maxMint(address owner) public view override returns (uint256) {
        return strategy.getSuperVaultState(owner, 1);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address owner) public view override returns (uint256) {
        return convertToAssets(maxMint(owner));
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view override returns (uint256) {
        return strategy.getSuperVaultState(owner, 2);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override returns (uint256) {
        return convertToShares(maxWithdraw(owner));
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 /*assets*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 /*shares*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 /*assets*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 /*shares*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC7540Deposit
    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        _validateController(controller);

        uint256 averageDepositPrice = strategy.getSuperVaultState(controller, 3);
        if (averageDepositPrice == 0) revert INVALID_DEPOSIT_PRICE();

        // Convert maxMint to assets using average deposit price
        uint256 maxAssets = maxMint(controller).mulDiv(averageDepositPrice, 1e18, Math.Rounding.Floor);
        if (assets > maxAssets) revert INVALID_DEPOSIT_CLAIM();

        // Calculate shares based on assets and average price
        shares = assets.mulDiv(1e18, averageDepositPrice, Math.Rounding.Floor);

        // Forward to strategy
        strategy.handleOperation(controller, shares, ISuperVaultStrategy.Operation.ClaimDeposit);

        // Transfer shares to receiver
        ISuperVaultEscrow(escrow).transferShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        shares = deposit(assets, receiver, msg.sender);
    }

    /// @inheritdoc IERC7540Deposit
    function mint(uint256 shares, address receiver, address controller) public returns (uint256 assets) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        _validateController(controller);

        uint256 maxMintAmount = maxMint(controller);

        if (shares > maxMintAmount) revert INVALID_DEPOSIT_CLAIM();
        uint256 averageDepositPrice = strategy.getSuperVaultState(controller, 3);
        if (averageDepositPrice == 0) revert INVALID_DEPOSIT_PRICE();
        assets = shares.mulDiv(averageDepositPrice, 1e18, Math.Rounding.Floor);

        // Forward to strategy
        strategy.handleOperation(controller, shares, ISuperVaultStrategy.Operation.ClaimDeposit);

        // Transfer shares to receiver
        ISuperVaultEscrow(escrow).transferShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = mint(shares, receiver, msg.sender);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        _validateController(owner);

        uint256 averageWithdrawPrice = strategy.getSuperVaultState(owner, 4);
        if (averageWithdrawPrice == 0) revert INVALID_WITHDRAW_PRICE();

        uint256 maxWithdrawAmount = maxWithdraw(owner);
        if (assets > maxWithdrawAmount) revert INVALID_AMOUNT();

        // Calculate shares based on assets and average withdraw price
        shares = assets.mulDiv(1e18, averageWithdrawPrice, Math.Rounding.Floor);

        // Forward to strategy
        // true assets transferred are returned here
        assets = strategy.handleOperation(owner, assets, ISuperVaultStrategy.Operation.ClaimRedeem);

        // Transfer shares back to vault and burn them
        ISuperVaultEscrow(escrow).transferShares(address(this), shares);
        _burn(address(this), shares);
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        _validateController(owner);

        uint256 averageWithdrawPrice = strategy.getSuperVaultState(owner, 4);
        if (averageWithdrawPrice == 0) revert INVALID_WITHDRAW_PRICE();

        // Calculate assets based on shares and average withdraw price
        assets = shares.mulDiv(averageWithdrawPrice, 1e18, Math.Rounding.Floor);

        uint256 maxWithdrawAmount = maxWithdraw(owner);

        if (assets > maxWithdrawAmount) revert INVALID_AMOUNT();

        // Forward to strategy
        // true assets transferred are returned here
        assets = strategy.handleOperation(owner, assets, ISuperVaultStrategy.Operation.ClaimRedeem);

        // Transfer shares back to vault and burn them
        ISuperVaultEscrow(escrow).transferShares(address(this), shares);
        _burn(address(this), shares);
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Mint new shares, only callable by strategy
    /// @param amount The amount of shares to mint
    function mintShares(uint256 amount) external {
        if (msg.sender != address(strategy)) revert UNAUTHORIZED();
        _mint(escrow, amount);
    }

    /// @notice Callback function for when a deposit becomes claimable
    /// @param user The user whose deposit is claimable
    /// @param assets The amount of assets deposited
    /// @param shares The amount of shares to be received
    function onDepositClaimable(address user, uint256 assets, uint256 shares) external {
        if (msg.sender != address(strategy)) revert UNAUTHORIZED();
        emit DepositClaimable(user, REQUEST_ID, assets, shares);
    }

    /// @notice Callback function for when a redeem becomes claimable
    /// @param user The user whose redeem is claimable
    /// @param assets The amount of assets to be received
    /// @param shares The amount of shares redeemed
    function onRedeemClaimable(address user, uint256 assets, uint256 shares) external {
        if (msg.sender != address(strategy)) revert UNAUTHORIZED();
        emit RedeemClaimable(user, REQUEST_ID, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC165 INTERFACE
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC7540Vault).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC7741).interfaceId || interfaceId == type(IERC4626).interfaceId
            || interfaceId == type(IERC7575).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateController(address controller) internal view {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert INVALID_CONTROLLER();
    }

    /// @notice Calculate the EIP712 domain separator
    function _calculateDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Verify an EIP712 signature
    function _isValidSignature(address signer, bytes32 digest, bytes memory signature) internal pure returns (bool) {
        if (signature.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) v += 27;
        if (v != 27 && v != 28) return false;

        address recoveredSigner = ecrecover(digest, v, r, s);
        return recoveredSigner != address(0) && recoveredSigner == signer;
    }

    /**
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     */
    function _tryGetAssetDecimals(address asset_) private view returns (bool ok, uint8 assetDecimals) {
        (bool success, bytes memory encodedDecimals) =
            address(asset_).staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }
}
