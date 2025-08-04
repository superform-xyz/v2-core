// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { UserOpData, AccountInstance, Execution, ExecutionLib, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ISafeConfiguration } from "../../../src/vendor/gnosis/ISafeConfiguration.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperExecutorBase } from "../../../src/executors/SuperExecutorBase.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";

contract SafeAccountExecution is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    function setUp() public override {
        super.setUp();
    }

    function test_SafeAccount_SignatureValidation() public {
        // TODO: Implement test
    }
}
