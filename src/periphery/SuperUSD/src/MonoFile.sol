// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SuperUSD created by Gemini form PRD
 * @notice Need to be split into different files and contracts and fixed 
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Abstract interface for the SuperOracle
interface ISuperOracle {
    function getMeanPrice(address token) external view returns (uint256 mu, uint256 sigma, uint256 N, uint256 M);
    function isDepeg(address token) external view returns (bool);
    function isDispersion(address token) external view returns (bool);
    function isUp(address token) external view returns (bool);
}

// Abstract interface for EIP7540
interface IEIP7540 {
    function deposit(address receiver, address token, uint256 amount, uint256 minShares) external returns (uint256 shares);
    function redeem(address receiver, uint256 shares, address token, uint256 minAmount) external returns (uint256 amount);
    function previewDeposit(address token, uint256 amount) external view returns (uint265);
    function previewRedeem(uint265 shares) external view returns (uint265);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

// Abstract interface for EIP4626
interface IEIP4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver) external returns (uint256 assets);
    function previewDeposit(uint256 assets) external view returns (uint265);
    function previewRedeem(uint265 shares) external view returns (uint265);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

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
        address _swapFeeFundContract
    ) {
        require(_incentiveCalculationContract != address(0), "SuperUSD: ICC address cannot be zero");
        require(_incentiveFundContract != address(0), "SuperUSD: Incentive Fund address cannot be zero");
        require(_swapFeeFundContract != address(0), "SuperUSD: Swap Fee Fund address cannot be zero");

        incentiveCalculationContract = _incentiveCalculationContract;
        incentiveFundContract = _incentiveFundContract;
        swapFeeFundContract = _swapFeeFundContract;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(VAULT_MANAGER_ROLE, msg.sender);
        _setupRole(SWAP_FEE_MANAGER_ROLE, msg.sender);
        _setupRole(INCENTIVE_FUND_MANAGER, msg.sender);
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

        // Calculate swap fees (example: 0.1% fee)
        uint256 swapFee = (amountTokenToDeposit * 1) / 1000; // 0.1%
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

/**
 * @title Incentive Calculation Contract (ICC)
 * @notice A stateless contract for calculating incentives.
 */
contract IncentiveCalculationContract {
    // --- View Functions ---

    /**
     * @notice Calculates the energy function.
     * @param allocationPreOperation The allocation before the operation.
     * @param allocationTarget The target allocation.
     * @param weights The weights for each asset.
     * @return energy The calculated energy.
     */
    function energy(
        uint256[] memory allocationPreOperation,
        uint256[] memory allocationTarget,
        uint256[]memory weights
    ) public pure returns (uint256 energy) {
        require(allocationPreOperation.length == allocationTarget.length &&
                allocationPreOperation.length == weights.length,
                "ICC: Input arrays must have the same length");

        for (uint256 i = 0; i < allocationPreOperation.length; i++) {
            //  Safe subtraction to avoid underflow
            uint256 diff;
            if (allocationPreOperation[i] > allocationTarget[i]) {
                diff = allocationPreOperation[i] - allocationTarget[i];
            } else {
                diff = allocationTarget[i] - allocationPreOperation[i];
            }
            energy += (diff * diff * weights[i]); // Simplified square
        }
    }

    /**
     * @notice Calculates the incentive.
     * @param allocationPreOperation The allocation before the operation.
     * @param allocationPostOperation The allocation after the operation.
     * @param allocationTarget The target allocation.
     * @return incentive The calculated incentive.
     */
    function calculateIncentive(
        uint256[] memory allocationPreOperation,
        uint256[] memory allocationPostOperation,
        uint256[] memory allocationTarget
    ) public view returns (uint256 incentive) {
        require(allocationPreOperation.length == allocationPostOperation.length &&
                allocationPreOperation.length == allocationTarget.length,
                "ICC: Input arrays must have the same length");
        // Example weights (replace with actual weights)
        uint256[] memory weights = new uint256[](allocationPreOperation.length);
        for(uint i = 0; i < weights.length; i++){
            weights[i] = 1; // default weight
        }

        uint256 energyBefore = energy(allocationPreOperation, allocationTarget, weights);
        uint256 energyAfter = energy(allocationPostOperation, allocationTarget, weights);
        //  Simplified incentive calculation (replace with actual calculation)
        incentive = (energyBefore > energyAfter) ? (energyBefore - energyAfter) : 0;
        incentive = (incentive * 10) / 100; // Example: 10% of the energy difference
    }
}

/**
 * @title Incentive Fund Contract
 * @notice Manages incentive tokens.
 */
contract IncentiveFundContract is AccessControl {
    // --- State ---
    address public tokenInIncentive;  // The token users send incentives to.
    address public tokenOutIncentive; // The token we pay incentives with.

    // --- Events ---
    event IncentivePaid(address receiver, address tokenOut, uint256 amount);
    event IncentiveTaken(address sender, address tokenIn, uint256 amount);
    event RebalanceWithdrawal(address receiver, address tokenOut, uint256 amount);
    event SettlementTokenInSet(address token);
    event SettlementTokenOutSet(address token);

    // --- Constructor ---
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(INCENTIVE_FUND_MANAGER, msg.sender);
    }

    // --- State Changing Functions ---

    /**
     * @notice Pays incentives to a receiver.
     * @param receiver The address to receive the incentives.
     * @param tokenOut The token to pay the incentives in.
     * @param amount The amount of incentives requested.
     * @return amountOut The amount of incentives actually paid.
     */
    function payIncentive(address receiver, address tokenOut, uint256 amount)
        external
        onlyRole(INCENTIVE_FUND_MANAGER)
        returns (uint256 amountOut)
    {
        require(receiver != address(0), "IncentiveFund: Receiver cannot be zero address");
        require(tokenOut != address(0), "IncentiveFund: TokenOut cannot be zero address");

        amountOut = previewPayIncentive(tokenOut, amount);
        IERC20(tokenOut).transfer(receiver, amountOut);
        emit IncentivePaid(receiver, tokenOut, amountOut);
    }

    /**
     * @notice Takes incentives from a sender.
     * @param sender The address to send the incentives from.
     * @param tokenIn The token the incentives are paid in.
     * @param amount The amount of incentives to take.
     */
    function takeIncentive(address sender, address tokenIn, uint256 amount)
        external
        onlyRole(INCENTIVE_FUND_MANAGER)
    {
        require(sender != address(0), "IncentiveFund: Sender cannot be zero address");
        require(tokenIn != address(0), "IncentiveFund: TokenIn cannot be zero address");

        IERC20(tokenIn).transferFrom(sender, address(this), amount);
        emit IncentiveTaken(sender, tokenIn, amount);
    }

    /**
     * @notice Settles incentives for a user.
     * @param user The address of the user.
     * @param amount The amount of incentives (positive for pay, negative for take).
     */
    function settleIncentive(address user, int256 amount) internal {
        if (amount > 0) {
            payIncentive(user, tokenOutIncentive, uint256(amount));
        } else if (amount < 0) {
            takeIncentive(user, tokenInIncentive, uint256(-amount));
        }
        // If amount == 0, do nothing.
    }

    /**
     * @notice Withdraws tokens from the fund.
     * @param receiver The address to receive the tokens.
     * @param tokenOut The token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdraw(address receiver, address tokenOut, uint256 amount)
        external
        onlyRole(INCENTIVE_FUND_MANAGER)
    {
        require(receiver != address(0), "IncentiveFund: Receiver cannot be zero address");
        require(tokenOut != address(0), "IncentiveFund: TokenOut cannot be zero address");

        IERC20(tokenOut).transferFrom(address(this), receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }

    // --- View Functions ---

    /**
     * @notice Preview the amount of incentives to pay.
     * @param tokenOut The token to pay the incentives in.
     * @param amount The amount of incentives requested.
     * @return amountOut The actual amount of incentives to pay.
     */
    function previewPayIncentive(address tokenOut, uint256 amount)
        public
        view
        returns (uint256 amountOut)
    {
        require(tokenOut != address(0), "IncentiveFund: TokenOut cannot be zero address");
        amountOut = _cappingLogic(tokenOut, amount);
    }

    // --- Internal Functions ---

    /**
     * @notice Applies capping logic to the incentive amount.
     * @param tokenOut The token to pay the incentives in.
     * @param amount The amount of incentives.
     * @return cappedAmount The capped amount of incentives.
     */
    function _cappingLogic(address tokenOut, uint256 amount)
        internal
        view
        returns (uint256 cappedAmount)
    {
        // TBD: It could be something no more than X% of the remaining availability for tokenOut
        uint256 balance = IERC20(tokenOut).balanceOf(address(this));
        cappedAmount = (amount <= balance) ? amount : balance; // Simple cap: amount or balance, whichever is smaller
    }

     function setSettlementTokenIn(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "IncentiveFund: Token address cannot be zero");
        tokenInIncentive = token;
        emit SettlementTokenInSet(token);
    }

    function setSettlementTokenOut(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "IncentiveFund: Token address cannot be zero");
        tokenOutIncentive = token;
        emit SettlementTokenOutSet(token);
    }
}

/**
 * @title Swap Fee Fund
 * @notice Manages swap fee tokens.
 */
contract SwapFeeFund is AccessControl{

    // --- Events ---
    event RebalanceWithdrawal(address receiver, address tokenOut, uint256 amount);

    // --- Constructor ---
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(INCENTIVE_FUND_MANAGER, msg.sender);
    }

    // --- State Changing Functions ---

    /**
     * @notice Withdraws tokens from the fund.
     * @param receiver The address to receive the tokens.
     * @param tokenOut The token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdraw(address receiver, address tokenOut, uint256 amount)
        external
        onlyRole(INCENTIVE_FUND_MANAGER)
    {
        require(receiver != address(0), "SwapFeeFund: Receiver cannot be zero address");
        require(tokenOut != address(0), "SwapFeeFund: TokenOut cannot be zero address");

        IERC20(tokenOut).transferFrom(address(this), receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }
}
