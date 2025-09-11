# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claude Master Agent

### Rules
- Before you do any work, MUST view files in .claude/tasks/context_session_x.md file to get the full context (x being the id of the session we are operate, if file doesnt exist, then create one)
- context_session_x.md should contain most of context of what we did, overall plan, and sub agents will continusly add context to the file
- After you finish the work, MUST update the . claude/tasks/context_session_x.md file to make sure others can get full context of what you did

### While implementing
- You should update the session as you work.
- After you complete tasks in the plan, you should update and append detailed descriptions of the changes you made, so following tasks can be easily hand over to other sub-agents and engineers.

## Sub Agents

### Access and purpose
You have access to 2 sub-agents:
- hooks-master.md
- solidity-master.md

Sub agents will do research about the implementation, but you will do the actual implementation;
When passing task to sub agent, make sure you pass the context file, e.g. 'claude/tasks/session_context_x.md',
After each sub agent finishes the work, make sure you read the related documentation they created to get full context of the plan before you start executing

### Rules
- Always in plan mode to make a plan
- After get the plan, make sure you Write the plan to '.claude/tasks/session_context_x.md'
- The plan should be a detailed implementation plan and the reasoning behind them, as well as tasks broken down.
- If the task require external knowledge or certain package, also research to get latest knowledge (Use Task tool for research)
- Don't over plan it, always think MVP.
- Once they write the plan, firstly ask me, the Master Claude, to review it. Do not continue until I approve the plan.

## Commands

### Building & Testing
- `forge build` - Build all contracts
- `make ftest` - Run all tests (requires RPC configuration in Makefile)
- `make ftest-ci` - Run tests with verbose output for CI (10 parallel jobs)
- `make coverage` - Generate coverage report using lcov format
- `make coverage-genhtml` - Generate HTML coverage report (excludes vendor and test files)

### Development Workflow
- `make forge-test TEST=<test_name>` - Run specific test via Makefile
- `make forge-script SCRIPT=<script_name>` - Run forge script via Makefile

### Specialized Testing
- `make test-integration` - Run cross-chain execution tests
- `make test-gas-report-user` - Generate gas usage report for single user
- `make test-gas-report-2vaults` - Gas report for two vault operations
- `make test-gas-report-3vaults` - Gas report for three vault operations

### Contract Compilation & Bindings
- `make generate` - Regenerate contract bindings (requires ABI extraction)
- Uses `./script/run/retrieve-abis.sh` and `./script/run/generate-contract-bindings.sh`

### Dependencies
Install dependencies in submodules:
```bash
cd lib/modulekit && pnpm install
cd lib/safe7579 && pnpm install  
cd lib/nexus && yarn
```

## Architecture

### Core System Components

**Execution Layer:**
- `SuperExecutor` (src/executors/) - Main execution engine for same-chain operations
- `SuperDestinationExecutor` (src/executors/) - Cross-chain execution handler for destination chains
- Uses transient storage for inter-hook communication during execution

**Validation Layer:**
- `SuperValidator` (src/validators/) - ERC-4337 userOp validation using Merkle proofs
- `SuperDestinationValidator` (src/validators/) - Cross-chain operation signature validation
- Both implement single-signature-for-multiple-operations via Merkle trees

**Accounting System:**
- `SuperLedger` (src/accounting/) - Core accounting with performance fee calculations
- `FlatFeeLedger` (src/accounting/) - Simplified fee structure for certain vault types
- `SuperLedgerConfiguration` (src/accounting/) - Fee configuration management

**Hook System:**
- Modular execution units in `src/hooks/` organized by function:
  - `vaults/` - ERC-4626, ERC-5115, ERC-7540 vault integrations
  - `swappers/` - DEX integrations (1inch, Odos, Pendle, Spectra)
  - `bridge/` - Cross-chain bridge operations
  - `tokens/` - ERC-20 operations and batch transfers
  - `claim/` - Reward claiming mechanisms
  - `loan/` - Lending protocol interactions (Morpho)

### ERC-7579 Module Integration
Smart accounts must install four essential modules:
- SuperExecutor/SuperDestinationExecutor (execution)
- SuperValidator/SuperDestinationValidator (validation)

### Cross-Chain Architecture
1. Source chain operations via SuperExecutor
2. Bridge adapters (src/adapters/) relay messages
3. Destination chain execution via SuperDestinationExecutor
4. Unified accounting across chains via SuperLedger

### Development Environment Setup

**Prerequisites:**
- Foundry (forge, cast)
- Node.js with pnpm and yarn
- RPC endpoints for testing (configured in Makefile or .env)

**Key Configuration Files:**
- `foundry.toml` - Solidity compiler settings, remappings, profiles
- `Makefile` - Build scripts and RPC configuration
- `.env.example` - Environment variable template

### Testing Structure
- `test/BaseTest.t.sol` - Base test class with common setup
- `test/unit/` - Unit tests for individual components
- `test/integration/` - Cross-chain execution tests
- `test/mocks/` - Mock contracts for testing
- Uses Foundry's testing framework with fuzzing support

### Code Style Guidelines (from .cursor/rules/)
- Solidity 0.8.30 with explicit visibility modifiers
- NatSpec comments for all public/external functions
- Custom errors instead of revert strings
- Comprehensive events for state changes
- Checks-Effects-Interactions pattern for security
- Use of OpenZeppelin libraries and patterns

### Oracle System
- `SuperYieldSourceOracle` - Unified oracle for price per share data
- Handles different vault standards (ERC-4626, ERC-5115, ERC-7540, Pendle PT)
- Normalizes pricing units for consistent accounting

### Security Considerations

**Core Security Features:**
- Reentrancy protection via OpenZeppelin ReentrancyGuard
- Signature replay protection with chainId, timestamps, and unique namespaces
- Transient storage prevents state manipulation between hooks
- Single signature validates multiple operations via Merkle proofs

**Known Security Trade-offs (from SECURITY.md):**
- Cross-bridge replay attacks possible in low-likelihood scenarios (user must have destination chain balance)
- Front-running susceptibility when marking roots as processed
- Static system assumptions between intent signing and execution
- Hook safety depends on external contract trustworthiness
- Limited ERC-7579 compatibility (optimized for Nexus and Safe accounts)
- Cost basis caching behavior when withdrawing directly from vaults
- Protocol fees may be bypassed in edge cases
- One leaf per destination limitation in Merkle roots (avoid race conditions)
- Infinite deadline transactions allowed (use with caution)
- Multiple valid execution paths exist for signed intents

**Smart Account Requirements:**
- Tested primarily with Nexus and Safe smart accounts
- Other ERC-7579 accounts may have compatibility issues
- Proper vault integration essential (accurate `convertToAssets()` etc.)

### Protocol Overview
Superform v2 is a modular DeFi protocol for yield abstraction enabling:
- Dynamic execution via ERC-7579 modules
- Cross-chain operations with unified accounting
- Flexible composition of user operations
- Single signature for multiple operations via Merkle trees

**Key Infrastructure Components:**
- **SuperBundler**: Off-chain bundler for timed UserOperation batches
- **SuperNativePaymaster**: ERC20 token payment for gas fees
- **SuperRegistry**: Centralized address management and configuration
- **Bridge Adapters**: Cross-chain message handling (Across, deBridge)

### Deployment
- Production deployment scripts in `script/run/`
- Locked bytecode system prevents contract modification post-audit
- Multi-network deployment support (Ethereum, Base, BSC, Arbitrum)
- Contract verification via Tenderly integration
- One-time deployment limitation per network with same bytecode

## Agent Synchronization

**Critical Requirement**: This repository maintains synchronized AI agent configurations across three tools: Claude Code, Cursor, and Windsurf. All agent definitions must remain synchronized to ensure consistent development experiences across tools.

**Agent Files:**
- `.claude/agents/` - Claude Code agent definitions
- `.cursor/rules/` - Cursor AI agent rules  
- `.windsurf/rules/` - Windsurf agent rules

**Synchronization Protocol:**
When creating or modifying specialized agents (like the `superform-hook-master` agent), developers MUST:
1. Update the agent definition in all three directories
2. Maintain identical core functionality across all versions
3. Adapt only the metadata format required by each tool (frontmatter structure)
4. Test agent behavior in each tool to ensure consistency

**Current Synchronized Agents:**
- `superform-hook-master` - Master agent for Superform v2-core hook development
  - `.claude/agents/hooks-master.md`
  - `.cursor/rules/superform-hook-master.mdc` 
  - `.windsurf/rules/superform-hook-master.md`

This synchronization enables developers to seamlessly switch between Claude Code, Cursor, and Windsurf while maintaining access to the same specialized knowledge and capabilities for Superform v2-core development.

