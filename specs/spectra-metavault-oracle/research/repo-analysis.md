# Repository Research Analysis: SpectraMetaVaultOracle

## Oracle Architecture Patterns

### Inheritance Hierarchy
All yield source oracles extend `AbstractYieldSourceOracle`:
- `src/accounting/oracles/AbstractYieldSourceOracle.sol` - base class
  - Single immutable: `SUPER_LEDGER_CONFIGURATION`
  - 7 abstract methods: `decimals`, `getShareOutput`, `getWithdrawalShareOutput`, `getAssetOutput`, `getPricePerShare`, `getBalanceOfOwner`, `getTVLByOwnerOfShares`, `getTVL`
  - Implements `getAssetOutputWithFees` with fee calculation via SuperLedger

### Existing Oracle Implementations (14+)
- `ERC4626YieldSourceOracle.sol` - Standard ERC-4626
- `ERC5115YieldSourceOracle.sol` - ERC-5115 (SY tokens)
- `ERC7540YieldSourceOracle.sol` - Async vaults (our base reference)
- `PendlePTYieldSourceOracle.sol` - Pendle PT tokens
- `YoYieldSourceOracle.sol` - Yo protocol
- `SpectraPTYieldSourceOracle.sol` - Spectra PT tokens
- `MorphoYieldSourceOracle.sol` - Morpho vaults
- `RadiantATokenYieldSourceOracle.sol` - Radiant aTokens
- `AaveV3ATokenYieldSourceOracle.sol` - Aave V3 aTokens
- And more...

### ERC7540YieldSourceOracle (Reference Implementation)
- **Constructor**: `(address superLedgerConfiguration_, uint256 requestId_)`
- **REQUEST_ID**: immutable, typically 0 for accumulated-pattern vaults
- **5-component TVL**: held shares + pending redeem + claimable redeem + pending deposit + claimable deposit
- **Share token discovery**: `_getShareToken()` - tries `share()`, falls back to vault address
- **R1/R2 pattern**: Hard revert for PPS, try/catch for async components
- **Component 3 (BUG)**: Uses `maxWithdraw(owner)` - broken for MetaVaultWrapper

### Deployment Patterns

#### Constants.sol Keys
```solidity
string internal constant ERC7540_YIELD_SOURCE_ORACLE_KEY = "ERC7540YieldSourceOracle";
// Pattern: {ContractName}_KEY = "{ContractName}"
```

#### regenerate_bytecode.sh
```bash
ORACLE_CONTRACTS=("ERC4626YieldSourceOracle" "ERC5115YieldSourceOracle" "ERC7540YieldSourceOracle" ...)
```

#### DeployV2Core.s.sol
- `_deployOracles()` function deploys all oracle instances
- Each oracle gets a Constants key, salt, and constructor args
- Pattern: `__deployContractIfNeeded(key, chainId, salt, bytecodeWithArgs)`

### Testing Patterns

#### Unit Tests
- `test/unit/oracles/` directory
- Inline mock contracts (e.g., `MockERC7540VaultFull`)
- Test all 5 TVL components individually
- Test edge cases: zero balances, reverts, wrong pricing

#### Fork Tests
- `test/integration/` directory
- Use `vm.createSelectFork()` with RPC URLs from env
- Verify against live on-chain state

### Standalone Deploy Scripts
- `script/run/DeployYoYieldSourceOracle.s.sol` - precedent for single oracle deployment
- Can be used for initial deployment before full system integration
