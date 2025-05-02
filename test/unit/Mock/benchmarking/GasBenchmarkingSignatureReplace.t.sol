// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { console2 } from "forge-std/console2.sol";

import { ISuperExecutor } from "../../../../src/core/interfaces/ISuperExecutor.sol";
import "../../../mocks/benchmarking/GasBenchmarkingSignatureReplace.sol";
import "../../../mocks/benchmarking/ExecutorSimulator.sol";
import "./GasBenchmarkingSignatureHelper.sol";

contract GasBenchmarkingSignatureReplaceTest is GasBenchmarkingSignatureHelper {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    GasBenchmarkingSignatureReplace public benchmarker;
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

        benchmarker = new GasBenchmarkingSignatureReplace(bytes32(uint256(123456789)));
        executor = new ExecutorSimulator(address(0), address(benchmarker));
    }

    function testBenchmarkSignature_WithReplace() public {
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

        // append sigData + the other extra fields to the calldata
        bytes memory originalData = srcUserOpData.userOp.callData;
        console2.log("original data length", originalData.length);
        console2.log("signature data length", sigData.length);
        // [ initial data | Info[] (48 * N bytes) | Signature | InfoLength (32 bytes) | SignatureLength (32 bytes) ]

        Info memory info = Info({
            hookIndex: 0x01, // can be removed
            startBytes: 100,
            endBytes: uint128(100 + sigData.length)
        });
        bytes memory infoBytes = abi.encodePacked(uint256(info.hookIndex), bytes16(uint128(info.startBytes)), bytes16(uint128(info.endBytes)));
        uint256 infoLen = infoBytes.length;
        assertEq(infoLen, 64, "info is not ok");

        bytes memory fullData = bytes.concat(
            originalData,
            infoBytes,
            sigData,
            abi.encodePacked(uint256(infoLen)),
            abi.encodePacked(uint256(sigData.length))
        );
        console2.log("full data length", fullData.length);

        srcUserOpData.userOp.callData = fullData;
        uint256 gasBefore = gasleft();
        executor.executeWithReplace(srcUserOpData.userOp);
        uint256 gasAfter = gasleft();
        console2.log("Gas used by replace option:", gasBefore - gasAfter);
    }

    function namespace() external view returns (string memory) {
        return "GasBenchmarkingSignatureReplaceTest";
    }
}