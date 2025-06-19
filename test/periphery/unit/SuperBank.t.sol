// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ApproveERC20Hook } from "../../../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Redeem4626VaultHook } from "../../../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from "../../../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import { SwapOdosHook } from "../../../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import { Bank } from "../../../src/periphery/Bank.sol";
import { SuperBank } from "../../../src/periphery/SuperBank.sol";
import { ISuperBank } from "../../../src/periphery/interfaces/ISuperBank.sol";
import { ISuperGovernor, FeeType } from "../../../src/periphery/interfaces/ISuperGovernor.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { Up } from "../../../src/periphery/UP/Up.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { MockSuperHook } from "../../mocks/MockSuperHook.sol";
import { MockHookTarget } from "../../mocks/MockHookTarget.sol";
import { IHookExecutionData } from "../../../src/periphery/interfaces/IHookExecutionData.sol";
import { MockOdosRouterV2 } from "../../mocks/MockOdosRouterV2.sol";
import { OdosAPIParser } from "../../utils/parsers/OdosAPIParser.sol";
import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";

import "forge-std/Test.sol";


contract SuperBankTest is Helpers, InternalHelpers, OdosAPIParser {
    SuperGovernor internal superGovernor;
    SuperBank internal superBank;
    Up internal up;
    MockOdosRouterV2 internal odosRouter;
    MockERC20 internal token;
    Mock4626Vault internal vault;
    AcrossV3Helper internal acrossV3Helper;

    address internal sGovernor;
    address internal governor;
    address internal treasury;
    address internal user;
    address internal hook1;
    address internal hook2;
    address internal fulfillHook1;
    address internal fulfillHook2;
    address internal validator1;
    address internal validator2;
    address internal ppsOracle1;
    address internal ppsOracle2;
    address internal superVaultAggregator;
    address internal strategy1;
    address internal newStrategist;
    address internal admin;

    address underlying; 

    string public ETHEREUM_RPC_URL = vm.envString(ETHEREUM_RPC_URL_KEY);
    string public BASE_RPC_URL = vm.envString(BASE_RPC_URL_KEY); 

    function setUp() public {
        sGovernor = _deployAccount(0x1, "SuperGovernor");
        governor = _deployAccount(0x2, "Governor");
        treasury = _deployAccount(0x3, "Treasury");
        user = _deployAccount(0x4, "User");
        hook1 = _deployAccount(0x5, "Hook1");
        hook2 = _deployAccount(0x6, "Hook2");
        fulfillHook1 = _deployAccount(0x7, "FulfillHook1");
        fulfillHook2 = _deployAccount(0x8, "FulfillHook2");
        validator1 = _deployAccount(0x9, "Validator1");
        validator2 = _deployAccount(0xA, "Validator2");
        ppsOracle1 = _deployAccount(0xB, "PPSOracle1");
        ppsOracle2 = _deployAccount(0xC, "PPSOracle2");
        admin = _deployAccount(0xD, "Admin");
        newStrategist = _deployAccount(0xE, "NewStrategist");

        superGovernor = new SuperGovernor(sGovernor, governor, governor, treasury, address(this));
        superBank = new SuperBank(address(superGovernor));
        up = new Up(admin);
        
        underlying = CHAIN_1_USDC;
        odosRouter = new MockOdosRouterV2();
        vm.label(address(odosRouter), "OdosRouter");

        token = new MockERC20("Test Token", "TEST", 18);
        vm.label(address(token), "Test Token");

        vault = new Mock4626Vault(address(token), "Test Vault", "TSTV");
        vm.label(address(vault), "4626 vault");

        acrossV3Helper = new AcrossV3Helper();
        vm.label(address(acrossV3Helper), "Pigeon AcrossV3Helper");
        vm.allowCheatcodes(address(acrossV3Helper));
        vm.makePersistent(address(acrossV3Helper));
    }

    function test_SuperBank_Constructor() public {
        assertEq(address(superBank.SUPER_GOVERNOR()), address(superGovernor), "SuperGovernor address not set correctly");
        
        vm.expectRevert(ISuperBank.INVALID_ADDRESS.selector);
        new SuperBank(address(0));
    }

    function test_SuperBank_receive() public {
        uint256 initialBalance = address(superBank).balance;
        
        uint256 amountToSend = 1 ether;
        vm.deal(user, amountToSend);
        
        vm.prank(user);
        (bool success,) = address(superBank).call{value: amountToSend}("");
        assertTrue(success, "ETH transfer failed");
        
        assertEq(address(superBank).balance, initialBalance + amountToSend, "SuperBank did not receive ETH correctly");
    }

    function test_SuperBank_distribute_ZeroLengthArray() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();
        
        vm.expectRevert(Bank.ZERO_LENGTH_ARRAY.selector);
        superBank.distribute(0);
    }

    function test_SuperBank_distribute_InvalidUpAmountToDistribute() public {
        vm.startPrank(sGovernor);
        vm.stopPrank();
        
        vm.startPrank(sGovernor);
        superGovernor.grantRole(keccak256("BANK_MANAGER_ROLE"), address(this));
        superGovernor.setAddress(keccak256("UP"), address(up));
        superGovernor.setAddress(keccak256("SUP"), address(this));
        superGovernor.setAddress(keccak256("TREASURY"), address(treasury));
        vm.stopPrank();

        vm.expectRevert(ISuperBank.INVALID_UP_AMOUNT_TO_DISTRIBUTE.selector);
        superBank.distribute(1e6);
    }

    function test_SuperBank_distribute_success_unit() public {
        address supToken = address(0xF); // Mock sUP token address
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        superGovernor.setAddress(superGovernor.UP(), address(up));
        superGovernor.setAddress(superGovernor.SUP(), supToken);
        superGovernor.setAddress(superGovernor.TREASURY(), treasury);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 * 365 days);
        
        uint256 upAmount = 100 ether;
        vm.startPrank(admin);
        up.mint(address(superBank), upAmount);
        vm.stopPrank();
        
        uint256 initialSupBalance = up.balanceOf(supToken);
        uint256 initialTreasuryBalance = up.balanceOf(treasury);
        
        uint256 revenueShare = superGovernor.getFee(FeeType.REVENUE_SHARE);
        uint256 expectedSupAmount = (upAmount * revenueShare) / 10_000;
        uint256 expectedTreasuryAmount = upAmount - expectedSupAmount;
        
        vm.expectEmit(true, true, true, true);
        emit ISuperBank.RevenueDistributed(
            address(up),
            supToken,
            treasury,
            expectedSupAmount,
            expectedTreasuryAmount
        );
        superBank.distribute(upAmount);
        
        assertEq(up.balanceOf(supToken), initialSupBalance + expectedSupAmount, "sUP token received incorrect amount");
        assertEq(up.balanceOf(treasury), initialTreasuryBalance + expectedTreasuryAmount, "Treasury received incorrect amount");
    }

   function test_SuperBank_executeHooks_ZeroLengthArray() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();
        
        address[] memory hooks = new address[](0);
        bytes[] memory data = new bytes[](0);
        bytes32[][] memory merkleProofs = new bytes32[][](0);
        
        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooks,
            data: data,
            merkleProofs: merkleProofs
        });
        
        vm.startPrank(address(this));
        vm.expectRevert(Bank.ZERO_LENGTH_ARRAY.selector);
        superBank.executeHooks(executionData);
        vm.stopPrank();
    }
    
    function test_SuperBank_executeHooks_InvalidArrayLength() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();
        
        address[] memory hooks = new address[](2);
        hooks[0] = address(0x1111);
        hooks[1] = address(0x2222);
        
        bytes[] memory data = new bytes[](1); 
        data[0] = "data1";
        
        bytes32[][] memory merkleProofs = new bytes32[][](2);
        merkleProofs[0] = new bytes32[](1);
        merkleProofs[1] = new bytes32[](1);
        
        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooks,
            data: data,
            merkleProofs: merkleProofs
        });
        
        vm.expectRevert(Bank.INVALID_ARRAY_LENGTH.selector);
        superBank.executeHooks(executionData);
        vm.stopPrank();
    }
    
    function test_SuperBank_executeHooks_InvalidMerkleProof() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();
        
        MockHookTarget mockTarget = new MockHookTarget();
        MockSuperHook mockHook = new MockSuperHook(address(mockTarget));
        
        address[] memory hooks = new address[](1);
        hooks[0] = address(mockHook);
        
        bytes[] memory data = new bytes[](1);
        data[0] = "data1";
        
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](1);
        merkleProofs[0][0] = bytes32(uint256(1)); 
        
        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooks,
            data: data,
            merkleProofs: merkleProofs
        });
        
        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", address(mockHook)),
            abi.encode(bytes32(uint256(2)))
        );
        
        vm.expectRevert(Bank.INVALID_MERKLE_PROOF.selector);
        superBank.executeHooks(executionData);
        vm.stopPrank();
    }
    
    function test_SuperBank_executeHooks_HookExecutionFailed() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();
        
        MockHookTarget mockTarget = new MockHookTarget();
        mockTarget.setShouldFailExecution(true); // Set to fail during execution
        mockTarget.setShouldFailExecution(true);
        
        MockSuperHook mockHook = new MockSuperHook(address(mockTarget));
        
        bytes32 targetLeaf = keccak256(bytes.concat(keccak256(abi.encodePacked(address(mockTarget)))));
        bytes32 merkleRoot = targetLeaf; 
        
        address[] memory hooks = new address[](1);
        hooks[0] = address(mockHook);
        
        bytes[] memory data = new bytes[](1);
        data[0] = "data1";
        
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](0); 
        
        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooks,
            data: data,
            merkleProofs: merkleProofs
        });
        
        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", address(mockHook)),
            abi.encode(merkleRoot)
        );
        
        vm.startPrank(address(this));
        vm.expectRevert(Bank.HOOK_EXECUTION_FAILED.selector);
        superBank.executeHooks(executionData);
        vm.stopPrank();
    }
    
    function test_SuperBank_executeHooks_Success() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();

        MockHookTarget mockTarget = new MockHookTarget();
        MockSuperHook mockHook = new MockSuperHook(address(mockTarget));
        
        bytes32 targetLeaf = keccak256(bytes.concat(keccak256(abi.encodePacked(address(mockTarget)))));
        bytes32 merkleRoot = targetLeaf;
        
        address[] memory hooks = new address[](1);
        hooks[0] = address(mockHook);
        
        bytes[] memory data = new bytes[](1);
        data[0] = "data1";
        
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](0); 
        
        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooks,
            data: data,
            merkleProofs: merkleProofs
        });
        
        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", address(mockHook)),
            abi.encode(merkleRoot)
        );
        
        vm.expectEmit(true, true, false, false, address(mockTarget));
        emit MockHookTarget.Executed();
        
        vm.expectEmit(true, true, true, true, address(superBank));
        emit Bank.HooksExecuted(hooks, data);
        
        superBank.executeHooks(executionData);
        vm.stopPrank();
    }
    
    function test_SuperBank_executeHooks_MultipleHooks() public {   
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();
        
        MockHookTarget mockTarget1 = new MockHookTarget();
        MockHookTarget mockTarget2 = new MockHookTarget();
        
        MockSuperHook mockHook1 = new MockSuperHook(address(mockTarget1));
        MockSuperHook mockHook2 = new MockSuperHook(address(mockTarget2));
        
        bytes32 targetLeaf1 = keccak256(bytes.concat(keccak256(abi.encodePacked(address(mockTarget1)))));
        bytes32 targetLeaf2 = keccak256(bytes.concat(keccak256(abi.encodePacked(address(mockTarget2)))));
        
        bytes32 merkleRoot1 = targetLeaf1;
        bytes32 merkleRoot2 = targetLeaf2;
        
        address[] memory hooks = new address[](2);
        hooks[0] = address(mockHook1);
        hooks[1] = address(mockHook2);
        
        bytes[] memory data = new bytes[](2);
        data[0] = "data1";
        data[1] = "data2";
        
        bytes32[][] memory merkleProofs = new bytes32[][](2);
        merkleProofs[0] = new bytes32[](0); 
        merkleProofs[1] = new bytes32[](0); 
        
        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooks,
            data: data,
            merkleProofs: merkleProofs
        });
        
        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", address(mockHook1)),
            abi.encode(merkleRoot1)
        );
        
        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", address(mockHook2)),
            abi.encode(merkleRoot2)
        );
        
        superBank.executeHooks(executionData);
        vm.stopPrank();
    }

    function test_SuperBank_SwapHookOdos() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();

        uint256 amount = SMALL;
        
        vm.warp(block.timestamp + 4 * 365 days);
        
        vm.startPrank(admin);
        up.mint(address(odosRouter), amount);
        vm.stopPrank();

        ApproveERC20Hook approveHook = new ApproveERC20Hook();
        SwapOdosHook odosHook = new SwapOdosHook(address(odosRouter));

        _getTokens(address(token), address(superBank), amount);

        QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
        quoteInputTokens[0] = QuoteInputToken({ tokenAddress: address(underlying), amount: amount });

        QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
        quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: address(up), proportion: 1 });

        bytes memory odosCalldata = abi.encodePacked(
            address(token),
            amount,
            address(this),
            address(up),
            amount,
            amount - amount * 1e4 / 1e5,
            true,
            uint256(0),
            bytes(""),
            address(0),
            uint32(0),
            false
        );
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(token), address(odosRouter), amount, false);
        hooksData[1] = odosCalldata;

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = address(odosHook);

        bytes32[][] memory merkleProofs = new bytes32[][](2);
        merkleProofs[0] = new bytes32[](0); 
        merkleProofs[1] = new bytes32[](0); 

        bytes32 targetLeaf1 = keccak256(bytes.concat(keccak256(abi.encodePacked(address(token)))));
        bytes32 targetLeaf2 = keccak256(bytes.concat(keccak256(abi.encodePacked(address(odosRouter)))));
        bytes32 merkleRoot1 = targetLeaf1;
        bytes32 merkleRoot2 = targetLeaf2;

        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooksAddresses,
            data: hooksData,
            merkleProofs: merkleProofs
        });

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", hooksAddresses[0]),
            abi.encode(merkleRoot1)
        );

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", hooksAddresses[1]),
            abi.encode(merkleRoot2)
        );  

        uint256 inputTokenBalanceBefore = token.balanceOf(address(superBank));
        uint256 upTokenBalanceBefore = up.balanceOf(address(superBank));
        superBank.executeHooks(executionData);
        uint256 inputTokenBalanceAfter = token.balanceOf(address(superBank));
        uint256 upTokenBalanceAfter = up.balanceOf(address(superBank));

        assertGt(inputTokenBalanceBefore, inputTokenBalanceAfter);
        assertGt(upTokenBalanceAfter, upTokenBalanceBefore);
    }
    

    function test_SuperBank_RedeemHookOdos() public {
        vm.startPrank(sGovernor);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
        vm.stopPrank();

        uint256 amount = SMALL;

        //add to vault
        _getTokens(address(token), address(this), amount);
        IERC20(token).approve(address(vault), amount);
        vault.deposit(amount, address(superBank));

        uint256 shares = vault.balanceOf(address(superBank));
        assertGt(shares, 0);

        uint256 superBankTokenBalanceBefore = token.balanceOf(address(superBank));
        assertEq(superBankTokenBalanceBefore, 0);

        Redeem4626VaultHook redeemHook = new Redeem4626VaultHook();


        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(bytes4(0), address(vault), address(superBank), shares, false);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(redeemHook);

        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](0); 

        bytes32 targetLeaf1 = keccak256(bytes.concat(keccak256(abi.encodePacked(address(vault)))));
        bytes32 merkleRoot1 = targetLeaf1;

        IHookExecutionData.HookExecutionData memory executionData = IHookExecutionData.HookExecutionData({
            hooks: hooksAddresses,
            data: hooksData,
            merkleProofs: merkleProofs
        });

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", hooksAddresses[0]),
            abi.encode(merkleRoot1)
        );

        superBank.executeHooks(executionData);
        shares = vault.balanceOf(address(superBank));
        assertEq(shares, 0);

        uint256 superBankTokenBalanceAfter = token.balanceOf(address(superBank));
        assertGt(superBankTokenBalanceAfter, superBankTokenBalanceBefore);
    }

    function test_SuperBank_Across() public {
        uint256 baseForkId = vm.createFork(BASE_RPC_URL);
        uint256 ethForkId = vm.createFork(ETHEREUM_RPC_URL);

        //base is source
        vm.selectFork(baseForkId);
        {
            superGovernor = new SuperGovernor(sGovernor, governor, governor, treasury, address(this));
            superBank = new SuperBank(address(superGovernor));
            up = new Up(admin);
            _getTokens(CHAIN_8453_USDC, address(superBank), uint256(100e6));

            vm.startPrank(sGovernor);
            superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), address(this));
            vm.stopPrank();
        }

        AcrossSendFundsAndExecuteOnDstHook acrossSendFundsAndExecuteOnDstHook = new AcrossSendFundsAndExecuteOnDstHook(CHAIN_8453_SPOKE_POOL_V3_ADDRESS, address(this));

        IHookExecutionData.HookExecutionData memory executionData;
        {
            bytes[] memory hooksData = new bytes[](1);

            address[] memory dstTokens = new address[](1);
            dstTokens[0] = CHAIN_1_USDC;
            uint256[] memory intentAmounts = new uint256[](1);
            intentAmounts[0] = 100e6;
            bytes memory destinationData = abi.encode(bytes("0x123"), bytes("0x123"), address(superBank), dstTokens, intentAmounts);
            hooksData[0] = abi.encodePacked(
                uint256(0),
                address(superBank),
                CHAIN_8453_USDC,
                CHAIN_1_USDC,
                uint256(100e6),
                uint256(100e6),
                uint256(ETH),
                address(0),
                uint32(10 minutes),
                uint32(0),
                false,
                destinationData
            );

            address[] memory hooksAddresses = new address[](1);
            hooksAddresses[0] = address(acrossSendFundsAndExecuteOnDstHook);

            bytes32[][] memory merkleProofs = new bytes32[][](1);
            merkleProofs[0] = new bytes32[](0); 

            bytes32 targetLeaf1 = keccak256(bytes.concat(keccak256(abi.encodePacked(address(CHAIN_8453_SPOKE_POOL_V3_ADDRESS)))));
            bytes32 merkleRoot1 = targetLeaf1;

            executionData = IHookExecutionData.HookExecutionData({
                hooks: hooksAddresses,
                data: hooksData,
                merkleProofs: merkleProofs
            });

            vm.mockCall(
                address(superGovernor),
                abi.encodeWithSignature("getSuperBankHookMerkleRoot(address)", hooksAddresses[0]),
                abi.encode(merkleRoot1)
            );

            vm.startPrank(address(superBank));
            IERC20(CHAIN_8453_USDC).approve(CHAIN_8453_SPOKE_POOL_V3_ADDRESS, 100e6);
            vm.stopPrank();
        }

       
        
        address acrossRelayer = _deployAccount(ACROSS_RELAYER_KEY, "ACROSS_RELAYER");

        vm.recordLogs();
        superBank.executeHooks(executionData);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        acrossV3Helper.help(
            CHAIN_8453_SPOKE_POOL_V3_ADDRESS,
            CHAIN_1_SPOKE_POOL_V3_ADDRESS,
            acrossRelayer,
            30 days,
            ethForkId,
            ETH,
            BASE,
            logs
        );

        //eth is destination
        vm.selectFork(ethForkId);
        uint256 usdcBalanceAfter = IERC20(CHAIN_1_USDC).balanceOf(address(superBank));
        assertEq(usdcBalanceAfter, uint256(100e6));

    }

    function retrieveSignatureData(address) external pure returns (bytes memory) {
        return  "";
    }
}