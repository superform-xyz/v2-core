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

contract CCTPScopedHarness is DeployV2Core {
    function status(uint64 chainId, string memory name) external view returns (bool isDeployed, address addr) {
        ContractStatus memory s = _getContractStatus(chainId, name);
        return (s.isDeployed, s.contractAddress);
    }

    function checkedNames(uint64 chainId) external view returns (uint256) {
        return _getAllContractNames(chainId).length;
    }

    function usdc(uint64 chainId) external view returns (address) {
        return configuration.usdcs[chainId];
    }
}

contract MessengerStub {
    address public immutable localMinter;
    address public immutable localMessageTransmitter;

    constructor(address m, address t) {
        localMinter = m;
        localMessageTransmitter = t;
    }
}

/// @dev Stand-in for the live GatewayMinter proxy: the deploy sanity check and the adapter constructor both call
///      `isTokenSupported(usdc)`.
contract GatewayMinterStub {
    address public immutable usdc;

    constructor(address u) {
        usdc = u;
    }

    function isTokenSupported(address token) external view returns (bool) {
        return token == usdc;
    }
}

contract MinterStub {
    address public immutable localUsdc;

    constructor(address u) {
        localUsdc = u;
    }

    function getLocalToken(uint32, bytes32) external view returns (address) {
        return localUsdc;
    }
}

/// @title DeployV2CoreScopedEntrypointsTest
/// @notice Fresh-instance regressions for the scoped deploy entrypoints (`runRelayAdapterV2`, `runCCTPAdapter`,
///         `runCircleGatewayAdapter`):
///         check resolves the executor from the output JSON and counts one contract, an unconfigured chain skips
///         cleanly, deploy lands at the checked CREATE2 address and writes its key while keeping the existing ones,
///         and a further fresh check sees it deployed.
/// @dev ONE test function on purpose: the entrypoints locate the output JSON via SUPERFORM_PROJECT_ROOT, which
///      `vm.setEnv` sets PROCESS-WIDE — separate tests or test contracts race on it under forge's parallel runner
///      (observed twice). Scenarios therefore run sequentially in a single test.
contract DeployV2CoreScopedEntrypointsTest is Test {
    uint64 internal constant BASE = 8453;
    uint64 internal constant FLARE = 14; // neither a Relay depository nor CCTP V2 config
    uint256 internal constant ENV_STAGING = 2;

    address internal constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    // Arachnid CREATE2 deployer runtime, read from Base with `cast code`
    bytes internal constant DEPLOYER_CODE =
        hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";

    address internal constant TRANSMITTER = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;
    address internal constant MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address internal constant MINTER = 0xfd78EE919681417d192449715b2594ab58f5D002;
    address internal constant GATEWAY_MINTER = 0x2222222d7164433c4C09B0b0D809a9b52C04C205;
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

    function test_ScopedEntrypoints_FreshInstances_Relay_Then_CCTP_Then_Gateway() public {
        _relayScenario();
        _cctpScenario();
        _gatewayScenario();
    }

    /// @notice R2-F2 / R2-F3 / R2-F4 in ONE sequential test. `vm.setEnv` is process-global, so separate tests
    ///         sharing SUPERFORM_PROJECT_ROOT race each other under forge's parallel runner (observed: the deploy
    ///         test reading the check test's fixture root). Sequencing the scenarios removes the race.
    function _relayScenario() internal {
        _useRoot("scoped");
        string memory before = vm.readFile(outputPath);

        // 1. check pass from a fresh instance: executor resolved from the output JSON, exactly one contract
        //    checked (-> "0 out of 1"), nothing written
        ScopedHarness check = new ScopedHarness();
        check.runRelayAdapterV2(true, ENV_STAGING, BASE);
        (bool deployed, address expected) = check.status(BASE, "RelayAdapterV2");
        assertFalse(deployed, "not deployed yet");
        assertTrue(expected != address(0), "CREATE2 address computed");
        assertEq(check.checkedNames(BASE), 1, "exactly one contract checked");
        assertEq(vm.readFile(outputPath), before, "check pass does not touch the output JSON");

        // 2. unconfigured chain: clean skip, zero checked (-> "0 out of 0")
        vm.chainId(FLARE);
        ScopedHarness skip = new ScopedHarness();
        skip.runRelayAdapterV2(true, ENV_STAGING, FLARE);
        assertEq(skip.checkedNames(FLARE), 0, "nothing checked on a skipped chain");
        vm.chainId(BASE);

        // 3. deploy pass from a fresh instance: lands at the checked address, writes the V2 key, keeps the rest
        ScopedHarness deployer = new ScopedHarness();
        deployer.runRelayAdapterV2(false, ENV_STAGING, BASE);
        assertGt(expected.code.length, 0, "adapter deployed at the checked CREATE2 address");
        string memory json = vm.readFile(outputPath);
        assertEq(vm.parseJsonAddress(json, ".RelayAdapterV2"), expected, "V2 key written");
        assertEq(vm.parseJsonAddress(json, ".SuperDestinationExecutor"), EXECUTOR, "executor key retained");
        assertEq(vm.parseJsonAddress(json, ".RelayAdapter"), RELAY_ADAPTER_V1, "V1 adapter key retained");

        // 4. a further fresh check sees the deployment (-> "1 out of 1")
        ScopedHarness recheck = new ScopedHarness();
        recheck.runRelayAdapterV2(true, ENV_STAGING, BASE);
        (deployed,) = recheck.status(BASE, "RelayAdapterV2");
        assertTrue(deployed, "fresh check sees the deployment");
        tearDown();
    }

    /// @notice `runCircleGatewayAdapter`: same four steps as the CCTP scenario against a GatewayMinter stub.
    function _gatewayScenario() internal {
        root = string.concat(vm.projectRoot(), "/test/.tmp-scoped-deploy-gateway");
        string memory dir = string.concat(root, "/script/output/staging/", vm.toString(uint256(BASE)));
        vm.createDir(dir, true);
        outputPath = string.concat(dir, "/Base-latest.json");
        vm.writeFile(
            outputPath,
            string.concat(
                '{"CCTPAdapter":"',
                vm.toString(address(0xCC7)),
                '","SuperDestinationExecutor":"',
                vm.toString(EXECUTOR),
                '"}'
            )
        );
        vm.setEnv("SUPERFORM_PROJECT_ROOT", root);
        vm.setEnv("CI", "true");
        vm.setEnv("GITHUB_REF_NAME", "staging");
        vm.etch(DETERMINISTIC_DEPLOYER, DEPLOYER_CODE);
        vm.etch(EXECUTOR, address(new ExecStub(VALIDATOR)).code);
        vm.chainId(BASE);

        string memory before = vm.readFile(outputPath);

        // 1. fresh check: executor from the output JSON, exactly one contract checked, nothing written
        CCTPScopedHarness check = new CCTPScopedHarness();
        check.runCircleGatewayAdapter(true, ENV_STAGING, BASE);
        (bool deployed, address expected) = check.status(BASE, "CircleGatewayAdapter");
        assertFalse(deployed, "not deployed yet");
        assertTrue(expected != address(0), "CREATE2 address computed");
        assertEq(check.checkedNames(BASE), 1, "exactly one contract checked");
        assertEq(vm.readFile(outputPath), before, "check pass does not touch the output JSON");

        // 2. unconfigured chain: clean skip
        vm.chainId(FLARE);
        CCTPScopedHarness skip = new CCTPScopedHarness();
        skip.runCircleGatewayAdapter(true, ENV_STAGING, FLARE);
        assertEq(skip.checkedNames(FLARE), 0, "nothing checked on a skipped chain");
        vm.chainId(BASE);

        // 3. fresh deploy: the minter stub satisfies the sanity check and the adapter constructor
        vm.etch(GATEWAY_MINTER, address(new GatewayMinterStub(check.usdc(BASE))).code);
        CCTPScopedHarness deployer = new CCTPScopedHarness();
        deployer.runCircleGatewayAdapter(false, ENV_STAGING, BASE);
        assertGt(expected.code.length, 0, "adapter deployed at the checked CREATE2 address");
        string memory json = vm.readFile(outputPath);
        assertEq(vm.parseJsonAddress(json, ".CircleGatewayAdapter"), expected, "CircleGatewayAdapter key written");
        assertEq(vm.parseJsonAddress(json, ".SuperDestinationExecutor"), EXECUTOR, "executor key retained");
        assertEq(vm.parseJsonAddress(json, ".CCTPAdapter"), address(0xCC7), "CCTP key retained");

        // 4. a further fresh check sees the deployment
        CCTPScopedHarness recheck = new CCTPScopedHarness();
        recheck.runCircleGatewayAdapter(true, ENV_STAGING, BASE);
        (deployed,) = recheck.status(BASE, "CircleGatewayAdapter");
        assertTrue(deployed, "fresh check sees the deployment");

        vm.removeDir(root, true);
    }

    function _cctpScenario() internal {
        // --- fixture: isolated output root + Circle/executor stubs on a plain local chain ---
        root = string.concat(vm.projectRoot(), "/test/.tmp-scoped-deploy-cctp");
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
                '"}'
            )
        );
        vm.setEnv("SUPERFORM_PROJECT_ROOT", root);
        vm.setEnv("CI", "true");
        vm.setEnv("GITHUB_REF_NAME", "staging");
        vm.etch(DETERMINISTIC_DEPLOYER, DEPLOYER_CODE);
        vm.etch(EXECUTOR, address(new ExecStub(VALIDATOR)).code);
        vm.chainId(BASE);

        string memory before = vm.readFile(outputPath);

        // 1. fresh check: executor from the output JSON, exactly one contract checked, nothing written
        CCTPScopedHarness check = new CCTPScopedHarness();
        check.runCCTPAdapter(true, ENV_STAGING, BASE);
        (bool deployed, address expected) = check.status(BASE, "CCTPAdapter");
        assertFalse(deployed, "not deployed yet");
        assertTrue(expected != address(0), "CREATE2 address computed");
        assertEq(check.checkedNames(BASE), 1, "exactly one contract checked");
        assertEq(vm.readFile(outputPath), before, "check pass does not touch the output JSON");

        // 2. unconfigured chain: clean skip
        vm.chainId(FLARE);
        CCTPScopedHarness skip = new CCTPScopedHarness();
        skip.runCCTPAdapter(true, ENV_STAGING, FLARE);
        assertEq(skip.checkedNames(FLARE), 0, "nothing checked on a skipped chain");
        vm.chainId(BASE);

        // 3. fresh deploy: Circle stubs satisfy the sanity checks and the adapter constructor
        vm.etch(MINTER, address(new MinterStub(check.usdc(BASE))).code);
        vm.etch(MESSENGER, address(new MessengerStub(MINTER, TRANSMITTER)).code);
        CCTPScopedHarness deployer = new CCTPScopedHarness();
        deployer.runCCTPAdapter(false, ENV_STAGING, BASE);
        assertGt(expected.code.length, 0, "adapter deployed at the checked CREATE2 address");
        string memory json = vm.readFile(outputPath);
        assertEq(vm.parseJsonAddress(json, ".CCTPAdapter"), expected, "CCTPAdapter key written");
        assertEq(vm.parseJsonAddress(json, ".SuperDestinationExecutor"), EXECUTOR, "executor key retained");
        assertEq(vm.parseJsonAddress(json, ".RelayAdapter"), RELAY_ADAPTER_V1, "V1 relay key retained");

        // 4. a further fresh check sees the deployment
        CCTPScopedHarness recheck = new CCTPScopedHarness();
        recheck.runCCTPAdapter(true, ENV_STAGING, BASE);
        (deployed,) = recheck.status(BASE, "CCTPAdapter");
        assertTrue(deployed, "fresh check sees the deployment");

        vm.removeDir(root, true);
    }
}
