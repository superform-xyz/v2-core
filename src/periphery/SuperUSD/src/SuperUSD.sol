// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IncentiveCalculationContract.sol";
import "./IncentiveFundContract.sol";
import "./interfaces/ISuperUSDErrors.sol";

/**
 * @title SuperUSD
 * @notice A meta-vault that manages deposits and redemptions across multiple underlying vaults.
 * Implements ERC20 standard for better compatibility with integrators.
 */
contract SuperUSD is AccessControl, ERC20, ISuperUSDErrors {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // --- Roles ---
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant SWAP_FEE_MANAGER_ROLE = keccak256("SWAP_FEE_MANAGER_ROLE");
    bytes32 public constant INCENTIVE_FUND_MANAGER = keccak256("INCENTIVE_FUND_MANAGER");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // --- State ---
    mapping(address => bool) public isVault;
    mapping(address => bool) public isERC20;
    EnumerableSet.AddressSet private _supportedVaults;
    address public immutable incentiveCalculationContract;  // Address of the ICC
    address public immutable incentiveFundContract;      // Address of the Incentive Fund Contract
    address public immutable swapFeeFundContract;        // Address of the Swap Fee Fund Contract
    address public settlementTokenIn;
    address public settlementTokenOut;
    ISuperOracle public superOracle;

    mapping(address => uint256) public targetAllocations;

    uint256 public swapFeeInPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public swapFeeOutPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)

    // Add a constant equal to 10^6
    uint256 public constant SWAP_FEE_PERC = 10**6; // TODO: Add this to SuperOracle

    mapping(address => uint256) public emergencyPrices; // Used when an oracle is down, managed by us

    // --- Events ---
    event Deposit(address receiver, address tokenIn, uint256 amountTokenToDeposit, uint256 amountSharesOut);
    event Redeem(address receiver, uint256 amountSharesToRedeem, address tokenOut, uint256 amountTokenOut);
    event Swap(address receiver, address tokenIn, uint256 amountTokenToDeposit, address tokenOut, uint256 amountSharesOut, uint256 amountTokenOut);
    event VaultWhitelisted(address vault);
    event VaultRemoved(address vault);
    event ERC20Whitelisted(address token);
    event ERC20Removed(address token);
    event SettlementTokenInSet(address token);
    event SettlementTokenOutSet(address token);
    event SuperOracleSet(address oracle);

    // --- Modifiers ---
    modifier onlyVault() {
        if (!isVault[msg.sender]) revert NotVault();
        _;
    }

    modifier onlyERC20() {
        if (!isERC20[msg.sender]) revert NotERC20Token();
        _;
    }

    /**
     * @dev Constructor initializes the ERC20 token with name and symbol
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @param icc_ Address of the Incentive Calculation Contract
     * @param ifc_ Address of the Incentive Fund Contract
     * @param sfc_ Address of the Swap Fee Fund Contract
     * @param swapFeeInPercentage_ Swap fee as a percentage (e.g., 10 for 0.1%)
     * @param swapFeeOutPercentage_ Swap fee as a percentage (e.g., 10 for 0.1%)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address icc_,
        address ifc_,
        address sfc_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    ) ERC20(name_, symbol_) {
        if (icc_ == address(0)) revert ZeroAddress();
        if (ifc_ == address(0)) revert ZeroAddress();
        if (sfc_ == address(0)) revert ZeroAddress();
        if (swapFeeInPercentage_ > SWAP_FEE_PERC) revert InvalidSwapFeePercentage();
        if (swapFeeOutPercentage_ > SWAP_FEE_PERC) revert InvalidSwapFeePercentage();
        
        incentiveCalculationContract = icc_;
        incentiveFundContract = ifc_;
        swapFeeFundContract = sfc_;
        swapFeeInPercentage = swapFeeInPercentage_;
        swapFeeOutPercentage = swapFeeOutPercentage_;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    /**
     * @dev Mints new tokens. Can only be called by accounts with MINTER_ROLE.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens. Can only be called by accounts with BURNER_ROLE.
     * @param from The address whose tokens will be burned
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    // NOTE:
    // This is equivalent to also returning the normalized amount since it can be obtained just by doing absoluteAllocation[i] / totalAllocation
    function getAllocations() public view returns (uint256[] memory absoluteCurrentAllocation, uint256 totalCurrentAllocation, uint256[] memory absoluteTargetAllocation, uint256 totalTargetAllocation) {
        // Placeholder for the current allocation normalized
        // This function should return the current allocation of assets in the SuperUSD contract
        // For now, we return an empty array
        uint256 length = _supportedVaults.length();
        absoluteCurrentAllocation = new uint256[](length);
        absoluteTargetAllocation = new uint256[](length);
        uint256 i;
        for (; i < length; i++) {
            address vault = _supportedVaults.at(i);
            absoluteCurrentAllocation[i] = IERC20(vault).balanceOf(address(this));
            totalCurrentAllocation += absoluteCurrentAllocation[i];
            absoluteTargetAllocation[i] = targetAllocations[vault];
            totalTargetAllocation += absoluteTargetAllocation[i];
        }
    }


    function getAllocationsPrePostOperation(address token, int256 deltaToken) public view returns (uint256[] memory absoluteCurrentAllocation, uint256 totalCurrentAllocation, uint256[] memory absoluteTargetAllocation, uint256 totalTargetAllocation) {
        // Placeholder for the current allocation normalized
        // This function should return the current allocation of assets in the SuperUSD contract
        // For now, we return an empty array
        uint256 length = _supportedVaults.length();
        absoluteCurrentAllocation = new uint256[](length);
        absoluteTargetAllocation = new uint256[](length);
        uint256 i;
        for (; i < length; i++) {
            address vault = _supportedVaults.at(i);
            absoluteCurrentAllocation[i] = IERC20(vault).balanceOf(address(this));
            totalCurrentAllocation += absoluteCurrentAllocation[i];
            absoluteTargetAllocation[i] = targetAllocations[vault];
            totalTargetAllocation += absoluteTargetAllocation[i];
        }
    }


    function setSwapFeePercentage(uint256 _swapFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_swapFeePercentage > 1000) revert InvalidSwapFeePercentage(); // Max 10%
        swapFeePercentage = _swapFeePercentage;
    }

    // --- Token Movement Functions ---

    /**
     * @notice Deposits an underlying asset into a whitelisted vault and mints SuperUSD shares.
     * @param receiver The address to receive the output shares.
     * @param tokenIn The address of the underlying asset to deposit.
     * @param amountTokenToDeposit The amount of the underlying asset to deposit.
     * @param minSharesOut The minimum amount of SuperUSD shares to receive.
     * @return amountSharesOut The amount of SuperUSD shares minted.
     */
    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut            // Slippage Protection
    ) external returns (uint256 amountSharesOut) {
        if (amountTokenToDeposit == 0) revert ZeroAmount();
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();
        if (receiver == address(0)) revert ZeroAddress();

        // Transfer the tokenIn from the sender to this contract
        // If there is not enough allowance or balance, this will revert and saves gas
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);

        // Calculate swap fees (example: 0.1% fee)
        // TODO: Make it a governance params
        // TODO: Use mulDiv() for better precision
        //  Example: 0.1% fee
        //  uint256 swapFee = (amountTokenToDeposit * 1) / 1000; // 0.1%
        //  uint256 amountAfterFees = amountTokenToDeposit - swapFee;
        uint256 swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC); // Swap fee based on percentage
        uint256 amountInAfterFees = amountTokenToDeposit - swapFee;

        // Transfer swap fees to Swap Fee Fund while holding the rest in the contract, since the full amount was already transferred in the beginning of the function
        IERC20(tokenIn).safeTransfer(swapFeeFundContract, swapFee);


//        // Deposit into underlying vault or handle ERC20
//        uint256 underlyingShares;
//        if (isVault[tokenIn]) {
//            underlyingShares = IEIP7540(tokenIn).deposit(address(this), IERC20(tokenIn).asset(), amountAfterFees, 0); // Use 0 for minShares
//        } else {
//            //  Handle ERC20 deposit (simplified -  no vault involved, mint shares directly)
//            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountAfterFees);
//            underlyingShares = amountAfterFees; // Example: 1:1 conversion.  Adjust as needed.
//        }

        // TODO: Replace this with calling SuperOracle to get the conversion price
        // Get price of underlying vault shares in USD
        (uint256 pricePerShare,) = getPrice(tokenIn);

        // Calculate SuperUSD shares to mint
        amountSharesOut = (amountInAfterFees * 1e18) / pricePerShare; // Adjust for decimals
//        amountSharesOut = (underlyingShares * pricePerShare) / 1e18; // Adjust for decimals

        // Slippage Check
        if (amountSharesOut < minSharesOut) revert SlippageProtection();

        // Mint SuperUSD shares (assuming this contract is a minter)
        _mintSuperUSD(receiver, amountSharesOut); //  Use a proper minting mechanism.

        // Calculate and settle incentives
        (uint256 amountIncentives,) = previewDeposit(tokenIn, amountTokenToDeposit);
        _settleIncentive(msg.sender, int256(amountIncentives));

        emit Deposit(receiver, tokenIn, amountTokenToDeposit, amountSharesOut);
        return amountSharesOut;
    }

    /**
     * @notice Redeems SuperUSD shares for underlying assets from a whitelisted vault.
     * @param receiver The address to receive the output assets.
     * @param amountSharesToRedeem The amount of SuperUSD shares to redeem.
     * @param tokenOut The address of the underlying asset to redeem for.
     * @param minTokenOut The minimum amount of the underlying asset to receive.
     * @return amountTokenOut The amount of the underlying asset received.
     */
    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    ) external returns (uint256 amountTokenOut) {
        if (!isVault[tokenOut] && !isERC20[tokenOut]) revert NotSupportedToken();
        if (receiver == address(0)) revert ZeroAddress();

        // Get price of underlying asset
        (uint256 pricePerShare,) = getPrice(tokenOut);

        // Calculate underlying shares to redeem
        uint256 underlyingShares = (amountSharesToRedeem * 1e18) / pricePerShare; // Adjust for decimals

        // Burn SuperUSD shares (assuming this contract is a burner)
        // Missing burn function.  For demo, assume a simple state variable.
        _burnSuperUSD(msg.sender, amountSharesToRedeem);  // Use a proper burning mechanism

        uint256 amountBeforeFees;

        if (isVault[tokenOut]) {
            // Redeem from underlying vault
            amountBeforeFees = IEIP7540(tokenOut).redeem(address(this), underlyingShares, IERC20(tokenOut).asset(), 0); // Use 0 for minAmount
        } else {
            // Handle ERC20 (simplified -  no vault involved, send directly)
            amountBeforeFees = underlyingShares; // Example 1:1
        }


        // Calculate swap fees on output (example: 0.1% fee)
        uint256 swapFee = (amountBeforeFees * swapFeeOutPercentage) / SWAP_FEE_PERC;
        amountTokenOut = amountBeforeFees - swapFee;

        // Transfer swap fees to Swap Fee Fund
        IERC20(tokenOut).safeTransferFrom(address(this), swapFeeFundContract, swapFee);

        // Transfer assets to receiver
        IERC20(tokenOut).safeTransfer(receiver, amountTokenOut);

        if (amountTokenOut < minTokenOut) revert SlippageProtection();

        // Calculate and settle incentives
        (uint256 amountIncentives,) = previewRedeem(tokenOut, amountSharesToRedeem);
        _settleIncentive(msg.sender, int256(amountIncentives));

        emit Redeem(receiver, amountSharesToRedeem, tokenOut, amountTokenOut);
        return amountTokenOut;
    }

    /**
     * @notice Swaps an underlying asset for another.
     * @param receiver The address to receive the output assets.
     * @param tokenIn The address of the input asset.
     * @param amountTokenToDeposit The amount of the input asset to deposit.
     * @param tokenOut The address of the output asset.
     * @param minSharesOut The minimum amount of SuperUSD shares to receive.
     * @param minTokenOut The minimum amount of the output asset to receive.
     * @return amountTokenOut The amount of the output asset received.
     */
    function swap(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        address tokenOut,
        uint256 minSharesOut,
        uint256 minTokenOut
    ) external returns (uint256 amountTokenOut) {
        if (receiver == address(0)) revert ZeroAddress();
        uint256 amountSharesOut = deposit(address(this), tokenIn, amountTokenToDeposit, minSharesOut);
        amountTokenOut = redeem(receiver, amountSharesOut, tokenOut, minTokenOut);
        emit Swap(receiver, tokenIn, amountTokenToDeposit, tokenOut, amountSharesOut, amountTokenOut);
        return amountTokenOut;
    }

    // --- Vault Whitelist Management ---
    function whitelistVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        if (isVault[vault]) revert AlreadyWhitelisted();
        isVault[vault] = true;
        _supportedVaults.add(vault);
        emit VaultWhitelisted(vault);
    }

    function removeVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        if (!isVault[vault]) revert NotWhitelisted();
        isVault[vault] = false;
        _supportedVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    function whitelistERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (isERC20[token]) revert AlreadyWhitelisted();
        isERC20[token] = true;
        emit ERC20Whitelisted(token);
    }

    function removeERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (!isERC20[token]) revert NotWhitelisted();
        isERC20[token] = false;
        emit ERC20Removed(token);
    }

    // --- View Functions ---

    /**
     * @notice Preview a deposit.
     * @param tokenIn The address of the underlying asset to deposit.
     * @param amountTokenToDeposit The amount of the underlying asset to deposit.
     * @return amountSharesOut The amount of SuperUSD shares that would be minted.
     * @return amountIncentives The amount of incentives.
     */
    function previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
    public
    view
    returns (uint256 amountSharesOut, uint256 amountIncentives)
    {
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();

        // Calculate swap fees (example: 0.1% fee)
        uint256 swapFee = (amountTokenToDeposit * 1) / 1000; // 0.1%
        uint256 amountAfterFees = amountTokenToDeposit - swapFee;

        uint256 underlyingShares;
        if (isVault[tokenIn]) {
            underlyingShares = IEIP7540(tokenIn).previewDeposit(amountAfterFees);
        } else {
            underlyingShares = amountAfterFees;
        }

        // Get price of underlying vault shares in USD
        (uint256 pricePerShare,) = getPrice(tokenIn);

        // Calculate SuperUSD shares to mint
        amountSharesOut = (underlyingShares * pricePerShare) / 1e18; // Adjust for decimals

        // Calculate incentives (using ICC)
        amountIncentives = IIncentiveCalculationContract(incentiveCalculationContract).calculateIncentive(
            new uint256[](0), // Placeholder, adjust as needed
            new uint256[](0), // Placeholder, adjust as needed
            new uint256[](0)  // Placeholder, adjust as needed
        );
    }

    /**
     * @notice Preview a redemption.
     * @param tokenOut The address of the underlying asset to redeem for.
     * @param amountSharesToRedeem The amount of SuperUSD shares to redeem.
     * @return amountTokenOut The amount of the underlying asset that would be received.
     * @return amountIncentives The amount of incentives.
     */
    function previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
    public
    view
    returns (uint256 amountTokenOut, uint256 amountIncentives)
    {
        if (!isVault[tokenOut] && !isERC20[tokenOut]) revert NotSupportedToken();

        // Get price of underlying asset
        (uint256 pricePerShare,) = getPrice(tokenOut);

        // Calculate underlying shares to redeem
        uint256 underlyingShares = (amountSharesToRedeem * 1e18) / pricePerShare; // Adjust for decimals

        uint256 amountBeforeFees;

        if(isVault[tokenOut]) {
            amountBeforeFees = IEIP7540(tokenOut).previewRedeem(underlyingShares);
        } else {
            amountBeforeFees = underlyingShares;
        }

        // Calculate swap fees on output (example: 0.1% fee)
        uint256 swapFee = (amountBeforeFees * 1) / 1000; // 0.1%
        amountTokenOut = amountBeforeFees - swapFee;

        // Calculate incentives (using ICC)
        amountIncentives = IIncentiveCalculationContract(incentiveCalculationContract).calculateIncentive(
            new uint256[](0), // Placeholder, adjust as needed
            new uint256[](0), // Placeholder, adjust as needed
            new uint256[](0)  // Placeholder, adjust as needed
        );
    }

    /**
     * @notice Preview a swap.
      * @param tokenIn The address of the input asset.
     * @param amountTokenToDeposit The amount of the input asset to deposit.
     * @param tokenOut The address of the output asset.
     * @return amountSharesOut The amount of SuperUSD shares that would be minted.
     * @return amountIncentives The amount of incentives.
     */
    function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokenOut)
    public
    view
    returns (uint256 amountSharesOut, uint256 amountIncentives)
    {
        (amountSharesOut, amountIncentives) = previewDeposit(tokenIn, amountTokenToDeposit);
        (, amountIncentives) = previewRedeem(tokenOut, amountSharesOut); // incentives are cumulative in this simplified example.
    }

    /**
     * @notice Checks if an underlying stablecoin has depegged.
     * @param tokenIn The address of the underlying asset.
     * @return res True if the stablecoin has depegged, false otherwise.
     */
    function isDepeg(address tokenIn) public view returns (bool res) {
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();
        res = ISuperOracle(superOracle).isDepeg(tokenIn);
    }

    /**
     * @notice Checks if the uncertainty of an underlying asset's price is too high.
     * @param tokenIn The address of the underlying asset.
     * @return res True if the uncertainty is too high, false otherwise.
     */
    function isDispersion(address tokenIn) public view returns (bool res) {
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();
        res = ISuperOracle(superOracle).isDispersion(tokenIn);
    }

    /**
     * @notice Checks if the SuperOracle is up.
     * @param tokenIn The address of the underlying asset.
     * @return res True if the SuperOracle is up, false otherwise.
     */
    function isSuperOracleUp(address tokenIn) public view returns (bool res) {
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();
        res = ISuperOracle(superOracle).isUp(tokenIn);
    }

    /**
     * @notice Gets the price of an underlying asset in USD.
     * @param tokenIn The address of the underlying asset.
     * @return amountUSD The price of the asset in USD.
     * @return stddev The standard deviation of the price.
     * @return N Oracle parameter.
     * @return M Oracle parameter.
     */
    function getPrice(address tokenIn)
    public
    view
    returns (uint256 amountUSD, uint256 stddev, uint256 N, uint256 M)
    {
        if (isVault[tokenIn]) {
            return getPPS(tokenIn);
        } else if (isERC20[tokenIn]) {
            return getPriceERC20(tokenIn);
        } else {
            revert NotSupportedToken();
        }
    }

    function relativeStdDev(uint256 mu, uint256 sigma) pure returns (uint256) {
        return (sigma * 1e18) / mu; // Adjust for decimals
    }

    function convertAssetToUSD(address tokenIn, uint256 amountAsset) public view returns (uint256 amountUSD, bool isDepeg, bool isDispersion, bool isOracleOff) {
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();
        (uint256 mu, uint256 sigma, uint256 N, uint256 M) = superOracle.getQuoteFromProvider(
            amountAsset,
            tokenIn,
            USD,                    // TODO: Add USD definition
            AVERAGE_PROVIDER        // TODO: Add AVERAGE_PROVIDER definition, taking it from SuperOracle
        );

        // Circuit Breaker for Oracle Off
        if (M == 0) {
            return (emergencyPrices[tokenIn], false, false, true);
        }

//        (uint256 mu, uint256 sigma, uint256 N, uint256 M) = getPrice(tokenIn);
        amountUSD = (amountAsset * mu) / 1e18; // Adjust for decimals
    }

    /**
     * @notice Gets the price per share of a vault in USD.
     * @param share The address of the vault.
     * @return ppsMu The price per share (mean).
     * @return ppsSigma The standard deviation of the price per share.
     * @return N Oracle parameter.
     * @return M Oracle parameter.
     */
    function getPPS(address share)
    public
    view
    returns (uint256 ppsMu, uint256 ppsSigma, uint256 N, uint256 M)
    {
        if (!isVault[share]) revert NotVault();
        address asset = IEIP7540(share).asset(); // or IEIP4626
        uint256 amountAssetPerShare = IEIP7540(share).convertToAssets(1e18); // Amount of asset for 1 share.
        (uint256 mu, uint256 sigma, N, M) = ISuperOracle(superOracle).getMeanPrice(asset);
        ppsMu = (amountAssetPerShare * mu) / 1e18; //  Adjust for decimals
        ppsSigma = (amountAssetPerShare * sigma) / 1e18; // Adjust for decimals
    }

    function getPriceERC20(address token)
        public
        view
        returns (uint256 mu, uint256 sigma, uint256 N, uint256 M)
    {
        if (!isERC20[token]) revert NotERC20Token();
        (mu, sigma, N, M) = ISuperOracle(superOracle).getMeanPrice(token);
    }

    // --- Settlement Token Management ---

    function setSettlementTokenIn(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        settlementTokenIn = token;
        emit SettlementTokenInSet(token);
    }

    function setSettlementTokenOut(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        settlementTokenOut = token;
        emit SettlementTokenOutSet(token);
    }

    function setSuperOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (oracle == address(0)) revert ZeroAddress();
        superOracle = ISuperOracle(oracle);
        emit SuperOracleSet(oracle);
    }

    // --- Internal Functions ---
    //  Placeholder functions.  These need to be implemented with a proper
    //  mechanism for minting and burning (e.g., using an ERC20 implementation,
    //  or a custom solution).
    function _mintSuperUSD(address receiver, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        _mint(receiver, amount);
    }

    function _burnSuperUSD(address sender, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf(sender) < amount) revert InsufficientBalance();
        _burn(sender, amount);
    }

    function _settleIncentive(address user, int256 amount) internal {
        // Interface for the IncentiveCalculationContract
        IIncentiveCalculationContract icc = IIncentiveCalculationContract(incentiveCalculationContract);

        // Call getAllocations()
        (uint256[] memory allocationPreOperation, uint256 totalCurrentAllocation, uint256[] memory allocationTarget, uint256 totalTargetAllocation) = getAllocations();

        // Call the calculateIncentive function
        int256 incentive = icc.calculateIncentive(
            allocationPreOperation,
            totalCurrentAllocation,
            allocationPreOperation,

            allocationTarget,
            totalTargetAllocation,
            new uint256[](0), // Placeholder, adjust as needed
            new uint256[](0)  // Placeholder, adjust as needed
        );

//        IIncentiveFundContract(incentiveFundContract).settleIncentive(user, amount);
    }
}
