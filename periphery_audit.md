# V2 Periphery Security Review

## Auditors

## Sujith Somraaj, Security Researcher

```
Report prepared by: Sujith Somraaj
```
```
June 8, 2025
```

## Contents


- 1 About Researcher
- 2 Disclaimer
- 3 Scope
- 4 Risk classification
   - 4.1 Impact
   - 4.2 Likelihood
   - 4.3 Action required for severity levels
- 5 Executive Summary
- 6 Findings
   - 6.1 Critical Risk
      - 6.1.1 Redemption fulfillment fails after share transfers
   - 6.2 High Risk
      - 6.2.1 SuperPosition transfer breaks cross-chain accounting in VaultBank
      - 6.2.2 Assets sent to wrong address inwithdraw()andredeem()functions of SuperVault
      - 6.2.3 Incorrect bundler address assignment inregisterBundler()function
   - 6.3 Medium Risk
      - 6.3.1 Permanent ownership lock of superPosition tokens
      - 6.3.2 SuperVault rounding inconsistency betweenmint()andconvertToAssets()
   - 6.4 Low Risk
         - Bank 6.4.1 Address-based accounting incompatible with cross-chain smart contracts in Vault-
      - 6.4.2 Unchecked chain validation causes permanent fund loss inlockAsset()
      - 6.4.3 Hard-coded address validation breaks cross-chain compatibility in VaultBank
      - 6.4.4 Operator can steal all owner funds via controller parameter manipulation
      - 6.4.5 ETH value forwarding with non-payable function
      - 6.4.6 FunctionregisterBundler()allows overwriting existing bundler data
      - 6.4.7 Potential bundler ID collision due to timestamp-based generation
      - 6.4.8 Sanity check_assetparameter in AssetMetadataLib
      - 6.4.9 Functionclaim()function is not compatible with non-EOA claimers
   - 6.5 Gas Optimization
      - 6.5.1 Declaretokenvariable outside loop inexecuteRemoveIncentiveTokens().
      - 6.5.2 Inefficient variable declarations inside loop
      - 6.5.3 Inconsistent error handling in UpDistributor
   - 6.6 Informational
      - 6.6.1 Use Ownable2Step instead of Ownable in VaultBankSuperPosition
      - 6.6.2 Missing event ininvalidateNonce().
      - 6.6.3 Unnecessary Code Complexity inrequestRedeem()of SuperVault
      - 6.6.4 Missing oracle address validation insetEmergencyPrice()function
      - 6.6.5 Shared timelock storage between add and remove incentive token functions
      - 6.6.6 Potential DoS ingetAllSuperformStrategists()function
      - 6.6.7 Logic error inexecuteRemoveIncentiveTokens()function
         - function 6.6.8 Missing zero-value vheck in timelock validation ofexecuteAddIncentiveTokens()
      - 6.6.9 Redundant contains check inexecuteAddIncentiveTokens()function
- 6.6.10 Sanity check oracle address inbatchSetEmergencyPrices()function
- 6.6.11 Declare constant_SUPER_ASSET_FACTORYasprivate
- 6.6.12 Possible DoS in_executeHooks()function of Bank
- 6.6.13 Remove redundantonlyStrategymodifier
- 6.6.14 Functionsclaim()andreclaimTokens()in UpDistributor violates CEI pattern
- 6.6.15 Insufficient validation in constructor of UpDistributor
- 6.6.16 Incorrect documentation about reclaiming tokens in UPDistributor


## 1 About Researcher

Sujith Somraaj is a distinguished security researcher and protocol engineer with over eight years of
comprehensive experience in the Web3 ecosystem.
In addition to working as a Security researcher at Spearbit, Sujith is also the security researcher and
advisor for bridge protocols, including LI.FI & Garden.Finance (over $25B in combined volume) and also
is a former founding engineer at Superform, a yield aggregator with over $150M in TVL.
Sujith has experience working with protocols including Monad, Blast, Berachain, Sonic, ZkSync, LI.FI,
Decent, Drips, SuperSushi Samurai, DistrictOne, Omni-X, Centrifuge, Tea.xyz, Paintswap, Bitcorn,
Sweep n' Flip, Byzantine Finance, Variational Finance, Botanix, Eco, Satsbridge and Angles
Learn more about Sujith on sujithsomraaj.xyz or on cantina.xyz

## 2 Disclaimer

Note that this security audit is not designed to replace functional tests required before any software
release, and does not give any warranties on finding all possible security issues of that given smart
contract(s) or blockchain software. i.e., the evaluation result does not guarantee against a hack (or)
the non existence of any further findings of security issues. As one audit-based assessment cannot be
considered comprehensive, I always recommend proceeding with several audits and a public bug bounty
program to ensure the security of smart contract(s). Lastly, the security audit is not an investment advice.
This review is done independently by the reviewer and is not entitled to any of the security agencies the
researcher worked / may work with.

## 3 Scope

- /periphery/UP/**
- /periphery/libraries/**
- /periphery/BundlerRegistry.sol
- /periphery/Bank.sol
- /periphery/SuperBank.sol
- /periphery/SuperGovernor.sol
- /periphery/SuperVault/**
- /periphery/VaultBank/**

## 4 Risk classification

```
Severity level Impact: High Impact: Medium Impact: Low
Likelihood: high Critical High Medium
Likelihood: medium High Medium Low
```

```
Likelihood: low Medium Low Low
```
### 4.1 Impact

```
High leads to a loss of a significant portion (>10%) of assets in the protocol, or
significant harm to a majority of users.
Medium global losses <10% or losses to only a subset of users, but still unacceptable.
Low losses will be annoying but bearable — applies to things like griefing attacks
that can be easily repaired or even gas inefficiencies.
```
### 4.2 Likelihood

```
High almost certain to happen, easy to perform, or not easy but highly incentivized
Medium only conditionally possible or incentivized, but still relatively likely
Low requires stars to align, or little-to-no incentive
```
### 4.3 Action required for severity levels

```
Critical Must fix as soon as possible (if already deployed)
High Must fix (before deployment if not already deployed)
Medium Should fix
Low Could fix
```
## 5 Executive Summary

Over the course of 7 days in total, Superform engaged with the researcher to audit the contracts de-
scribed in section 3 of this document ("scope"). Due to the limited audit timeline relative to the breadth
of the agreed-upon scope, certain code components—specifically the SuperVaultAggregator and Su-
perVaultStrategy modules—received incomplete review and may harbor unidentified vulnerabilities or
security issues.
In this period of time a total of 34 issues were found.


**Project Summary**
Project Name Superform
Repository superform-xyz/v2-contracts
Commit 233f5d071b4......35d0c3b00f
Audit Timeline May 28th - June 6th
Methods Manual Review
Documentation Medium-Low
Testing Coverage Medium-Low

```
Issues Found
Critical Risk 1
High Risk 3
Medium Risk 2
Low Risk 9
Gas Optimizations 3
Informational 16
Total Issues 34
```

## 6 Findings

### 6.1 Critical Risk

#### 6.1.1 Redemption fulfillment fails after share transfers

**Context:** SuperVaultStrategy.sol#L
**Description:** The SuperVault implements an ERC4626-compliant vault with asynchronous redemptions
via ERC7540. The system tracks user state through the SuperVaultState struct, which maintains:

- **accumulatorShares:** Total shares deposited by the user
- **accumulatorCostBasis:** Historical cost basis of user's deposits
- **pendingRedeemRequest:** Shares pending redemption
- **maxWithdraw:** Claimable assets after fulfillment
The redemption process follows these steps:
- User requests redemption viarequestRedeem()
- Strategist fulfills requests viafulfillRedeemRequests()
- Users claim assets viawithdraw()orredeem()
The issue stems from a fundamental disconnect between the ERC20 share token system and the strat-
egy's internal accounting system:
1. Share Transfers: When User A transfers shares to User B, the ERC20 balances update correctly,
but the strategy's SuperVaultState mapping remains unchanged.
2. State Mismatch: User B receives shares but has no corresponding accumulatorShares or accumu-
latorCostBasis in their state.
3. Fulfillment Failure: When User B requests redemption and the strategist attempts fulfillment, the
_calculateCostBasis()function checks:
if (requestedShares > state.accumulatorShares) revert INSUFFICIENT_SHARES();

Since User B's accumulatorShares is 0 (or less than requested), this check fails.
**Recommendation:** Consider implementing transfer hooks to tackle the above mentioned problem (or)
block all share transfers depending on the business requirements.
**Superform:
Researcher:**

### 6.2 High Risk

#### 6.2.1 SuperPosition transfer breaks cross-chain accounting in VaultBank

**Context:** VaultBankSource.sol#L87-L
**Description:** The VaultBank contract maintains user-specific locked asset accounting that becomes
desynchronized when SuperPositions are transferred between users. When a transferred SuperPosition
is burned, the system attempts to unlock assets from the wrong user's account, causing:


- Accounting Underflow: Deducting from user who doesn't have locked assets
- Accounting Overflow: Checking for user who have locked assets and transferred asset on destina-
    tion chain
- Permanent Fund Loss: Assets remain locked with no valid unlock path
**PoC:**
// Step 1: User A locks assets on Chain A
lockAsset(userA, USDC, 1000e6, chainB);// userA locks 1000 USDC
// Result: _lockedAmounts[userA][chainB][USDC] = 1000e
// Step 2: User A gets SuperPosition minted on Chain B
distributeSuperPosition(userA, 1000e6, sourceAsset, proof);
// Result: SuperPosition minted to userA
// Step 3: User A transfers SuperPosition to User B on Chain B
superPosition.transfer(userB, 1000e6);
// Result: userB owns the SuperPosition, but accounting unchanged
// _lockedAmounts[userA][chainB][USDC] still = 1000e
// Step 4: User B burns SuperPosition (instead of bridging back)
burnSuperPosition(1000e6, spAddress, chainA);
// Problem: Event emitted with msg.sender = userB
// Step 5: User B tries to unlock on Chain A
unlockAsset(userB, USDC, 1000e6, chainB, proof);
// CRITICAL ERROR: Tries to deduct from userB's locked amounts
// _lockedAmounts[userB][chainB][USDC] -= 1000e6; // UNDERFLOW!
// userA's locked assets remain forever locked

**Recommendation:** Consider fixing the accounting system to avoid user fund loss.
**Superform:
Researcher:**

#### 6.2.2 Assets sent to wrong address inwithdraw()andredeem()functions of SuperVault

**Context:** SuperVault.sol#L403, SuperVault.sol#L
**Description:** Thewithdraw()andredeem()functions violate the ERC4626 standard by sending assets
to the **owner** instead of the specified **receiver** parameter. This breaks core ERC4626 functionality and
user expectations.
Per EIP-4626:

- withdraw: "Burns shares from owner and sends assets of underlying tokens to receiver"
- redeem: "Burns exactly shares from owner and sends assets of underlying tokens to receiver"


```
function withdraw(uint256 assets, address receiver, address owner)
public override nonReentrant returns (uint256 shares) {
// ... validation and calculations ...
strategy.handleOperation(owner, assets, shares,
,→ ISuperVaultStrategy.Operation.ClaimRedeem);
emit Withdraw(msg.sender, receiver, owner, assets, shares);
// ^Event claims assets go to receiver^
}
function redeem(uint256 shares, address receiver, address owner)
public override nonReentrant returns (uint256 assets) {
// ... validation and calculations ...
strategy.handleOperation(owner, assets, shares,
,→ ISuperVaultStrategy.Operation.ClaimRedeem);
emit Withdraw(msg.sender, receiver, owner, assets, shares);
// ^Event claims assets go to receiver^
}
// In strategy
function _handleClaimRedeem(address controller, uint256 assetsToClaim) private {
// ... validation ...
// BUG: Sends assets to controller (owner), NOT to receiver!
_asset.safeTransfer(controller, actualAmountToClaim);
emit RedeemRequestFulfilled(controller, controller, actualAmountToClaim, 0);
}
```
The **controller** parameter is always set to **owner** , so assets are transferred to **owner** instead of **receiver**.
**Recommendation:** Modify strategy interface to accept an additional parameter called **receiver** to trans-
fer assets to the receiver address duringredeem()andwithdrawal()function calls.
**Superform:
Researcher:**

#### 6.2.3 Incorrect bundler address assignment inregisterBundler()function

**Context:** BundlerRegistry.sol#L
**Description:** TheregisterBundler()function contains a critical design flaw that prevents proper
bundler registration. The function usesmsg.senderas the bundler address, but since the function has
the onlyOwner modifier,msg.senderwill always be the contract owner.


```
function registerBundler(bytes calldata _extraData) external onlyOwner {
IBundlerRegistry.Bundler memory bundler = IBundlerRegistry.Bundler({
id: uint256(keccak256(abi.encodePacked(_extraData, block.timestamp, block.chainid))),
bundlerAddress: msg.sender, // Always the owner address
isActive: true,
extraData: _extraData
});
bundlers[msg.sender] = bundler; // Always overwrites owner's entry
bundlerIds[bundler.id] = msg.sender;// Multiple IDs map to same address
}
```
**Impact:**

1. Functional Breakdown: Only the contract owner can ever be registered as a bundler, defeating the
    purpose of a bundler registry
2. Data Corruption: Each registration overwrites the previous bundler data for the owner address
3. Mapping Inconsistency: Multiple bundler IDs will map to the same address (owner) in bundlerIds,
    but only the latest registration exists in bundlers
4. Business Logic Failure: The registry cannot fulfill its intended purpose of managing multiple distinct
    bundlers
**Recommendation:** Modify the function to accept a bundler address parameter:
function registerBundler(address bundlerAddress, bytes calldata _extraData) external
,→ onlyOwner {
// Input validation
require(bundlerAddress != address(0), "INVALID_BUNDLER_ADDRESS");
require(bundlers[bundlerAddress].bundlerAddress == address(0),
,→ "BUNDLER_ALREADY_REGISTERED");
IBundlerRegistry.Bundler memory bundler = IBundlerRegistry.Bundler({
id: uint256(keccak256(abi.encodePacked(bundlerAddress, _extraData, block.timestamp,
,→ block.chainid))),
bundlerAddress: bundlerAddress,
isActive: true,
extraData: _extraData
});
bundlers[bundlerAddress] = bundler;
bundlerIds[bundler.id] = bundlerAddress;
emit BundlerRegistered(bundler.id, bundlerAddress);
}

**Superform:** Fixed in PR 591
**Researcher:** Verified fix


### 6.3 Medium Risk

#### 6.3.1 Permanent ownership lock of superPosition tokens

**Context:** VaultBankDestination.sol#L
**Description:** The VaultBank contract creates VaultBankSuperPosition tokens through the_retrieveSu-
perPosition()function and automatically becomes their owner via the constructor:
// VaultBankSuperPosition.sol
constructor(string memory name, string memory symbol, uint8 decimals_)
ERC20(name, symbol)
Ownable(msg.sender) // msg.sender is VaultBank
{
_decimals = decimals_;
}

However, the VaultBank contract lacks any mechanism to transfer ownership of these SuperPosition
tokens to other addresses, creating a permanent lock-in situation.
**Recommendation:** Consider adding ownership transfer functionality to the VaultBank contract.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.3.2 SuperVault rounding inconsistency betweenmint()andconvertToAssets()

**Context:** SuperVault.sol#L163, SuperVault.sol#L
**Description:** The SuperVault contract contains a critical rounding inconsistency betweenconvertToAs-
sets()andmint()functions that violates ERC-4626 standard expectations:

- convertToAssets()uses Math.Rounding.Floor (line 320)
- mint()uses Math.Rounding.Ceil (line 139)
This inconsistency creates a preview/execution mismatch:
- User calls convertToAssets(1000 shares)returns 999 assets (floor)
- User attempts mint(1000 shares)requires 1000 assets (ceil)
- Transaction fails due to insufficient approved/available assets
This breaks the fundamental ERC-4626 expectation that preview functions should accurately reflect ex-
ecution requirements.
**Recommendation:** Change the convertToAssets()function to use Math.Rounding.Ceil to match
mint()behavior:
// Line 139 - Change from:
assets = Math.mulDiv(shares, currentPPS, PRECISION, Math.Rounding.Ceil);
// To:
assets = Math.mulDiv(shares, currentPPS, PRECISION, Math.Rounding.Floor);

**Superform:** Fixed in PR 591
**Researcher:** Verified fix


### 6.4 Low Risk

**6.4.1 Address-based accounting incompatible with cross-chain smart contracts in VaultBank**

**Context:** VaultBank.sol#L
**Description:** The VaultBank contract uses msg.sender (contract addresses) as the primary identifier for
cross-chain accounting. When smart contracts interact with VaultBank across different chains, they often
have different addresses on each chain due to:

- Different deployment order/nonce
- Different CREATE2 salt usage
- Chain-specific deployment constraints
- Different deployer addresses
This creates a scenario where:
- Contract locks assets on Chain A using addressA
- Contract exists at addressB on Chain B (different address)
- SuperPosition is minted to addressA on Chain B (non-existent contract)
- Assets become permanently locked as addressA cannot interact on Chain B
**Recommendation:** Consider implementing a mechanism to transfer shares to a different address on
the destination chain (or) add warning documentation about incompatibility with non-EOA users if their
addresses differ across chains.
**Superform:** Acknowledged
**Researcher:** Acknowledged

#### 6.4.2 Unchecked chain validation causes permanent fund loss inlockAsset()

**Context:** VaultBank.sol#L
**Description:** ThelockAsset()function accepts any **toChainId** parameter without validating whether:

- The destination chain exists
- A VaultBank is deployed on the destination chain
- The destination VaultBank can mint SuperPositions for the locked assets
**Recommendation:** Consider implementing a chain validation registry (or) a recovery mechanism to
claim funds that are bridged to the wrong chain ID.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.4.3 Hard-coded address validation breaks cross-chain compatibility in VaultBank

**Context:** VaultBank.sol#L178, VaultBank.sol#L


**Description:** The VaultBank contract contains a fundamental architectural assumption that it will be
deployed at identical addresses across all supported blockchain networks. This assumption manifests in
two critical validation functions:
// Line 151 in _validateDistributeSPProof
if (emittingContract != address(this)) revert INVALID_PROOF_EMITTER();
// Line 190 in _validateUnlockAssetProof
if (emittingContract != address(this)) revert INVALID_PROOF_EMITTER();

Both functions validate cross-chain proofs by comparing the emitting contract address against
address(this), expecting the VaultBank contract to exist at the same address on the source chain.
The issue stems from relying on CREATE2 deterministic deployment assumptions that don't hold univer-
sally across all blockchain networks, such as zkSync.
**Recommendation:** Consider implementing a Cross-chain address registry instead of assuming address
similarity across multiple chains.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.4.4 Operator can steal all owner funds via controller parameter manipulation

**Context:** SuperVault.sol#L
**Description:** TherequestRedeem()function allows authorized operators to steal all funds from the users
who granted them operator permissions.
function requestRedeem(uint256 shares, address controller, address owner) external returns
,→ (uint256) {
if (shares == 0) revert ZERO_AMOUNT();
if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();
if (owner != msg.sender && !isOperator[owner][msg.sender]) revert
,→ INVALID_OWNER_OR_OPERATOR();
if (balanceOf(owner) < shares) revert INVALID_AMOUNT();
// VULNERABILITY: No validation that controller should be owner
// Operator can pass ANY address as controller
address sender = isOperator[owner][msg.sender]? owner : msg.sender;
_approve(sender, escrow, shares);
ISuperVaultEscrow(escrow).escrowShares(sender, shares);
// CRITICAL: Associates redemption request with attacker's controller
strategy.handleOperation(controller, 0, shares,
,→ ISuperVaultStrategy.Operation.RedeemRequest);
emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
return REQUEST_ID;
}

**Recommendation:** Consider enforcing a check that the operator can always request redemption, but
the operator should be the user themselves. Or if this feature is intended to be used, consider adding
more documentation about the risks of approving an operator.


**Superform:** Acknowledged
**Researcher:** Acknowledged

#### 6.4.5 ETH value forwarding with non-payable function

**Context:** SuperBank.sol#L80, Bank.sol#L
**Description:** TheSuperBank.executeHooks()function is declared as non-payable, but the internal_ex-
ecuteHooks()function attempts to forward ETH value to target contracts through the executionStep.value
parameter in external calls:
// In Bank._executeHooks()
(bool success,) = executionStep.target.call{value:
,→ executionStep.value}(executionStep.callData);

This creates a functional inconsistency where:

- The externalexecuteHooks()function cannot receive ETH (msg.value will always be 0)
- The internal execution logic expects to forward ETH values to target contracts
- Hook executions requiring ETH transfers will fail unless the SuperBank contract already holds ETH
**Recommendation:** Consider making theexecuteHooks()functionpayableto process hooks with native
value transfer in one atomic transaction.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.4.6 FunctionregisterBundler()allows overwriting existing bundler data

**Context:** BundlerRegistry.sol#L
**Description:** TheregisterBundler()function lacks validation to check if a bundler is already registered,
allowing existing bundler data to be silently overwritten without any warning or revert.
function registerBundler(bytes calldata _extraData) external onlyOwner {
IBundlerRegistry.Bundler memory bundler = IBundlerRegistry.Bundler({
id: uint256(keccak256(abi.encodePacked(_extraData, block.timestamp, block.chainid))),
bundlerAddress: msg.sender,
isActive: true,
extraData: _extraData
});
bundlers[msg.sender] = bundler; // No check if already exists
bundlerIds[bundler.id] = msg.sender; // Overwrites without validation
emit BundlerRegistered(bundler.id, msg.sender);
}

**Recommendation:** Add validation to prevent overwriting existing registrations:


```
function registerBundler(bytes calldata _extraData) external onlyOwner {
+ require(bundlers[msg.sender].bundlerAddress == address(0), "BUNDLER_ALREADY_REGISTERED");
}
```
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.4.7 Potential bundler ID collision due to timestamp-based generation

**Context:** BundlerRegistry.sol#L
**Description:** The bundler ID generation mechanism has three deterministic parameters that can lead to
ID collisions when multiple bundlers are registered within the same block timestamp with the same extra
data.
The ID is generated using only **_extraData** , **block.timestamp** , and **block.chainid** :
id: uint256(keccak256(abi.encodePacked(_extraData, block.timestamp, block.chainid)))

Since block.timestamp and block.chainid are constant within the same block, two registrations with iden-
tical _extraData will produce the same ID, causing severe state inconsistency.
**Recommendation:** Add the bundler address to ID generation for guaranteed uniqueness:
uint256 bundlerId = uint256(keccak256(abi.encodePacked(
bundlerAddress, // Guaranteed unique per bundler
_extraData,
block.timestamp,
block.chainid
)));

**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.4.8 Sanity check_assetparameter in AssetMetadataLib

**Context:** AssetMetadataLib.sol#L
**Description:** ThetryGetAssetDecimals()function inAssetMetadataLibis used to query a token's
decimals using staticcall. However, this function does not validate if the function input parameter_asset
is a token contract, not an EOA.
Passing in an EOA returns false with 0 decimals which leads to issues based on the usage of this library
down the stack.
**Recommendation:** Consider implementing a sanity check on _asset parameter as follows:
function tryGetAssetDecimals(address asset_) internal view returns (bool ok, bytes memory,
,→ uint8 assetDecimals) {
+ if(asset_.code.length == 0) revert("not a valid asset");
....
}


**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.4.9 Functionclaim()function is not compatible with non-EOA claimers

**Context:** UpDistributor.sol#L
**Description:** TheUpDistributor.solcontract is used to distribute $UP tokens to users based on a
merkle root. However, theclaim()function assumes the external caller will be an EOA. If the tokens
were to be distributed to users who cannot call the claim function, their tokens will be locked in the
distributor.
**Recommendation:** Consider implementing a way to claim tokens for a **claimant** different than the
msg.sender
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

### 6.5 Gas Optimization

#### 6.5.1 Declaretokenvariable outside loop inexecuteRemoveIncentiveTokens().

**Context:** SuperGovernor.sol#L
**Description:**
function executeRemoveIncentiveTokens() external {
if (block.timestamp < _proposedRemoveWhitelistedIncentiveTokensEffectiveTime) revert
,→ TIMELOCK_NOT_EXPIRED();
for (uint256 i; i < _proposedRemoveWhitelistedIncentiveTokens.length(); i++) {
// Variable declared inside loop - gas inefficient
address token = _proposedRemoveWhitelistedIncentiveTokens.at(i);
if (_isWhitelistedIncentiveToken[token]) {
_isWhitelistedIncentiveToken[token] = false;
emit WhitelistedIncentiveTokensRemoved(token);
}
_proposedRemoveWhitelistedIncentiveTokens.remove(token);
}
_proposedRemoveWhitelistedIncentiveTokensEffectiveTime = 0;
}

**Recommendation:** Consider optimizing the implementation as follows:


```
function executeRemoveIncentiveTokens() external {
if (block.timestamp < _proposedRemoveWhitelistedIncentiveTokensEffectiveTime) revert
,→ TIMELOCK_NOT_EXPIRED();
// Declare variable outside loop for gas efficiency
address token;
for (uint256 i; i < _proposedRemoveWhitelistedIncentiveTokens.length(); i++) {
// Assign value to pre-declared variable
token = _proposedRemoveWhitelistedIncentiveTokens.at(i);
if (_isWhitelistedIncentiveToken[token]) {
_isWhitelistedIncentiveToken[token] = false;
emit WhitelistedIncentiveTokensRemoved(token);
}
_proposedRemoveWhitelistedIncentiveTokens.remove(token);
}
_proposedRemoveWhitelistedIncentiveTokensEffectiveTime = 0;
}
```
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.5.2 Inefficient variable declarations inside loop

**Context:** Bank.sol#L42-L
**Description:** In the_executeHooks()function, several variables are declared inside the main loop it-
eration, causing unnecessary gas consumption due to repeated memory allocation and initialization on
each iteration:
for (uint256 i; i < hooksLength; i++) {
address hookAddress = executionData.hooks[i]; // Declared inside loop
bytes memory hookData = executionData.data[i]; // Declared inside loop
bytes32[] memory merkleProof = executionData.merkleProofs[i];// Declared inside loop
ISuperHook hook = ISuperHook(hookAddress); // Declared inside loop
bytes32 merkleRoot = _getMerkleRootForHook(hookAddress);// Declared inside loop
// ...
}

Additionally, in the nested loop:
for (uint256 j; j < executions.length; ++j) {
Execution memory executionStep = executions[j]; // Declared inside loop
bytes32 targetLeaf =
keccak256(bytes.concat(keccak256(abi.encodePacked(executionStep.target))));//
Declared inside loop

```
,→
,→
}
```
**Estimated savings:** ~200-500 gas per iteration **Total potential savings:** Varies with hook count and
execution steps


**Recommendation:** Declare all reusable variables outside the loops:
function _executeHooks(IHookExecutionData.HookExecutionData calldata executionData) internal
,→ virtual {
uint256 hooksLength = executionData.hooks.length;
if (hooksLength == 0) revert ZERO_LENGTH_ARRAY();
if (hooksLength != executionData.data.length || hooksLength !=
,→ executionData.merkleProofs.length) {
revert INVALID_ARRAY_LENGTH();
}
// Declare variables outside loops
address prevHook;
address hookAddress;
bytes memory hookData;
bytes32[] memory merkleProof;
ISuperHook hook;
bytes32 merkleRoot;
Execution[] memory executions;
Execution memory executionStep;
bytes32 targetLeaf;
bool success;
for (uint256 i; i < hooksLength; i++) {
hookAddress = executionData.hooks[i];
hookData = executionData.data[i];
merkleProof = executionData.merkleProofs[i];
hook = ISuperHook(hookAddress);
merkleRoot = _getMerkleRootForHook(hookAddress);
// ... rest of the logic
for (uint256 j; j < executions.length; ++j) {
executionStep = executions[j];
targetLeaf =
,→ keccak256(bytes.concat(keccak256(abi.encodePacked(executionStep.target))));
// ... rest of the logic
}
prevHook = hookAddress;
}
emit HooksExecuted(executionData.hooks, executionData.data);
}

**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.5.3 Inconsistent error handling in UpDistributor

**Context:** UpDistributor.sol#L70, UpDistributor.sol#L
**Description:** Mix of custom errors and require statements for similar validations.
**Recommendation:** Use custom errors consistently:


```
error TransferFailed();
// Replace require with: if (!token.transfer(...)) revert TransferFailed();
```
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

### 6.6 Informational

#### 6.6.1 Use Ownable2Step instead of Ownable in VaultBankSuperPosition

**Context:** VaultBankSuperPosition.sol#L
**Description:** The contract VaultBankSuperPosition uses Ownable instead of Ownable2Step, making it
inconsistent across the entire codebase, where Ownable2Step is used across all the other contracts.
**Recommendation:** Consider using Ownable2Step instead of Ownable for ownership management in
VaultBankSuperPosition.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.6.2 Missing event ininvalidateNonce().

**Context:** SuperVault.sol#L
**Description:** TheinvalidateNonce()function allows users to invalidate authorization nonces preemp-
tively, but fails to emit any event when a nonce is successfully invalidated:
/// @inheritdoc IERC
function invalidateNonce(bytes32 nonce) external {
if (nonce == bytes32(0) || _authorizations[msg.sender][nonce]) revert INVALID_NONCE();
_authorizations[msg.sender][nonce] = true;
// NO EVENT EMITTED
}

**Recommendation:** Consider emitting an event in the above-mentioned function for better off-chain
tracking / monitoring.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.6.3 Unnecessary Code Complexity inrequestRedeem()of SuperVault

**Context:** SuperVault.sol#L182-L
**Description:** TherequestRedeem()function contains redundant logic that unnecessarily complicates
the share transfer process:
// Current implementation
address sender = isOperator[owner][msg.sender]? owner : msg.sender;
_approve(sender, escrow, shares);
ISuperVaultEscrow(escrow).escrowShares(sender, shares);


- Case 1: owner == msg.sendersender = owner
- Case 2: owner != msg.sender AND isOperator[owner][msg.sender] == truesender = owner
- Case 3: Unauthorized accessfunction reverts before reaching this code
In all successful execution paths, the sender variable always equals the owner, making the conditional
assignment pointless.
**Recommendation:** Remove the sender variable and directly use owner for all share transfers:
function requestRedeem(uint256 shares, address controller, address owner) external returns
,→ (uint256) {
// ... existing validation checks ...
// Simplified: Always transfer from owner (who owns the shares)
_approve(owner, escrow, shares);
ISuperVaultEscrow(escrow).escrowShares(owner, shares);
// ... rest of function unchanged ...
}

**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.6.4 Missing oracle address validation insetEmergencyPrice()function

**Context:** SuperGovernor.sol#L
**Description:** ThesetEmergencyPrice()function appears to be inconsistent with other functions by not
validating the oracle address retrieved from storage.
function setEmergencyPrice(address token_, uint256 price_) external onlyRole(_GOVERNOR_ROLE) {
// No oracle address validation
address oracle = _addressRegistry[SUPER_ORACLE];
ISuperOracle(oracle).setEmergencyPrice(token_, price_);
}

**Recommendation:** Consider implementing sanity checks to ensure theoracleaddress is notad-
dress(0)in the code mentioned above.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.6.5 Shared timelock storage between add and remove incentive token functions

**Context:** SuperGovernor.sol#L732, SuperGovernor.sol#L
**Description:** The system uses a single timestamp variable **_proposedWhitelistedIncentiveTokensEf-
fectiveTime** to control the timelock for both adding and removing incentive tokens. This creates a critical
state collision where one proposal type can interfere with another.
**Recommendation:** Implement separate timestamps for each proposal type to restore proper timelock
isolation and governance integrity.
**Superform:** Fixed in PR 591


**Researcher:** Verified fix

#### 6.6.6 Potential DoS ingetAllSuperformStrategists()function

**Context:** SuperGovernor.sol#L971
**Description:** ThegetAllSuperformStrategists()function appears to return all strategists in a single
call without pagination, creating a potential gas limit vulnerability as the system scales.
**Recommendation:** Consider implementing a pagination to retrieve strategists. Also consider adding a
warning about the function's behavior and risks for external integrators.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

#### 6.6.7 Logic error inexecuteRemoveIncentiveTokens()function

**Context:** SuperGovernor.sol#L787
**Description:** In theexecuteRemoveIncentiveTokens()function, the removal of tokens from the pro-
posed list is incorrectly placed within a conditional block, leading to incomplete state cleanup and poten-
tial system inconsistencies.
function executeRemoveIncentiveTokens() external {
if (block.timestamp < _proposedRemoveWhitelistedIncentiveTokensEffectiveTime) revert
,→ TIMELOCK_NOT_EXPIRED();
for (uint256 i; i < _proposedRemoveWhitelistedIncentiveTokens.length(); i++) {
address token = _proposedRemoveWhitelistedIncentiveTokens.at(i);
// Current problematic logic
if (_isWhitelistedIncentiveToken[token]) {
_isWhitelistedIncentiveToken[token] = false;
emit WhitelistedIncentiveTokensRemoved(token);
// ISSUE: Remove call is inside conditional block
_proposedRemoveWhitelistedIncentiveTokens.remove(token);
}
}
_proposedRemoveWhitelistedIncentiveTokensEffectiveTime = 0;
}

**Recommendation:** Consider moving theremoveoutside conditional:


```
function executeRemoveIncentiveTokens() external {
if (block.timestamp < _proposedRemoveWhitelistedIncentiveTokensEffectiveTime) revert
,→ TIMELOCK_NOT_EXPIRED();
for (uint256 i; i < _proposedRemoveWhitelistedIncentiveTokens.length(); i++) {
address token = _proposedRemoveWhitelistedIncentiveTokens.at(i);
// Process whitelisted tokens
if (_isWhitelistedIncentiveToken[token]) {
_isWhitelistedIncentiveToken[token] = false;
emit WhitelistedIncentiveTokensRemoved(token);
}
// FIXED: Always remove from proposed list
_proposedRemoveWhitelistedIncentiveTokens.remove(token);
}
_proposedRemoveWhitelistedIncentiveTokensEffectiveTime = 0;
}
```
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

**6.6.8 Missing zero-value vheck in timelock validation of** executeAddIncentiveTokens() **function**

**Context:** SuperGovernor.sol#L741
**Description:** The current timelock validation logic has a critical flaw: it doesn't account for the scenario
where_proposedWhitelistedIncentiveTokensEffectiveTimeis set to 0.
if (block.timestamp < _proposedWhitelistedIncentiveTokensEffectiveTime) revert
,→ TIMELOCK_NOT_EXPIRED();

- When _proposedWhitelistedIncentiveTokensEffectiveTime = 0, the condition block.timestamp < 0
    will always be false
- This allows the function to execute immediately, completely bypassing the intended timelock pro-
    tection
- The timelock mechanism becomes ineffective in this state
**Recommendation:** Replace the current check with a more robust validation:
// Before (Vulnerable)
if (block.timestamp < _proposedWhitelistedIncentiveTokensEffectiveTime) revert
,→ TIMELOCK_NOT_EXPIRED();
// After (Secure)
if (_proposedWhitelistedIncentiveTokensEffectiveTime != 0 && block.timestamp <
,→ _proposedWhitelistedIncentiveTokensEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

**Superform:** Fixed in PR 591
**Researcher:** Verified fix


#### 6.6.9 Redundant contains check inexecuteAddIncentiveTokens()function

**Context:** SuperGovernor.sol#L745
**Description:** The functionexecuteAddIncentiveTokens()contains a redundant contains() check that
validates whether a token exists in the _proposedWhitelistedIncentiveTokens set, despite the token being
retrieved directly from that same set using the at() method.
**Recommendation:** Consider removing the redundant contains check
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

## 6.6.10 Sanity check oracle address inbatchSetEmergencyPrices()function

**Context:** SuperGovernor.sol#L359
**Description:** ThebatchSetEmergencyPrices()function fetches the **oracle** address from the **_address-
Registry** but fails to sanity check it, which is inconsistent with the overall behavior.
**Recommendation:** Consider validating the oracle address as follow:
function batchSetEmergencyPrices(
address[] calldata tokens_,
uint256[] calldata prices_
) external onlyRole(_GOVERNOR_ROLE) {
address oracle = _addressRegistry[SUPER_ORACLE];
+ if(oracle == address(0)) revert CONTRACT_NOT_FOUND();
}

**Superform:** Fixed in PR 591
**Researcher:** Verified fix

## 6.6.11 Declare constant_SUPER_ASSET_FACTORYasprivate

**Context:** SuperGovernor.sol#L103
**Description:** The constant_SUPER_ASSET_FACTORYshould be declaredprivateinstead ofpublicas
the variable is readable through an external functionSUPER_ASSET_FACTORY
**Recommendation:** Consider declaring the constant asprivate
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

## 6.6.12 Possible DoS in_executeHooks()function of Bank

**Context:** Bank.sol#L36
**Description:** Large numbers of hook executions or complex hook logic could cause the _execute-
Hooks()function in Bank.sol to run out of block gas limit.
**Recommendation:** Consider implementing maximum execution limits as follows:


```
function _executeHooks(IHookExecutionData.HookExecutionData calldata executionData) internal
,→ virtual {
uint256 hooksLength = executionData.hooks.length;
if (hooksLength == 0) revert ZERO_LENGTH_ARRAY();
+ if (hooksLength > MAX_HOOK_LEN) revert INVALID_HOOK_LENGTH();
}
```
**Superform:** Acknowledged
**Researcher:** Acknowledged

## 6.6.13 Remove redundantonlyStrategymodifier

**Context:** SuperVaultEscrow.sol#L36
**Description:** TheSuperVaultEscrow.solcontract has implemented anonlyStrategymodifier to re-
strict access for specific functions to the strategy contract; however, this modifier is unused.
**Recommendation:** Consider removing the unused modifier and associated state variable to improve
code quality.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix

## 6.6.14 Functionsclaim()andreclaimTokens()in UpDistributor violates CEI pattern

**Context:** UpDistributor.sol#L57, UpDistributor.sol#L71
**Description:** The functionsclaim()andreclaimTokens()update the state (event emission) after the
external call to transfer, violating the CEI (Checks-Effects-Interactions) pattern.
**Recommendation:** Follow CEI pattern:
hasClaimed[msg.sender] = true;
emit TokensClaimed(msg.sender, amount);
require(token.transfer(msg.sender, amount), "Transfer failed");

**Superform:** Fixed in PR 591
**Researcher:** Verified fix

## 6.6.15 Insufficient validation in constructor of UpDistributor

**Context:** UpDistributor.sol#L31
**Description:** The constructor doesn't validate that the token address is not zero.
**Recommendation:** Add zero address validation:
if (_token == address(0)) revert InvalidTokenAddress();

**Superform:** Fixed in PR 591
**Researcher:** Verified fix


## 6.6.16 Incorrect documentation about reclaiming tokens in UPDistributor

**Context:** UpDistributor.sol#L12
**Description:** The owner has a way to reclaim tokens using thereclaimTokens()function. However,
the contract documentation mentions that reclaim is possible by updating the Merkle root, which seems
redundant.
**Recommendation:** Consider fixing the above mentioned documentation issue.
**Superform:** Fixed in PR 591
**Researcher:** Verified fix


