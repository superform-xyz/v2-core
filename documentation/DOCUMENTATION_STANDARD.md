# Documentation Standard for SuperUSD Core

This document outlines the documentation standards to be applied across the SuperUSD core codebase to ensure consistency, clarity, and adherence to the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html).

## Documentation Priority

Documentation improvements should follow this priority order:

1. **Interfaces First**: Focus on comprehensively documenting interfaces before implementation files.
   - Interfaces define the contract between components
   - Well-documented interfaces provide guidance for all implementations
   - Interface documentation has the widest impact on codebase quality

2. **Base Contracts Second**: After interfaces, focus on base/abstract contracts.
   - These contracts define shared functionality used by multiple implementations
   - Documentation here affects all derived contracts

3. **Implementation Files Last**: Finally, focus on concrete implementation files.
   - Implementation-specific documentation should focus on details not covered in interfaces
   - Avoid duplicating interface documentation; use `@inheritdoc` where appropriate
   - Focus on implementation-specific edge cases, optimizations, and security considerations

## NatSpec Documentation Format

All contracts and public/external functions MUST be documented using NatSpec format. Use the following templates:

### Contract Documentation

```solidity
/// @title [Contract Name]
/// @author Superform Labs
/// @notice [A plain-language explanation of what the contract does]
/// @dev [Additional details about implementation, assumptions, and security considerations]
```

### Function Documentation

```solidity
/// @notice [A plain-language explanation of what the function does]
/// @dev [Additional details about implementation, assumptions, and security considerations]
/// @param paramName [Description of the parameter's purpose and constraints]
/// @return [Description of what is returned and why]
```

### Error Documentation

```solidity
/// @notice [Description of when the error is thrown]
/// @param paramName [Description of the parameter included in the error]
error ERROR_NAME(type paramName);
```

## Code Layout Standards

### File Organization

Files should be organized in the following order:
1. SPDX License Identifier
2. Pragma directive
3. Import statements (grouped by external/internal)
4. Interface/Contract declaration with NatSpec
5. Code sections in proper order

### Code Sections Order

Each contract should organize code in the following sections:

```solidity
/*//////////////////////////////////////////////////////////////
                           CONSTANTS
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                          STATE VARIABLES
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                              EVENTS
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                              ERRORS
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
//////////////////////////////////////////////////////////////*/
```

Within each visibility section (EXTERNAL or INTERNAL), functions should be ordered with:
1. Public functions first (in EXTERNAL section)
2. Private functions last (in INTERNAL section)
3. View and pure functions last within each group

### Function Order

Functions should be ordered as follows:
1. Constructor
2. Receive function (if exists)
3. Fallback function (if exists)
4. External functions (including public functions)
5. Internal functions (including private functions)

Within each major group, use this ordering:
1. Public before private (within their respective sections)
2. State-modifying functions before view/pure functions
3. View functions before pure functions

## Naming Conventions

- **Contract Names**: PascalCase (e.g., `SuperLedger`)
- **Function Names**: camelCase (e.g., `calculateFees`)
- **Variables**: camelCase (e.g., `userBalance`)
- **Constants**: ALL_CAPS with underscores (e.g., `MAX_FEE_PERCENT`)
- **Events**: PascalCase (e.g., `AccountingInflow`)
- **Errors**: ALL_CAPS with underscores (e.g., `INVALID_PRICE`)
- **Modifiers**: camelCase (e.g., `onlyExecutor`)

## Comments

### Inline Comments

Add inline comments for complex logic using the following format:

```solidity
// Calculate profit based on current asset value minus original cost basis
uint256 profit = amountAssets > costBasis ? amountAssets - costBasis : 0;
```

### Block Comments

For longer explanations, use block comments:

```solidity
/* 
   This implementation uses a specialized algorithm for fee calculation
   that ensures proportional distribution across multiple yield sources.
   The calculation is based on the following formula...
*/
```

## Constants and Magic Numbers

All magic numbers should be replaced with named constants:

```solidity
// Bad
feeAmount = Math.mulDiv(profit, feePercent, 10_000);

// Good
uint256 private constant BASIS_POINTS_DENOMINATOR = 10_000;
feeAmount = Math.mulDiv(profit, feePercent, BASIS_POINTS_DENOMINATOR);
```

## Audit Preparation Notes

Functions or sections with special audit considerations should include an audit note:

```solidity
/// @dev AUDIT: This function handles critical state transitions and should be checked for reentrancy
```

This standard will be applied to all files in the `src/core` directory as part of the comprehensive code quality improvement and documentation effort.
