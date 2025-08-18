// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";

contract ERC4626YieldSourceOracleTest is Helpers {
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;
    ERC4626YieldSourceOracle public oracle;
    MockERC20 public underlying;
    Mock4626Vault public vault;

    function setUp() public {
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(0x777);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        oracle = new ERC4626YieldSourceOracle(address(ledgerConfig));
        underlying = new MockERC20("Underlying", "UND", 18);
        vault = new Mock4626Vault(address(underlying), "Vault", "VAULT");
    }

    function test_getPricePerShare() public view {
        uint256 pricePerShare = oracle.getPricePerShare(address(vault));
        assertEq(pricePerShare, 1e18);
    }

    function test_getPricePerShareMultiple() public view {
        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(vault);
        address[] memory assets = new address[](1);
        assets[0] = address(0);
        uint256[] memory prices = oracle.getPricePerShareMultiple(finalTargets);
        assertEq(prices[0], 1e18);
    }
}
