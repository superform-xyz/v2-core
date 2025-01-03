// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock5115Vault } from "../../mocks/Mock5115Vault.sol";
import { ERC5115YieldSourceOracleLibrary } from "../../../src/libraries/accounting/ERC5115YieldSourceOracleLibrary.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DepositRedeem5115LibraryTest is BaseTest {
    Mock5115Vault vault;
    MockERC20 underlying;

    function setUp() public override {
        super.setUp();
        underlying = new MockERC20("Underlying", "UND", 18);
        vault = new Mock5115Vault(IERC20(address(underlying)), "Vault", "VAULT");
    }

    function test_get5115PricePerShare() public view {
        uint256 expectedPricePerShare = 1e18;
        uint256 actualPricePerShare = ERC5115YieldSourceOracleLibrary.getPricePerShare(address(vault));
        assertEq(actualPricePerShare, expectedPricePerShare);
    }

    function test_get5115PricePerShareMultiple() public view {
        uint256[] memory expectedPricePerShares = new uint256[](1);
        expectedPricePerShares[0] = 1e18;

        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(vault);

        address[] memory tokenIns = new address[](1);
        tokenIns[0] = address(underlying);

        uint256[] memory actualPricePerShares =
            ERC5115YieldSourceOracleLibrary.getPricePerShareMultiple(finalTargets, tokenIns);
        assertEq(actualPricePerShares[0], expectedPricePerShares[0]);
    }
}
