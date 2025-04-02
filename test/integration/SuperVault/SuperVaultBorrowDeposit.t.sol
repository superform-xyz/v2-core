// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IMorphoBase } from "../../../src/vendor/morpho/IMorpho.sol";
import { ModuleKitHelpers, AccountInstance, AccountType, UserOpData } from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

contract SuperVaultBorrowDepositTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using Math for uint256;

    address public morpho;
    address public oracle;
    address public loanToken;
    address public collateralToken;

    uint256 public amount;
    uint256 public constant PRECISION = 1e18;

    function setUp() public override {
        super.setUp();

        amount = 1000e6;

        vm.selectFork(FORKS[ETH]);
        
        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];
        vm.label(accountEth, "AccountETH");

        collateralToken = existingUnderlyingTokens[ETH][USDC_KEY];
        vm.label(collateralToken, "CollateralToken");
        
        loanToken = existingUnderlyingTokens[ETH][WST_ETH_KEY];
        vm.label(loanToken, "LoanToken");

        morpho = MORPHO;
        vm.label(morpho, "Morpho");


    }
    
}