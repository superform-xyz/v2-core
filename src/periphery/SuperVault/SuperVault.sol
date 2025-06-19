// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Interfaces
import { ISuperVault } from "../interfaces/SuperVault/ISuperVault.sol";
import { ISuperVaultStrategy } from "../interfaces/SuperVault/ISuperVaultStrategy.sol";
import { IERC7540Operator, IERC7540Redeem, IERC7741 } from "../../vendor/standards/ERC7540/IERC7540Vault.sol";
import { IERC7575 } from "../../vendor/standards/ERC7575/IERC7575.sol";
import { ISuperVaultEscrow } from "../interfaces/SuperVault/ISuperVaultEscrow.sol";

// Libraries
import { AssetMetadataLib } from "../libraries/AssetMetadataLib.sol";

/// @title SuperVault
/// @author Superform Labs
/// @notice SuperVault vault contract implementing ERC4626 with synchronous deposits and asynchronous redeems via
/// ERC7540
contract SuperVault is ERC20, IERC7540Redeem, IERC7741, IERC4626, ISuperVault, ReentrancyGuard {
    using AssetMetadataLib for address;
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
    string private vaultName;
    string private vaultSymbol;
    address public share;
    bytes32 private _DOMAIN_SEPARATOR;
    bytes32 private _NAME_HASH;
    bytes32 private _VERSION_HASH;
    uint256 public deploymentChainId;
    address public deploymentAddress;
    IERC20 private _asset;
    uint8 private _underlyingDecimals;
    ISuperVaultStrategy public strategy;
    address public escrow;
    uint256 public PRECISION;

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

        // Set asset and precision
        _asset = IERC20(asset_);
        (bool success, uint8 assetDecimals) = asset_.tryGetAssetDecimals();
        _underlyingDecimals = success ? assetDecimals : 18;
        PRECISION = 10 ** _underlyingDecimals;
        share = address(this);
        strategy = ISuperVaultStrategy(strategy_);
        escrow = escrow_;

        // Initialize EIP712 domain separator
        _NAME_HASH = keccak256(bytes(name_));
        _VERSION_HASH = keccak256(bytes("1"));
        deploymentChainId = block.chainid;
        deploymentAddress = address(this);
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/
    function name() public view virtual override(IERC20Metadata, ERC20) returns (string memory) {
        return vaultName;
    }

    function symbol() public view virtual override(IERC20Metadata, ERC20) returns (string memory) {
        return vaultSymbol;
    }

    /*//////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (assets == 0) revert ZERO_AMOUNT();

        uint256 currentPPS = _getStoredPPSWithRevert();

        shares = Math.mulDiv(assets, PRECISION, currentPPS, Math.Rounding.Floor);
        if (shares == 0) revert ZERO_AMOUNT();

        _asset.safeTransferFrom(msg.sender, address(strategy), assets);

        strategy.handleOperation(msg.sender, receiver, assets, shares, ISuperVaultStrategy.Operation.Deposit);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256 assets) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (shares == 0) revert ZERO_AMOUNT();

        uint256 currentPPS = _getStoredPPSWithRevert();

        assets = Math.mulDiv(shares, currentPPS, PRECISION, Math.Rounding.Ceil);
        if (assets == 0) revert ZERO_AMOUNT();

        _asset.safeTransferFrom(msg.sender, address(strategy), assets);

        strategy.handleOperation(msg.sender, receiver, assets, shares, ISuperVaultStrategy.Operation.Deposit);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC7540Redeem
    /// @notice Once owner has authorized an operator, the operator can request a redeem with any controller address
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256) {
        if (shares == 0) revert ZERO_AMOUNT();
        if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert INVALID_OWNER_OR_OPERATOR();
        if (balanceOf(owner) < shares) revert INVALID_AMOUNT();

        // Transfer shares to escrow for temporary locking
        _approve(owner, escrow, shares);
        ISuperVaultEscrow(escrow).escrowShares(owner, shares);

        // Forward to strategy
        strategy.handleOperation(controller, address(0), 0, shares, ISuperVaultStrategy.Operation.RedeemRequest);

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /// @inheritdoc ISuperVault
    function cancelRedeem(address controller) external {
        _validateController(controller);

        uint256 shares = strategy.pendingRedeemRequest(controller);
        if (shares == 0) revert REQUEST_NOT_FOUND();

        // Forward to strategy
        strategy.handleOperation(controller, address(0), 0, 0, ISuperVaultStrategy.Operation.CancelRedeem);

        // Return shares to controller
        ISuperVaultEscrow(escrow).returnShares(controller, shares);

        emit RedeemRequestCancelled(controller, msg.sender);
    }

    /// @inheritdoc IERC7540Operator
    function setOperator(address operator, bool approved) external returns (bool success) {
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

    /// @inheritdoc IERC7540Redeem
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

    /// @inheritdoc IERC7540Redeem
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
        return block.chainid == deploymentChainId && address(this) == deploymentAddress
            ? _DOMAIN_SEPARATOR
            : _calculateDomainSeparator();
    }

    /// @inheritdoc IERC7741
    function invalidateNonce(bytes32 nonce) external {
        if (nonce == bytes32(0) || _authorizations[msg.sender][nonce]) revert INVALID_NONCE();
        _authorizations[msg.sender][nonce] = true;

        emit NonceInvalidated(msg.sender, nonce);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/
    function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return _underlyingDecimals;
    }

    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view override returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        uint256 currentPPS = _getStoredPPS();
        return Math.mulDiv(supply, currentPPS, PRECISION, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 currentPPS = _getStoredPPS();
        if (currentPPS == 0) return assets;
        return Math.mulDiv(assets, PRECISION, currentPPS, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 currentPPS = _getStoredPPS();
        if (currentPPS == 0) return shares;
        return Math.mulDiv(shares, currentPPS, PRECISION, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function maxMint(address owner) external view override returns (uint256) {
        uint256 maxAssets = maxDeposit(owner);
        return convertToShares(maxAssets);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view override returns (uint256) {
        return strategy.claimableWithdraw(owner);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 withdrawPrice = strategy.getAverageWithdrawPrice(owner);
        if (withdrawPrice == 0) return 0;
        return maxWithdraw(owner).mulDiv(PRECISION, withdrawPrice, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 /* assets*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 /* shares*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    )
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        _validateController(controller);

        uint256 averageWithdrawPrice = strategy.getAverageWithdrawPrice(controller);
        if (averageWithdrawPrice == 0) revert INVALID_WITHDRAW_PRICE();

        uint256 maxWithdrawAmount = maxWithdraw(controller);
        if (assets > maxWithdrawAmount) revert INVALID_AMOUNT();

        // Calculate shares based on assets and average withdraw price
        shares = assets.mulDiv(PRECISION, averageWithdrawPrice, Math.Rounding.Floor);

        // Take assets from strategy
        strategy.handleOperation(controller, receiver, assets, shares, ISuperVaultStrategy.Operation.ClaimRedeem);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    )
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        _validateController(controller);

        uint256 averageWithdrawPrice = strategy.getAverageWithdrawPrice(controller);
        if (averageWithdrawPrice == 0) revert INVALID_WITHDRAW_PRICE();

        // Calculate assets based on shares and average withdraw price
        assets = shares.mulDiv(averageWithdrawPrice, PRECISION, Math.Rounding.Floor);

        uint256 maxWithdrawAmount = maxWithdraw(controller);
        if (assets > maxWithdrawAmount) revert INVALID_AMOUNT();

        // Take assets from strategy
        strategy.handleOperation(controller, receiver, assets, shares, ISuperVaultStrategy.Operation.ClaimRedeem);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    // @inheritdoc ISuperVault
    function mintShares(uint256 amount) external {
        if (msg.sender != address(strategy)) revert UNAUTHORIZED();
        _mint(escrow, amount);
    }

    // @inheritdoc ISuperVault
    function burnShares(uint256 amount) external {
        if (msg.sender != address(strategy)) revert UNAUTHORIZED();
        _burn(escrow, amount);
    }

    // @inheritdoc ISuperVault
    function onRedeemClaimable(
        address user,
        uint256 assets,
        uint256 shares,
        uint256 averageWithdrawPrice,
        uint256 accumulatorShares,
        uint256 accumulatorCostBasis
    )
        external
    {
        if (msg.sender != address(strategy)) revert UNAUTHORIZED();
        emit RedeemClaimable(
            user, REQUEST_ID, assets, shares, averageWithdrawPrice, accumulatorShares, accumulatorCostBasis
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ERC165 INTERFACE
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC7540Redeem).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC7741).interfaceId || interfaceId == type(IERC4626).interfaceId
            || interfaceId == type(IERC7575).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that the controller is the msg.sender or has been authorized by the controller
    /// @param controller The controller to validate
    function _validateController(address controller) internal view {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert INVALID_CONTROLLER();
    }

    /// @notice Calculates the EIP712 domain separator
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

    /// @notice Verify an EIP712 signature using OpenZeppelin's ECDSA library
    /// @param signer The signer to verify
    /// @param digest The digest to verify
    /// @param signature The signature to verify
    function _isValidSignature(address signer, bytes32 digest, bytes memory signature) internal pure returns (bool) {
        address recoveredSigner = ECDSA.recover(digest, signature);
        return recoveredSigner == signer;
    }

    /// @notice Overrides the ERC20 _update function to update the state of the vault when a transfer occurs
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param value The amount of shares being transferred
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            ISuperVaultStrategy.SuperVaultState memory state = strategy.getSuperVaultState(from);
            strategy.updateSuperVaultState(to, state);
        }
        super._update(from, to, value);
    }

    function _getStoredPPS() internal view returns (uint256) {
        return strategy.getStoredPPS();
    }

    function _getStoredPPSWithRevert() internal view returns (uint256) {
        uint256 currentPPS = _getStoredPPS();
        if (currentPPS == 0) revert INVALID_PPS();
        return currentPPS;
    }
}
