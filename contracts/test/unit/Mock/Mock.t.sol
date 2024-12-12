// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "test/BaseTest.t.sol";

import { MockSignature } from "test/mocks/MockSignature.sol";
import { TransientStorageExecutor } from "test/mocks/TransientStorageExecutor.sol";

contract Mocktsol is BaseTest {
    TransientStorageExecutor transientExecutor;

    function setUp() public override {
        super.setUp();
        transientExecutor = new TransientStorageExecutor();
    }

    function test_WhenIsValid() external pure {
        // it should not revert
        assertTrue(true);
    }

    function test_GasBenchmarkForTransientStorageExecutor() external {
        transientExecutor.execute(abi.encode(1e8));
    }

    function test_GasBenchmarkForTransientStorageExecutorNotTransient() external {
        transientExecutor.executeNotTransient(abi.encode(1e8));
    }

    function test_MockSignature() external {
        MockSignature mock = new MockSignature();

        // create signer
        uint256 signerPrivateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;  
        address signer = vm.addr(signerPrivateKey);

        // simulate signature fields
        mock.setMerkleRoot(0xabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabca);
        bytes32[] memory proofs = new bytes32[](2);
        proofs[0] = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;
        proofs[1] = 0xbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdead;
        mock.setProofs(proofs);

        // simulate parameters
        MockSignature.Execution[] memory executions = new MockSignature.Execution[](1);
        executions[0] = MockSignature.Execution({
            to: address(0xdead),
            value: 1 ether,
            data: "0x"
        });

        // test a valid signature
        bytes32 messageHash = keccak256(
            abi.encode(
                mock.DOMAIN_NAMESPACE(),
                mock.merkleRoot(),
                proofs,
                signer,
                mock.nonce(),
                executions
            )
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool isValid = mock.validateSignature(signer, executions, signature);
        assertTrue(isValid);


        // test an invalid signature
        bytes memory invalidSignature = hex"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        isValid = mock.validateSignature(signer, executions, invalidSignature);
        assertFalse(isValid);
    }
}

