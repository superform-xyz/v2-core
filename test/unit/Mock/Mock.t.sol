// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { ExecLib } from "modulekit/accounts/kernel/lib/ExecLib.sol";
import { ModeLib, ModeCode } from "modulekit/accounts/common/lib/ModeLib.sol";
import { CallType, ExecType, ExecMode, ExecLib } from "modulekit/accounts/kernel/lib/ExecLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import "modulekit/test/RhinestoneModuleKit.sol";
import { ERC7579Precompiles } from "modulekit/deployment/precompiles/ERC7579Precompiles.sol";
import "modulekit/accounts/erc7579/ERC7579Factory.sol";

import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import { Helpers } from "../../utils/Helpers.sol";

import { MockSignature } from "../../mocks/MockSignature.sol";

import { MockExecutorModule } from "../../mocks/MockExecutorModule.sol";
import { MockValidatorModule } from "../../mocks/MockValidatorModule.sol";

import "forge-std/console2.sol";

contract Mock is Helpers, RhinestoneModuleKit, ERC7579Precompiles {
    using ECDSA for bytes32;
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    uint256 public val;

    ERC7579Factory erc7579factory;
    IERC7579Account erc7579account;

    uint256 eoaKey;
    address account7702;    
    function setUp() public {
        eoaKey = uint256(8);
        account7702 = vm.addr(eoaKey);
        vm.label(account7702, "7702CompliantAccount");
        vm.deal(account7702, LARGE);

        erc7579factory = new ERC7579Factory();

        erc7579account = deployERC7579Account();
        assertGt(address(erc7579account).code.length, 0);
        vm.label(address(erc7579account), "ERC7579Account");
    }

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

    function test_7579call_from_7702_compliant_account() external {
        MockValidatorModule validator = new MockValidatorModule();
        MockExecutorModule executor = new MockExecutorModule();

        // account for 7702 test
        AccountInstance memory instance = makeAccountInstance("MockAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(executor), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "MockAccount");

        // set 7579 code for account7702 EOA
        vm.etch(account7702, instance.account.code);

        uint256 amount = 1e18;
        bytes memory data = abi.encode(amount);

        // Get exec user ops
        UserOpData memory userOpData = instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeCall(executor.execute, (instance.account, data)),
            txValidator: address(validator)
        });

        vm.startPrank(account7702);
        userOpData.execUserOps();
        vm.stopPrank();

        uint256 validatorVal = validator.val();
        assertEq(validatorVal, amount);

        uint256 executorVal = executor.val();
        assertEq(executorVal, amount);  

        // remove 7579 from account7702 EOA
        vm.etch(account7702, "");
    }

    struct Test7579MethodsVars {
        uint256 amount;
        MockValidatorModule validator;
        MockExecutorModule executor;
        AccountInstance instance;
        bytes setValueCalldata;
        bytes userOpCalldata;
        uint192 key;
        uint256 nonce;
        bytes signature;
        PackedUserOperation[] userOps;
        bool success;
        bytes result;
        bool opsSuccess;
        bytes opsResult;
    }
    function _get7702InitData() internal view returns (bytes memory) {
        bytes memory initData = erc7579factory.getInitData(address(_defaultValidator), "");
        return initData;
    }
    function _getDefaultUserOp() internal pure returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }
    function _getSignature(
        PackedUserOperation memory userOp,
        IEntryPoint entrypoint
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 hash = entrypoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaKey, _toEthSignedMessageHash(hash));
        return abi.encodePacked(r, s, v);
    }

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }
    function test_7579methods_on_7702_compliant_account() external {
        Test7579MethodsVars memory vars;
        vars.amount = 1e18;

        // create SCA
        vars.instance = makeAccountInstance("MockAccount");
        vm.label(vars.instance.account, "MockAccount");
        vm.deal(account7702, LARGE);

        bytes memory initData = _get7702InitData(); 

        vars.setValueCalldata = abi.encodeCall(this.setValue, vars.amount);

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: account7702,
            value: 0,
            callData: abi.encodeCall(IMSA.initializeAccount, initData)
        });
        executions[1] = Execution({ target: address(this), value: 0, callData: vars.setValueCalldata });


        vars.userOpCalldata = abi.encodeCall(
            IERC7579Account.execute,
            (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
        );

        vars.key = uint192(bytes24(bytes20(address(_defaultValidator))));
        vars.nonce = vars.instance.aux.entrypoint.getNonce(address(account7702), vars.key);


        // prepare PackedUserOperation
        vars.userOps = new PackedUserOperation[](1);
        vars.userOps[0] = _getDefaultUserOp();
        vars.userOps[0].sender = account7702;
        vars.userOps[0].nonce = vars.nonce;
        vars.userOps[0].callData = vars.userOpCalldata;
        vars.userOps[0].signature = _getSignature(vars.userOps[0], vars.instance.aux.entrypoint);


        vm.etch(account7702, address(erc7579account).code);
        assertGt(account7702.code.length, 0);
        
        vars.instance.aux.entrypoint.handleOps(vars.userOps, payable(address(0x69)));
        assertEq(val, vars.amount);
    }




    function setValue(uint256 value) external {
        val = value;
    }
}
