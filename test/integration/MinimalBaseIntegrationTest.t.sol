// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { Helpers } from "../utils/Helpers.sol";
import { InternalHelpers } from "../utils/InternalHelpers.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ERC4626YieldSourceOracle } from "../../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../src/core/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../src/core/executors/SuperExecutor.sol";
import { SuperLedger } from "../../src/core/accounting/SuperLedger.sol";
import { ERC5115Ledger } from "../mocks/ERC5115Ledger.sol";
import { ISuperLedgerConfiguration } from "../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ApproveERC20Hook } from "../../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Deposit4626VaultHook } from "../../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { ApproveAndDeposit4626VaultHook } from "../../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import "forge-std/console2.sol";

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault
abstract contract MinimalBaseIntegrationTest is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    IERC4626 public vaultInstanceEth;
    address public yieldSourceAddressEth;

    address public yieldSourceOracle;
    address public underlyingEth_USDC;

    address public accountEth;
    AccountInstance public instanceOnEth;
    AccountInstance public instanceOnEth2;
    ISuperExecutor public superExecutorOnEth;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;
    address public approveHook;
    address public deposit4626Hook;
    address public approveAndDeposit4626Hook;
    address public redeem4626Hook;
    uint256 public blockNumber;

    bool public useRealOdosRouter;

    function setUp() public virtual {
        blockNumber != 0
            ? vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), blockNumber)
            : vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        underlyingEth_USDC = CHAIN_1_USDC;
        yieldSourceAddressEth = CHAIN_1_MorphoVault;
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));

        yieldSourceOracle = address(new ERC4626YieldSourceOracle(address(ledgerConfig)));
        vaultInstanceEth = IERC4626(yieldSourceAddressEth);
        instanceOnEth = makeAccountInstance(keccak256(abi.encode("acc1")));
        instanceOnEth2 = makeAccountInstance(keccak256(abi.encode("acc2")));
        accountEth = instanceOnEth.account;
        _getTokens(underlyingEth_USDC, accountEth, 1e18);

        superExecutorOnEth = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnEth), data: "" });

        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorOnEth);

        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](3);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(new ERC7540YieldSourceOracle(address(ledgerConfig))),
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(new ERC5115YieldSourceOracle(address(ledgerConfig))),
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(new ERC5115Ledger(address(ledgerConfig), allowedExecutors))
        });
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        salts[1] = bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
        salts[2] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY));
        ledgerConfig.setYieldSourceOracles(salts, configs);

        approveHook = address(new ApproveERC20Hook());
        deposit4626Hook = address(new Deposit4626VaultHook());
        redeem4626Hook = address(new Redeem4626VaultHook());
        approveAndDeposit4626Hook = address(new ApproveAndDeposit4626VaultHook());

        useRealOdosRouter = false;
    }

    function _toggleUseRealOdosRouter(bool _useRealOdosRouter) public {
        useRealOdosRouter = _useRealOdosRouter;
    }
}
