// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ModeCode } from "modulekit/accounts/common/lib/ModeLib.sol";

import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

abstract contract DestinationSimulationTestBase is Test {
    function _assertAndPatchImmutableReferences(
        bytes memory runtime,
        uint256[2] memory offsets,
        address value
    )
        internal
        pure
    {
        bytes32 encodedValue = bytes32(uint256(uint160(value)));

        for (uint256 i; i < offsets.length; ++i) {
            uint256 offset = offsets[i];
            assertLe(offset + 32, runtime.length, "immutable reference exceeds runtime");

            bytes32 placeholder;
            assembly ("memory-safe") {
                placeholder := mload(add(add(runtime, 0x20), offset))
            }
            assertEq(placeholder, bytes32(0), "immutable reference placeholder is not zero");

            assembly ("memory-safe") {
                mstore(add(add(runtime, 0x20), offset), encodedValue)
            }
        }
    }

    function _signatureData(
        address account,
        address executor,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        bytes memory executorCalldata,
        uint64 chainId,
        bytes32 merkleRoot
    )
        internal
        pure
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory dstProofs = new ISuperValidator.DstProof[](1);
        dstProofs[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: executor,
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: address(0xFACE),
                data: executorCalldata
            })
        });

        uint64[] memory destinationChains = new uint64[](1);
        destinationChains[0] = chainId;

        return abi.encode(
            destinationChains,
            uint48(type(uint48).max),
            uint48(0),
            merkleRoot,
            new bytes32[](0),
            dstProofs,
            new bytes(65)
        );
    }

    function _singleAddress(address value) internal pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = value;
    }

    function _singleUint(uint256 value) internal pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }
}

contract RecordingDestinationExecutor is ISuperDestinationExecutor {
    error MOCK_EXECUTION_REVERTED();

    bool public shouldRevert;
    uint256 public callCount;
    bytes32 public lastCallHash;

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function processBridgedExecution(
        address tokenSent,
        address targetAccount,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external
    {
        if (shouldRevert) revert MOCK_EXECUTION_REVERTED();

        ++callCount;
        lastCallHash = keccak256(
            abi.encode(
                tokenSent, targetAccount, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData
            )
        );
    }

    function isMerkleRootUsed(address, bytes32) external pure returns (bool) {
        return false;
    }

    function markRootsAsUsed(bytes32[] memory) external { }
}

contract RejectingEIP1271Owner {
    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return 0xffffffff;
    }
}

contract RecordingERC7579Account {
    error MOCK_ACCOUNT_EXECUTION_REVERTED();

    bool public shouldRevert;
    uint256 public callCount;

    receive() external payable { }

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function executeFromExecutor(ModeCode, bytes calldata) external returns (bytes[] memory returnData) {
        if (shouldRevert) revert MOCK_ACCOUNT_EXECUTION_REVERTED();
        ++callCount;
        returnData = new bytes[](1);
    }
}

contract SimulationStargatePool {
    address private immutable TOKEN;

    constructor(address token_) {
        TOKEN = token_;
    }

    function token() external view returns (address) {
        return TOKEN;
    }
}

contract SimulationTokenMessaging {
    mapping(address pool => uint16 assetId) public assetIds;

    function setAssetId(address pool, uint16 assetId) external {
        assetIds[pool] = assetId;
    }
}
