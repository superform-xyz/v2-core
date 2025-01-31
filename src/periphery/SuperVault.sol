// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { ERC4626, ERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { ISuperVault } from "./interfaces/ISuperVault.sol";
import {
    IERC7540Vault,
    IERC7540Operator,
    IERC7540Deposit,
    IERC7540Redeem,
    IERC7540CancelDeposit,
    IERC7540CancelRedeem,
    IERC7741
} from "./interfaces/IERC7540Vault.sol";
import { ISuperHook, ISuperHookResult, Execution, ISuperHookInflowOutflow } from "../core/interfaces/ISuperHook.sol";

/// @title SuperVault
/// @notice A vault that allows users to deposit and withdraw assets across multiple yield sources
/// @author SuperForm Labs
contract SuperVault is ERC4626, AccessControl, IERC7540Vault, ISuperVault {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    uint256 public constant ONE_WEEK = 7 days;
    uint256 private constant REQUEST_ID = 0;

    // EIP712 TypeHash
    bytes32 public constant AUTHORIZE_OPERATOR_TYPEHASH =
        keccak256("AuthorizeOperator(address controller,address operator,bool approved,bytes32 nonce,uint256 deadline)");

    // Domain separator
    bytes32 private immutable _DOMAIN_SEPARATOR;
    bytes32 private immutable _NAME_HASH;
    bytes32 private immutable _VERSION_HASH;
    uint256 public immutable deploymentChainId;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    // Asset configuration
    IERC20 private immutable _asset;

    // Global configuration
    GlobalConfig public globalConfig;

    // Fee configuration
    FeeConfig public feeConfig;

    // Hook root configuration
    bytes32 public hookRoot;
    bytes32 public proposedHookRoot;
    uint256 public hookRootEffectiveTime;

    // Yield source configuration
    mapping(address => YieldSource) public yieldSources;
    address[] public yieldSourcesList;

    // Request tracking
    mapping(address controller => SuperVaultState state) public superVaultState;

    /// @inheritdoc IERC7540Operator
    mapping(address owner => mapping(address operator => bool)) public isOperator;

    // Authorization tracking
    mapping(address controller => mapping(bytes32 nonce => bool used)) private _authorizations;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address asset_,
        string memory name_,
        string memory symbol_,
        address strategist_,
        address keeper_,
        GlobalConfig memory globalConfig_,
        FeeConfig memory feeConfig_
    )
        ERC4626(IERC20(asset_))
        ERC20(name_, symbol_)
    {
        if (asset_ == address(0)) revert INVALID_ASSET();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (keeper_ == address(0)) revert INVALID_KEEPER();
        if (globalConfig_.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (globalConfig_.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (globalConfig_.maxAllocationRate == 0 || globalConfig_.maxAllocationRate > 10_000) {
            revert INVALID_MAX_ALLOCATION_RATE();
        }
        if (globalConfig_.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();
        if (feeConfig_.feeBps > 10_000) revert INVALID_FEE();
        if (feeConfig_.recipient == address(0)) revert INVALID_FEE_RECIPIENT();
        _asset = IERC20(asset_);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGIST_ROLE, strategist_);
        _grantRole(KEEPER_ROLE, keeper_);

        // Initialize EIP712 domain separator
        _NAME_HASH = keccak256(bytes("SuperVault"));
        _VERSION_HASH = keccak256(bytes("1"));
        deploymentChainId = block.chainid;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();

        globalConfig = globalConfig_;
        feeConfig = feeConfig_;
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

        SuperVaultState storage state = superVaultState[controller];

        if (state.pendingCancelDepositRequest) revert CANCELLATION_IS_PENDING();
        // Create deposit request
        state.pendingDepositRequest = state.pendingDepositRequest + assets;

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    /// @inheritdoc IERC7540CancelDeposit
    function cancelDepositRequest(uint256, address controller) external {
        _validateController(controller);
        SuperVaultState storage state = superVaultState[controller];
        if (state.pendingDepositRequest == 0) revert REQUEST_NOT_FOUND();
        if (state.pendingCancelDepositRequest) revert CANCELLATION_IS_PENDING();
        state.pendingCancelDepositRequest = true;

        emit CancelDepositRequest(controller, REQUEST_ID, msg.sender);
    }

    function claimCancelDepositRequest(
        uint256, /*requestId*/
        address receiver,
        address controller
    )
        external
        returns (uint256 assets)
    {
        _validateController(controller);
        assets = superVaultState[controller].claimableCancelDepositRequest;
        superVaultState[controller].claimableCancelDepositRequest = 0;
        if (assets > 0) {
            _asset.safeTransferFrom(address(this), receiver, assets);
        }
        emit CancelDepositClaim(receiver, controller, REQUEST_ID, msg.sender, assets);
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

        // Transfer shares to SuperVault for temporary locking
        _transfer(sender, address(this), shares);

        // Create redeem request
        SuperVaultState storage state = superVaultState[controller];
        if (state.pendingCancelRedeemRequest) revert CANCELLATION_IS_PENDING();
        state.pendingRedeemRequest = state.pendingRedeemRequest + shares;

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /// @inheritdoc IERC7540CancelRedeem
    function cancelRedeemRequest(uint256, address controller) external {
        _validateController(controller);
        SuperVaultState storage state = superVaultState[controller];
        if (state.pendingRedeemRequest == 0) revert REQUEST_NOT_FOUND();
        if (state.pendingCancelRedeemRequest) revert CANCELLATION_IS_PENDING();
        state.pendingCancelRedeemRequest = true;
        state.claimableCancelRedeemRequest = state.claimableCancelRedeemRequest + state.pendingRedeemRequest;
        delete state.pendingCancelRedeemRequest;

        emit CancelRedeemRequest(controller, REQUEST_ID, msg.sender);
    }

    function claimCancelRedeemRequest(
        uint256, /*requestId*/
        address receiver,
        address controller
    )
        external
        returns (uint256 shares)
    {
        _validateController(controller);
        shares = superVaultState[controller].claimableCancelRedeemRequest;
        superVaultState[controller].claimableCancelRedeemRequest = 0;
        if (shares > 0) {
            _transfer(address(this), receiver, shares);
        }
        emit CancelRedeemClaim(receiver, controller, REQUEST_ID, msg.sender, shares);
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
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fulfill deposit requests for multiple users
    /// @param users Array of user addresses to fulfill deposits for
    /// @param hooks Array of hook addresses to use for building executions
    /// @param hookProofs Array of merkle proofs for hook verification, one per hook
    /// @param hookCalldata Array of calldata to pass to hooks for building executions
    function fulfillDepositRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external
        onlyRole(KEEPER_ROLE)
    {
        // Validate array lengths match
        if (hooks.length != hookProofs.length || hooks.length != hookCalldata.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        // Validate requests and get total assets
        uint256 totalRequestedAssets = _validateDepositRequests(users);

        // Process each hook in sequence
        address prevHook;
        uint256 spentAssets;
        for (uint256 i = 0; i < hooks.length; i++) {
            // Validate hook via merkle proof
            if (!isHookAllowed(hooks[i], hookProofs[i])) revert INVALID_HOOK();

            // Process hook executions
            (prevHook, spentAssets) = _processHookExecution(hooks[i], prevHook, hookCalldata[i], spentAssets);
        }

        // Verify all assets were spent
        if (spentAssets != totalRequestedAssets) revert INVALID_AMOUNT();

        // Update accounting for each user
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            SuperVaultState storage state = superVaultState[user];
            uint256 requestedAssets = state.pendingDepositRequest;

            // TODO: inscribe PPS for deposit in superVaultsState
            // Move request to claimable state
            state.pendingDepositRequest = 0;
            delete state.pendingCancelDepositRequest;
            // TODO: below is wrong as we need PPS to convert to requestedAssets
            uint256 shares = requestedAssets;

            // TODO: mint shares to this vault
            _mint(address(this), shares);

            // Emit event
            emit DepositClaimable(user, REQUEST_ID, requestedAssets, shares);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Add a new yield source
    /// @param source Address of the yield source
    /// @param oracle Address of the yield source oracle
    function addYieldSource(address source, address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (source == address(0)) revert INVALID_YIELD_SOURCE();
        if (oracle == address(0)) revert INVALID_ORACLE();
        if (yieldSources[source].oracle != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();

        yieldSources[source] = YieldSource({ oracle: oracle, isActive: true });

        yieldSourcesList.push(source);
        emit YieldSourceAdded(source, oracle);
    }

    /// @notice Remove a yield source
    /// @param source Address of the yield source to remove
    function removeYieldSource(address source) external onlyRole(DEFAULT_ADMIN_ROLE) {
        YieldSource storage yieldSource = yieldSources[source];
        if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_FOUND();

        yieldSource.isActive = false;
        emit YieldSourceRemoved(source);
    }

    /// @notice Update global configuration
    /// @param config New global configuration
    function updateGlobalConfig(GlobalConfig calldata config) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (config.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (config.maxAllocationRate == 0 || config.maxAllocationRate > 10_000) revert INVALID_MAX_ALLOCATION_RATE();
        if (config.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();

        globalConfig = config;
        emit GlobalConfigUpdated(config.vaultCap, config.superVaultCap, config.maxAllocationRate, config.vaultThreshold);
    }

    /// @notice Propose a new hook root
    /// @param newRoot New hook root to propose
    function proposeHookRoot(bytes32 newRoot) external onlyRole(DEFAULT_ADMIN_ROLE) {
        proposedHookRoot = newRoot;
        hookRootEffectiveTime = block.timestamp + ONE_WEEK;
        emit HookRootProposed(newRoot, hookRootEffectiveTime);
    }

    /// @notice Execute the proposed hook root update after timelock
    function executeHookRootUpdate() external {
        if (block.timestamp < hookRootEffectiveTime) revert TIMELOCK_NOT_EXPIRED();
        if (proposedHookRoot == bytes32(0)) revert INVALID_HOOK_ROOT();

        hookRoot = proposedHookRoot;
        proposedHookRoot = bytes32(0);
        hookRootEffectiveTime = 0;
        emit HookRootUpdated(hookRoot);
    }

    /// @notice Update fee configuration
    /// @param feeBps New fee in basis points
    /// @param recipient New fee recipient
    function updateFeeConfig(uint256 feeBps, address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (feeBps > 10_000) revert INVALID_FEE();
        if (recipient == address(0)) revert INVALID_FEE_RECIPIENT();

        feeConfig = FeeConfig({ feeBps: feeBps, recipient: recipient });
        emit FeeConfigUpdated(feeBps, recipient);
    }

    /*//////////////////////////////////////////////////////////////
                    USER EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    //--ERC7540--

    function pendingDepositRequest(
        uint256 requestId,
        address controller
    )
        external
        view
        returns (uint256 pendingAssets)
    { }

    function claimableDepositRequest(
        uint256 requestId,
        address controller
    )
        external
        view
        returns (uint256 claimableAssets)
    { }

    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    )
        external
        view
        returns (uint256 pendingShares)
    { }

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    )
        external
        view
        returns (uint256 claimableShares)
    { }

    function pendingCancelDepositRequest(
        uint256 requestId,
        address controller
    )
        external
        view
        returns (bool isPending)
    { }

    function claimableCancelDepositRequest(
        uint256 requestId,
        address controller
    )
        external
        view
        returns (uint256 claimableAssets)
    { }

    function pendingCancelRedeemRequest(uint256 requestId, address controller) external view returns (bool isPending) { }

    function claimableCancelRedeemRequest(
        uint256 requestId,
        address controller
    )
        external
        view
        returns (uint256 claimableShares)
    { }

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
        _authorizations[msg.sender][nonce] = true;
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get a yield source's configuration
    /// @param source Address of the yield source

    function getYieldSource(address source) external view returns (YieldSource memory) {
        return yieldSources[source];
    }

    /// @notice Get the global configuration
    function getGlobalConfig() external view returns (GlobalConfig memory) {
        return globalConfig;
    }

    /// @notice Get the fee configuration
    function getFeeConfig() external view returns (FeeConfig memory) {
        return feeConfig;
    }

    /// @notice Get the current hook root
    function getHookRoot() external view returns (bytes32) {
        return hookRoot;
    }

    /// @notice Get the proposed hook root
    function getProposedHookRoot() external view returns (bytes32) {
        return proposedHookRoot;
    }

    /// @notice Get the hook root effective time
    function getHookRootEffectiveTime() external view returns (uint256) {
        return hookRootEffectiveTime;
    }

    /// @notice Get the list of all yield sources
    function getYieldSourcesList() external view returns (address[] memory) {
        return yieldSourcesList;
    }

    /// @notice Check if a hook is allowed via merkle proof
    /// @param hook Address of the hook to check
    /// @param proof Merkle proof for the hook
    function isHookAllowed(address hook, bytes32[] calldata proof) public view returns (bool) {
        if (hookRoot == bytes32(0)) return false;
        bytes32 leaf = keccak256(abi.encodePacked(hook));
        return MerkleProof.verify(proof, hookRoot, leaf);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256) {
        // Total assets is the sum of all assets in yield sources plus idle assets
        uint256 total = _asset.balanceOf(address(this));
        for (uint256 i = 0; i < yieldSourcesList.length; i++) {
            address source = yieldSourcesList[i];
            if (yieldSources[source].isActive) {
                total += IERC4626(source).convertToAssets(IERC4626(source).balanceOf(address(this)));
            }
        }
        return total;
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : assets.mulDiv(supply, totalAssets());
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares.mulDiv(totalAssets(), supply);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) public view override returns (uint256) {
        return globalConfig.superVaultCap - totalAssets();
    }

    /// @inheritdoc IERC4626
    function maxMint(address) public view override returns (uint256) {
        return convertToShares(maxDeposit(address(0)));
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override returns (uint256) {
        return balanceOf(owner);
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
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);
        // TODO

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = deposit(assets, receiver, msg.sender);
    }

    function mint(uint256 shares, address receiver, address controller) public returns (uint256 assets) {
        uint256 assets = previewMint(shares);
        if (assets > maxDeposit(receiver)) revert INVALID_AMOUNT();

        _asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return assets;
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = mint(shares, receiver, msg.sender);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        if (assets > maxWithdraw(owner)) revert INVALID_AMOUNT();
        uint256 shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        _burn(owner, shares);
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        if (shares > maxRedeem(owner)) revert INVALID_AMOUNT();
        uint256 assets = previewRedeem(shares);

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        _burn(owner, shares);
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC165 INTERFACE
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return interfaceId == type(IERC7540Vault).interfaceId || interfaceId == type(ISuperVault).interfaceId
            || interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7741).interfaceId
            || interfaceId == type(IERC4626).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //--Fulfilment and allocation helpers--

    /// @notice Validate and get total assets for deposit requests
    /// @param users Array of user addresses to validate
    /// @return totalRequestedAssets Total assets to be deposited
    function _validateDepositRequests(address[] calldata users) internal view returns (uint256 totalRequestedAssets) {
        for (uint256 i = 0; i < users.length; i++) {
            SuperVaultState storage state = superVaultState[users[i]];
            if (state.pendingDepositRequest == 0) revert REQUEST_NOT_FOUND();
            if (state.pendingCancelDepositRequest) revert CANCELLATION_IS_PENDING();

            totalRequestedAssets += state.pendingDepositRequest;
        }
    }

    /// @notice Process a single hook's executions
    /// @param hook The hook to process
    /// @param prevHook The previous hook in the sequence
    /// @param hookCalldata The calldata for the hook
    /// @param spentAssets Running total of assets spent so far
    /// @return (address, uint256) The hook address and updated spent assets amount
    function _processHookExecution(
        address hook,
        address prevHook,
        bytes calldata hookCalldata,
        uint256 spentAssets
    )
        internal
        returns (address, uint256)
    {
        // Build executions for this hook
        ISuperHook hookContract = ISuperHook(hook);
        Execution[] memory executions = hookContract.build(prevHook, hookCalldata);
        // prevent any hooks with more than one execution
        if (executions.length > 1) revert INVALID_HOOK();

        // Only process INFLOW hooks
        ISuperHook.HookType hookType = ISuperHookResult(hook).hookType();
        if (hookType != ISuperHook.HookType.INFLOW) revert INVALID_HOOK();

        // Get amount from hook
        uint256 amount = ISuperHookInflowOutflow(hook).decodeAmount(hookCalldata);

        // Validate target is an active yield source and check constraints
        YieldSource storage source = yieldSources[executions[0].target];
        if (!source.isActive) revert INVALID_YIELD_SOURCE();

        // Validate yield source constraints
        // Check vault caps
        if (amount > globalConfig.vaultCap) revert VAULT_CAP_EXCEEDED();

        // Get current total assets in yield source
        uint256 currentYieldSourceAssets =
            IERC4626(executions[0].target).convertToAssets(IERC4626(executions[0].target).balanceOf(address(this)));

        // Check allocation rate
        if ((currentYieldSourceAssets + amount).mulDiv(10_000, totalAssets()) > globalConfig.maxAllocationRate) {
            revert MAX_ALLOCATION_RATE_EXCEEDED();
        }

        // Check vault threshold
        if (currentYieldSourceAssets < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_NOT_MET();

        // Approve assets to target
        _asset.approve(executions[0].target, amount);

        // Execute the transaction
        (bool success,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        if (!success) revert EXECUTION_FAILED();

        // Reset approval
        _asset.approve(executions[0].target, 0);

        // Update spent assets
        spentAssets += amount;

        return (hook, spentAssets);
    }

    //--Misc helpers--

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
}
