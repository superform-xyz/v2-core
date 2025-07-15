// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { console2 } from "forge-std/console2.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { MockExecutorModule } from "../../mocks/MockExecutorModule.sol";
import { MockAccountingVault } from "../../mocks/MockAccountingVault.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

contract FeeConfigChangeTest is MinimalBaseIntegrationTest {
    IERC4626 public vaultInstance;

    address public yieldSourceAddress;
    address public underlying;

    SuperLedgerConfiguration public configSuperLedger;
    SuperLedger public superLedger;

    address public executor1;
    address public executor2;
    address public manager;
    address public feeRecipient;
    
    bytes32 yieldSourceOracleId;
    ERC4626YieldSourceOracle public oracle;

    MockExecutorModule public executorModule1;

    function setUp() public override {
        super.setUp();

        executor1 = makeAddr("executor1");
        executor2 = makeAddr("executor2");
        manager = makeAddr("manager");
        feeRecipient = makeAddr("feeRecipient");

        underlying = CHAIN_1_WETH;

        MockAccountingVault vault = new MockAccountingVault(IERC20(underlying), "Vault", "VAULT");
        vm.label(address(vault), "MockAccountingVault");
        yieldSourceAddress = address(vault);
        vaultInstance = IERC4626(vault);

        configSuperLedger = new SuperLedgerConfiguration();

        executorModule1 = new MockExecutorModule();

        address[] memory allowedExecutors = new address[](2);
        allowedExecutors[0] = address(executorModule1);

        superLedger = new SuperLedger(address(configSuperLedger), allowedExecutors);

        yieldSourceOracleId = bytes32(keccak256("TEST_ORACLE_ID"));
        yieldSourceOracleId = keccak256(abi.encodePacked(yieldSourceOracleId, address(this)));

        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = bytes32(keccak256("TEST_ORACLE_ID"));

        oracle = new ERC4626YieldSourceOracle(address(superLedger));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 0,
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        configSuperLedger.setYieldSourceOracles(yieldSourceOracleIds, configs);
    }

    function test_FeeConfigChange() public {
        // User deposits with fee = 0
        uint256 depositAmount = 1e18;

        _getTokens(underlying, accountEth, depositAmount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, depositAmount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            depositAmount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        // Propose and accept a new config with fee = 100 (1%)
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 2000, // 20%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = yieldSourceOracleId;
        configSuperLedger.proposeYieldSourceOracleConfig(ids, configs);

        // Fast forward timelock
        vm.warp(block.timestamp + 1 weeks);
        configSuperLedger.acceptYieldSourceOracleConfigProposal(ids);

        // User redeems all shares
        uint256 feeRecipientBalanceBefore = vaultInstance.balanceOf(feeRecipient);
        uint256 userShares = vaultInstance.balanceOf(accountEth);
        
        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = redeem4626Hook;

        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            accountEth,
            userShares,
            false
        );

        ISuperExecutor.ExecutorEntry memory entry1 =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry1));
        executeOp(userOpData1);

        console2.log(vaultInstance.balanceOf(feeRecipient));

        // Check that the user received the correct amount of assets and the fee recipient received the correct amount of shares
        uint256 expectedFee = userShares * 2000 / 10_000;
        uint256 balanceInAsset = vaultInstance.convertToAssets(userShares);
        uint256 expectedUserAssets = balanceInAsset - (balanceInAsset * 2000 / 10_000);

        assertEq(balanceInAsset, expectedUserAssets, "User did not receive correct assets after fee");
        uint256 feeRecipientShares = vaultInstance.balanceOf(feeRecipient) - feeRecipientBalanceBefore;
        assertEq(feeRecipientShares, expectedFee, "Fee recipient did not receive correct shares");
    }
}
