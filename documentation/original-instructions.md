# Project Overview
You are responsible for building a SuperVault. A SuperVault is a ERC7540 vault that allows users to deposit and withdraw assets across multiple yield sources. 

You will be using foundry and solidity to build the project, together with openzeppelin-contracts as a library.

The repository is structured as follows:
- `src/periphery`: contains the code for the SuperVault
- `src/core`: contains the code for the core functionalities of Superform core (which may be leveraged, such as hooks and yield source oracles)

The EIP7540 must be followed to the letter. 

# Core Functionalities


1. Yield Source Management and Configuration - COMPLETE
    1. Global configurations for
        1. VaultCap: Maximum assets per individual yield source - used to limit the amount of assets that can be deposited into a single yield source in allocations by managers
        2. SuperVaultCap: Maximum total assets across all yield sources - used to limit the amount of assets that can be deposited into the vault by users
        3. MaxAllocationRate: Maximum allocation percentage per yield source - used to limit the amount of assets that can be allocated to a single yield source, in percentage terms, at any given time (checked in memory in fulfillments or allocations)
        4. VaultThreshold: Minimum TVL of a yield source that can be interacted with
    2. Propose new yield sources with associated yield source oracle address from v2-core gated by a role manager
        1. The proposal goes into a timelock queue of a week
        2. After a week, the proposal can be executed by anyone via an execute function
    3. Deactivate yield sources gated by a role manager
    4. Propose new merkle root of hook addresses to be used in the entire system. This function is gated by a role manager
        1. The proposal goes into a timelock queue of a week
        2. After a week, the proposal can be executed by anyone via an execute function
    5. Each yield source address has a configuration that includes:
        1. Associated yield source oracle address
        2. Active status
    6. Configure the fee in BPS for the vault with a given recipient address gated by a role manager
2. Ability to request to deposit assets via requestDeposit of ERC7540  - COMPLETE
    1. Users send assets via ERC7540 requestDeposit
    2. Assets are transferred to the vault for future allocation by a strategist
3. Strategists take each user address's address to fulfill the deposit and pass it to a 'fulfillDepositRequests' function  - COMPLETE
    1. Funds deposited by the users can be deposited via a fulfillDepositRequests function by a keeper (fulfillment of each user request must be done in full)
    2. This fulfillment happens to the yield sources that are active and have the hook addresses that are allowed to be used via the merkle root check
    3. Calldata is prebuilt and passed into each hook build function. Each hook build function returns an Execution struct. This struct contains the target (which is a yield source present in this system) and the calldata to be executed on the target. For this purpose v2-core hooks are used.
    4. For each user, an entry is inscribed into the accounting ledger system to track shares minted and their PPS
        1. Note, when redeeming, we only know assets, but here we inscribed shares
    5. All users' requests fulfilled this way are moved to claimable and each user can call ERC4626 deposit to get their shares
    6. Only a single hooks, yield sources and calldata sequence is used for all users being fulfilled at once
4. Ability to allocate funds deployed by the SuperVault in any way desired (withdraw/deposits at will), via an 'allocate' function by strategists - COMPLETE
    1. Strategists pass a list of yield sources, calldata and hooks per yield source, proofs of hooks per yield source to a function that will execute the allocations
    2. The function will verify the selectors via Merkle proof verification
    3. The function will then execute the allocations one by one by calling the appropriate selectors and calldata passed in. Each hook build function of a hook returns an Execution struct. This struct contains the target and the calldata passed in to be executed on the target. For this purpose v2-core is used.
    4. VaultCap, MaxAllocationRate and VaultThreshold must be checked accordingly during the allocation process
        1. For MaxAllocationRate, we temporarly calculate the allocation percentage for each yield source and check if it is within the limit
5. User claims their shares by calling ERC4626 deposit - COMPLETE
    1. The deposit function will check if the user has any shares to claim
    2. If the user has shares to claim, the shares are transferred to the user
6. Ability to request to redeem assets - COMPLETE
    1. Users send approved vault shares to redeem via requestRedeem of ERC7540
    2. Shares are burned and a request to redeem is placed in a queue
7. Strategists take each user's address to fulfill the redeem and pass it to a 'fulfillRedeemRequests' function - COMPLETE
    1. A function to fulfill redeem requests is called by a keeper (fulfillment of each user request must be done in full). The keeper passes:
        1. List of yield sources to redeem from
        2. Calldata and hooks per yield source
        3. Proofs of hooks per yield source
        4. Array of users to fulfill per yield source
    2. The function will then execute the redeem request by calling the appropriate selectors and calldata of each yield source and redeem according to instructed
    3. For each user, the ledger is looked upon to get entries for the user's assets
        1. Given we inscribe shares, we must convert shares to assets at each PPS when they were inscribed, to properly determine the PNL in assets
    4. Assets are moved to claimable for each user fulfilled this way and each user can call ERC4626 redeem to get their assets
8. Strategists are able to call a 'matchRequests' function that performs the following:  - COMPLETE
    1. Users that have pending redeem requests are matched with users that have pending deposit requests
    2. For pending redeem requests only look at number of assets requested. These users have shares temporarily locked available to give depositors who need them
    3. For pending deposit requests, we only need at number of shares requested, these users have money available as "freeFunds" state variable in the vault
    4. When matching, no yield sources access is made
    5. Each users' deposit request is prioritized to be fulfilled by one or more user requests to redeem shares (their shares are transferred to these users)
    6. All deposit requests must be fully filled, but redeem requests don't need to be consumed entirely (meaning, some pendingRequestRedeem can be left over)    
    7. This function assumes the keeper knows exactly the match needed
    8. For users receiving shares, an entry is inscribed into the accounting ledger system to track that action and the respective PPS
    9. For users receiving assets, the ledger is looked upon to get entries for the user's assets. Given we inscribed shares in deposit(), we must convert shares to assets at each PPS when it was inscribed, to properly determine the PNL in assets.
9. Ability to claim their assets by calling ERC4626 redeem - COMPLETE
    1. Each user can call ERC4626 redeem to get their assets once in claimable state
    2. The redeem function will check if the user has any assets to claim
    3. If the user has assets to claim, the assets are transferred to the user
    4. The ledger is looked upon to get entries for the user's assets. Given we inscribed shares in deposit(), we must convert shares to assets at each PPS when it was inscribed, to properly determine the PNL in assets.
10. Ability to claim rewards accrued by the vault
    1. A keeper is able to call claim with a list of yield sources to claim from and approved selectors which are matched against the merkle root
    2. Calldata is prebuilt and passed into each hook build function. Each hook build function returns an Execution struct. This struct contains the target (which is a yield source present in this system) and the calldata to be executed on the target. For this purpose v2-core hooks are used.
    3. The claimed rewards are available in the vault's balance. Strategists can pass in these amounts to allocate them to yield sources to reinvest (by passing a swap hook)
    - claimAndAutocompound 
        - Has three sets of hooks, hook proofs and call data: one set for claim (non inflow or outflow), another set for swapping the claimed tokens to asset (non inflow or outflow) and another set for allocation into the vault (INFLOW only). In addition, there is an array which contains the expected tokens out from each claim hook call
        - During first set execution, hooks are called normally as the current claimRewards() implementation. This is going to be internalized as it is going to be re-used in claimAndDistribute
        -  At the end of loop of the execution we check the balance of the expected tokens out increased (and save the increase)
        - Then the second set of hooks is executed. Now we swap all expected tokens out different than asset for asset. We must check the balance increase was negated for expected tokens and note the balance increase for asset between all operations
        - Third, we supply asset as desired to the yield sources. Normal constraint checks apply, similar to allocate in inflow hooks. It should internalize the inflow approach in allocate and re-use it here
        - At the end we verify that the balance of asset reset exactly to the original value, pre swaps, otherwise revert the entire function
    - claimAndDistribute
        - Has two sets of hooks, hook proofs and call data: one set for claim (non inflow or outflow)  just like current claim and another set to distribute tokens to users (also non inflow or outflow). It also includes an array of expectedTokensOut
        - Follows exactly he process like 1st claim step of claimAndAutocompound including the balance check at the end of the first set (all of this can be internalized between the two functions)
        - The second set of hooks is executed. There are no checks or constraints in this call, but they must target a specific rewards address (set by the manager in a separate function). This avoid a strategist being able to designate arbitrary targets during claimAndDistribute
        - These hooks are expected to distribute the claimed tokens, thus we check the balance for the expectedTokensOut decreases
11. Implement ERC7540 cancelation flow of requests  - COMPLETE
    1. Users are able to call cancelRedeemRequest and cancelDepositRequest to cancel their requests
    2. This is made according to IERC7540CancelDeposit and IERC7540CancelRedeem
    3. Other functions should have checks to ensure they cannot act upon requests that have a cancelation request
12. Access Control    - COMPLETE
    1. Transfer strategist role to new address
    2. Strategist-only functions for critical operations
    3. Cannot transfer to zero address
13. Emergency Controls   - COMPLETE
    1. Emergency pause functionality
    2. Emergency withdrawal mechanisms
14. Relevant interfaces for SuperVaults   - COMPLETE
    1. All errors in CAMEL_CASE
    2. All events and structs are placed in this interface
    3. Should have the scaffolding of the main functions that are core to this contract (it shouldn't inherit or put functions from ERC7540 or ERC4626)
    4. Format according to solidity natspec (https://docs.soliditylang.org/en/latest/style-guide.html)  
15. SuperVaults factory
    1. Proxy Implementation pattern for SuperVaults to reduce init size
    2. Create new SuperVaults on demand with new parameters
        1. **Vault Cap:** Hard cap on the total allocation to a single vault (e.g., 1000000000 USDC).
        2. **Super Vault Cap**: Total cap on the SuperVault
        3. **Vault Threshold**: Vaults must meet a threshold total value locked (e.g., 1000000 USDC) to be eligible for allocations, reducing risk from low-liquidity pools.
        4. **Max Allocation Rate**: Amount of the portfolio that can be allocated to any one vault (e.g., 20%).
        5. **Name:** Name of the SuperVault (ERC4626 compliance)
        6. **Symbol**: Symbol of the SuperVault (ERC4626 compliance)
        7. **Asset:** Vaults can only accept and make deposits in a singular, pre-defined asset. 
        8. **Initial MerkleRoot of Hooks:** To ensure all hooks within SuperVaults are **verifiable and secure**, the Factory passes a initial merkle root of a list containing the only authorized hooks (e.g., for deposit, redeem, stake operations) to be utilized in vault strategies. This integration ensures that all rebalancing and operational actions remain within mandates, protecting users from unauthorized or risky modifications.
        9. **FeePercentInBps**: Vault creators can configure management and performance fees, subject to governance-set caps. These fees incentivize agents while maintaining user-friendliness and transparency.
        10. **FeeRecipient: Receives fees**
        11. **Keeper: Fulfills user requests**
        12. **Strategist: Performs allocations**
        13. **EmergencyAdmin**: Has admin access to some function in case manager is locked out


# Documentation
## Documentation of an example matching implementation
CODE_EXAMPLE
```solidity
contract SuperVault {
    struct RedeemRequest {
        address user;
        uint256 assetsWanted;    // Assets they want to receive
        uint256 sharesLocked;    // Shares they've locked
        uint256 assetsReceived;  // Running total of assets matched
    }

    struct DepositRequest {
        address user;
        uint256 sharesWanted;    // Shares they want to receive
        uint256 assetsDeposited; // Assets they've deposited
        uint256 sharesReceived;  // Running total of shares matched
    }

    /// @notice Match redeem requests with deposit requests
    /// @dev All requests must be fully matched or the function reverts
    function matchRequests(
        address[] calldata redeemUsers,
        address[] calldata depositUsers
    ) external onlyStrategist nonReentrant {
        // Step 1: Collect and validate all requests
        (
            RedeemRequest[] memory redeems,
            DepositRequest[] memory deposits,
            uint256 totalAssetsRequested,
            uint256 totalAssetsAvailable
        ) = _collectRequests(redeemUsers, depositUsers);

        // Quick check: total assets must match
        if (totalAssetsRequested != totalAssetsAvailable) revert AMOUNTS_DONT_MATCH();

        // Step 2: Match requests
        _matchAndExecute(redeems, deposits);

        // Step 3: Verify all requests were fully matched
        _verifyFullMatches(redeems, deposits);
    }

    function _collectRequests(
        address[] calldata redeemUsers,
        address[] calldata depositUsers
    ) internal view returns (
        RedeemRequest[] memory redeems,
        DepositRequest[] memory deposits,
        uint256 totalAssetsRequested,
        uint256 totalAssetsAvailable
    ) {
        // Collect redeem requests
        redeems = new RedeemRequest[](redeemUsers.length);
        for (uint256 i = 0; i < redeemUsers.length; i++) {
            address user = redeemUsers[i];
            uint256 assetsWanted = pendingRedeemRequest[user].assets;
            uint256 sharesLocked = pendingRedeemRequest[user].shares;
            
            if (assetsWanted == 0 || sharesLocked == 0) revert INVALID_REQUEST();
            
            redeems[i] = RedeemRequest({
                user: user,
                assetsWanted: assetsWanted,
                sharesLocked: sharesLocked,
                assetsReceived: 0
            });
            
            totalAssetsRequested += assetsWanted;
        }

        // Collect deposit requests
        deposits = new DepositRequest[](depositUsers.length);
        for (uint256 i = 0; i < depositUsers.length; i++) {
            address user = depositUsers[i];
            uint256 sharesWanted = pendingDepositRequest[user].shares;
            uint256 assetsDeposited = pendingDepositRequest[user].assets;
            
            if (sharesWanted == 0 || assetsDeposited == 0) revert INVALID_REQUEST();
            
            deposits[i] = DepositRequest({
                user: user,
                sharesWanted: sharesWanted,
                assetsDeposited: assetsDeposited,
                sharesReceived: 0
            });
            
            totalAssetsAvailable += assetsDeposited;
        }
    }

    function _matchAndExecute(
        RedeemRequest[] memory redeems,
        DepositRequest[] memory deposits
    ) internal {
        // For each redeem request
        for (uint256 i = 0; i < redeems.length; i++) {
            RedeemRequest memory redeem = redeems[i];
            uint256 remainingAssets = redeem.assetsWanted;
            uint256 remainingShares = redeem.sharesLocked;

            // Try to fulfill with deposits
            for (uint256 j = 0; j < deposits.length && remainingAssets > 0; j++) {
                DepositRequest memory deposit = deposits[j];
                
                // Skip if deposit is fully matched
                if (deposit.sharesReceived == deposit.sharesWanted) continue;

                // Calculate matching amounts
                uint256 matchableAssets = Math.min(
                    remainingAssets,
                    deposit.assetsDeposited - _convertSharesToAssets(deposit.sharesReceived)
                );
                uint256 matchableShares = _convertAssetsToShares(matchableAssets);

                if (matchableShares > 0 && matchableShares <= remainingShares) {
                    // Execute the match
                    _executeMatch(
                        redeem.user,
                        deposit.user,
                        matchableAssets,
                        matchableShares
                    );

                    // Update running totals
                    redeem.assetsReceived += matchableAssets;
                    deposit.sharesReceived += matchableShares;
                    remainingAssets -= matchableAssets;
                    remainingShares -= matchableShares;
                }
            }
        }
    }

    function _verifyFullMatches(
        RedeemRequest[] memory redeems,
        DepositRequest[] memory deposits
    ) internal pure {
        // Verify all redeems were fully matched
        for (uint256 i = 0; i < redeems.length; i++) {
            if (redeems[i].assetsReceived != redeems[i].assetsWanted) {
                revert INCOMPLETE_REDEEM_MATCH();
            }
        }

        // Verify all deposits were fully matched
        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].sharesReceived != deposits[i].sharesWanted) {
                revert INCOMPLETE_DEPOSIT_MATCH();
            }
        }
    }

    function _executeMatch(
        address redeemer,
        address depositor,
        uint256 assets,
        uint256 shares
    ) internal {
        // Transfer shares from redeemer to depositor
        _transferShares(redeemer, depositor, shares);
        
        emit MatchExecuted(
            redeemer,
            depositor,
            assets,
            shares
        );
    }
}
```

## Documentation of a hook's build function in v2-core
CODE_EXAMPLE
```solidity
    function build(
        address prevHook,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address account = data.extractAccount();
        address yieldSource = data.extractYieldSource();
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 104);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: yieldSource, value: 0, callData: abi.encodeCall(IERC4626.deposit, (amount, account)) });
    }
```

# Current file structure
v2-SuperVaults
├── LICENSE-MIT
├── Makefile
├── README.md
├── foundry.toml
├── instructions
│   └── instructions.md
├── lib
│   ├── forge-std
│   └── openzeppelin-contracts
├── script
│   └── utils
├── src
├── test
└── utils
    └── retrieve-abis.sh