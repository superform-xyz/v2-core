// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { console2 } from "forge-std/console2.sol";

import { ISuperExecutor } from "../../../../src/core/interfaces/ISuperExecutor.sol";
import "../../../mocks/benchmarking/GasBenchmarkingSignatureStorage.sol";
import "../../../mocks/benchmarking/ExecutorSimulator.sol";
import "./GasBenchmarkingSignatureHelper.sol";

contract GasBenchmarkingSignatureStorageTest is GasBenchmarkingSignatureHelper {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;


    GasBenchmarkingSignatureStorage public benchmarker;
    ExecutorSimulator public executor;
    AccountInstance public instance;
    address public account;
    address public underlying;
    address public validatorSigner;
    uint256 public validatorSignerPrivateKey;

    struct Info {
        uint256 hookIndex;
        uint128 startBytes;
        uint128 endBytes;
    }


    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);
        instance = accountInstances[ETH];
        account = accountInstances[ETH].account;
        underlying = existingUnderlyingTokens[1][USDC_KEY];
        validatorSigner = validatorSigners[ETH];
        validatorSignerPrivateKey = validatorSignerPrivateKeys[ETH];

        benchmarker = new GasBenchmarkingSignatureStorage(bytes32(uint256(123456789)));
        executor = new ExecutorSimulator(address(benchmarker), address(0));
    }

    function testBenchmarkSignature_WithStorage() public {
        uint256 amount = 1e6;

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes memory targetExecutorMessage;
        {
            address[] memory dstHookAddresses = new address[](0);
            bytes[] memory dstHookData = new bytes[](0);

            TargetExecutorMessage memory messageData = TargetExecutorMessage({
                hooksAddresses: dstHookAddresses,
                hooksData: dstHookData,
                validator: address(this),
                signer: validatorSigner,
                signerPrivateKey: validatorSignerPrivateKey,
                targetAdapter: address(this),
                targetExecutor: address(this),
                nexusFactory: CHAIN_1_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                chainId: uint64(ETH),
                amount: amount,
                account: address(0),
                tokenSent: underlying
            });

            (targetExecutorMessage, ) = _createTargetExecutorMessage(messageData);
        }
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] =
            _createApproveHookData(underlying, SPOKE_POOL_V3_ADDRESSES[ETH], amount, false);
        hooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlying, underlying, amount, amount, ETH, true, targetExecutorMessage
        );
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory srcUserOpData = instance.getExecOps(
            address(executor), 0, abi.encodeWithSelector(ISuperExecutor.execute.selector, entryToExecute), address(this)
        );

        uint256 timestamp = block.timestamp;
        (bytes memory sigData,,) = _createMerkleTree(benchmarker.leafHash(), timestamp, "GasBenchmarkingSignatureStorage", validatorSigner, validatorSignerPrivateKey);
        srcUserOpData.userOp.signature = sigData;

        /**
        struct UserOpData {
            PackedUserOperation userOp;
            bytes32 userOpHash;
            IEntryPoint entrypoint;
        }
        */

        uint256 gasBefore = gasleft();
        executor.executeWithStorage(srcUserOpData.userOp);
        uint256 gasAfter = gasleft();
        console2.log("Gas used by storage option:", gasBefore - gasAfter);
    }

    function namespace() external view returns (string memory) {
        return "GasBenchmarkingSignatureStorageTest";
    }
}