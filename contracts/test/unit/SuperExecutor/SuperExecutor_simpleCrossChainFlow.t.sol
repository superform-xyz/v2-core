// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "src/interfaces/ISuperExecutor.sol";
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperLedger } from "src/interfaces/accounting/ISuperLedger.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

import { AcrossBridgeGateway } from "src/bridges/AcrossBridgeGateway.sol";
import { AcrossExecuteOnDestinationHook } from "src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";
import { SpokePoolV3Mock } from "../../mocks/SpokePoolV3Mock.sol";

import { BaseTest } from "../../BaseTest.t.sol";

contract SuperExecutor_simpleCrossChainFlow is BaseTest {
    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public yieldSourceOracle;
    address public underlying;
    address public account;
    AccountInstance public instance;
    ISuperExecutor public superExecutor;
    ISuperRbac public superRbac;
    SpokePoolV3Mock public spokePoolV3Mock;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        underlying = existingUnderlyingTokens[1]["USDC"];

        yieldSourceAddress = realVaultAddresses[1]["ERC4626"]["MorphoVault"]["USDC"];
        yieldSourceOracle = _getContract(ETH, "ERC4626YieldSourceOracle");
        vaultInstance = IERC4626(yieldSourceAddress);
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];
        superExecutor = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
        superRbac = ISuperRbac(_getContract(ETH, "SuperRbac"));
        spokePoolV3Mock = SpokePoolV3Mock(_getContract(ETH, "SpokePoolV3Mock"));
    }

    function test_GivenAStrategyDoesNotExist(uint256 amount) external addRole(superRbac, superRbac.BRIDGE_GATEWAY()) {
        amount = _bound(amount);
        // it should retrieve an empty array of hooks
        // it should revert ?
        address[] memory hooksAddresses = new address[](0);
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        superExecutor.executeFromGateway(account, abi.encode(entry));
    }

    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid()
        external
        addRole(superRbac, superRbac.BRIDGE_GATEWAY())
    {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");

        // it should revert
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encode(uint256(1));
        hooksData[1] = abi.encode(uint256(1));

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert();
        superExecutor.executeFromGateway(account, abi.encode(entry));
    }

    modifier givenStrategyHasACrossHookAndNoSameChainHooks() {
        _;
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValidAndSentinelIsConfigured(uint256 amount)
        external
        addRole(superRbac, superRbac.BRIDGE_GATEWAY())
    {
        amount = _bound(amount);
        (
            address[] memory depositHooksAddresses,
            bytes[] memory depositHooksData,
            address[] memory withdrawHooksAddresses,
            bytes[] memory withdrawHooksData
        ) = _createDepositAndBridgeActionData(amount);

        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: depositHooksAddresses, hooksData: depositHooksData });

        // check bridge emitted event; assume Orchestrator picks it up
        ISuperExecutor.ExecutorEntry memory subEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: withdrawHooksAddresses, hooksData: withdrawHooksData });

        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        vm.expectEmit(true, true, true, true);
        emit AcrossBridgeGateway.InstructionProcessed(account, abi.encode(subEntry));
        executeOp(userOpData);

        //  simulate Orchestrator call for the remaning data
        superExecutor.executeFromGateway(account, abi.encode(subEntry));
    }

    function _createDepositAndBridgeActionData(uint256 amount)
        internal
        view
        returns (
            address[] memory depositHooksAddresses,
            bytes[] memory depositHooksData,
            address[] memory withdrawHooksAddresses,
            bytes[] memory withdrawHooksData
        )
    {
        withdrawHooksAddresses = new address[](2);
        withdrawHooksAddresses[0] = _getHook(ETH, "Withdraw4626VaultHook");
        withdrawHooksAddresses[1] = _getHook(ETH, "SuperLedgerHook");

        withdrawHooksData = new bytes[](2);
        withdrawHooksData[0] = _createWithdrawHookData(yieldSourceAddress, account, account, amount, false);
        withdrawHooksData[1] = _createSuperLedgerHookData(account, yieldSourceOracle, yieldSourceAddress);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: withdrawHooksAddresses, hooksData: withdrawHooksData });

        AcrossExecuteOnDestinationHook.AcrossV3DepositData memory acrossV3DepositData = AcrossExecuteOnDestinationHook
            .AcrossV3DepositData({
            value: SMALL,
            recipient: account,
            inputToken: yieldSourceAddress,
            outputToken: yieldSourceAddress,
            inputAmount: amount,
            outputAmount: amount,
            destinationChainId: 1,
            exclusiveRelayer: address(0),
            fillDeadline: 0,
            exclusivityDeadline: 0,
            instruction: IAcrossV3Interpreter.Instruction({
                account: account,
                amount: amount,
                strategyData: abi.encode(entry)
            })
        });

        depositHooksAddresses = new address[](5);
        depositHooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        depositHooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        depositHooksAddresses[2] = _getHook(ETH, "SuperLedgerHook");
        depositHooksAddresses[3] = _getHook(ETH, "ApproveERC20Hook");
        depositHooksAddresses[4] = _getHook(ETH, "AcrossExecuteOnDestinationHook");

        depositHooksData = new bytes[](5);
        depositHooksData[0] = abi.encodePacked(underlying, yieldSourceAddress, amount, false);
        depositHooksData[1] = abi.encodePacked(yieldSourceAddress, account, amount, false);
        depositHooksData[2] = abi.encodePacked(account, yieldSourceOracle, yieldSourceAddress, true, amount);
        depositHooksData[3] = abi.encodePacked(yieldSourceAddress, address(spokePoolV3Mock), amount, false);
        depositHooksData[4] = abi.encode(acrossV3DepositData);
    }
}
