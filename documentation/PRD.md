# Product Requirements Document: Code Quality & Documentation Improvement for SuperUSD Core

## 1. Project Overview

**Objective:** Enhance code quality, documentation, and in-line comments across the `src/core` folder according to the Solidity style guide standards ahead of an upcoming audit.

https://docs.soliditylang.org/en/latest/style-guide.html](https://docs.soliditylang.org/en/latest/style-guide.html)

## 2. Key Components to Address

### 2.1 NatSpec Documentation Enhancement
- **Current State:** Basic NatSpec comments exist but are incomplete or missing parameter details
- **Requirements:** 
  - Ensure 100% NatSpec coverage for all public/external functions
  - Add detailed `@param`, `@return`, and `@dev` documentation
  - Improve function purpose descriptions in `@notice` tags

### 2.2 Code Organization and Style
- **Current State:** Inconsistent formatting and organization in some contracts
- **Requirements:**
  - Standardize function grouping (external → public → internal → private)
  - Add clear section headers with consistent formatting
  - Ensure proper spacing and line breaks according to style guide

### 2.3 Error Handling Improvements
- **Current State:** Basic error messages, sometimes lacking context
- **Requirements:**
  - Convert all `revert` statements to custom errors with descriptive names
  - Add parameters to custom errors for better debugging
  - Document error conditions thoroughly

### 2.4 Inline Comments for Complex Logic
- **Current State:** Limited explanations for complex calculations and business logic
- **Requirements:**
  - Add detailed comments for mathematical operations
  - Document the purpose of important state transitions
  - Explain security considerations and trust assumptions

### 2.5 Variable Naming and Constants
- **Current State:** Some abbreviated variable names and magic numbers
- **Requirements:**
  - Rename variables for clarity following style guide conventions
  - Extract all magic numbers to named constants
  - Use descriptive mapping names

## 3. Implementation Plan

### Phase 1: Analysis and Documentation Template (20%)
- Review all core contracts against style guide requirements
- Create documentation templates for consistent implementation
- Identify high-priority files based on complexity and audit focus

### Phase 2: Core Contract Documentation (40%)
- Implement complete NatSpec documentation for:
  - Accounting system (BaseLedger, SuperLedgerConfiguration)
  - Executor contracts
  - Base hook implementations
  - Key interfaces

### Phase 3: Code Style and Error Handling (20%)
- Standardize code organization and structure
- Implement custom errors with improved context
- Extract magic numbers to constants

### Phase 4: Advanced Inline Documentation (20%)
- Document complex business logic and calculations
- Add security consideration notes
- Create relationship diagrams in comments

## 4. Priority Files

1. **High Priority:**
   - BaseLedger.sol - Core accounting logic
   - SuperExecutorBase.sol - Critical execution flow
   - BaseHook.sol - Foundation for all hooks
   - Key interfaces (ISuperRegistry, ISuperLedger, ISuperHook)

2. **Medium Priority:**
   - Specialized hooks in vaults, bridges, etc.
   - SuperLedgerConfiguration.sol
   - Library implementations

3. **Lower Priority:**
   - Simple adapter contracts
   - Utility functions

## 5. Documentation Standards

### Function Documentation Template:
```solidity
/// @notice [WHAT the function does in simple terms]
/// @dev [WHY the function exists and HOW it works, including any special considerations]
/// @param paramName [Description of the parameter's purpose and constraints]
/// @return [Description of what is returned and why]
```

### Error Documentation Template:
```solidity
/// @notice Error thrown when [condition occurs]
/// @param paramName The [description of what this parameter represents]
error ERROR_NAME(type paramName);
```

### Code Section Headers:
```solidity
/*//////////////////////////////////////////////////////////////
                          [SECTION NAME]
//////////////////////////////////////////////////////////////*/
```

## 6. Success Metrics

- 100% NatSpec coverage for public/external functions
- All custom errors properly documented with parameters
- No magic numbers in the codebase
- Logical and consistent organization across all files
- Improved readability score in static analysis tools

## 7. Sample Implementation

Here's an example of how the improvements should be applied to the `_calculateFees` function in BaseLedger.sol:

```solidity
/// @notice Calculates performance fees based on profit from yield-bearing assets
/// @dev Uses the difference between current asset value and cost basis to determine profit
///      Fees are only charged on positive profit with a percentage defined in configuration
/// @param costBasis The original value of the assets when acquired
/// @param amountAssets The current value of the assets
/// @param feePercent The percentage of profit to take as fees (in basis points, e.g., 300 = 3%)
/// @return feeAmount The calculated fee amount, zero if no profit or feePercent is zero
function _calculateFees(
    uint256 costBasis,
    uint256 amountAssets,
    uint256 feePercent
)
    internal
    pure
    virtual
    returns (uint256 feeAmount)
{
    // Calculate profit as the positive difference between current value and cost basis
    uint256 profit = amountAssets > costBasis ? amountAssets - costBasis : 0;
    
    // Only charge fees on positive profit
    if (profit > 0) {
        // Ensure fee percentage is configured
        if (feePercent == 0) revert FEE_NOT_SET();
        
        // Calculate fee amount: profit * feePercent / 10_000 (basis points denominator)
        feeAmount = Math.mulDiv(profit, feePercent, 10_000);
    }
    // Return 0 if no profit
}
```
