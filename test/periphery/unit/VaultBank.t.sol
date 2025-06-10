// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { VaultBank } from "../../../src/periphery/VaultBank/VaultBank.sol";
import { VaultBankSuperPosition } from "../../../src/periphery/VaultBank/VaultBankSuperPosition.sol";
import { Bank } from "../../../src/periphery/Bank.sol";
import {
    IVaultBank,
    IVaultBankSource,
    IVaultBankDestination
} from "../../../src/periphery/interfaces/VaultBank/IVaultBank.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockSuperHook } from "../../mocks/MockSuperHook.sol";
import { MockHookTarget } from "../../mocks/MockHookTarget.sol";
import { IHookExecutionData } from "../../../src/periphery/interfaces/IHookExecutionData.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { MockCrossL2ProverV2 } from "../../mocks/MockCrossL2ProverV2.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract TestVaultBank is VaultBank {
    constructor(address governor_) VaultBank(governor_) { }

    function exposed_markAsSyntheticAsset(address spToken) external {
        _spAssetsInfo[spToken].wasCreated = true;
    }

    function exposed_setSuperPositionToToken(address spToken, uint64 srcChainId, address srcTokenAddress) external {
        _spAssetsInfo[spToken].spToToken[srcChainId] = srcTokenAddress;
    }

    function exposed_setTokenToSuperPosition(uint64 srcChainId, address srcTokenAddress, address spToken) external {
        _tokenToSuperPosition[srcChainId][srcTokenAddress] = spToken;
    }

    function exposed_burnSP(address account, address superPosition, uint256 amount) external {
        _burnSP(account, superPosition, amount);
    }

    function exposed_claimRewards(
        address target,
        uint256 gasLimit,
        uint256 value,
        uint16 maxReturnDataCopy,
        bytes calldata data
    )
        external
        returns (bytes memory)
    {
        return _claimRewards(target, gasLimit, value, maxReturnDataCopy, data);
    }

    function exposed_retrieveSuperPosition(
        uint64 srcChainId,
        address srcTokenAddress,
        string calldata name,
        string calldata symbol,
        uint8 decimals
    )
        external
        returns (address)
    {
        return _retrieveSuperPosition(srcChainId, srcTokenAddress, name, symbol, decimals);
    }
}

contract VaultBankTest is Helpers {
    TestVaultBank internal vaultBank;
    SuperGovernor internal superGovernor;
    MockERC20 internal token;
    MockERC20 internal otherToken;
    MockHook internal mockHook;
    MockCrossL2ProverV2 internal mockProver;
    VaultBankSuperPosition internal vaultBankSp;

    uint64 internal constant DST_CHAIN_ID = 10;
    uint64 internal constant CURRENT_CHAIN_ID = 1;

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
        newStrategist = _deployAccount(0xF, "NewStrategist");
        admin = _deployAccount(0xD, "Admin");

        vm.chainId(CURRENT_CHAIN_ID);

        mockProver = new MockCrossL2ProverV2();

        superGovernor = new SuperGovernor(sGovernor, governor, governor, treasury, address(this));
        vaultBank = new TestVaultBank(address(superGovernor));

        vm.startPrank(governor);
        superGovernor.addExecutor(address(this));
        superGovernor.addVaultBank(uint64(block.chainid), address(vaultBank));
        superGovernor.addVaultBank(uint64(DST_CHAIN_ID), address(vaultBank));
        vm.stopPrank();

        bytes32 bankManagerRole = superGovernor.BANK_MANAGER_ROLE();
        address testContractAddress = address(this);
        console.log("Test contract address:", testContractAddress);
        vm.startPrank(sGovernor);
        superGovernor.grantRole(bankManagerRole, testContractAddress);
        vm.stopPrank();

        console.log("Test contract address:", address(this));
        console.log("VaultBank address:", address(vaultBank));

        vm.startPrank(sGovernor);
        superGovernor.setProver(address(mockProver));
        vm.stopPrank();

        token = new MockERC20("Token", "TKN", 18);
        otherToken = new MockERC20("OtherToken", "OTH", 18);

        vaultBankSp = new VaultBankSuperPosition("VaultBankSuperPosition", "VBS", 18);

        mockHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(token));
        vm.prank(sGovernor);
        superGovernor.registerHook(address(mockHook), false);
    }

    function test_lockAsset_Amount0() public {
        token.mint(user, 100 ether);

        vm.startPrank(user);
        token.approve(address(vaultBank), 100 ether);
        vm.stopPrank();

        vm.expectRevert(IVaultBankSource.INVALID_AMOUNT.selector);
        vaultBank.lockAsset(user, address(token), address(mockHook), 0, 1);
    }

    function test_lockAsset_TokenAddress0() public {
        vm.expectRevert(IVaultBankSource.INVALID_TOKEN.selector);
        vaultBank.lockAsset(user, address(0), address(mockHook), 100 ether, 1);
    }

    function test_lockAsset_AccountAddress0() public {
        vm.expectRevert(IVaultBankSource.INVALID_ACCOUNT.selector);
        vaultBank.lockAsset(address(0), address(token), address(mockHook), 100 ether, 1);
    }

    function test_lockAsset_InvalidHook() public {
        vm.expectRevert();
        vaultBank.lockAsset(user, address(token), address(0), 100 ether, 1);
    }

    function test_lockAsset_TokensNotAvailable() public {
        token.mint(address(this), 50 ether);
        token.approve(address(vaultBank), 50 ether);

        vm.expectRevert();
        vaultBank.lockAsset(address(this), address(token), address(mockHook), 100 ether, 1);
    }

    function test_lockAsset_Success() public {
        token.mint(user, 100 ether);

        vm.startPrank(user);
        token.approve(address(vaultBank), 100 ether);
        vm.stopPrank();

        uint64 destinationChainId = 10;
        uint256 lockAmount = 50 ether;

        uint256 expectedNonce = vaultBank.nonces(destinationChainId);

        vm.expectEmit(true, true, false, true);
        emit IVaultBankSource.SharesLocked(
            user, address(token), lockAmount, uint64(block.chainid), destinationChainId, expectedNonce
        );

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, destinationChainId);

        assertEq(vaultBank.nonces(destinationChainId), expectedNonce + 1, "Nonce not incremented");
        assertEq(vaultBank.viewTotalLockedAsset(address(token)), lockAmount, "Total locked amount incorrect");
        assertEq(vaultBank.viewAllLockedAssets().length, 1, "Locked assets length incorrect");
        assertEq(vaultBank.viewAllLockedAssets()[0], address(token), "Token not in locked assets");
        assertEq(token.balanceOf(address(vaultBank)), lockAmount, "VaultBank balance incorrect");
        assertEq(token.balanceOf(user), 50 ether, "User balance incorrect");
    }

    function test_unlockAsset_InvalidProofChain() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setValidateEventReturn(
            uint32(DST_CHAIN_ID + 1), // Invalid chain ID
            address(vaultBank),
            new bytes(0),
            new bytes(0)
        );

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBank.INVALID_PROOF_CHAIN.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidProofEmitter() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(0xdead), new bytes(0), new bytes(0));

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBank.INVALID_PROOF_EMITTER.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidProofEvent() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        bytes memory invalidTopics = new bytes(128);
        bytes32 invalidEventSelector = bytes32(uint256(0x12345678));
        assembly {
            mstore(add(invalidTopics, 32), invalidEventSelector)
        }

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), invalidTopics, new bytes(0));

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBank.INVALID_PROOF_EVENT.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidProofToken() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        MockERC20 token2 = new MockERC20("Token2", "TKN2", 18);

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user,
            address(token2), // different token
            lockAmount,
            CURRENT_CHAIN_ID,
            0,
            uint32(DST_CHAIN_ID)
        );

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBank.INVALID_PROOF_TOKEN.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidProofAmount() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setValidateEventReturn(
            uint32(DST_CHAIN_ID), address(vaultBank), new bytes(128), abi.encode(lockAmount - 1, CURRENT_CHAIN_ID, 0)
        );

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user, address(token), lockAmount - 1, CURRENT_CHAIN_ID, 0, uint32(DST_CHAIN_ID)
        );

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBank.INVALID_PROOF_AMOUNT.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidProofTargetedChain() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setValidateEventReturn(
            uint32(DST_CHAIN_ID), address(vaultBank), new bytes(128), abi.encode(lockAmount, CURRENT_CHAIN_ID + 1, 0)
        );

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user, address(token), lockAmount, CURRENT_CHAIN_ID + 1, 0, uint32(DST_CHAIN_ID)
        );

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBank.INVALID_PROOF_TARGETED_CHAIN.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidProofNonce() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user, address(token), lockAmount / 2, CURRENT_CHAIN_ID, 0, uint32(DST_CHAIN_ID)
        );

        bytes memory mockProof = new bytes(0);

        vaultBank.unlockAsset(user, address(token), lockAmount / 2, DST_CHAIN_ID, mockProof);

        vm.expectRevert(IVaultBank.NONCE_ALREADY_USED.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount / 2, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidAccount() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            address(0), address(token), lockAmount, CURRENT_CHAIN_ID, 0, uint32(DST_CHAIN_ID)
        );

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBankSource.INVALID_ACCOUNT.selector);
        vaultBank.unlockAsset(address(0), address(token), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidToken() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user, address(0), lockAmount, CURRENT_CHAIN_ID, 0, uint32(DST_CHAIN_ID)
        );

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBankSource.INVALID_TOKEN.selector);
        vaultBank.unlockAsset(user, address(0), lockAmount, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_InvalidAmount() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(user, address(token), 0, CURRENT_CHAIN_ID, 0, uint32(DST_CHAIN_ID));

        bytes memory mockProof = new bytes(0);

        vm.expectRevert(IVaultBankSource.INVALID_AMOUNT.selector);
        vaultBank.unlockAsset(user, address(token), 0, DST_CHAIN_ID, mockProof);

        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user, address(token), lockAmount * 2, CURRENT_CHAIN_ID, 1, uint32(DST_CHAIN_ID)
        );

        vm.expectRevert(IVaultBankSource.INVALID_AMOUNT.selector);
        vaultBank.unlockAsset(user, address(token), lockAmount * 2, DST_CHAIN_ID, mockProof);
    }

    function test_unlockAsset_Success() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        assertEq(token.balanceOf(user), 0, "Initial user balance incorrect");
        assertEq(token.balanceOf(address(vaultBank)), lockAmount, "Initial vault balance incorrect");

        uint256 unlockAmount = lockAmount / 2;
        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user, address(token), unlockAmount, CURRENT_CHAIN_ID, 0, uint32(DST_CHAIN_ID)
        );

        bytes memory mockProof = new bytes(0);

        uint256 expectedNonce = vaultBank.nonces(CURRENT_CHAIN_ID);

        vm.expectEmit(true, true, false, true);
        emit IVaultBankSource.SharesUnlocked(
            user, address(token), unlockAmount, CURRENT_CHAIN_ID, DST_CHAIN_ID, expectedNonce
        );

        vaultBank.unlockAsset(user, address(token), unlockAmount, DST_CHAIN_ID, mockProof);

        assertEq(vaultBank.nonces(CURRENT_CHAIN_ID), expectedNonce + 1, "Nonce not incremented");
        assertEq(token.balanceOf(user), unlockAmount, "User balance after unlock incorrect");
        assertEq(token.balanceOf(address(vaultBank)), lockAmount - unlockAmount, "Vault balance after unlock incorrect");
        assertEq(
            vaultBank.viewTotalLockedAsset(address(token)),
            lockAmount - unlockAmount,
            "Total locked amount after unlock incorrect"
        );
    }

    function test_unlockAsset_Success_WithSP_Transfer() public {
        address account = address(0xAcc3);
        uint256 amount = 75 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        address existingSPAddress = address(0xe5000000000000000000000000000000000000e5);

        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature(
                "_retrieveSuperPosition(uint64,address,string,string,uint8)",
                DST_CHAIN_ID,
                address(token),
                "Test Token",
                "TT",
                18
            ),
            abi.encode(existingSPAddress)
        );

        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature("_mintSP(address,address,uint256)", account, existingSPAddress, amount),
            abi.encode()
        );

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);

        assertEq(vaultBank.nonces(uint64(block.chainid)), 1, "Nonce should be incremented");
        assertTrue(vaultBank.noncesUsed(DST_CHAIN_ID, 0), "Proof nonce should be marked as used");

        address user2 = vm.addr(0x100);

        vm.startPrank(account);
        IERC20(0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2).transfer(user2, amount);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(vaultBank), amount);
        vm.stopPrank();

        uint256 lockAmount = 75 ether;
        token.mint(user2, lockAmount);

        vm.startPrank(user2);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user2, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        assertEq(token.balanceOf(user2), 0, "Initial user balance incorrect");
        assertEq(token.balanceOf(address(vaultBank)), lockAmount, "Initial vault balance incorrect");

        uint256 unlockAmount = lockAmount / 2;
        mockProver.setEmittingContract(address(vaultBank));
        mockProver.mockSuperpositionsBurnedEvent(
            user2, address(token), unlockAmount, CURRENT_CHAIN_ID, 2, uint32(DST_CHAIN_ID)
        );

        vm.expectEmit(true, true, false, true);
        emit IVaultBankSource.SharesUnlocked(user2, address(token), unlockAmount, CURRENT_CHAIN_ID, DST_CHAIN_ID, 1);

        vaultBank.unlockAsset(user2, address(token), unlockAmount, DST_CHAIN_ID, mockProof);

        assertEq(vaultBank.nonces(CURRENT_CHAIN_ID), 2, "Nonce not incremented");
        assertEq(token.balanceOf(user2), unlockAmount, "User balance after unlock incorrect");
        assertEq(token.balanceOf(address(vaultBank)), lockAmount - unlockAmount, "Vault balance after unlock incorrect");
        assertEq(
            vaultBank.viewTotalLockedAsset(address(token)),
            lockAmount - unlockAmount,
            "Total locked amount after unlock incorrect"
        );
    }

    function test_distributeSuperPosition_InvalidProofEmitter() public {
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        address invalidEmitter = address(0x123);
        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), invalidEmitter, mockTopics, mockUnindexedData);

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vm.expectRevert(IVaultBank.INVALID_PROOF_EMITTER.selector);
        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);
    }

    function test_distributeSuperPosition_InvalidProofEvent() public {
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes32 invalidEventSelector = bytes32(uint256(0x12345678));
        bytes memory mockTopics = abi.encodePacked(
            invalidEventSelector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vm.expectRevert(IVaultBank.INVALID_PROOF_EVENT.selector);
        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);
    }

    function test_distributeSuperPosition_InvalidProofToken() public {
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        address wrongToken = address(0x0000000000000000000000000000000000BaD123);
        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(wrongToken))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vm.expectRevert(IVaultBank.INVALID_PROOF_TOKEN.selector);
        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);
    }

    function test_distributeSuperPosition_InvalidProofAmount() public {
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        uint256 wrongAmount = 200 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(wrongAmount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vm.expectRevert(IVaultBank.INVALID_PROOF_AMOUNT.selector);
        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);
    }

    function test_distributeSuperPosition_Success() public {
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        address superPositionAddress = address(0x5000000000000000000000000000000000000001);
        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature(
                "_retrieveSuperPosition(uint64,address,string,string,uint8)",
                DST_CHAIN_ID,
                address(token),
                "Test Token",
                "TT",
                18
            ),
            abi.encode(superPositionAddress)
        );

        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature("_mintSP(address,address,uint256)", account, superPositionAddress, amount),
            abi.encode()
        );

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);

        assertEq(vaultBank.nonces(uint64(block.chainid)), 1, "Nonce should be incremented");
        assertTrue(vaultBank.noncesUsed(DST_CHAIN_ID, 0), "Proof nonce should be marked as used");
    }

    function test_distributeSuperPosition_InvalidProofSourceChain() public {
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        uint64 invalidSourceChain = DST_CHAIN_ID + 1;
        bytes memory mockUnindexedData = abi.encode(amount, invalidSourceChain, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vm.expectRevert(IVaultBank.INVALID_PROOF_SOURCE_CHAIN.selector);
        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);
    }

    function test_distributeSuperPosition_InvalidProofTargetedChain() public {
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        uint64 invalidTargetChain = uint64(block.chainid) + 1;
        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, invalidTargetChain, uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vm.expectRevert(IVaultBank.INVALID_PROOF_TARGETED_CHAIN.selector);
        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);
    }

    function test_distributeSuperPosition_InvalidProofNonce() public {
        // Set up tst data
        address account = address(0xaCC1000000000000000000000000000000000001);
        uint256 amount = 100 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        address superPositionAddress = address(0x5000000000000000000000000000000000000001);
        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature(
                "_retrieveSuperPosition(uint64,address,string,string,uint8)",
                DST_CHAIN_ID,
                address(token),
                "Test Token",
                "TT",
                18
            ),
            abi.encode(superPositionAddress)
        );

        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature("_mintSP(address,address,uint256)", account, superPositionAddress, amount),
            abi.encode()
        );

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);

        assertTrue(vaultBank.noncesUsed(DST_CHAIN_ID, 0), "Proof nonce should be marked as used");

        vm.expectRevert(IVaultBank.NONCE_ALREADY_USED.selector);
        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);
    }

    function test_distributeSuperPosition_Success_DifferentSenderEmissions() public {
        address account = address(0x5000000000000000000000000000000000000001);
        uint256 amount = 50 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        address superPositionAddress = address(0x5000000000000000000000000000000000000002);
        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature(
                "_retrieveSuperPosition(uint64,address,string,string,uint8)",
                DST_CHAIN_ID,
                address(token),
                "Test Token",
                "TT",
                18
            ),
            abi.encode(superPositionAddress)
        );

        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature("_mintSP(address,address,uint256)", account, superPositionAddress, amount),
            abi.encode()
        );

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);

        assertEq(vaultBank.nonces(uint64(block.chainid)), 1, "Nonce should be incremented");
        assertTrue(vaultBank.noncesUsed(DST_CHAIN_ID, 0), "Proof nonce should be marked as used");
    }

    function test_distributeSuperPosition_Success_ExistingTokenToSuperposition() public {
        address account = address(0xAcc3);
        uint256 amount = 75 ether;
        IVaultBank.SourceAssetInfo memory sourceAsset = IVaultBank.SourceAssetInfo({
            asset: address(token),
            name: "Test Token",
            symbol: "TT",
            decimals: 18,
            chainId: DST_CHAIN_ID
        });

        bytes memory mockTopics = abi.encodePacked(
            IVaultBankSource.SharesLocked.selector,
            keccak256(abi.encodePacked(account)),
            bytes32(0),
            keccak256(abi.encodePacked(address(token)))
        );

        bytes memory mockUnindexedData = abi.encode(amount, DST_CHAIN_ID, uint64(block.chainid), uint256(0));

        bytes memory mockProof = abi.encode("mock proof data");

        mockProver.setValidateEventReturn(uint32(DST_CHAIN_ID), address(vaultBank), mockTopics, mockUnindexedData);

        address existingSPAddress = address(0xe5000000000000000000000000000000000000e5);

        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature(
                "_retrieveSuperPosition(uint64,address,string,string,uint8)",
                DST_CHAIN_ID,
                address(token),
                "Test Token",
                "TT",
                18
            ),
            abi.encode(existingSPAddress)
        );

        vm.mockCall(
            address(vaultBank),
            abi.encodeWithSignature("_mintSP(address,address,uint256)", account, existingSPAddress, amount),
            abi.encode()
        );

        vm.startPrank(governor);
        superGovernor.addRelayer(address(this));
        vm.stopPrank();

        vaultBank.distributeSuperPosition(account, amount, sourceAsset, mockProof);

        assertEq(vaultBank.nonces(uint64(block.chainid)), 1, "Nonce should be incremented");
        assertTrue(vaultBank.noncesUsed(DST_CHAIN_ID, 0), "Proof nonce should be marked as used");
    }

    function test_burnSuperPositions_SuperPositionNotFound() public {
        address nonExistentSP = address(0xdeadbeef);
        uint256 amount = 1e18;
        uint64 forChainId = 1;

        vm.mockCall(address(vaultBank), abi.encodeWithSignature("_spAssets(address)", nonExistentSP), abi.encode(false));

        vm.expectRevert(IVaultBankDestination.SUPERPOSITION_ASSET_NOT_FOUND.selector);
        vaultBank.burnSuperPosition(amount, nonExistentSP, forChainId);
    }

    function test_burnSuperPositions_InvalidBurnAmount() public {
        address validSP = address(0x1234);
        address underlyingToken = address(0x5678);
        uint256 userBalance = 5e18;
        uint256 burnAmount = 10e18;
        uint64 forChainId = 1;

        vm.etch(validSP, new bytes(0x1000));

        vaultBank.exposed_markAsSyntheticAsset(validSP);

        vaultBank.exposed_setSuperPositionToToken(validSP, forChainId, underlyingToken);
        vaultBank.exposed_setTokenToSuperPosition(forChainId, underlyingToken, validSP);

        vm.mockCall(validSP, abi.encodeWithSignature("balanceOf(address)", address(this)), abi.encode(userBalance));

        vm.expectRevert(IVaultBankDestination.INVALID_BURN_AMOUNT.selector);
        vaultBank.burnSuperPosition(burnAmount, validSP, forChainId);
    }

    function test_burnSuperPositions_Success() public {
        address validSP = address(0x1234);
        address underlyingToken = address(0x5678);
        uint256 userBalance = 10e18;
        uint256 burnAmount = 5e18;
        uint64 forChainId = 1;

        vm.etch(validSP, new bytes(0x1000));

        vaultBank.exposed_markAsSyntheticAsset(validSP);

        vaultBank.exposed_setSuperPositionToToken(validSP, forChainId, underlyingToken);
        vaultBank.exposed_setTokenToSuperPosition(forChainId, underlyingToken, validSP);

        vm.mockCall(validSP, abi.encodeWithSignature("balanceOf(address)", address(this)), abi.encode(userBalance));

        vm.mockCall(validSP, abi.encodeWithSignature("burn(address,uint256)", address(this), burnAmount), abi.encode());

        bytes32 nonceSlot = keccak256(abi.encode(address(this), uint256(forChainId), uint256(0)));
        vm.store(address(vaultBank), nonceSlot, bytes32(uint256(0)));

        vm.expectEmit(true, true, true, true, address(vaultBank));
        emit IVaultBank.SuperpositionsBurned(
            address(this), // account
            validSP, // spAddress
            underlyingToken, // token address
            burnAmount, // amount
            forChainId, // chain ID
            0 // nonce
        );

        vaultBank.burnSuperPosition(burnAmount, validSP, forChainId);

        assertEq(vaultBank.nonces(forChainId), 1, "Nonce should be incremented");
    }

    function test_executeHooks_ZeroLengthArray() public {
        address[] memory hooks = new address[](0);
        bytes[] memory data = new bytes[](0);
        bytes32[][] memory merkleProofs = new bytes32[][](0);

        IHookExecutionData.HookExecutionData memory executionData =
            IHookExecutionData.HookExecutionData({ hooks: hooks, data: data, merkleProofs: merkleProofs });

        vm.startPrank(address(this));
        vm.expectRevert(Bank.ZERO_LENGTH_ARRAY.selector);
        vaultBank.executeHooks(executionData);
        vm.stopPrank();
    }

    function test_executeHooks_InvalidArrayLength() public {
        vm.startPrank(address(this));

        address[] memory hooks = new address[](2);
        hooks[0] = address(0x1111);
        hooks[1] = address(0x2222);

        bytes[] memory data = new bytes[](1);
        data[0] = "data1";

        bytes32[][] memory merkleProofs = new bytes32[][](2);
        merkleProofs[0] = new bytes32[](1);
        merkleProofs[1] = new bytes32[](1);

        IHookExecutionData.HookExecutionData memory executionData =
            IHookExecutionData.HookExecutionData({ hooks: hooks, data: data, merkleProofs: merkleProofs });

        vm.expectRevert(Bank.INVALID_ARRAY_LENGTH.selector);
        vaultBank.executeHooks(executionData);
        vm.stopPrank();
    }

    function test_executeHooks_InvalidMerkleProof() public {
        console.log("VaultBank address:", address(vaultBank));
        console.log("Test contract address (this):", address(this));
        console.log(
            "This has BANK_MANAGER_ROLE:", superGovernor.hasRole(superGovernor.BANK_MANAGER_ROLE(), address(this))
        );

        vm.startPrank(address(this));

        MockHookTarget mockTarget = new MockHookTarget();

        address[] memory hooks = new address[](1);
        hooks[0] = address(mockHook);

        bytes[] memory data = new bytes[](1);
        data[0] = "data1";

        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](1);
        merkleProofs[0][0] = bytes32(uint256(1));

        IHookExecutionData.HookExecutionData memory executionData =
            IHookExecutionData.HookExecutionData({ hooks: hooks, data: data, merkleProofs: merkleProofs });

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getVaultBankHookMerkleRoot(address)", address(mockHook)),
            abi.encode(bytes32(uint256(2)))
        );

        vm.expectRevert(Bank.INVALID_MERKLE_PROOF.selector);
        vaultBank.executeHooks(executionData);
        vm.stopPrank();
    }

    function test_executeHooks_HookExecutionFailed() public {
        MockHookTarget mockTarget = new MockHookTarget();
        mockTarget.setShouldFailExecution(true); // Set to fail during execution
        mockTarget.setShouldFailExecution(true);

        bytes32 targetLeaf = keccak256(bytes.concat(keccak256(abi.encodePacked(address(mockTarget)))));
        bytes32 merkleRoot = targetLeaf;

        address[] memory hooks = new address[](1);
        hooks[0] = address(mockHook);

        bytes[] memory data = new bytes[](1);
        data[0] = "data1";

        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](0);

        IHookExecutionData.HookExecutionData memory executionData =
            IHookExecutionData.HookExecutionData({ hooks: hooks, data: data, merkleProofs: merkleProofs });

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getVaultBankHookMerkleRoot(address)", address(mockHook)),
            abi.encode(merkleRoot)
        );

        vm.startPrank(address(this));
        vm.expectRevert(Bank.HOOK_EXECUTION_FAILED.selector);
        vaultBank.executeHooks(executionData);
        vm.stopPrank();
    }

    function test_executeHooks_Success() public {
        vm.startPrank(address(this));

        MockHookTarget mockTarget = new MockHookTarget();

        bytes32 targetLeaf = keccak256(bytes.concat(keccak256(abi.encodePacked(address(mockTarget)))));
        bytes32 merkleRoot = targetLeaf;

        address[] memory hooks = new address[](1);
        hooks[0] = address(mockHook);

        bytes[] memory data = new bytes[](1);
        data[0] = "data1";

        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](0);

        IHookExecutionData.HookExecutionData memory executionData =
            IHookExecutionData.HookExecutionData({ hooks: hooks, data: data, merkleProofs: merkleProofs });

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getVaultBankHookMerkleRoot(address)", address(mockHook)),
            abi.encode(merkleRoot)
        );

        vm.expectEmit(true, true, true, true, address(mockHook));
        emit MockSuperHook.PreExecuteCalled(address(0), address(vaultBank), "data1");

        vm.expectEmit(true, true, false, false, address(mockTarget));
        emit MockHookTarget.Executed();

        vm.expectEmit(true, true, true, true, address(mockHook));
        emit MockSuperHook.PostExecuteCalled(address(0), address(vaultBank), "data1");

        vm.expectEmit(true, true, true, true, address(vaultBank));
        emit Bank.HooksExecuted(hooks, data);

        vaultBank.executeHooks(executionData);
        vm.stopPrank();
    }

    function test_executeHooks_MultipleHooks() public {
        vm.startPrank(address(this));

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

        IHookExecutionData.HookExecutionData memory executionData =
            IHookExecutionData.HookExecutionData({ hooks: hooks, data: data, merkleProofs: merkleProofs });

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getVaultBankHookMerkleRoot(address)", address(mockHook1)),
            abi.encode(merkleRoot1)
        );

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getVaultBankHookMerkleRoot(address)", address(mockHook2)),
            abi.encode(merkleRoot2)
        );

        vaultBank.executeHooks(executionData);
        vm.stopPrank();
    }

    function test_constructor() public {
        address newGovernor = address(0xABCD);
        VaultBank newVaultBank = new VaultBank(newGovernor);

        assertEq(
            address(newVaultBank.SUPER_GOVERNOR()),
            newGovernor,
            "SUPER_GOVERNOR should be set to the provided governor address"
        );

        vm.expectRevert(IVaultBank.INVALID_VALUE.selector);
        new VaultBank(address(0));
    }

    function test_viewTotalLockedAsset() public {
        uint256 lockAmount1 = 100 ether;
        uint256 lockAmount2 = 50 ether;
        token.mint(user, lockAmount1 + lockAmount2);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount1 + lockAmount2);
        vm.stopPrank();

        assertEq(vaultBank.viewTotalLockedAsset(address(token)), 0, "Initial total locked amount should be 0");

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount1, DST_CHAIN_ID);

        assertEq(
            vaultBank.viewTotalLockedAsset(address(token)),
            lockAmount1,
            "Total locked amount should match sum of all locks"
        );
    }

    function test_viewAllLockedAssets() public {
        uint256 lockAmount = 100 ether;
        token.mint(user, lockAmount);

        vm.startPrank(user);
        token.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        address[] memory initialAssets = vaultBank.viewAllLockedAssets();
        assertEq(initialAssets.length, 0, "Initial locked assets array should be empty");

        vaultBank.lockAsset(user, address(token), address(mockHook), lockAmount, DST_CHAIN_ID);

        address[] memory assets = vaultBank.viewAllLockedAssets();
        assertEq(assets.length, 1, "Locked assets array should have one entry");
        assertEq(assets[0], address(token), "Locked asset should match the token address");

        MockERC20 token2 = new MockERC20("Token2", "TKN2", 18);
        token2.mint(user, lockAmount);

        vm.startPrank(user);
        token2.approve(address(vaultBank), lockAmount);
        vm.stopPrank();

        vaultBank.lockAsset(user, address(token2), address(mockHook), lockAmount, DST_CHAIN_ID);

        address[] memory assetsAfterSecondLock = vaultBank.viewAllLockedAssets();
        assertEq(assetsAfterSecondLock.length, 2, "Locked assets array should have two entries");

        bool foundToken1 = false;
        bool foundToken2 = false;

        for (uint256 i = 0; i < assetsAfterSecondLock.length; i++) {
            if (assetsAfterSecondLock[i] == address(token)) {
                foundToken1 = true;
            } else if (assetsAfterSecondLock[i] == address(token2)) {
                foundToken2 = true;
            }
        }

        assertTrue(foundToken1, "First token should be in the locked assets array");
        assertTrue(foundToken2, "Second token should be in the locked assets array");
    }

    function test_receive() public {
        uint256 initialBalance = address(vaultBank).balance;
        uint256 amount = 1 ether;

        vm.deal(user, amount);

        vm.startPrank(user);
        (bool success,) = address(vaultBank).call{ value: amount }("");
        vm.stopPrank();

        assertTrue(success, "VaultBank should receive ETH");
        assertEq(
            address(vaultBank).balance, initialBalance + amount, "VaultBank balance should increase by the sent amount"
        );
    }

    function test_getSuperPositionForAsset() public {
        address mockSuperPosition = address(0x1234);
        address mockToken = address(0x5678);
        uint64 mockChainId = 5;

        assertEq(
            vaultBank.getSuperPositionForAsset(mockChainId, mockToken),
            address(0),
            "Should return zero address initially"
        );

        vaultBank.exposed_setTokenToSuperPosition(mockChainId, mockToken, mockSuperPosition);

        assertEq(
            vaultBank.getSuperPositionForAsset(mockChainId, mockToken),
            mockSuperPosition,
            "Should return correct super position address"
        );
    }

    function test_getAssetForSuperPosition() public {
        address mockSuperPosition = address(0x1234);
        address mockToken = address(0x5678);
        uint64 mockChainId = 5;

        assertEq(
            vaultBank.getAssetForSuperPosition(mockChainId, mockSuperPosition),
            address(0),
            "Should return zero address initially"
        );

        vaultBank.exposed_setSuperPositionToToken(mockSuperPosition, mockChainId, mockToken);

        assertEq(
            vaultBank.getAssetForSuperPosition(mockChainId, mockSuperPosition),
            mockToken,
            "Should return correct token address"
        );
    }

    function test_isSuperPositionCreated() public {
        address mockSuperPosition = address(0x1234);

        assertFalse(vaultBank.isSuperPositionCreated(mockSuperPosition), "Should return false initially");

        vaultBank.exposed_markAsSyntheticAsset(mockSuperPosition);

        assertTrue(
            vaultBank.isSuperPositionCreated(mockSuperPosition), "Should return true after marking as synthetic asset"
        );
    }

    function test_claimRewards_InvalidTarget() public {
        address mockTarget = address(0);
        uint256 gasLimit = 100_000;
        uint256 value = 0;
        uint16 maxReturnDataCopy = 256;
        bytes memory data = "";

        vm.expectRevert(IVaultBankSource.INVALID_CLAIM_TARGET.selector);
        vm.prank(address(this));
        vaultBank.exposed_claimRewards(mockTarget, gasLimit, value, maxReturnDataCopy, data);

        vm.expectRevert(IVaultBankSource.INVALID_CLAIM_TARGET.selector);
        vm.prank(address(this));
        vaultBank.exposed_claimRewards(address(vaultBank), gasLimit, value, maxReturnDataCopy, data);
    }

    function test_claimRewards_FailedCall() public {
        MockHookTarget mockTarget = new MockHookTarget();
        mockTarget.setShouldFailExecution(true);

        uint256 gasLimit = 100_000;
        uint256 value = 0;
        uint16 maxReturnDataCopy = 256;
        bytes memory data = abi.encodeWithSignature("execute()");

        vm.expectRevert(IVaultBankSource.CLAIM_FAILED.selector);
        vm.prank(address(this));
        vaultBank.exposed_claimRewards(address(mockTarget), gasLimit, value, maxReturnDataCopy, data);
    }

    function test_claimRewards_Success() public {
        MockHookTarget mockTarget = new MockHookTarget();
        mockTarget.setShouldFailExecution(false);

        uint256 gasLimit = 100_000;
        uint256 value = 0;
        uint16 maxReturnDataCopy = 256;
        bytes memory data = abi.encodeWithSignature("execute()");

        vm.prank(address(this));
        bytes memory result =
            vaultBank.exposed_claimRewards(address(mockTarget), gasLimit, value, maxReturnDataCopy, data);

        assertTrue(result.length == 0, "Result should be empty for a successful call that doesn't return data");
    }

    function test_retrieveSuperPosition_ExistingSP() public {
        address existingSPAddress = address(0x1234);
        address mockToken = address(0x5678);
        uint64 mockChainId = 5;

        vaultBank.exposed_setTokenToSuperPosition(mockChainId, mockToken, existingSPAddress);

        address retrievedSP = vaultBank.exposed_retrieveSuperPosition(mockChainId, mockToken, "Token", "TKN", 18);

        assertEq(retrievedSP, existingSPAddress, "Should return existing super position address");
    }

    function test_retrieveSuperPosition_NewSP() public {
        address mockToken = address(0x9ABC);
        uint64 mockChainId = 6;
        string memory name = "New Token";
        string memory symbol = "NTKN";
        uint8 decimals = 18;

        address retrievedSP = vaultBank.exposed_retrieveSuperPosition(mockChainId, mockToken, name, symbol, decimals);

        assertFalse(retrievedSP == address(0), "Should not return zero address");
        assertTrue(vaultBank.isSuperPositionCreated(retrievedSP), "Should mark new SP as created");
        assertEq(
            vaultBank.getSuperPositionForAsset(mockChainId, mockToken), retrievedSP, "Should set token to SP mapping"
        );
        assertEq(
            vaultBank.getAssetForSuperPosition(mockChainId, retrievedSP), mockToken, "Should set SP to token mapping"
        );
    }

    function test_batchDistributeRewardsToSuperBank() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(otherToken);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 50 ether;

        address mockSuperBank = address(0x9999);

        token.mint(address(vaultBank), amounts[0]);
        otherToken.mint(address(vaultBank), amounts[1]);

        vm.mockCall(
            address(superGovernor), abi.encodeWithSignature("isSuperBank(address)", mockSuperBank), abi.encode(true)
        );

        vm.mockCall(
            address(superGovernor), abi.encodeWithSignature("isRelayer(address)", address(this)), abi.encode(true)
        );

        vm.mockCall(
            address(superGovernor),
            abi.encodeWithSignature("getAddress(bytes32)", keccak256("SUPER_BANK")),
            abi.encode(mockSuperBank)
        );

        uint256 initialTokenBalance = token.balanceOf(mockSuperBank);
        uint256 initialOtherTokenBalance = otherToken.balanceOf(mockSuperBank);

        vaultBank.batchDistributeRewardsToSuperBank(tokens, amounts);

        assertEq(
            token.balanceOf(mockSuperBank),
            initialTokenBalance + amounts[0],
            "Token reward amount should be distributed to SuperBank"
        );
        assertEq(
            otherToken.balanceOf(mockSuperBank),
            initialOtherTokenBalance + amounts[1],
            "Other token reward amount should be distributed to SuperBank"
        );
    }

    function test_VaultBankSuperPositions_constructor() public view {
        assertEq(vaultBankSp.decimals(), 18);
        assertEq(vaultBankSp.owner(), address(this));
    }

    function test_VaultBankSuperPositions_mint() public {
        vaultBankSp.mint(address(this), 100 ether);
        assertEq(vaultBankSp.balanceOf(address(this)), 100 ether);
    }

    function test_VaultBankSuperPositions_burn() public {
        vaultBankSp.mint(address(this), 100 ether);
        vaultBankSp.burn(address(this), 100 ether);
        assertEq(vaultBankSp.balanceOf(address(this)), 0);
    }

    function test_transferSuperPositionOwnership_OnlyBankManager() public {
        // Test that only bank manager can call this function
        VaultBankSuperPosition testSP = new VaultBankSuperPosition("TestSP", "TSP", 18);
        address newOwner = address(0x9999);

        // Verify current owner
        assertEq(testSP.owner(), address(this), "Initial owner should be test contract");

        // Try calling from non-bank manager (should fail)
        vm.startPrank(user);
        vm.expectRevert(IVaultBank.INVALID_BANK_MANAGER.selector);
        vaultBank.transferSuperPositionOwnership(address(testSP), newOwner);
        vm.stopPrank();

        // Verify ownership hasn't changed
        assertEq(testSP.owner(), address(this), "Owner should not have changed");
    }

    function test_transferSuperPositionOwnership_Success() public {
        // Test successful ownership transfer by bank manager
        address mockToken = address(0x9ABC);
        uint64 mockChainId = 6;
        string memory name = "New Token";
        string memory symbol = "NTKN";
        uint8 decimals = 18;

        address testSP = vaultBank.exposed_retrieveSuperPosition(mockChainId, mockToken, name, symbol, decimals);
        address newOwner = address(0x9999);

        // Call from bank manager (address(this) has BANK_MANAGER_ROLE)
        vaultBank.transferSuperPositionOwnership(address(testSP), newOwner);

        vm.prank(newOwner);
        VaultBankSuperPosition(testSP).acceptOwnership();

        // Verify ownership has changed
        assertEq(VaultBankSuperPosition(testSP).owner(), newOwner, "Owner should have changed to new owner");
    }

    function test_transferSuperPositionOwnership_ZeroAddress() public {
        // Test with zero address as new owner
        VaultBankSuperPosition testSP = new VaultBankSuperPosition("TestSP", "TSP", 18);

        // This should revert due to OpenZeppelin's Ownable constraints
        vm.expectRevert();
        vaultBank.transferSuperPositionOwnership(address(testSP), address(0));
    }

    function test_transferSuperPositionOwnership_InvalidSuperPosition() public {
        // Test with invalid super position address
        address invalidSP = address(0x1111);
        address newOwner = address(0x9999);

        // This should revert when trying to call transferOwnership on a non-contract
        vm.expectRevert();
        vaultBank.transferSuperPositionOwnership(invalidSP, newOwner);
    }
}
