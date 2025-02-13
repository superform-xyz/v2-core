# Superform v2-contracts

This repository contains the smart contracts for Superform v2

## Overview

Superform is a protocol that enables cross-chain DeFi operations with a focus on security, efficiency, and
composability. The protocol is built using Foundry and implements various components including core contracts, periphery
contracts, and cross-chain messaging systems.

## Repository Structure

```
src/
├── core/               # Core protocol contracts
│   ├── interfaces/     # Contract interfaces
│   ├── executors/      # Execution logic contracts
│   ├── validators/     # Validation contracts
│   ├── libraries/      # Shared libraries
│   ├── settings/       # Protocol settings
│   ├── hooks/         # Protocol hooks
│   ├── bridges/       # Bridge implementations
│   ├── utils/         # Utility contracts
│   ├── accounting/    # Accounting logic
│   ├── sentinels/     # Security monitoring
│   └── paymaster/     # Gas abstraction
└── periphery/         # Peripheral contracts
```

## Dependencies

The project uses the following main dependencies:

- OpenZeppelin Contracts: For standard contract implementations
- Solady: For gas-optimized contract building blocks
- Modulekit: For modular contract development
- Forge Standard Library: For testing utilities
- ExcessivelySafeCall: For secure cross-contract calls
- Pigeon: For additional utilities

## Development Setup

### Prerequisites

- Foundry
- Node.js
- Git

### Installation

1. Clone the repository with submodules:

```bash
git clone --recursive https://github.com/superform-xyz/v2-contracts
cd v2-contracts
```

2. Install dependencies:

```bash
forge install
```

3. Copy the environment file:

```bash
cp .env.example .env
```

### Building

```bash
forge build
```

If `forge build` fails:

```bash
cd lib/modulekit
pnpm install
```

> **Note:** This requires `pnpm` and will not work with `npm`. To install `pnpm`:

```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

### Testing

```bash
forge test
```

## Configuration

The project uses Foundry as the development framework with the following configuration highlights:

- Solidity version: 0.8.28
- Optimizer enabled with 10,000 runs
- Comprehensive test coverage
- Custom remappings for dependencies

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## Security

If you discover a security vulnerability, please do NOT open an issue. Email security@[your-domain].com instead.

## License

[Add License Information]

## Documentation

For detailed documentation about the protocol and its components, please visit [Add Documentation Link].
