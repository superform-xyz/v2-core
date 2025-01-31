// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { Helpers } from "../../utils/Helpers.sol";

import { MockSignature } from "../../mocks/MockSignature.sol";

import { MockExecutorModule } from "../../mocks/MockExecutorModule.sol";
import { MockValidatorModule } from "../../mocks/MockValidatorModule.sol";

contract Mock is Helpers, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    function test_WhenIsValid() external pure {
        // it should not revert
        assertTrue(true);
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
        executions[0] = MockSignature.Execution({ to: address(0xdead), value: 1 ether, data: "0x" });

        // test a valid signature
        bytes32 messageHash =
            keccak256(abi.encode(mock.DOMAIN_NAMESPACE(), mock.merkleRoot(), proofs, signer, mock.nonce(), executions));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool isValid = mock.validateSignature(signer, executions, signature);
        assertTrue(isValid);

        // test an invalid signature
        bytes memory invalidSignature =
            hex"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        isValid = mock.validateSignature(signer, executions, invalidSignature);
        assertFalse(isValid);
    }

    function test_MockValidatorModule_notCalled() external {
        MockValidatorModule validator = new MockValidatorModule();
        MockExecutorModule executor = new MockExecutorModule();

        AccountInstance memory instance = makeAccountInstance("MockAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(executor), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "MockAccount");

        uint256 amount = 1e18;
        bytes memory data = abi.encode(amount);

        executor.execute(instance.account, data);
        // validator was not called if executor wasn't triggered through the entry point
        uint256 validatorVal = validator.val();
        assertEq(validatorVal, 0);
    }

    function test_MockValidatorModule_called() external {
        MockValidatorModule validator = new MockValidatorModule();
        MockExecutorModule executor = new MockExecutorModule();

        AccountInstance memory instance = makeAccountInstance("MockAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(executor), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "MockAccount");

        uint256 amount = 1e18;
        bytes memory data = abi.encode(amount);

        // Get exec user ops
        UserOpData memory userOpData = instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeCall(executor.execute, (instance.account, data)),
            txValidator: address(validator)
        });
        userOpData.execUserOps();

        uint256 validatorVal = validator.val();
        assertEq(validatorVal, amount);

        uint256 executorVal = executor.val();
        assertEq(executorVal, amount);
    }
}
