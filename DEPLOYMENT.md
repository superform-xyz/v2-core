# V2 Core Production Deployment Guide

This guide provides step-by-step instructions for deploying the V2 Core smart contracts to production environments. The deployment is designed to be permissionless, meaning anyone with proper RPC access and credentials can deploy the contracts.

## 🎯 Key Features

- **Centralized Network Management**: All network configurations are managed in `script/utils/networks.sh`
- **One-Time Deployment**: Contracts can only be deployed once per network with same bytecode
- **Multi-Network Support**: Deploy to Ethereum, Base, BSC, and Arbitrum simultaneously
- **Locked Bytecode**: All contracts use pre-compiled, audited bytecode artifacts

## 🔧 Prerequisites

### Required Tools
- **Foundry**: Latest version with `forge` CLI tool
- **Secure credential manager**: For managing sensitive credentials
- **jq**: For JSON processing

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

```bash
# For production simulation (recommended first step)
./script/run/deploy_v2_staging_prod.sh prod simulate

# For production deployment  
./script/run/deploy_v2_staging_prod.sh prod deploy
```

### Step 4: Review Deployment

The script will:

1. **🔍 Validate Prerequisites**: Check locked bytecode artifacts
2. **📋 Show Contract Addresses**: Display which contracts will be deployed vs already exist
3. **🤝 Request Confirmation**: Ask for user confirmation before proceeding
4. **🚀 Deploy to Networks**: Deploy to all supported networks:
   - Ethereum Mainnet (Chain ID: 1)
   - Base Mainnet (Chain ID: 8453)
   - BSC Mainnet (Chain ID: 56)
   - Arbitrum Mainnet (Chain ID: 42161)
5. **✅ Verify Contracts**: Automatically verify contracts on Tenderly

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

**1. Missing RPC URLs**
```
Error: Failed to load RPC URL for network
```
- Verify credential management system provides required environment variables
- Check RPC URL accessibility and validity

**2. Insufficient Gas**
```
Error: Transaction failed with insufficient gas
```
- Ensure deployment account has sufficient native tokens on all networks
- Check current gas prices and network congestion

**3. Contract Already Deployed**
```
Info: Contract already deployed at address 0x...
```
- This is normal - the script will skip already deployed contracts
- Review the address verification output to ensure correctness

**4. Verification Failed**
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
./script/run/deploy_v2_staging_prod.sh prod simulate

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

---

**⚠️ Important**: Always run simulation mode before production deployments to verify expected behavior and gas costs. Remember that contracts can only be deployed once per network with the same bytecode and constructor arguments.