// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock7540Vault } from "../../../mocks/Mock7540Vault.sol";
import { ERC7540YieldSourceOracleLibrary } from
    "../../../../src/core/libraries/accounting/ERC7540YieldSourceOracleLibrary.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DepositRedeem7540LibraryTest is Helpers {
    Mock7540Vault vault;
    MockERC20 underlying;

    function setUp() public virtual {
        underlying = new MockERC20("Underlying", "UND", 18);
        vault = new Mock7540Vault(IERC20(address(underlying)), "Vault", "VAULT");
    }

    function test_get7540PricePerShare() public view {
        uint256 expectedPricePerShare = 1e18;
        uint256 actualPricePerShare =
            ERC7540YieldSourceOracleLibrary.getPricePerShare(address(vault));
        assertEq(actualPricePerShare, expectedPricePerShare);
    }

    function test_get7540PricePerShareMultiple() public view {
        uint256[] memory expectedPricePerShares = new uint256[](1);
        expectedPricePerShares[0] = 1e18;

        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(vault);

        address underlyingAsset = address(underlying);

        uint256[] memory actualPricePerShares =
            ERC7540YieldSourceOracleLibrary.getPricePerShareMultiple(finalTargets, underlyingAsset);
        assertEq(actualPricePerShares[0], expectedPricePerShares[0]);
    }
}
