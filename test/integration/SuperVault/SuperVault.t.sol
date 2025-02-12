// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
// external

import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { console } from "forge-std/console.sol";
// superform
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

contract SuperVaultTest is MerkleReader {
    address public accountEth;
    AccountInstance public instanceOnEth;
    ISuperExecutor public superExecutorOnEth;

    // Core contracts
    SuperVaultFactory public factory;
    SuperVault public vault;
    SuperVaultStrategy public strategy;
    SuperVaultEscrow public escrow;

    // Roles
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;
    address public FEE_RECIPIENT;

    // Tokens and yield sources
    IERC20Metadata public asset;
    IERC4626 public morphoVault;
    IERC4626 public aaveVault;

    // Constants
    uint256 constant VAULT_CAP = 1_000_000e6; // 1M USDC
    uint256 constant SUPER_VAULT_CAP = 5_000_000e6; // 5M USDC
    uint256 constant MAX_ALLOCATION_RATE = 5000; // 50%
    uint256 constant VAULT_THRESHOLD = 100_000e6; // 100k USDC

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        // Deploy factory
        factory = new SuperVaultFactory();

        // Set up roles
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");
        FEE_RECIPIENT = _deployAccount(FEE_RECIPIENT_KEY, "FEE_RECIPIENT");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);

        address morphoVaultAddr = 0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458;
        address aaveVaultAddr = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
        vm.label(morphoVaultAddr, "MorphoVault");
        vm.label(aaveVaultAddr, "AaveVault");
        // Get real yield sources from fork
        morphoVault = IERC4626(morphoVaultAddr);
        aaveVault = IERC4626(aaveVaultAddr);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: MAX_ALLOCATION_RATE,
            vaultThreshold: VAULT_THRESHOLD
        });

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            address(asset), "SuperVault USDC", "svUSDC", SV_MANAGER, STRATEGIST, EMERGENCY_ADMIN, config, FEE_RECIPIENT
        );
        vm.label(vaultAddr, "SuperVault");
        vm.label(strategyAddr, "SuperVaultStrategy");
        vm.label(escrowAddr, "SuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Add yield sources as manager
        vm.startPrank(SV_MANAGER);
        strategy.addYieldSource(address(morphoVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        strategy.addYieldSource(address(aaveVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        vm.stopPrank();

        // Set up hook root
        bytes32 hookRoot = _getMerkleRoot();
        vm.startPrank(SV_MANAGER);
        strategy.proposeHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategy.executeHookRootUpdate();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _requestDeposit(uint256 depositAmount) internal {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(asset), address(vault), depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accountEth, depositAmount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function _fulfillDeposit(uint256 depositAmount) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(depositHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(morphoVault), depositAmount / 2, false, false
        );
        fulfillHooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(aaveVault), depositAmount / 2, false, false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillDepositRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData);
        vm.stopPrank();
    }

    function _claimDeposit(uint256 depositAmount) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accountEth, depositAmount, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _requestRedeem(uint256 redeemShares) internal {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(ETH, REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRequestWithdraw7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accountEth, redeemShares, false
        );

        ISuperExecutor.ExecutorEntry memory redeemEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHooksAddresses, hooksData: redeemHooksData });
        UserOpData memory redeemUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(redeemEntry));
        executeOp(redeemUserOpData);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        _requestDeposit(depositAmount);

        // Verify state
        assertEq(strategy.pendingDepositRequest(accountEth), depositAmount, "Wrong pending deposit amount");
        assertEq(asset.balanceOf(address(strategy)), depositAmount, "Wrong strategy balance");
    }

    function test_FulfillDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup deposit request first
        _requestDeposit(depositAmount);

        // Verify request state
        assertEq(strategy.pendingDepositRequest(accountEth), depositAmount, "Wrong pending deposit amount");
        console.log("Pending deposit request:", strategy.pendingDepositRequest(accountEth));
        // Fulfill deposit
        _fulfillDeposit(depositAmount);

        // Verify state
        assertEq(strategy.pendingDepositRequest(accountEth), 0, "Pending request not cleared");
        assertGt(strategy.maxMint(accountEth), 0, "No shares available to mint");
    }

    function test_ClaimDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup and fulfill deposit
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);

        // Get claimable shares
        uint256 claimableShares = strategy.maxMint(accountEth);

        // Claim deposit
        _claimDeposit(depositAmount);

        // Verify state
        assertEq(vault.balanceOf(accountEth), claimableShares, "Wrong share balance");
        assertEq(strategy.maxMint(accountEth), 0, "Shares not claimed");
    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestRedeem() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // First setup a deposit and claim it
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);
        _claimDeposit(depositAmount);

        // Now request redeem of half the shares
        uint256 redeemShares = vault.balanceOf(accountEth) / 2;
        _requestRedeem(redeemShares);

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), redeemShares, "Wrong pending redeem amount");
        assertEq(vault.balanceOf(address(escrow)), redeemShares, "Wrong escrow balance");
    }

    // TODO: Add remaining tests following test-plan.md
}
