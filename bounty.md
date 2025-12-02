## 1. Extended Overview Description

```
This document provides technical details, reasoning behind design choices, and discussion of potential edge cases and risks in Superform's v2 contracts. This repository of core contracts include primary business logic, interfaces, execution routines, accounting mechanisms, and validation components.
```

---

## 2. Deployment Networks & Documentation Link

```
View product documentation here: https://docs.superform.xyz/, which includes current v2-core deployments across Ethereum, Base, Optimism, Arbitrum, BNB, Polygon, and Unichain.
```

---

## 3. Vendor Scope Note

In repository structure:
```
src/
└── vendor/             # Vendor contracts (NOT IN SCOPE)
```

---

## 4. Detailed SuperValidator Documentation

```
SuperValidator:
- Role: A validator contract for ERC4337 entrypoint actions. It enables users to sign once for multiple user operations using merkle proofs, enhancing the chain abstraction experience.
- Usage: Designed for standard ERC-4337 `EntryPoint` interactions. Validates `UserOperation` hashes (`userOpHash`) provided within a Merkle proof, typically constructed by the SuperBundler. Implements `validateUserOp` and EIP-1271 `isValidSignatureWithSender`.
```

---

## 5. Detailed SuperDestinationValidator Documentation

```
SuperDestinationValidator:
- Role: Validates cross-chain operation signatures for destination chain operations. It verifies merkle proofs and signatures to ensure only authorized operations are executed.
- Usage: Specifically designed for validating operations executed *directly* on a destination chain via `SuperDestinationExecutor`, bypassing the ERC-4337 `EntryPoint`. Implements a custom `isValidDestinationSignature` method; `validateUserOp` and `isValidSignatureWithSender` are explicitly **not** implemented and will revert.
- Merkle Leaf Contents: `keccak256(keccak256(abi.encode(callData, chainId, sender, executor, dstTokens[], intentAmounts[], validUntil, validatorAddress)))`. The leaf commits to the full context of the destination execution parameters.
- Replay Protection:
    - Includes `block.chainid` in the leaf and verifies it during signature validation to prevent cross-chain replay.
    - Incorporates a `validUntil` timestamp in the leaf, checked against `block.timestamp`.
    - Includes the `executor` address in the leaf to prevent replay across different executor modules installed on the same account.
    - Includes the `validator` address in the leaf to prevent replay across different validator modules installed on the same account.
    - Uses a unique namespace (`SuperValidator`) in the final signed message hash.
- Notes:
    - The destination account must use the same signer as the source account. If the validator is uninstalled and then reinstalled with a different configuration, the flow will no longer function correctly.
    - Execution occurs only if the account holds a balance greater than the corresponding intentAmounts[] for each token in dstTokens[].
```

---

## 6. PPS Unit Semantics & Pendle Gotchas

```
**⚠️ PPS Unit Semantics & Pendle Gotchas**

Not all `getPricePerShare()` values are returned in underlying asset units:

- **ERC-4626/ERC-7540/Spectra PT**: Returns base-asset denominated amounts (in underlying token decimals)
- **Pendle PT**: Returns ratio from `IPMarket.getPtToAssetRate()` scaled to 1e18 (assets per 1 PT)
- **ERC-5115**: Returns `exchangeRate()` scaled to 1e18 (assets per share)

`SuperYieldSourceOracle` normalizes ratio-style PPS (1e18) to base token units only for quote functions via auto-detection. Accounting remains consistent by design. FlatFeeLedger is used for ERC-5115 and Pendle PT.
```

---

## 7. Bundler ERC-4337 Recommendation Note

```
⚠️ Note: According to ERC-4337 recommendations, bundler operates using a private RPC endpoint. All UserOperations are simulated before submission to ensure validity and avoid wasting gas on failing transactions.
```

---

## 8. Detailed Bundler Operation Section

```
Bundler Operation

- Allows fee charging in ERC20 tokens with a fee payment hook (a transfer hook), which transfers fees to the
  SuperBundler so that it can orchestrate the entire operation.
- Allows for a single signature experience flow, where the SuperBundler builds a merkle tree of all userOps that are
  going to be executed in all chains for a given user intent. This signature is validated in SuperMerkle Validator.
- Allows for delayed execution of userOps (async userOps) with a single user signature. UserOps are processed when and
  where required rather than immediately upon receipt. Reasonable deadlines apply here. Typical desired flow of usage is
  for example with asynchronous vaults like those following ERC7540 standard.
- Centralization Concerns:
  - Since SuperBundler controls both the userOp and validation flow, it introduces a degree of centralization. We
    acknowledge that this could be flagged by auditors.
  - In later stages this system is planned to be decentralized.
- Mitigation: Transparency around this design choice and the availability of fallback mechanisms when operations are not
  executed through SuperBundler.
```

---

## 9. SuperNativePaymaster Key Assumptions

```
**Key Assumptions and Responsibilities:**

- **Bundler Responsibility**: The bundler is responsible for making correct gas estimation and calling `SuperNativePaymaster.handleOps` with the correct amount of native tokens required for the operation. Any extra
tokens are returned to whoever calls the function. Bundler does not supply the entrypoint directly, thus fund
loss is not possible.
```

---

## 10. Original Repository Structure Format

```
core/                   # Core protocol contracts
├── accounting/         # Accounting logic
├── adapters/           # Bridge implementations
├── executors/          # Execution logic contracts
├── hooks/              # Protocol hooks
├── interfaces/         # Contract interfaces
├── libraries/          # Shared libraries
├── paymaster/          # Native paymaster
└── validators/         # Validation contract
src/
└── vendor/             # Vendor contracts (NOT IN SCOPE)
```

---

## 11. Original Mermaid Diagram Styling

```
classDef userFacing fill:#f9f,stroke:#333,stroke-width:2px;
classDef core fill:#bbf,stroke:#333,stroke-width:1px;
classDef infra fill:#bfb,stroke:#333,stroke-width:1px;

class User,Frontend userFacing;
class SmartAccount,Executors,Validators,Accounting,Hooks,Registry core;
class Bridges,DestExecutors,DestValidators,Ledgers infra;
```
