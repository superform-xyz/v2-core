// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// vault interfaces
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { RestrictionManagerLike } from "../../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IRestrictionManager } from "../../mocks/centrifuge/IRestrictionManager.sol";
import { IInvestmentManager } from "../../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../../mocks/centrifuge/ITranch.sol";
import { IRoot } from "../../mocks/centrifuge/IRoot.sol";
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVault } from "../../../src/periphery/interfaces/ISuperVault.sol";
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";

contract SuperVault7540UnderlyingTest is BaseSuperVaultTest {
    using Math for uint256;
    ISuperLedger public superLedgerETH;

    address public centrifugeAddress;
    IERC7540 public centrifugeVault;

    address public underlyingETH_USDC;

    uint256 amount;
    uint64 public poolId;
    uint128 public assetId;
    bytes16 public trancheId;

    address public rootManager;

    IRoot public root;
    IPoolManager public poolManager;
    IInvestmentManager public investmentManager;
    RestrictionManagerLike public restrictionManager;

    string public constant YIELD_SOURCE_7540_ETH_USDC_KEY = "Centrifuge_7540_ETH_USDC";
    string public constant YIELD_SOURCE_ORACLE_7540_KEY = "YieldSourceOracle_7540";

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        // Deploy factory
        factory = new SuperVaultFactory(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        asset = IERC20Metadata(underlyingETH_USDC);

        // Set up the 7540 yield source
        centrifugeAddress =
            realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];
        vm.label(centrifugeAddress, YIELD_SOURCE_7540_ETH_USDC_KEY);

        centrifugeVault = IERC7540(centrifugeAddress);

        // Fluid 4626 vault was set up in BaseTest

        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));

        vm.startPrank(SV_MANAGER);
        deal(address(asset), SV_MANAGER, BOOTSTRAP_AMOUNT);
        IERC20(address(asset)).approve(address(factory), BOOTSTRAP_AMOUNT);

        // Deploy the vault trio
        (
          address superVaultAddress, 
          address superVaultStrategyAddress, 
          address superVaultEscrowAddress
        ) = _deployVault(
          address(asset),
          SUPER_VAULT_CAP,
          BOOTSTRAP_AMOUNT,
          "SV7540U"
        );

        vault = SuperVault(superVaultAddress);
        escrow = SuperVaultEscrow(superVaultEscrowAddress);
        strategy = SuperVaultStrategy(superVaultStrategyAddress);

        amount = 1000e6; // 1000 USDC

        vm.startPrank(SV_MANAGER);
        strategy.manageYieldSource(
            address(centrifugeVault),
            _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            0,
            false // addYieldSource
        );
        vm.stopPrank();

        address share = centrifugeVault.share();

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        ITranche(share).hook();

        address mngr = ITranche(share).hook();

        restrictionManager = RestrictionManagerLike(mngr);

        vm.startPrank(RestrictionManagerLike(mngr).root());
        
        restrictionManager.updateMember(share, address(strategy), type(uint64).max);

        vm.stopPrank();

        poolId = centrifugeVault.poolId();
        assertEq(poolId, 4_139_607_887);
        trancheId = centrifugeVault.trancheId();
        assertEq(trancheId, bytes16(0x97aa65f23e7be09fcd62d0554d2e9273));

        poolManager = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);

        rootManager = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

        assetId = poolManager.assetToId(underlyingETH_USDC);
        assertEq(assetId, uint128(242_333_941_209_166_991_950_178_742_833_476_896_417));
    }

    function test_SuperVault_7540_Underlying_Flow() public {
        // Request deposit into superVault as user1
        _requestDeposit(amount / 2);

        // Request deposit into superVault as user2
        deal(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);
        
        // Deposit into underlying vaults as strategy
        _fulfillDepositRequest(amount);

        // Fulfill deposit request into 7540 vault
        _fulfillCentrifugeDeposit(amount / 2);
    }

    function _fulfillDepositRequest(uint256 amountToDeposit) internal {
        // Fulfill deposit request for half amount into superVault
        uint256 amountPerVault = amountToDeposit / 2;

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;

        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](1);
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), amountPerVault, false, false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = fluidVault.convertToShares(amountPerVault);

        vm.prank(STRATEGIST);
        strategy.fulfillRequests(
            requestingUsers, fulfillHooksAddresses, fulfillHooksData, expectedAssetsOrSharesOut, true
        );

        // 7540 request deposit
        address approveAndRequestDepositHookAddress = _getHookAddress(ETH, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        address[] memory requestHooksAddresses = new address[](1);
        requestHooksAddresses[0] = approveAndRequestDepositHookAddress;

        bytes[] memory requestHooksData = new bytes[](1);
        requestHooksData[0] = _createApproveAndRequestDeposit7540HookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(centrifugeVault), address(asset), amountPerVault, false
        );

        vm.prank(STRATEGIST);
        strategy.executeHooks(requestHooksAddresses, requestHooksData);

        (uint256 pricePerShare) = _getSuperVaultPricePerShare();
        console2.log("pricePerShare after Fluid deposit", pricePerShare);

        uint256 shares = amountPerVault.mulDiv(1e18, pricePerShare);
        userSharePricePoints[accountEth].push(SharePricePoint({ shares: shares, pricePerShare: pricePerShare }));
    }

    function _fulfillCentrifugeDeposit(uint256 amountPerVault) internal {
        uint256 expectedShares = centrifugeVault.convertToShares(amountPerVault);
        vm.prank(rootManager);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, address(strategy), assetId, uint128(amountPerVault), uint128(expectedShares)
        );

        uint256 maxDeposit = centrifugeVault.maxDeposit(address(strategy));

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(centrifugeVault), maxDeposit, false, false
        );

        vm.prank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        uint256 pps = _getSuperVaultPricePerShare();
        console2.log("PPS AFTER CENTRIFUGE DEPOSIT", pps);
    }
}