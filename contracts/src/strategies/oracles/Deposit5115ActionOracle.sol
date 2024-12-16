// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IActionOracle } from "../../interfaces/strategies/IActionOracle.sol";
import { Deposit5115Library } from "../../libraries/strategies/Deposit5115Library.sol";

/// @title Deposit5115ActionOracle
/// @author Superform Labs
/// @notice Oracle for the Deposit Action in 5115 Vaults
contract Deposit5115ActionOracle is IActionOracle {
  constructor() {}
}
