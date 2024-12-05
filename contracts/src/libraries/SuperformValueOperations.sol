// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

type IntValue is int256;

type UintValue is uint256;

library SuperformValueOperations {
    error UNDERFLOW();
    error DIVISION_BY_ZERO();

    function add(IntValue a, IntValue b) internal pure returns (IntValue) {
        return IntValue.wrap(IntValue.unwrap(a) + IntValue.unwrap(b));
    }

    function sub(IntValue a, IntValue b) internal pure returns (IntValue) {
        return IntValue.wrap(IntValue.unwrap(a) - IntValue.unwrap(b));
    }

    function mul(IntValue a, IntValue b) internal pure returns (IntValue) {
        return IntValue.wrap(IntValue.unwrap(a) * IntValue.unwrap(b));
    }

    function div(IntValue a, IntValue b) internal pure returns (IntValue) {
        if (IntValue.unwrap(b) == 0) revert DIVISION_BY_ZERO();
        return IntValue.wrap(IntValue.unwrap(a) / IntValue.unwrap(b));
    }

    function add(UintValue a, UintValue b) internal pure returns (UintValue) {
        return UintValue.wrap(UintValue.unwrap(a) + UintValue.unwrap(b));
    }

    function sub(UintValue a, UintValue b) internal pure returns (UintValue) {
        if (UintValue.unwrap(a) < UintValue.unwrap(b)) revert UNDERFLOW();
        return UintValue.wrap(UintValue.unwrap(a) - UintValue.unwrap(b));
    }

    function mul(UintValue a, UintValue b) internal pure returns (UintValue) {
        return UintValue.wrap(UintValue.unwrap(a) * UintValue.unwrap(b));
    }

    function div(UintValue a, UintValue b) internal pure returns (UintValue) {
        if (UintValue.unwrap(b) == 0) revert DIVISION_BY_ZERO();
        return UintValue.wrap(UintValue.unwrap(a) / UintValue.unwrap(b));
    }
}
