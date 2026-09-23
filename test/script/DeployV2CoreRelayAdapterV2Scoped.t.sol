// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { DeployV2Core } from "../../script/DeployV2Core.s.sol";

/// @dev Exposes the in-memory status the scoped entrypoint must populate.
contract ScopedHarness is DeployV2Core {
    function status(uint64 chainId, string memory name) external view returns (bool isDeployed, address addr) {
        ContractStatus memory s = _getContractStatus(chainId, name);
        return (s.isDeployed, s.contractAddress);
    }

    function checkedNames(uint64 chainId) external view returns (uint256) {
        return _getAllContractNames(chainId).length;
    }
}

/// @dev Stand-in for the already-deployed SuperDestinationExecutor: the adapter constructor reads the
///      validator through it. Immutable so the value survives `vm.etch` of the runtime code.
contract ExecStub {
    address public immutable SUPER_DESTINATION_VALIDATOR;

    constructor(address v) {
        SUPER_DESTINATION_VALIDATOR = v;
    }
}

/// @title DeployV2CoreRelayAdapterV2ScopedTest
/// @notice Regression for PR #1014 review R2-F2 / R2-F3 / R2-F4: `runRelayAdapterV2` must work from a FRESH
///         script instance (empty in-memory status map) by resolving the executor from the chain's output
///         JSON, must record exactly one checked contract (the counts behind the summary line
///         lib_deploy.sh parses), must treat an unconfigured chain as a clean skip, and after deploying must
///         write the adapter into the output JSON while keeping the existing keys.
contract DeployV2CoreRelayAdapterV2ScopedTest is Test {
    uint64 internal constant BASE = 8453;
    uint64 internal constant FLARE = 14; // no Relay depository configured
    uint256 internal constant ENV_STAGING = 2;

    address internal constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    // Arachnid CREATE2 deployer runtime, read from Base
    bytes internal constant DEPLOYER_CODE =
        hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";

    address internal constant EXECUTOR = 0xd0B5d200a6B136D619Dd1c7BBA30b004b4773C40;
    address internal constant VALIDATOR = 0xCA9bB3fcDfB455962ee284A189CbFc2262970b39;
    address internal constant RELAY_ADAPTER_V1 = 0xaf57cEF9EFA4dcEAdDA843C00E02b4F108416361;

    string internal root;
    string internal outputPath;

    function setUp() public {
        vm.etch(DETERMINISTIC_DEPLOYER, DEPLOYER_CODE);
        vm.etch(EXECUTOR, address(new ExecStub(VALIDATOR)).code);
        vm.chainId(BASE);
    }

    /// @dev Isolated project root PER TEST (tests run in parallel; a shared root would be torn down by a
    ///      sibling mid-run), so the real script/output tree is never touched.
    function _useRoot(string memory tag) internal {
        root = string.concat(vm.projectRoot(), "/test/.tmp-scoped-deploy-", tag);
        string memory dir = string.concat(root, "/script/output/staging/", vm.toString(uint256(BASE)));
        vm.createDir(dir, true);
        outputPath = string.concat(dir, "/Base-latest.json");
        vm.writeFile(
            outputPath,
            string.concat(
                '{"RelayAdapter":"',
                vm.toString(RELAY_ADAPTER_V1),
                '","SuperDestinationExecutor":"',
                vm.toString(EXECUTOR),
                '","SuperDestinationValidator":"',
                vm.toString(VALIDATOR),
                '"}'
            )
        );
        vm.setEnv("SUPERFORM_PROJECT_ROOT", root);
        vm.setEnv("CI", "true");
        vm.setEnv("GITHUB_REF_NAME", "staging");
    }

    function tearDown() internal {
        vm.removeDir(root, true);
    }

    /// @notice R2-F2 + R2-F3: a fresh instance's check pass resolves the executor from the output JSON and
    ///         records exactly one checked, not-yet-deployed contract; it writes nothing.
    function test_Scoped_Check_FreshInstance_ResolvesExecutorAndCountsOneContract() public {
        _useRoot("check");
        string memory before = vm.readFile(outputPath);

        ScopedHarness h = new ScopedHarness();
        h.runRelayAdapterV2(true, ENV_STAGING, BASE);

        (bool deployed, address expected) = h.status(BASE, "RelayAdapterV2");
        assertFalse(deployed, "not deployed yet");
        assertTrue(expected != address(0), "CREATE2 address computed");
        assertEq(h.checkedNames(BASE), 1, "exactly one contract checked -> '0 out of 1' summary");
        assertEq(vm.readFile(outputPath), before, "check pass does not touch the output JSON");
        tearDown();
    }

    /// @notice R2-F3: an unconfigured chain is a clean skip, not a revert, with zero checked contracts
    ///         ('0 out of 0' summary).
    function test_Scoped_Check_UnconfiguredChain_SkipsCleanly() public {
        _useRoot("skip");
        vm.chainId(FLARE);
        ScopedHarness h = new ScopedHarness();
        h.runRelayAdapterV2(true, ENV_STAGING, FLARE);
        assertEq(h.checkedNames(FLARE), 0, "nothing checked on a skipped chain");
        tearDown();
    }

    /// @notice R2-F2 + R2-F4: a fresh instance's deploy pass deploys the adapter at the checked address,
    ///         wires it to the executor from the output JSON, and writes the V2 key into the output JSON
    ///         while retaining the executor and V1 adapter keys. A further fresh check then sees it deployed.
    function test_Scoped_Deploy_FreshInstance_DeploysAndWritesOutput() public {
        _useRoot("deploy");
        ScopedHarness check = new ScopedHarness();
        check.runRelayAdapterV2(true, ENV_STAGING, BASE);
        (, address expected) = check.status(BASE, "RelayAdapterV2");

        ScopedHarness deployer = new ScopedHarness();
        deployer.runRelayAdapterV2(false, ENV_STAGING, BASE);

        assertGt(expected.code.length, 0, "adapter deployed at the checked CREATE2 address");

        string memory json = vm.readFile(outputPath);
        assertEq(vm.parseJsonAddress(json, ".RelayAdapterV2"), expected, "V2 key written");
        assertEq(vm.parseJsonAddress(json, ".SuperDestinationExecutor"), EXECUTOR, "executor key retained");
        assertEq(vm.parseJsonAddress(json, ".RelayAdapter"), RELAY_ADAPTER_V1, "V1 adapter key retained");

        ScopedHarness recheck = new ScopedHarness();
        recheck.runRelayAdapterV2(true, ENV_STAGING, BASE);
        (bool deployed,) = recheck.status(BASE, "RelayAdapterV2");
        assertTrue(deployed, "fresh check sees the deployment -> '1 out of 1' summary");
        tearDown();
    }
}
