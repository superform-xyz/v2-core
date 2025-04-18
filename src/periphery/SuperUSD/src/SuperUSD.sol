// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;



/**
 * @title SuperUSD
 * @notice A meta-vault that manages deposits and redemptions across multiple underlying vaults.
 */
contract SuperUSD is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;


    // --- Roles ---
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant SWAP_FEE_MANAGER_ROLE = keccak256("SWAP_FEE_MANAGER_ROLE");
    bytes32 public constant INCENTIVE_FUND_MANAGER = keccak256("INCENTIVE_FUND_MANAGER");

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

    uint256 public swapFeePercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)

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
        require(isVault[msg.sender], "SuperUSD: Sender is not a whitelisted vault");
        _;
    }

    modifier onlyERC20() {
        require(isERC20[msg.sender], "SuperUSD: Sender is not a whitelisted ERC20");
        _;
    }

    // --- Constructor ---
    constructor(
        address _incentiveCalculationContract,
        address _incentiveFundContract,
        address _swapFeeFundContract,
        uint256 _swapFeePercentage
    ) {
        require(_incentiveCalculationContract != address(0), "SuperUSD: ICC address cannot be zero");
        require(_incentiveFundContract != address(0), "SuperUSD: Incentive Fund address cannot be zero");
        require(_swapFeeFundContract != address(0), "SuperUSD: Swap Fee Fund address cannot be zero");
        require(_swapFeePercentage <= 1000, "SuperUSD: Swap fee percentage too high"); // Max 10%
        incentiveCalculationContract = _incentiveCalculationContract;
        incentiveFundContract = _incentiveFundContract;
        swapFeeFundContract = _swapFeeFundContract;
        swapFeePercentage = _swapFeePercentage;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(VAULT_MANAGER_ROLE, msg.sender);
        _setupRole(SWAP_FEE_MANAGER_ROLE, msg.sender);
        _setupRole(INCENTIVE_FUND_MANAGER, msg.sender);
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
        for (uint256 i = 0; i < length; i++) {
            address vault = _supportedVaults.at(i);
            absoluteCurrentAllocation[i] = IERC20(vault).balanceOf(address(this));
            totalCurrentAllocation += absoluteCurrentAllocation[i];
            absoluteTargetAllocation[i] = targetAllocations[vault];
            totalTargetAllocation += absoluteTargetAllocation[i];
        }
    }

    function setSwapFeePercentage(uint256 _swapFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_swapFeePercentage <= 1000, "SuperUSD: Swap fee percentage too high"); // Max 10%
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
        uint256 minSharesOut
    ) external returns (uint256 amountSharesOut) {
        require(isVault[tokenIn] || isERC20[tokenIn], "SuperUSD: Token not supported");
        require(receiver != address(0), "SuperUSD: Receiver cannot be zero address");

        // TODO: Transfer the tokenIn from the sender to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountTokenToDeposit);

        // Calculate swap fees (example: 0.1% fee)
        // TODO: Make it a governance params
        // TODO: Use mulDiv() for better precision
        //  Example: 0.1% fee
        //  uint256 swapFee = (amountTokenToDeposit * 1) / 1000; // 0.1%
        //  uint256 amountAfterFees = amountTokenToDeposit - swapFee;
        uint256 swapFee = Math.mulDiv(amountTokenToDeposit, swapFeePercentage, 10000); // Swap fee based on percentage
        uint256 amountAfterFees = amountTokenToDeposit - swapFee;

        // Transfer swap fees to Swap Fee Fund
        IERC20(tokenIn).transfer(swapFeeFundContract, swapFee);

        // Deposit into underlying vault or handle ERC20
        uint256 underlyingShares;
        if (isVault[tokenIn]) {
            underlyingShares = IEIP7540(tokenIn).deposit(address(this), IERC20(tokenIn).asset(), amountAfterFees, 0); // Use 0 for minShares
        } else {
            //  Handle ERC20 deposit (simplified -  no vault involved, mint shares directly)
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountAfterFees);
            underlyingShares = amountAfterFees; // Example: 1:1 conversion.  Adjust as needed.
        }

        // TODO: Replace this with calling SuperOracle to get the conversion price
        // Get price of underlying vault shares in USD
        (uint256 pricePerShare,) = getPrice(tokenIn);

        // Calculate SuperUSD shares to mint
        amountSharesOut = (underlyingShares * pricePerShare) / 1e18; // Adjust for decimals

        require(amountSharesOut >= minSharesOut, "SuperUSD: Amount of shares is less than minSharesOut");

        // Mint SuperUSD shares (assuming this contract is a minter)
        //  Missing mint function.  For demo, assume a simple state variable.
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
        require(isVault[tokenOut] || isERC20[tokenOut], "SuperUSD: Token not supported");
        require(receiver != address(0), "SuperUSD: Receiver cannot be zero address");

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
        uint256 swapFee = (amountBeforeFees * 1) / 1000; // 0.1%
        amountTokenOut = amountBeforeFees - swapFee;

        // Transfer swap fees to Swap Fee Fund
        IERC20(tokenOut).transferFrom(address(this), swapFeeFundContract, swapFee);

        // Transfer assets to receiver
        IERC20(tokenOut).transfer(receiver, amountTokenOut);

        require(amountTokenOut >= minTokenOut, "SuperUSD: Amount of token is less than minTokenOut");

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
        require(receiver != address(0), "SuperUSD: Receiver cannot be zero address");
        uint256 amountSharesOut = deposit(address(this), tokenIn, amountTokenToDeposit, minSharesOut);
        amountTokenOut = redeem(receiver, amountSharesOut, tokenOut, minTokenOut);
        emit Swap(receiver, tokenIn, amountTokenToDeposit, tokenOut, amountSharesOut, amountTokenOut);
        return amountTokenOut;
    }

    // --- Vault Whitelist Management ---
    function whitelistVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        require(vault != address(0), "SuperUSD: Vault address cannot be zero");
        require(!isVault[vault], "SuperUSD: Vault already whitelisted");
        isVault[vault] = true;
        _supportedVaults.add(vault);
        emit VaultWhitelisted(vault);
    }

    function removeVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        require(vault != address(0), "SuperUSD: Vault address cannot be zero");
        require(isVault[vault], "SuperUSD: Vault not whitelisted");
        isVault[vault] = false;
        _supportedVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    function whitelistERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        require(token != address(0), "SuperUSD: Token address cannot be zero");
        require(!isERC20[token], "SuperUSD: Token already whitelisted");
        isERC20[token] = true;
        emit ERC20Whitelisted(token);
    }

    function removeERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        require(token != address(0), "SuperUSD: Token address cannot be zero");
        require(isERC20[token], "SuperUSD: Token not whitelisted");
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
        require(isVault[tokenIn] || isERC20[tokenIn], "SuperUSD: Token not supported");

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
        require(isVault[tokenOut] || isERC20[tokenOut], "SuperUSD: Token not supported");

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
        require(isVault[tokenIn] || isERC20[tokenIn], "SuperUSD: Token not supported");
        res = ISuperOracle(superOracle).isDepeg(tokenIn);
    }

    /**
     * @notice Checks if the uncertainty of an underlying asset's price is too high.
     * @param tokenIn The address of the underlying asset.
     * @return res True if the uncertainty is too high, false otherwise.
     */
    function isDispersion(address tokenIn) public view returns (bool res) {
        require(isVault[tokenIn] || isERC20[tokenIn], "SuperUSD: Token not supported");
        res = ISuperOracle(superOracle).isDispersion(tokenIn);
    }

    /**
     * @notice Checks if the SuperOracle is up.
     * @param tokenIn The address of the underlying asset.
     * @return res True if the SuperOracle is up, false otherwise.
     */
    function isSuperOracleUp(address tokenIn) public view returns (bool res) {
        require(isVault[tokenIn] || isERC20[tokenIn], "SuperUSD: Token not supported");
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
            revert("SuperUSD: Unsupported tokenIn");
        }
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
        require(isVault[share], "SuperUSD: Not a vault");
        address asset = IEIP7540(share).asset(); // or IEIP4626
        uint256 amountAssetPerShare = IEIP7540(share).convertToAssets(1e18); // Amount of asset for 1 share.
        (uint256 mu, uint256 sigma, N, M) = ISuperOracle(superOracle).getMeanPrice(asset);
        ppsMu = (amountAssetPerShare * mu) / 1e18; //  Adjust for decimals
        ppsSigma = (amountAssetPerShare * sigma) / 1e18; // Adjust for decimals
    }

    /**
     * @notice Gets the price of an ERC20 token in USD.
     * @param token The address of the ERC20 token.
     * @return mu The price (mean).
     * @return sigma The standard deviation of the price.
     * @return N Oracle parameter.
     * @return M Oracle parameter.
     */
    function getPriceERC20(address token)
    public
    view
    returns (uint256 mu, uint256 sigma, uint256 N, uint256 M)
    {
        require(isERC20[token], "SuperUSD: Not an ERC20 token");
        (mu, sigma, N, M) = ISuperOracle(superOracle).getMeanPrice(token);
    }

    // --- Settlement Token Management ---

    function setSettlementTokenIn(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "SuperUSD: Token address cannot be zero");
        settlementTokenIn = token;
        emit SettlementTokenInSet(token);
    }

    function setSettlementTokenOut(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "SuperUSD: Token address cannot be zero");
        settlementTokenOut = token;
        emit SettlementTokenOutSet(token);
    }

    function setSuperOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(oracle != address(0), "SuperUSD: Oracle address cannot be zero");
        superOracle = ISuperOracle(oracle);
        emit SuperOracleSet(oracle);
    }

    // --- Internal Functions ---
    //  Placeholder functions.  These need to be implemented with a proper
    //  mechanism for minting and burning (e.g., using an ERC20 implementation,
    //  or a custom solution).
    function _mintSuperUSD(address receiver, uint256 amount) internal {
        // Implement minting logic here.
        // For example, if you have a `_balances` mapping:
        // _balances[receiver] += amount;
    }

    function _burnSuperUSD(address sender, uint256 amount) internal {
        // Implement burning logic here.
        // For example, if you have a `_balances` mapping:
        // _balances[sender] -= amount;
    }

    function _settleIncentive(address user, int256 amount) internal {
        IIncentiveFundContract(incentiveFundContract).settleIncentive(user, amount);
    }
}


