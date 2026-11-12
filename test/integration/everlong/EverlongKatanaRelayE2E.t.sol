// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Vm } from "forge-std/Vm.sol";

// Superform
import { SwapEverlongHook } from "../../../src/hooks/swappers/everlong/SwapEverlongHook.sol";
import { ApproveAndSwapEverlongHook } from "../../../src/hooks/swappers/everlong/ApproveAndSwapEverlongHook.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { RelayAdapterV2 } from "../../../src/adapters/RelayAdapterV2.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { INexusFactory } from "../../../src/vendor/nexus/INexusFactory.sol";
import { NexusBootstrap, BootstrapConfig, BootstrapPreValidationHookConfig } from "@nexus/utils/NexusBootstrap.sol";

import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { EverlongKatanaFixtures } from "./EverlongKatanaFixtures.sol";

/// @title EverlongKatanaRelayE2E
/// @author Superform Labs
/// @notice Bridge -> Everlong destination swap on Katana through the production stack: a Relay solver's fill is
///         modelled exactly as on mainnet (funds delivered to the PRODUCTION `RelayAdapterV2`, then its permissionless
///         `processRelayExecution`), the production `SuperSenderCreator` + Nexus factory create the user's account from
///         `initData`, the production `SuperDestinationValidator` checks the owner's signature and the production
///         `SuperDestinationExecutor` runs the new Everlong hooks against the live router / liquidity with the
/// UNMODIFIED Everlong Swap API calldata. NOTE: the API fixes the multicall deadline at quote + 600 s, so a real bridge
///         fill slower than that reverts 'Transaction too old' (funds rest in the account; see the hook-floor test).
/// @dev Production addresses are read from `script/output/prod/747474/Katana-latest.json` and cross-checked on the
///      fork (`SUPER_DESTINATION_EXECUTOR()` / `SUPER_DESTINATION_VALIDATOR()` of the adapter). Runs against
///      KATANA_RPC_URL (default public RPC) at the pinned fixture block; skips without connectivity; excluded from
///      `ftest-ci`.
contract EverlongKatanaRelayE2E is MerkleTreeHelper, EverlongKatanaFixtures {
    // ─── Production Katana deployment (script/output/prod/747474/Katana-latest.json)
    // ────────────────────────
    address internal constant PROD_RELAY_ADAPTER_V2 = 0x85071489810C560D66112fEc6f236ec6f30E9cF4;
    address internal constant PROD_DST_EXECUTOR = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF;
    address internal constant PROD_DST_VALIDATOR = 0xADEFF5A0684392C4c273a9C638d1dB8c5dfd0098;
    address internal constant PROD_SENDER_CREATOR = 0xBC6FB94D2f10A3B4349F592FFA80C4B7C97C1799;
    address internal constant PROD_NEXUS_FACTORY = 0x4153Db38136E74a88A77b51a955A88823820C050;
    address internal constant PROD_NEXUS_BOOTSTRAP = 0x5eBeb4d51723bA345080D81bBF178D93E84bC9BE;

    uint48 internal constant VALID_UNTIL = type(uint48).max;

    RelayAdapterV2 internal adapter = RelayAdapterV2(payable(PROD_RELAY_ADAPTER_V2));
    SuperDestinationExecutor internal executor = SuperDestinationExecutor(PROD_DST_EXECUTOR);
    SuperDestinationValidator internal validator = SuperDestinationValidator(PROD_DST_VALIDATOR);

    SwapEverlongHook internal swapHook;
    ApproveAndSwapEverlongHook internal approveHook;
    ApproveERC20Hook internal approveErc20Hook;

    address internal owner;
    uint256 internal ownerPk;
    address internal solver = makeAddr("relay-solver");
    bool internal forked;
    uint256 internal saltNonce;
    uint256 internal prodExecutorUsdcAtSetup;

    receive() external payable { }

    function setUp() public {
        string memory rpc = envOr("KATANA_RPC_URL", "https://rpc.katana.network");
        if (bytes(rpc).length == 0) return;
        try vm.createSelectFork(rpc, KATANA_BLOCK) {
            forked = true;
        } catch {
            return;
        }

        (owner, ownerPk) = makeAddrAndKey("katanaUserEverlong");
        swapHook = new SwapEverlongHook(EVERLONG_ROUTER, WETH9, NATIVE);
        approveHook = new ApproveAndSwapEverlongHook(EVERLONG_ROUTER, WETH9, NATIVE);
        approveErc20Hook = new ApproveERC20Hook();
        vm.deal(solver, 100 ether);
        prodExecutorUsdcAtSetup = IERC20(VB_USDC).balanceOf(PROD_DST_EXECUTOR);
    }

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }

    /*//////////////////////////////////////////////////////////////
                          PRODUCTION WIRING SANITY
    //////////////////////////////////////////////////////////////*/

    function test_ProdWiring_AdapterPointsAtProdExecutorAndValidator() public {
        _requireFork();
        assertGt(PROD_RELAY_ADAPTER_V2.code.length, 0, "RelayAdapterV2 live");
        assertEq(address(adapter.SUPER_DESTINATION_EXECUTOR()), PROD_DST_EXECUTOR, "adapter -> prod executor");
        assertEq(adapter.SUPER_DESTINATION_VALIDATOR(), PROD_DST_VALIDATOR, "adapter -> prod validator");
        assertEq(executor.SUPER_DESTINATION_VALIDATOR(), PROD_DST_VALIDATOR, "executor -> prod validator");
        assertGt(PROD_SENDER_CREATOR.code.length, 0, "sender creator live");
        assertGt(PROD_NEXUS_FACTORY.code.length, 0, "nexus factory live");
        assertGt(PROD_NEXUS_BOOTSTRAP.code.length, 0, "nexus bootstrap live");
    }

    /*//////////////////////////////////////////////////////////////
                    BRIDGE (RELAY) -> SUSHISWAP ON KATANA
    //////////////////////////////////////////////////////////////*/

    /// @notice First-time user, approve variant, flag off: the Relay fill creates the Nexus account through the
    ///         production factory, the signed intent runs `ApproveAndSwapEverlongHook`, KAT lands in the brand-new
    ///         account, the root is consumed, the adapter holds nothing.
    function test_Relay_FirstTimeAccount_ApproveAndSwap_FlagOff() public {
        _requireFork();
        uint256 fill = QUOTE_USDC_KAT_IN;
        (bytes memory initData, address account) = _nexusInitData();
        assertEq(account.code.length, 0, "account does not exist before the fill");

        bytes memory cd = _executorCalldata1(address(approveHook), _usdcKatData(account, false));
        (bytes memory message, bytes32 root) = _signedMessage(initData, account, cd, VB_USDC, fill);

        deal(VB_USDC, address(adapter), fill); // Relay solver's funds-delivery leg
        uint256 feeBefore = IERC20(KAT).balanceOf(FEE_RECIPIENT);
        vm.recordLogs();
        vm.prank(solver);
        uint256 gasBefore = gasleft();
        adapter.processRelayExecution(VB_USDC, fill, message); // solver's execution leg
        uint256 gasUsed = gasBefore - gasleft();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertLt(gasUsed, KATANA_PER_TX_GAS_CAP, "account creation + swap fit under Katana's per-tx gas cap");
        assertGt(account.code.length, 0, "Nexus account created via production SuperSenderCreator");
        assertEq(IERC20(VB_USDC).balanceOf(address(adapter)), 0, "adapter forwarded everything");
        assertEq(IERC20(VB_USDC).balanceOf(account), 0, "bridged input fully swapped");
        uint256 out = IERC20(KAT).balanceOf(account);
        uint256 fee = IERC20(KAT).balanceOf(FEE_RECIPIENT) - feeBefore;
        assertEq(fee, (out + fee) * FEE_BIPS / 10_000, "4 bps fee identity through the production stack");
        assertGe(out, HEADER_MIN_USDC_KAT, "output reached the new account");
        assertEq(IERC20(VB_USDC).allowance(account, EVERLONG_ROUTER), 0, "allowance reset");
        assertTrue(executor.isMerkleRootUsed(account, root), "root consumed on the production executor");
        _assertNoExecutionFailed(logs);
        _assertNoDustOnHooks();
    }

    /// @notice The bundler's destination shape: the fill is 95% of the quote (fees), the approve hook is trimmed
    ///         to the delivered amount, the swap header + payload stay at the original quote with the flag on. The
    ///         production executor runs `[ApproveERC20Hook, SwapEverlongHook]` and the hook rescales both heads.
    function test_Relay_FirstTimeAccount_ApproveHook_PlusPlainSwap_FlagOn_Below95() public {
        _requireFork();
        uint256 fill = QUOTE_USDC_KAT_IN * 95 / 100;
        (bytes memory initData, address account) = _nexusInitData();

        bytes memory cd = _executorCalldata2(
            address(approveErc20Hook), _approveData(fill), address(swapHook), _usdcKatData(account, true)
        );
        (bytes memory message, bytes32 root) = _signedMessage(initData, account, cd, VB_USDC, fill);

        deal(VB_USDC, address(adapter), fill);
        vm.recordLogs();
        vm.prank(solver);
        adapter.processRelayExecution(VB_USDC, fill, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(VB_USDC).balanceOf(account), 0, "exactly the delivered amount was swapped");
        uint256 out = IERC20(KAT).balanceOf(account);
        assertGe(out, Math.mulDiv(HEADER_MIN_USDC_KAT, 95, 100, Math.Rounding.Ceil), "scaled floor");
        assertEq(IERC20(VB_USDC).allowance(account, EVERLONG_ROUTER), 0, "predecessor allowance consumed");
        assertTrue(executor.isMerkleRootUsed(account, root));
        _assertNoExecutionFailed(logs);
        _assertNoDustOnHooks();
    }

    /// @notice Over-delivered fill (105%) with the approve variant and the flag on, into an account that already
    ///         exists (second intent for the same user): no initData, the executor reuses the account.
    function test_Relay_ExistingAccount_ApproveAndSwap_FlagOn_Above105() public {
        _requireFork();
        (bytes memory initData, address account) = _nexusInitData();
        _createAccountDirectly(initData, account);

        uint256 fill = QUOTE_USDC_KAT_IN * 105 / 100;
        bytes memory cd = _executorCalldata2(
            address(approveErc20Hook), _approveData(fill), address(approveHook), _usdcKatData(account, true)
        );
        (bytes memory message, bytes32 root) = _signedMessage(bytes(""), account, cd, VB_USDC, fill);

        deal(VB_USDC, address(adapter), fill);
        vm.recordLogs();
        vm.prank(solver);
        adapter.processRelayExecution(VB_USDC, fill, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(VB_USDC).balanceOf(account), 0);
        uint256 out = IERC20(KAT).balanceOf(account);
        assertGe(out, Math.mulDiv(HEADER_MIN_USDC_KAT, 105, 100, Math.Rounding.Ceil), "scaled floor");
        assertGt(out, QUOTE_USDC_KAT_OUT, "more delivered, more output");
        assertTrue(executor.isMerkleRootUsed(account, root));
        _assertNoExecutionFailed(logs);
        _assertNoDustOnHooks();
    }

    /// @notice Native fill: Relay delivers ETH (`tokenSent == address(0)`, value attached), the intent names
    ///         `address(0)`, and the native-input swap forwards exactly the delivered value into vbUSDC.
    function test_Relay_NativeFill_NativeInputSwap() public {
        _requireFork();
        uint256 fill = QUOTE_NATIVE_USDC_IN;
        (bytes memory initData, address account) = _nexusInitData();

        bytes memory data = _hookData(
            NATIVE,
            VB_USDC,
            QUOTE_NATIVE_USDC_IN,
            QUOTE_NATIVE_USDC_OUT,
            HEADER_MIN_NATIVE_USDC,
            false,
            _withRecipient(TX_NATIVE_IN_USDC, TAIL_RECIPIENT_OFFSET_NATIVE_USDC, account)
        );
        bytes memory cd = _executorCalldata1(address(approveHook), data);
        (bytes memory message, bytes32 root) = _signedMessage(initData, account, cd, address(0), fill);

        vm.recordLogs();
        vm.prank(solver);
        adapter.processRelayExecution{ value: fill }(address(0), fill, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(address(adapter).balance, 0, "adapter forwarded the value");
        assertEq(account.balance, 0, "the whole fill went into the swap");
        assertGe(IERC20(VB_USDC).balanceOf(account), HEADER_MIN_NATIVE_USDC, "vbUSDC reached the account");
        assertTrue(executor.isMerkleRootUsed(account, root));
        _assertNoExecutionFailed(logs);
        _assertNoDustOnHooks();
    }

    /// @notice Native fill at 90% of the quote, resized through the OMS path (`replaceCalldataAmounts`, flag OFF) and
    ///         signed at that size. Native `usePrevHookAmount` chaining is covered on the same chain by
    ///         `EverlongKatanaFork.test_RoundTrip_*` / `test_NativeIn_Chained90_PlainVariant`.
    function test_Relay_NativeFill_Resized90_ViaReplaceCalldataAmounts() public {
        _requireFork();
        uint256 fill = QUOTE_NATIVE_USDC_IN * 90 / 100;
        (bytes memory initData, address account) = _nexusInitData();

        // There is no ERC20-approve predecessor for a native fill, so the known fill is sized the way the OMS does
        // it: the quoted header + payload are resized together through `replaceCalldataAmounts` (header amount,
        // quote, min and the four embedded words) before signing, and the swap runs with the flag off.
        bytes memory quoted = _hookData(
            NATIVE,
            VB_USDC,
            QUOTE_NATIVE_USDC_IN,
            QUOTE_NATIVE_USDC_OUT,
            HEADER_MIN_NATIVE_USDC,
            false,
            _withRecipient(TX_NATIVE_IN_USDC, TAIL_RECIPIENT_OFFSET_NATIVE_USDC, account)
        );
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = fill;
        bytes memory resized = approveHook.replaceCalldataAmounts(quoted, amounts);
        bytes memory cd = _executorCalldata1(address(approveHook), resized);
        (bytes memory message, bytes32 root) = _signedMessage(initData, account, cd, address(0), fill);

        vm.recordLogs();
        vm.prank(solver);
        adapter.processRelayExecution{ value: fill }(address(0), fill, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(account.balance, 0, "exactly the resized value was swapped");
        assertGe(
            IERC20(VB_USDC).balanceOf(account),
            Math.mulDiv(HEADER_MIN_NATIVE_USDC, 90, 100, Math.Rounding.Ceil),
            "resized floor"
        );
        assertTrue(executor.isMerkleRootUsed(account, root));
        _assertNoExecutionFailed(logs);
        _assertNoDustOnHooks();
    }

    /// @notice Under-filled below the signed minimum: the adapter still delivers the funds to the account (Relay
    ///         semantics), the production executor refuses to execute (balance gate), the root stays unused so the
    ///         intent can complete on a top-up, and no swap happens.
    function test_Relay_UnderFill_DeliversButDoesNotExecute() public {
        _requireFork();
        uint256 signedMin = QUOTE_USDC_KAT_IN;
        uint256 fill = QUOTE_USDC_KAT_IN * 90 / 100;
        (bytes memory initData, address account) = _nexusInitData();

        bytes memory cd = _executorCalldata1(address(approveHook), _usdcKatData(account, false));
        (bytes memory message, bytes32 root) = _signedMessage(initData, account, cd, VB_USDC, signedMin);

        deal(VB_USDC, address(adapter), fill);
        vm.prank(solver);
        adapter.processRelayExecution(VB_USDC, fill, message);

        assertGt(account.code.length, 0, "account still created");
        assertEq(IERC20(VB_USDC).balanceOf(account), fill, "funds delivered, not swapped");
        assertEq(IERC20(KAT).balanceOf(account), 0, "no swap");
        assertFalse(executor.isMerkleRootUsed(account, root), "root untouched (re-drivable)");

        // top-up to the signed minimum completes the same intent through the adapter
        uint256 topUp = signedMin - fill;
        deal(VB_USDC, address(adapter), topUp);
        vm.recordLogs();
        vm.prank(solver);
        adapter.processRelayExecution(VB_USDC, topUp, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(VB_USDC).balanceOf(account), 0, "swapped once the minimum was met");
        assertGe(IERC20(KAT).balanceOf(account), HEADER_MIN_USDC_KAT, "output cleared the post-fee floor");
        assertTrue(executor.isMerkleRootUsed(account, root), "root consumed on completion");
        _assertNoExecutionFailed(logs);
    }

    /// @notice A fill whose signed hooks fail on-chain (header floor 2x the quote, so the hook's own
    ///         `_postExecute` check reverts) is still DELIVERED by the adapter: the production executor rolls the
    ///         root back, the adapter emits ExecutionFailed, the funds rest in the user's account.
    function test_Relay_HookFloorReverts_FundsRestInAccount_RootNotConsumed() public {
        _requireFork();
        uint256 fill = QUOTE_USDC_KAT_IN;
        (bytes memory initData, address account) = _nexusInitData();

        bytes memory data = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            QUOTE_USDC_KAT_OUT * 2, // unreachable post-fee floor
            false,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account)
        );
        bytes memory cd = _executorCalldata1(address(approveHook), data);
        (bytes memory message, bytes32 root) = _signedMessage(initData, account, cd, VB_USDC, fill);

        deal(VB_USDC, address(adapter), fill);
        vm.recordLogs();
        vm.prank(solver);
        adapter.processRelayExecution(VB_USDC, fill, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(VB_USDC).balanceOf(account), fill, "funds delivered and untouched");
        assertEq(IERC20(KAT).balanceOf(account), 0, "swap rolled back atomically");
        assertEq(IERC20(VB_USDC).allowance(account, EVERLONG_ROUTER), 0, "no approval survived the rollback");
        assertFalse(executor.isMerkleRootUsed(account, root), "root rolled back");
        _assertExecutionFailed(logs);
    }

    /// @notice THE cross-chain latency risk, concretely: the API fixes the multicall deadline at quote + 600 s. A fill
    ///         that lands after it is still delivered (Relay semantics) but the router reverts 'Transaction too old',
    ///         the production executor rolls the root back and the adapter reports ExecutionFailed. Funds rest in the
    ///         user's account; the intent can be re-driven with a fresh quote.
    function test_Relay_DeadlineExpired_FundsRest_RootNotConsumed() public {
        _requireFork();
        uint256 fill = QUOTE_USDC_KAT_IN;
        (bytes memory initData, address account) = _nexusInitData();
        bytes memory cd = _executorCalldata1(address(approveHook), _usdcKatData(account, false));
        (bytes memory message, bytes32 root) = _signedMessage(initData, account, cd, VB_USDC, fill);

        vm.warp(DEADLINE_USDC_KAT + 1);
        deal(VB_USDC, address(adapter), fill);
        vm.recordLogs();
        vm.prank(solver);
        adapter.processRelayExecution(VB_USDC, fill, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(VB_USDC).balanceOf(account), fill, "funds delivered and untouched");
        assertEq(IERC20(KAT).balanceOf(account), 0, "no swap");
        assertFalse(executor.isMerkleRootUsed(account, root), "root rolled back");
        _assertExecutionFailed(logs);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Production Nexus initData for a first-time user. Katana runs the NEWER Nexus (v1.2 bootstrap): the
    ///      factory's `initData` is `abi.encode(bootstrap, bootstrapCall)` and the bootstrap entry point is
    ///      `initNexusNoRegistry` (the legacy `getInitNexusCalldata` does not exist there). Validator + destination
    ///      executor are installed at birth; a fresh salt per call keeps accounts distinct across tests.
    function _nexusInitData() internal returns (bytes memory initData, address predicted) {
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: PROD_DST_VALIDATOR, data: abi.encode(owner) });
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: PROD_DST_EXECUTOR, data: "" });
        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);
        BootstrapPreValidationHookConfig[] memory preHooks = new BootstrapPreValidationHookConfig[](0);

        bytes memory bootstrapCall =
            abi.encodeCall(NexusBootstrap.initNexusNoRegistry, (validators, executors, hook, fallbacks, preHooks));
        bytes memory nexusInit = abi.encode(PROD_NEXUS_BOOTSTRAP, bootstrapCall);
        bytes32 salt = keccak256(abi.encode("everlong-relay-e2e", ++saltNonce));
        predicted = INexusFactory(PROD_NEXUS_FACTORY).computeAccountAddress(nexusInit, salt);
        bytes memory factoryCalldata = abi.encodeCall(INexusFactory.createAccount, (nexusInit, salt));
        initData = abi.encodePacked(PROD_SENDER_CREATOR, PROD_NEXUS_FACTORY, factoryCalldata);
    }

    /// @dev Pre-creates the account the way the first fill would, so a later intent can omit initData.
    function _createAccountDirectly(bytes memory initData, address expected) internal {
        // initData = senderCreator ++ factory ++ factoryCalldata; call the factory directly
        bytes memory factoryCalldata = new bytes(initData.length - 40);
        for (uint256 i; i < factoryCalldata.length; ++i) {
            factoryCalldata[i] = initData[40 + i];
        }
        (bool ok, bytes memory ret) = PROD_NEXUS_FACTORY.call(factoryCalldata);
        require(ok, "factory create failed");
        assertEq(abi.decode(ret, (address)), expected, "factory returned the predicted account");
    }

    function _usdcKatData(address account, bool flag) internal view returns (bytes memory) {
        return _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            HEADER_MIN_USDC_KAT,
            flag,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account)
        );
    }

    function _approveData(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes(new bytes(52)), VB_USDC, EVERLONG_ROUTER, amount, false);
    }

    function _executorCalldata1(address hook, bytes memory data) internal pure returns (bytes memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        return abi.encodeCall(
            ISuperExecutor.execute,
            (abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas })))
        );
    }

    function _executorCalldata2(
        address hookA,
        bytes memory dataA,
        address hookB,
        bytes memory dataB
    )
        internal
        pure
        returns (bytes memory)
    {
        address[] memory hooks = new address[](2);
        hooks[0] = hookA;
        hooks[1] = hookB;
        bytes[] memory datas = new bytes[](2);
        datas[0] = dataA;
        datas[1] = dataB;
        return abi.encodeCall(
            ISuperExecutor.execute,
            (abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas })))
        );
    }

    /// @dev RelayAdapterV2 message = abi.encode(initData, sigData), where sigData carries a single-leaf destination
    ///      intent (root == leaf) signed by the account owner against the PRODUCTION validator's namespace.
    function _signedMessage(
        bytes memory initData,
        address account,
        bytes memory executorCalldata,
        address token,
        uint256 minimum
    )
        internal
        view
        returns (bytes memory message, bytes32 root)
    {
        root = _createDestinationValidatorLeaf(
            executorCalldata,
            uint64(KATANA_CHAIN_ID),
            account,
            PROD_DST_EXECUTOR,
            _one(token),
            _one(minimum),
            VALID_UNTIL,
            PROD_DST_VALIDATOR
        );
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, MessageHashUtils.toEthSignedMessageHash(messageHash));
        bytes memory signature = abi.encodePacked(r, s, v);

        ISuperValidator.DstProof[] memory proofs = new ISuperValidator.DstProof[](1);
        proofs[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(KATANA_CHAIN_ID),
            info: ISuperValidator.DstInfo({
                account: account,
                executor: PROD_DST_EXECUTOR,
                dstTokens: _one(token),
                intentAmounts: _one(minimum),
                validator: PROD_DST_VALIDATOR,
                data: executorCalldata
            })
        });
        uint64[] memory chains = new uint64[](1);
        chains[0] = uint64(KATANA_CHAIN_ID);
        bytes memory sigData = abi.encode(chains, VALID_UNTIL, uint48(0), root, new bytes32[](0), proofs, signature);
        message = abi.encode(initData, sigData);
    }

    function _one(address v) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = v;
    }

    function _one(uint256 v) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = v;
    }

    function _assertNoExecutionFailed(Vm.Log[] memory logs) internal view {
        bytes32 topic = keccak256("ExecutionFailed(address)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                revert("adapter reported ExecutionFailed");
            }
        }
    }

    function _assertExecutionFailed(Vm.Log[] memory logs) internal view {
        bytes32 topic = keccak256("ExecutionFailed(address)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                return;
            }
        }
        revert("expected ExecutionFailed from the adapter");
    }

    function _assertNoDustOnHooks() internal view {
        assertEq(IERC20(VB_USDC).balanceOf(address(swapHook)), 0);
        assertEq(IERC20(KAT).balanceOf(address(swapHook)), 0);
        assertEq(address(swapHook).balance, 0);
        assertEq(IERC20(VB_USDC).balanceOf(address(approveHook)), 0);
        assertEq(IERC20(KAT).balanceOf(address(approveHook)), 0);
        assertEq(address(approveHook).balance, 0);
        assertEq(
            IERC20(VB_USDC).balanceOf(PROD_DST_EXECUTOR),
            prodExecutorUsdcAtSetup,
            "production executor balance unchanged"
        );
    }
}
