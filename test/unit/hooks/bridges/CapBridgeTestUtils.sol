// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ISuperExecutor } from "../../../../src/interfaces/ISuperExecutor.sol";

/// @dev Cap guard stand-in for the B1 hook family: view no-op validateAllocation (tuples asserted
///      via vm.expectCall) plus the settable destination-transport policy the hooks read.
interface ICapGuardLike {
    function validateAllocation(address strategy, uint64 chainId, address vault, uint256 amount) external view;
}

contract MockCapGuard is ICapGuardLike {
    mapping(uint64 => mapping(address => bool)) public isApprovedAdapter;
    mapping(uint64 => address) internal _approveHook;
    mapping(uint64 => address) internal _depositHook;
    mapping(uint32 => uint64) public chainIdForEid;
    mapping(uint64 => mapping(address => address)) public destinationVaultAsset;
    mapping(address => mapping(uint64 => address)) public stargateDstToken;
    uint256 public stargateMinDeliveryBps;

    function validateAllocation(address, uint64, address, uint256) external view { }

    function setApprovedAdapter(uint64 chainId, address adapter, bool ok) external {
        isApprovedAdapter[chainId][adapter] = ok;
    }

    function setDestinationHooks(uint64 chainId, address approveHook_, address depositHook_) external {
        _approveHook[chainId] = approveHook_;
        _depositHook[chainId] = depositHook_;
    }

    function destinationHooks(uint64 chainId) external view returns (address, address) {
        return (_approveHook[chainId], _depositHook[chainId]);
    }

    function setEidChainId(uint32 eid, uint64 chainId) external {
        chainIdForEid[eid] = chainId;
    }

    function setDestinationVaultAsset(uint64 chainId, address vault, address asset) external {
        destinationVaultAsset[chainId][vault] = asset;
    }

    function setStargateRoute(address srcPool, uint64 chainId, address dstToken) external {
        stargateDstToken[srcPool][chainId] = dstToken;
    }

    function setStargateMinDeliveryBps(uint256 bps) external {
        stargateMinDeliveryBps = bps;
    }
}

/// @dev Records where in-flight exposure landed (keyed by contract instance for migration tests)
///      and mints deterministic reservation ids, mirroring the K1 registry surface.
contract MockPositionRegistry {
    mapping(address => uint256) public bridgedOut;
    mapping(address => mapping(uint64 => uint256)) public bridgedOutByChain;
    address public lastVault;
    bytes32 public lastReservationId;
    uint256 internal _salt;

    function recordBridgedOut(
        address strategy,
        uint64 chainId,
        address destinationVault,
        uint256 amount
    )
        external
        returns (bytes32 reservationId)
    {
        bridgedOut[strategy] += amount;
        bridgedOutByChain[strategy][chainId] += amount;
        lastVault = destinationVault;
        reservationId = keccak256(abi.encode(strategy, chainId, destinationVault, amount, _salt++));
        lastReservationId = reservationId;
    }
}

/// @dev SuperGovernor address book stub: swappable registry pointer to model a governance migration.
contract MockGovernorAddressBook {
    bytes32 private constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 private constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    address public capGuard;
    address public registry;

    constructor(address capGuard_, address registry_) {
        capGuard = capGuard_;
        registry = registry_;
    }

    function setRegistry(address registry_) external {
        registry = registry_;
    }

    function getAddress(bytes32 key) external view returns (address) {
        if (key == CROSS_CHAIN_CAP_GUARD) return capGuard;
        if (key == CROSS_CHAIN_POSITION_REGISTRY) return registry;
        return address(0);
    }
}

/// @dev Minimal prev-hook returning a fixed getOutAmount for the usePrevHookAmount branch.
contract MockPrevHook {
    uint256 private immutable OUT;

    constructor(uint256 out_) {
        OUT = out_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return OUT;
    }
}

/// @dev Builders for the shared 5-tuple destination message
///      abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts)
///      and the strictly typed destination actions the cap hooks accept.
library CapMessageLib {
    /// @dev Destination ApproveERC20Hook data: 52-byte header | token | spender | amount | usePrev.
    function approveHookData(address token, address spender, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(new bytes(52), token, spender, amount, false);
    }

    /// @dev Destination Deposit4626VaultHook data: oracleId(32) | yieldSource | amount | usePrev.
    function depositHookData(address vault, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), vault, amount, true);
    }

    function executorCalldataFor(address[] memory hooks, bytes[] memory hooksData)
        internal
        pure
        returns (bytes memory)
    {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hooksData });
        return abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)));
    }

    function wrap(
        bytes memory executorCalldata,
        address account,
        address token,
        uint256 intentAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = token;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = intentAmount;
        return abi.encode(bytes(""), executorCalldata, account, dstTokens, intentAmounts);
    }

    /// @dev VAULT_DEPOSIT action: exactly [approveHook, depositHook], approve spender == vault,
    ///      approve token == dstTokens[0], approve amount == intentAmounts[0], deposit consumes
    ///      the approve amount (usePrevHookAmount) — the R2-B1 canonical shape.
    function vaultDepositMessage(
        address account,
        address approveHook,
        address depositHook,
        address vault,
        address token,
        uint256 amount
    )
        internal
        pure
        returns (bytes memory)
    {
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = depositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = approveHookData(token, vault, amount);
        hooksData[1] = depositHookData(vault, amount);
        return wrap(executorCalldataFor(hooks, hooksData), account, token, amount);
    }

    /// @dev IDLE_HOLD action: a well-formed execute() with zero hooks.
    function idleHoldMessage(address account, address token, uint256 amount) internal pure returns (bytes memory) {
        return wrap(executorCalldataFor(new address[](0), new bytes[](0)), account, token, amount);
    }
}
