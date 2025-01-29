// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../../mocks/Mock4626Vault.sol";
import { ERC4626YieldSourceOracleLibrary } from
    "../../../../src/core/libraries/accounting/ERC4626YieldSourceOracleLibrary.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DepositRedeem4626LibraryTest is Helpers {
    Mock4626Vault vault;
    MockERC20 underlying;

    function setUp() public virtual {
        underlying = new MockERC20("Underlying", "UND", 18);

        vault = new Mock4626Vault(IERC20(address(underlying)), "Vault", "VAULT");
    }

    function test_getPricePerShare() public view {
        uint256 expectedPricePerShare = 1e18;
        uint256 actualPricePerShare = ERC4626YieldSourceOracleLibrary.getPricePerShare(address(vault));
        assertEq(actualPricePerShare, expectedPricePerShare);
    }
}
