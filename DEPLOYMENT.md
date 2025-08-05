# V2 Core Production Deployment Guide

This guide provides step-by-step instructions for deploying the V2 Core smart contracts to production environments. The deployment is designed to be permissionless, meaning anyone with proper RPC access and credentials can deploy the contracts.

## 🎯 Key Features

- **Intelligent Deployment Detection**: Automatically analyzes deployment status and skips confirmation when all contracts are deployed
- **Contract Count Validation**: Sources expected contract count from `update_locked_bytecode.sh` for accuracy
- **Centralized Network Management**: All network configurations are managed in `script/utils/networks.sh`
- **One-Time Deployment**: Contracts can only be deployed once per network with same bytecode
- **Multi-Network Support**: Deploy to Ethereum, Base, BSC, and Arbitrum simultaneously
- **Locked Bytecode**: All contracts use pre-compiled, audited bytecode artifacts
- **Smart Flow Control**: Auto-terminates with success when all contracts are already deployed

## 🔧 Prerequisites

### Required Tools
- **Foundry**: Latest version with `forge` CLI tool
- **Bash 4.0+**: For associative array support (required for deployment analysis)
- **Secure credential manager**: For managing sensitive credentials
- **jq**: For JSON processing

### Bash Version Requirements

**⚠️ Critical**: The deployment script requires **Bash 4.0 or later** for associative array support.

#### Check Your Bash Version
```bash
bash --version
```

#### macOS Users: Install Modern Bash
macOS ships with Bash 3.2 which doesn't support associative arrays. Install a modern version:

```bash
# Install via Homebrew
brew install bash

# Verify installation
/opt/homebrew/bin/bash --version  # Should show 5.x
```

#### Linux Users
Most modern Linux distributions include Bash 4.0+. If needed:

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install bash

# CentOS/RHEL
sudo yum update bash
```

#### Execution Method
**Important**: Always run the script directly to use the proper bash shebang:

```bash
# ✅ Correct - Uses modern bash via shebang
./script/run/deploy_v2_staging_prod.sh prod simulate v2

# ❌ Wrong - Forces system bash 3.2 and will fail
sh script/run/deploy_v2_staging_prod.sh prod simulate v2
```

### Required Credentials

You'll need the following credentials securely stored:

#### RPC URLs
- `ETHEREUM_RPC_URL`: Ethereum mainnet RPC endpoint
- `BASE_RPC_URL`: Base mainnet RPC endpoint  
- `BSC_RPC_URL`: BSC mainnet RPC endpoint
- `ARBITRUM_RPC_URL`: Arbitrum mainnet RPC endpoint

#### Contract Verification
- `TENDERLY_ACCESS_KEY_V2`: Tenderly API access token for contract verification

### Forge Account Setup

Ensure you have a forge account named `v2` configured:

```bash
# Create a new forge account (if not exists)
forge account create v2

# Or import an existing private key
forge account import v2 --from-private-key YOUR_PRIVATE_KEY
```

## 🚀 Deployment Process

### ⚠️ Important: One-Time Deployment Limitation

**Critical Notice**: Each smart contract can only be deployed **once per network** using the same locked bytecode and constructor arguments. This is by design for security and determinism. If you attempt to redeploy contracts that already exist, the deployment will skip those contracts.

### Step 1: Environment Setup

Ensure your credential management system provides access to the required RPC URLs and Tenderly credentials. The deployment script expects these environment variables to be available.

### Step 2: Choose Deployment Mode

The deployment script supports production deployment with two modes:

**Modes:**
- `simulate`: Dry run without broadcasting transactions (recommended first)
- `deploy`: Full deployment with transaction broadcasting and verification

### Step 3: Run Deployment Script

**⚠️ Account Parameter Required**: The script now requires specifying a foundry account name as the third parameter.

#### Check Available Accounts
First, verify your available foundry accounts:
```bash
cast wallet list
```

#### Execute Deployment
```bash
# For production simulation (recommended first step)
./script/run/deploy_v2_staging_prod.sh prod simulate v2

# For production deployment with account 'v2'
./script/run/deploy_v2_staging_prod.sh prod deploy v2

# For staging deployment with a different account
./script/run/deploy_v2_staging_prod.sh staging deploy deployer
```

**Usage**: `./script/run/deploy_v2_staging_prod.sh <environment> <mode> <account>`
- **environment**: `staging` or `prod`
- **mode**: `simulate` or `deploy` 
- **account**: foundry account name (e.g., `v2`, `deployer`, `main`)

### Step 4: Review Deployment

The script intelligently analyzes deployment status and adapts accordingly:

#### Automatic Flow Detection

1. **🔍 Validate Prerequisites**: Check locked bytecode artifacts (expected total: 49 contracts)
2. **📋 Address Verification**: Display contract addresses and deployment status per network
3. **🧠 Smart Analysis**: Analyze deployment status across all networks:

   **Scenario A: All Contracts Deployed (49/49)**
   ```bash
   🎉 EXCELLENT! All contracts are already deployed on all networks!
      Expected: 49 contracts (from update_locked_bytecode.sh)
      Status: Fully deployed across all chains
      No deployment needed - terminating with success
   ```
   ✅ **Auto-terminates** with success message (no confirmation needed)

   **Scenario B: Some Contracts Missing**
   ```bash
   📋 DEPLOYMENT REQUIRED
      Expected total per network: 49 contracts (from update_locked_bytecode.sh)
      The following networks have missing contracts:
      • Ethereum (47/49 contracts, 2 missing)
      • Base (49/49 contracts, fully deployed)
      
      Only missing contracts will be deployed (existing ones will be skipped)
   ```
   🤝 **Requests confirmation** only for missing contracts

4. **🚀 Deploy to Networks**: Deploy only missing contracts to:
   - Ethereum Mainnet (Chain ID: 1)
   - Base Mainnet (Chain ID: 8453)
   - BSC Mainnet (Chain ID: 56)
   - Arbitrum Mainnet (Chain ID: 42161)
5. **✅ Verify Contracts**: Automatically verify new contracts on Tenderly

#### Contract Count Validation

The script now sources expected contract counts from `update_locked_bytecode.sh`:
- **Core contracts**: 11
- **Hook contracts**: 31  
- **Oracle contracts**: 7
- **Total expected**: 49 contracts per network

## 📁 Output Structure

Deployed contract addresses are saved to:

```
script/output/prod/{chain_id}/{network_name}-latest.json
```

**Examples:**
- `script/output/prod/1/Ethereum-latest.json`
- `script/output/prod/8453/Base-latest.json`

## 🔒 Security Features

### Deployment Safety
- **One-time deployment**: Contracts can only be deployed once per network with same bytecode
- **Locked bytecode**: All contracts use pre-compiled, audited bytecode artifacts
- **Deterministic addresses**: Predictable contract addresses for security verification

### Transaction Safety
- Simulation mode allows dry-run testing before actual deployment
- User confirmation required before broadcasting transactions

## 🌐 Supported Networks

| Network | Chain ID | RPC Variable | 
|---------|----------|--------------|
| Ethereum | 1 | `ETHEREUM_RPC_URL` |
| Base | 8453 | `BASE_RPC_URL` |
| BSC | 56 | `BSC_RPC_URL` |
| Arbitrum | 42161 | `ARBITRUM_RPC_URL` |

## 📊 Contract Types Deployed

The deployment includes the following contract categories:

### Core Infrastructure
- **SuperExecutor**: Main execution engine
- **SuperDestinationExecutor**: Cross-chain execution handler
- **SuperSenderCreator**: Transaction sender management
- **SuperValidator**: Transaction validation
- **SuperDestinationValidator**: Cross-chain validation

### Bridge Adapters
- **AcrossV3Adapter**: Across Protocol integration
- **DebridgeAdapter**: deBridge Protocol integration

### Accounting System
- **SuperLedger**: Core accounting ledger
- **FlatFeeLedger**: Fee management system
- **SuperLedgerConfiguration**: Configuration management

### Hook Contracts (50+ contracts)
- **Vault Hooks**: ERC-4626, ERC-5115, ERC-7540 vault integrations
- **Token Hooks**: ERC-20 operations and batch transfers
- **Bridge Hooks**: Cross-chain bridge integrations
- **Swap Hooks**: DEX integrations (1inch, Odos)
- **Claim Hooks**: Reward claiming mechanisms

### Oracle System
- **Yield Source Oracles**: Various yield source price feeds
- **SuperYieldSourceOracle**: Unified oracle aggregator

## 🛠️ Troubleshooting

### Common Issues

**1. Bash Compatibility Issues**
```
declare: -A: invalid option
syntax error near unexpected token `<'
```
- **Cause**: Using Bash 3.2 (default on macOS) which doesn't support associative arrays
- **Solution**: Install Bash 4.0+ and run script directly:
  ```bash
  # Install modern bash (macOS)
  brew install bash
  
  # Run correctly
  ./script/run/deploy_v2_staging_prod.sh prod simulate v2
  
  # NOT: sh script/run/deploy_v2_staging_prod.sh prod simulate v2
  ```

**2. Missing RPC URLs**
```
Error: Failed to load RPC URL for network
```
- Verify credential management system provides required environment variables
- Check RPC URL accessibility and validity

**3. Insufficient Gas**
```
Error: Transaction failed with insufficient gas
```
- Ensure deployment account has sufficient native tokens on all networks
- Check current gas prices and network congestion

**4. Contract Already Deployed**
```
Info: Contract already deployed at address 0x...
```
- This is normal - the script will skip already deployed contracts
- Review the address verification output to ensure correctness
- If all contracts are deployed (49/49), the script will automatically terminate with success

**5. Contract Count Mismatch**
```
Expected total artifacts: X (from update_locked_bytecode.sh)
```
- The script sources contract counts from `update_locked_bytecode.sh`
- If counts seem wrong, verify the locked bytecode files are up to date
- Run `./script/run/update_locked_bytecode.sh` to refresh artifacts

**6. Verification Failed**
```
Error: Failed to verify contract on Tenderly
```
- Check Tenderly access token validity
- Verify network configuration in Tenderly project

### Getting Help

For deployment issues:
1. Check the script output for specific error messages
2. Verify all prerequisites are met
3. Run in simulation mode first to identify issues
4. Review network status and gas prices

## 🔄 Adding New Networks

All network configurations are centralized in `script/utils/networks.sh`. To add support for new networks:

### Step 1: Update Centralized Network Configuration

Edit `script/utils/networks.sh` and add your network to the `NETWORKS` array:

```bash
# Add to the NETWORKS array in script/utils/networks.sh
NETWORKS=(
    "1:Ethereum:ETH_MAINNET:ETH_VERIFIER_URL"
    "8453:Base:BASE_MAINNET:BASE_VERIFIER_URL"
    "56:BNB:BSC_MAINNET:BSC_VERIFIER_URL"
    "42161:Arbitrum:ARBITRUM_MAINNET:ARBITRUM_VERIFIER_URL"
    "137:Polygon:POLYGON_MAINNET:POLYGON_VERIFIER_URL"  # Example new network
)
```

### Step 2: Update Network Helper Functions

Add your network to all helper functions in `script/utils/networks.sh`:

```bash
# Add to get_network_name() function
137)
    echo "Polygon"
    ;;

# Add to get_rpc_var() function  
137)
    echo "POLYGON_MAINNET"
    ;;

# Add to get_rpc_url() function
137)
    echo "$POLYGON_MAINNET"
    ;;

# Add to get_verifier_var() function
137)
    echo "POLYGON_VERIFIER_URL"
    ;;
```

### Step 3: Configure Credentials and URLs

1. **Add RPC URL**: Configure in your credential management system
2. **Add Verification URL**: Set up Tenderly verification endpoint
3. **Update Scripts**: Add RPC and verifier URL exports to deployment scripts

### Step 4: Test the New Network

```bash
# Test with simulation first
./script/run/deploy_v2_staging_prod.sh prod simulate v2

# Verify the new network appears in the deployment list
# Check that all contracts deploy successfully
# Confirm verification works
```

### Benefits of Centralized Configuration

- **Single Source of Truth**: All scripts use the same network definitions
- **Easy Maintenance**: Add a network once, available everywhere
- **Consistency**: No risk of mismatched network configurations
- **Validation**: Built-in network validation and helper functions

### Network Configuration Format

```bash
"CHAIN_ID:NetworkName:RPC_VAR:VERIFIER_VAR"
```

Where:
- `CHAIN_ID`: Numeric chain identifier (e.g., 137)
- `NetworkName`: Human-readable name (e.g., Polygon)  
- `RPC_VAR`: Environment variable name for RPC URL
- `VERIFIER_VAR`: Environment variable name for verifier URL

## 📝 Notes

- **Gas Optimization**: All contracts use optimized bytecode via locked artifacts
- **Deterministic Addresses**: Some contracts use CREATE2 for predictable addresses  
- **Upgrade Safety**: Deployment script checks for existing contracts to prevent overwrites
- **Multi-Network**: All networks deploy sequentially for reliability
- **One-Time Deployment**: Each contract can only be deployed once per network with same parameters
- **Intelligent Analysis**: Script automatically detects deployment status and adapts flow accordingly
- **Contract Count Accuracy**: Expected counts sourced from `update_locked_bytecode.sh` for consistency
- **Bash 4.0+ Required**: Modern bash needed for associative array support in deployment analysis

## 🚀 Recent Improvements (Latest)

### Smart Deployment Detection
- **Auto-termination**: When all 49 contracts are deployed, script exits automatically with success
- **Conditional confirmation**: Only asks for confirmation when contracts need deployment
- **Accurate counting**: Contract expectations sourced from `update_locked_bytecode.sh`

### Enhanced User Experience
- **Clear status indicators**: Per-network deployment status with missing contract counts
- **Informative analysis**: Detailed breakdown of core/hook/oracle contract counts
- **Improved error handling**: Better bash compatibility and clearer error messages

### Technical Improvements
- **Bash compatibility**: Updated shebang to use modern bash for associative arrays
- **Consistent parsing**: Unified contract extraction logic across all functions
- **Source of truth**: `update_locked_bytecode.sh` as definitive contract list

---

**⚠️ Important**: Always run simulation mode before production deployments to verify expected behavior and gas costs. Remember that contracts can only be deployed once per network with the same bytecode and constructor arguments.

**💡 Pro Tip**: If all contracts are already deployed, the script will automatically detect this and terminate with a celebration message - no manual intervention needed!