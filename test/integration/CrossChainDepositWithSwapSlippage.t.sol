// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperDestinationExecutor } from "../../src/core/interfaces/ISuperDestinationExecutor.sol";
import { IYieldSourceOracle } from "../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { AcrossV3Adapter } from "../../src/core/adapters/AcrossV3Adapter.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { IStakeManager } from "@account-abstraction/interfaces/IStakeManager.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

// Two briding actions to the same chain, Across gateway waits for both to arrive
// Two target vaults where one requires a swap due to underlying mismatch which incurs slippage
contract CrossChainDepositWithSwapSlippage is BaseTest {
    IERC4626 public vaultInstance4626Base_USDC;
    IERC4626 public vaultInstance4626Base_WETH;

    address public addressOracleBase_4626;

    address public underlyingBase_USDC;
    address public underlyingBase_WETH;
    address public underlyingETH_USDC;
    address public underlyingOP_USDC;

    address public swapRouter;

    address public yieldSource4626AddressBase_USDC;
    address public yieldSource4626AddressBase_WETH;

    IYieldSourceOracle public yieldSourceOracleBase_4626;
    IYieldSourceOracle public yieldSourceOracleBase_WETH;

    address public yieldSourceAddressEth;
    IERC4626 public vaultInstanceEth;

    address public yieldSourceAddressBase;
    IERC4626 public vaultInstanceBase;

    address public accountOP;
    address public accountETH;
    address public accountBase;

    AccountInstance public instanceOnOP;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnBase;

    ISuperExecutor public superExecutorOnOP;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnBase;

    ISuperDestinationExecutor public superTargetExecutorOnBase;
    ISuperDestinationExecutor public superTargetExecutorOnETH;
    ISuperDestinationExecutor public superTargetExecutorOnOP;

    AcrossV3Adapter public acrossV3AdapterOnBase;
    AcrossV3Adapter public acrossV3AdapterOnETH;
    AcrossV3Adapter public acrossV3AdapterOnOP;

    IValidator public validatorOnBase;
    IValidator public validatorOnETH;
    IValidator public validatorOnOP;

    IValidator public sourceValidatorOnBase;
    IValidator public sourceValidatorOnETH;
    IValidator public sourceValidatorOnOP;

    address public validatorSigner;
    uint256 public validatorSignerPrivateKey;

    string public constant YIELD_SOURCE_ORACLE_4626_BASE = "YieldSourceOracle_4626";

    string public constant YIELD_SOURCE_4626_BASE_USDC_KEY = "ERC4626_BASE_USDC";
    string public constant YIELD_SOURCE_4626_BASE_WETH_KEY = "ERC4626_BASE_WETH";
    uint256 public constant WARP_START_TIME = 1_740_559_708;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        // Set up the underlying tokens
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingOP_USDC = existingUnderlyingTokens[OP][USDC_KEY];

        // Set up the 4626 USDC yield source on BASE
        yieldSource4626AddressBase_USDC =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];

        vaultInstance4626Base_USDC = IERC4626(yieldSource4626AddressBase_USDC);
        vm.label(yieldSource4626AddressBase_USDC, YIELD_SOURCE_4626_BASE_USDC_KEY);

        // Set up the 4626 WETH yield source on BASE
        yieldSource4626AddressBase_WETH =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY];

        vaultInstance4626Base_WETH = IERC4626(yieldSource4626AddressBase_WETH);
        vm.label(yieldSource4626AddressBase_WETH, YIELD_SOURCE_4626_BASE_WETH_KEY);

        // Set up the yield source oracle
        addressOracleBase_4626 = _getContract(BASE, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleBase_4626, YIELD_SOURCE_ORACLE_4626_BASE);
        yieldSourceOracleBase_4626 = IYieldSourceOracle(addressOracleBase_4626);

        yieldSourceAddressEth = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstanceEth = IERC4626(yieldSourceAddressEth);

        yieldSourceAddressBase = realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceBase = IERC4626(yieldSourceAddressBase);

        // Set up the accounts
        accountOP = accountInstances[OP].account;
        accountETH = accountInstances[ETH].account;
        accountBase = accountInstances[BASE].account;

        instanceOnOP = accountInstances[OP];
        instanceOnETH = accountInstances[ETH];
        instanceOnBase = accountInstances[BASE];

        // Set up the Super Executors
        superExecutorOnOP = ISuperExecutor(_getContract(OP, "SuperExecutor"));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, "SuperExecutor"));

        // Set up the super target executors
        superTargetExecutorOnBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnOP = ISuperDestinationExecutor(_getContract(OP, SUPER_DESTINATION_EXECUTOR_KEY));

        acrossV3AdapterOnBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnOP = AcrossV3Adapter(_getContract(OP, ACROSS_V3_ADAPTER_KEY));

        // Set up the destination validators
        validatorOnBase = IValidator(_getContract(BASE, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnOP = IValidator(_getContract(OP, SUPER_DESTINATION_VALIDATOR_KEY));

        // Set up the source validators
        sourceValidatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnOP = IValidator(_getContract(OP, SUPER_MERKLE_VALIDATOR_KEY));

        // base is the destination
        vm.selectFork(FORKS[BASE]);

        // Set up the 1inch swap router
        deal(underlyingBase_WETH, mockOdosRouters[BASE], 1e12);
    }

    /*//////////////////////////////////////////////////////////////
                           FULL FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CrossChainDepositWithSlippage() public {
        _sendFundsFromOpToBase();
        _sendFundsFromEthToBase();
    }

    function test_RebalanceCrossChain_4626_Mainnet_FlowXX() public {
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        uint256 amount = 1e8;
        uint256 previewRedeemAmount = vaultInstanceEth.previewRedeem(vaultInstanceEth.previewDeposit(amount));

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);

        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            // PREPARE DST DATA
            address[] memory dstHooksAddresses = new address[](2);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](2);
            dstHooksData[0] =
                _createApproveHookData(underlyingBase_USDC, yieldSourceAddressBase, previewRedeemAmount, false);
            dstHooksData[1] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceAddressBase,
                previewRedeemAmount,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: amount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
        }

        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        address[] memory srcHooksAddresses = new address[](4);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](4);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceAddressEth, amount, false);
        srcHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, address(0), 0
        );
        srcHooksData[2] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 0, true);

        srcHooksData[3] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][USDC_KEY],
            previewRedeemAmount,
            previewRedeemAmount,
            BASE,
            true,
            targetExecutorMessage
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOpsWithValidator(instanceOnETH, superExecutorOnETH, abi.encode(entry), address(sourceValidatorOnETH));
        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        _processAcrossV3Message(
            ETH, BASE, block.timestamp, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase
        );
    }

    /*//////////////////////////////////////////////////////////////
                           PARTIAL FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Must be called before _sendFundsFromEthToBase
    function _sendFundsFromOpToBase() internal {
        uint256 intentAmount = 1e10;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);
        // Transfer users USDC to this contract so that balance checks are correct
        uint256 amountToRemove = IERC20(underlyingBase_USDC).balanceOf(accountBase);
        vm.prank(accountBase);
        IERC20(underlyingBase_USDC).transfer(address(this), amountToRemove);

        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            // PREPARE DST DATA
            address[] memory dstHooksAddresses = new address[](2);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](2);
            dstHooksData[0] =
                _createApproveHookData(underlyingBase_USDC, yieldSource4626AddressBase_USDC, intentAmount / 2, false);
            dstHooksData[1] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSource4626AddressBase_USDC,
                intentAmount / 2,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: intentAmount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
        }

        // OP IS SRC1
        SELECT_FORK_AND_WARP(OP, block.timestamp);

        // PREPARE SRC1 DATA
        address[] memory src1HooksAddresses = new address[](2);
        src1HooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        src1HooksAddresses[1] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory src1HooksData = new bytes[](2);
        src1HooksData[0] =
            _createApproveHookData(underlyingOP_USDC, SPOKE_POOL_V3_ADDRESSES[OP], intentAmount / 2, false);
        src1HooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingOP_USDC,
            underlyingBase_USDC,
            intentAmount / 2,
            intentAmount / 2,
            BASE,
            false,
            targetExecutorMessage
        );

        UserOpData memory src1UserOpData = _createUserOpData(src1HooksAddresses, src1HooksData, OP, true);

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, src1UserOpData.userOpHash, accountToUse);
        src1UserOpData.userOp.signature = signatureData;

        console2.log("sending from op to base");
        // not enough balance is received
        _processAcrossV3Message(
            OP, BASE, block.timestamp, executeOp(src1UserOpData), RELAYER_TYPE.NOT_ENOUGH_BALANCE, accountBase
        );
    }

    function _sendFundsFromEthToBase() internal {
        uint256 intentAmount = 1e10;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);

        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        // PREPARE DST DATA
        {
            address[] memory dstHooksAddresses = new address[](4);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[1] = _getHookAddress(BASE, MOCK_SWAP_ODOS_HOOK_KEY);
            dstHooksAddresses[2] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[3] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](4);
            dstHooksData[0] =
                _createApproveHookData(underlyingBase_USDC, mockOdosRouters[BASE], intentAmount / 2, false);
            dstHooksData[1] = _createOdosSwapHookData(
                underlyingBase_USDC,
                intentAmount / 2,
                address(this),
                underlyingBase_WETH,
                intentAmount / 2,
                0,
                bytes(""),
                mockOdosRouters[BASE],
                0,
                true
            );
            dstHooksData[2] =
                _createApproveHookData(underlyingBase_WETH, yieldSource4626AddressBase_WETH, intentAmount / 2, true);
            dstHooksData[3] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSource4626AddressBase_WETH,
                intentAmount / 2,
                true,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: intentAmount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
        }

        // ETH IS SRC1
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        // PREPARE SRC1 DATA
        address[] memory src1HooksAddresses = new address[](2);
        src1HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        src1HooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory src1HooksData = new bytes[](2);
        src1HooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], intentAmount, false);
        src1HooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC,
            underlyingBase_USDC,
            intentAmount / 2,
            intentAmount / 2,
            BASE,
            false,
            targetExecutorMessage
        );

        UserOpData memory src1UserOpData = _createUserOpData(src1HooksAddresses, src1HooksData, ETH, true);
        console2.log("sending from eth to base");

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, src1UserOpData.userOpHash, accountToUse);
        src1UserOpData.userOp.signature = signatureData;

        // enough balance is received
        _processAcrossV3Message(
            ETH, BASE, block.timestamp, executeOp(src1UserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase
        );

        SELECT_FORK_AND_WARP(BASE, block.timestamp + 10 minutes);

        uint256 sharesExpectedWETH =
            vaultInstance4626Base_WETH.convertToShares((intentAmount / 2) - ((intentAmount / 2) * 50 / 10_000));

        uint256 sharesWETH = IERC4626(yieldSource4626AddressBase_WETH).balanceOf(accountBase);
        assertApproxEqRel(sharesWETH, sharesExpectedWETH, 0.02e18);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    // Creates userOpData for the given chainId
    function _createUserOpData(
        address[] memory hooksAddresses,
        bytes[] memory hooksData,
        uint64 chainId,
        bool withValidator
    )
        internal
        returns (UserOpData memory)
    {
        if (chainId == ETH) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute), address(sourceValidatorOnETH));
            }
            return _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute));
        } else if (chainId == OP) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute), address(sourceValidatorOnOP));
            }
            return _getExecOps(instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute));
        } else {
            /// @dev only base requires a paymaster for across execution
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(
                instanceOnBase,
                superExecutorOnBase,
                abi.encode(entryToExecute),
                _getContract(BASE, SUPER_NATIVE_PAYMASTER_KEY)
            );
        }
    }
}
