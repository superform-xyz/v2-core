// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Id, MarketParams } from "../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../src/vendor/morpho/MarketParamsLib.sol";

using MarketParamsLib for MarketParams;

/// @notice The registry market key every Morpho hook carries at header offset 32.
/// @dev Byte-identical to `MorphoBlueMarketRegistry.computeMarketKey` and to the on-chain
///      `_marketKey` on both Morpho bases: the Morpho market id truncated to an address.
///      File-level function so any suite can import it by name without inheriting a helper contract.
function morphoMarketKey(
    address loanToken,
    address collateralToken,
    address oracle,
    address irm,
    uint256 lltv
)
    pure
    returns (address)
{
    return address(
        uint160(
            uint256(
                Id.unwrap(
                    MarketParams({
                            loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv
                        }).id()
                )
            )
        )
    );
}
