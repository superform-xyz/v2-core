# Superform v2 Web3 Actions

This directory contains Tenderly Web3 Actions for monitoring and automating Superform v2 protocol operations across all supported networks.

## Overview

Web3 Actions are serverless functions that run in response to blockchain events or on a schedule. They enable real-time monitoring, alerting, and automated responses to protocol events.

## Structure

```
script/web3Actions/
├── src/
│   ├── treasury/     # Treasury configuration monitoring
│   ├── monitoring/   # System health checks
│   ├── alerts/       # Failed transaction alerts
│   └── index.ts      # Main exports
├── package.json      # Dependencies and scripts
├── tsconfig.json     # TypeScript configuration
├── tenderly.yaml     # Action definitions and triggers
└── README.md         # This file
```

## Actions

### 1. Treasury Monitor (`treasury-monitor`)
- **Trigger**: Transaction to SuperLedgerConfiguration contract
- **Function**: `setYieldSourceOracleConfig`
- **Purpose**: Monitor treasury configuration changes across all networks
- **Networks**: All production networks (12 chains)

### 2. Ledger Health Check (`ledger-health-check`)
- **Trigger**: Periodic (every 6 hours)
- **Purpose**: Monitor SuperLedger health and performance metrics
- **Networks**: All production networks

### 3. Failed Transaction Alert (`failed-transaction-alert`)
- **Trigger**: Failed transactions to critical contracts
- **Purpose**: Immediate alerts for transaction failures
- **Contracts**: SuperLedgerConfiguration, SuperLedger, SuperExecutor, SuperDestinationExecutor

## Setup

### Prerequisites

1. Install Tenderly CLI:
```bash
npm install -g @tenderly/cli
```

2. Login to Tenderly:
```bash
tenderly login
```

3. Install dependencies:
```bash
cd script/web3Actions
npm install
```

### Configuration

1. Update `tenderly.yaml` with your account details:
```yaml
account_id: 'your-account-id'
project_slug: 'v2'
```

2. Configure secrets in Tenderly dashboard for:
   - `DISCORD_WEBHOOK_URL` (optional)
   - `SLACK_WEBHOOK_URL` (optional)
   - Other notification endpoints

### Development

```bash
# Build TypeScript
npm run build

# Watch mode for development
npm run dev

# Deploy actions (dry run)
npm run deploy:dry-run

# Deploy to production
npm run deploy
```

### Deployment

Deploy actions to Tenderly:

```bash
# From the web3Actions directory
tenderly actions deploy

# Or using npm script
npm run deploy
```

## Supported Networks

The actions monitor the following production networks:

| Network | Chain ID | Status |
|---------|----------|--------|
| Ethereum | 1 | ✅ Active |
| Base | 8453 | ✅ Active |
| BNB Chain | 56 | ✅ Active |
| Arbitrum | 42161 | ✅ Active |
| Optimism | 10 | ✅ Active |
| Polygon | 137 | ✅ Active |
| Unichain | 130 | ⏳ Pending |
| Avalanche | 43114 | ✅ Active |
| Berachain | 80094 | ⏳ Pending |
| Sonic | 146 | ⏳ Pending |
| Gnosis | 100 | ⏳ Pending |
| Worldchain | 480 | ⏳ Pending |

## Monitored Contracts

| Contract | Address | Purpose |
|----------|---------|---------|
| SuperLedgerConfiguration | `0x2e2D71289CBA19f831856f85DEC7f194B0165e69` | Oracle configuration |
| SuperLedger | `0x04916bB42564CdED96E10F55C059d65E4FCb1Be6` | Core accounting |
| SuperExecutor | `0x9cC8EDCC41154aaFC74D261aD3D87140D21F6281` | Same-chain execution |
| SuperDestinationExecutor | `0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF` | Cross-chain execution |

## Adding New Actions

1. Create a new directory under `src/` for your action category
2. Add your TypeScript action function following the pattern:
```typescript
import { ActionFn, Context, Event } from '@tenderly/actions';

export const myAction: ActionFn = async (context: Context, event: Event) => {
  // Your action logic here
};
```
3. Update `tenderly.yaml` with the new action spec
4. Export your action in `src/index.ts`
5. Deploy with `npm run deploy`

## Troubleshooting

### Common Issues

1. **Action fails to deploy**: Check TypeScript compilation with `npm run build`
2. **No events triggered**: Verify contract addresses and function signatures in `tenderly.yaml`
3. **Missing secrets**: Configure required secrets in Tenderly dashboard

### Logs and Debugging

- View action logs in Tenderly dashboard
- Use `console.log()` for debugging (visible in Tenderly logs)
- Test with dry-run deployments first

## Resources

- [Tenderly Web3 Actions Documentation](https://docs.tenderly.co/web3-actions)
- [Tenderly CLI Reference](https://docs.tenderly.co/tenderly-cli)
- [Superform v2 Protocol Documentation](../README.md)