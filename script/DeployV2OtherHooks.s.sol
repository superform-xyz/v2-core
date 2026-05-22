// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ConfigOtherHooks } from "./utils/ConfigOtherHooks.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployV2OtherHooks is DeployV2Base, ConfigOtherHooks {
    struct MorphoHookAddresses {
        address morphoSupplyAndBorrowHook;
        address morphoBorrowHook;
        address morphoRepayHook;
        address morphoRepayAndWithdrawHook;
        address morphoSupplyHook;
        address morphoWithdrawHook;
        address morphoLendHook;
        address metaMorphoReallocateHook;
    }

    struct AaveV4HookAddresses {
        address aaveV4SupplyHook;
        address aaveV4WithdrawHook;
        address aaveV4BorrowHook;
        address aaveV4RepayHook;
        address aaveV4SupplyAndBorrowHook;
        address aaveV4RepayAndWithdrawHook;
    }

    struct FirelightHookAddresses {
        address redeemFirelightVaultHook;
        address claimWithdrawFirelightVaultHook;
    }

    struct AlgebraIntegralHookAddresses {
        address swapAlgebraIntegralHook;
        address approveAndSwapAlgebraIntegralHook;
    }

    struct DETHHookAddresses {
        address requestRedeemDETHHook;
        address approveAndRequestRedeemDETHHook;
        address claimAssetsDETHHook;
    }

    struct OdosV3HookAddresses {
        address swapOdosV3Hook;
        address approveAndSwapOdosV3Hook;
    }

    struct HookDeployment {
        string name;
        string saltOverride; // Optional custom salt (empty = use name for salt)
        bytes creationCode;
    }

    /// @notice Sets up complete configuration for hook deployment
    /// @param env_ Environment (0/2 = production, 1 = test)
    /// @param saltNamespace_ Salt namespace for deployment (if empty, uses production default)
    function _setConfiguration(uint256 env_, string memory saltNamespace_) internal {
        _setBaseConfiguration(env_, saltNamespace_);
        _setOtherHooksConfiguration();
    }

    function run(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        _deployAllHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function run(uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        _deployAllHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runFirelight(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Firelight Hooks on chainId: ", chainId);

        _deployFirelightHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runAlgebraIntegral(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Algebra Integral Hooks on chainId: ", chainId);

        _deployAlgebraIntegralHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runDETH(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying DETH Hooks on chainId: ", chainId);

        _deployDETHHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runOdosV3(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Odos V3 Hooks on chainId: ", chainId);

        _deployOdosV3Hooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    /// @notice Deploy all applicable hooks for the given chain
    function _deployAllHooks(uint64 chainId, uint256 env) internal {
        // Morpho hooks — only on chains where Morpho is deployed
        if (otherHooksConfiguration.morphos[chainId] != address(0)) {
            console2.log("Deploying Morpho Hooks on chainId: ", chainId);
            _deployMorphoHooks(chainId, env);
        }

        // Aave V4 hooks — only on Ethereum mainnet (Aave V4 Hub-and-Spoke)
        if (chainId == MAINNET_CHAIN_ID) {
            console2.log("Deploying Aave V4 Hooks on chainId: ", chainId);
            _deployAaveV4Hooks(chainId, env);
        }

        // Firelight hooks — only on Flare
        if (chainId == FLARE_CHAIN_ID) {
            console2.log("Deploying Firelight Hooks on chainId: ", chainId);
            _deployFirelightHooks(chainId, env);
        }

        // Algebra Integral hooks — only on chains with configured swap routers
        if (otherHooksConfiguration.algebraSwapRouters[chainId] != address(0)) {
            console2.log("Deploying Algebra Integral Hooks on chainId: ", chainId);
            _deployAlgebraIntegralHooks(chainId, env);
        }

        // DETH hooks — only on Ethereum mainnet (DETH/Machine vault is mainnet-only)
        if (chainId == MAINNET_CHAIN_ID) {
            console2.log("Deploying DETH Hooks on chainId: ", chainId);
            _deployDETHHooks(chainId, env);
        }

        // Odos V3 hooks — on chains where Odos V3 router is deployed
        if (otherHooksConfiguration.odosRouterV3s[chainId] != address(0)) {
            console2.log("Deploying Odos V3 Hooks on chainId: ", chainId);
            _deployOdosV3Hooks(chainId, env);
        }
    }

    /// @notice Get bytecode directory based on environment
    function __getOtherHooksBytecodeDirectory(uint256 env) internal pure returns (string memory) {
        if (env == 1) {
            return "script/generated-bytecode-other/";
        } else {
            return "script/locked-bytecode-other/";
        }
    }

    /// @notice Get bytecode from environment-specific artifacts
    function __getOtherHooksBytecode(string memory contractName, uint256 env) internal view returns (bytes memory) {
        string memory artifactPath =
            string(abi.encodePacked(__getOtherHooksBytecodeDirectory(env), contractName, ".json"));
        return vm.getCode(artifactPath);
    }

    /*//////////////////////////////////////////////////////////////
                        MORPHO HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployMorphoHooks(uint64 chainId, uint256 env) internal {
        _deployMorphoHooksSet(chainId, env);
    }

    function _deployMorphoHooksSet(
        uint64 chainId,
        uint256 env
    )
        private
        returns (MorphoHookAddresses memory hookAddresses)
    {
        uint256 len = 8;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        bytes memory morphoArg = abi.encode(otherHooksConfiguration.morphos[chainId]);

        // Borrower-side hooks
        hooks[0] = HookDeployment(
            MORPHO_SUPPLY_AND_BORROW_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoSupplyAndBorrowHook", env), morphoArg)
        );
        hooks[1] = HookDeployment(
            MORPHO_BORROW_ONLY_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoBorrowHook", env), morphoArg)
        );
        hooks[2] = HookDeployment(
            MORPHO_REPAY_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoRepayHook", env), morphoArg)
        );
        hooks[3] = HookDeployment(
            MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoRepayAndWithdrawHook", env), morphoArg)
        );
        hooks[4] = HookDeployment(
            MORPHO_SUPPLY_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoSupplyHook", env), morphoArg)
        );
        hooks[5] = HookDeployment(
            MORPHO_WITHDRAW_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoWithdrawHook", env), morphoArg)
        );

        // Lender-side hook
        hooks[6] = HookDeployment(
            MORPHO_LEND_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoLendHook", env), morphoArg)
        );

        // MetaMorpho reallocate hook (no constructor args)
        hooks[7] = HookDeployment(
            META_MORPHO_REALLOCATE_HOOK_KEY, "", __getOtherHooksBytecode("MetaMorphoReallocateHook", env)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        // Assign hook addresses
        hookAddresses.morphoSupplyAndBorrowHook =
            Strings.equal(hooks[0].name, MORPHO_SUPPLY_AND_BORROW_HOOK_KEY) ? addresses[0] : address(0);
        hookAddresses.morphoBorrowHook =
            Strings.equal(hooks[1].name, MORPHO_BORROW_ONLY_HOOK_KEY) ? addresses[1] : address(0);
        hookAddresses.morphoRepayHook =
            Strings.equal(hooks[2].name, MORPHO_REPAY_HOOK_KEY) ? addresses[2] : address(0);
        hookAddresses.morphoRepayAndWithdrawHook =
            Strings.equal(hooks[3].name, MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY) ? addresses[3] : address(0);
        hookAddresses.morphoSupplyHook =
            Strings.equal(hooks[4].name, MORPHO_SUPPLY_HOOK_KEY) ? addresses[4] : address(0);
        hookAddresses.morphoWithdrawHook =
            Strings.equal(hooks[5].name, MORPHO_WITHDRAW_HOOK_KEY) ? addresses[5] : address(0);
        hookAddresses.morphoLendHook =
            Strings.equal(hooks[6].name, MORPHO_LEND_HOOK_KEY) ? addresses[6] : address(0);
        hookAddresses.metaMorphoReallocateHook =
            Strings.equal(hooks[7].name, META_MORPHO_REALLOCATE_HOOK_KEY) ? addresses[7] : address(0);

        // Verify no hooks were assigned address(0)
        require(hookAddresses.morphoSupplyAndBorrowHook != address(0), "MorphoSupplyAndBorrowHook not assigned");
        require(hookAddresses.morphoBorrowHook != address(0), "MorphoBorrowHook not assigned");
        require(hookAddresses.morphoRepayHook != address(0), "MorphoRepayHook not assigned");
        require(hookAddresses.morphoRepayAndWithdrawHook != address(0), "MorphoRepayAndWithdrawHook not assigned");
        require(hookAddresses.morphoSupplyHook != address(0), "MorphoSupplyHook not assigned");
        require(hookAddresses.morphoWithdrawHook != address(0), "MorphoWithdrawHook not assigned");
        require(hookAddresses.morphoLendHook != address(0), "MorphoLendHook not assigned");
        require(hookAddresses.metaMorphoReallocateHook != address(0), "MetaMorphoReallocateHook not assigned");

        console2.log("All Morpho hooks deployed and validated successfully.");

        return hookAddresses;
    }

    /*//////////////////////////////////////////////////////////////
                        AAVE V4 HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployAaveV4Hooks(uint64 chainId, uint256 env) internal {
        _deployAaveV4HooksSet(chainId, env);
    }

    /// @notice Deploy all 6 Aave V4 hooks (no constructor args — Spoke comes from calldata)
    function _deployAaveV4HooksSet(
        uint64 chainId,
        uint256 env
    )
        private
        returns (AaveV4HookAddresses memory hookAddresses)
    {
        uint256 len = 6;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // Aave V4 hooks have no constructor args
        hooks[0] = HookDeployment(
            AAVE_V4_SUPPLY_HOOK_KEY, "", __getOtherHooksBytecode("AaveV4SupplyHook", env)
        );
        hooks[1] = HookDeployment(
            AAVE_V4_WITHDRAW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV4WithdrawHook", env)
        );
        hooks[2] = HookDeployment(
            AAVE_V4_BORROW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV4BorrowHook", env)
        );
        hooks[3] = HookDeployment(
            AAVE_V4_REPAY_HOOK_KEY, "", __getOtherHooksBytecode("AaveV4RepayHook", env)
        );
        hooks[4] = HookDeployment(
            AAVE_V4_SUPPLY_AND_BORROW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV4SupplyAndBorrowHook", env)
        );
        hooks[5] = HookDeployment(
            AAVE_V4_REPAY_AND_WITHDRAW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV4RepayAndWithdrawHook", env)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        hookAddresses.aaveV4SupplyHook = addresses[0];
        hookAddresses.aaveV4WithdrawHook = addresses[1];
        hookAddresses.aaveV4BorrowHook = addresses[2];
        hookAddresses.aaveV4RepayHook = addresses[3];
        hookAddresses.aaveV4SupplyAndBorrowHook = addresses[4];
        hookAddresses.aaveV4RepayAndWithdrawHook = addresses[5];

        // Verify no hooks were assigned address(0)
        require(hookAddresses.aaveV4SupplyHook != address(0), "AaveV4SupplyHook not assigned");
        require(hookAddresses.aaveV4WithdrawHook != address(0), "AaveV4WithdrawHook not assigned");
        require(hookAddresses.aaveV4BorrowHook != address(0), "AaveV4BorrowHook not assigned");
        require(hookAddresses.aaveV4RepayHook != address(0), "AaveV4RepayHook not assigned");
        require(hookAddresses.aaveV4SupplyAndBorrowHook != address(0), "AaveV4SupplyAndBorrowHook not assigned");
        require(hookAddresses.aaveV4RepayAndWithdrawHook != address(0), "AaveV4RepayAndWithdrawHook not assigned");

        console2.log("All Aave V4 hooks deployed and validated successfully.");

        return hookAddresses;
    }

    /*//////////////////////////////////////////////////////////////
                      FIRELIGHT HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployFirelightHooks(uint64 chainId, uint256 env) internal returns (FirelightHookAddresses memory) {
        uint256 len = 2;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // Firelight hooks have no constructor args
        hooks[0] = HookDeployment(
            REDEEM_FIRELIGHT_VAULT_HOOK_KEY,
            "",
            __getOtherHooksBytecode("RedeemFirelightVaultHook", env)
        );
        hooks[1] = HookDeployment(
            CLAIM_WITHDRAW_FIRELIGHT_VAULT_HOOK_KEY,
            "",
            __getOtherHooksBytecode("ClaimWithdrawFirelightVaultHook", env)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        FirelightHookAddresses memory hookAddresses;
        hookAddresses.redeemFirelightVaultHook = addresses[0];
        hookAddresses.claimWithdrawFirelightVaultHook = addresses[1];

        require(hookAddresses.redeemFirelightVaultHook != address(0), "RedeemFirelightVaultHook not assigned");
        require(
            hookAddresses.claimWithdrawFirelightVaultHook != address(0), "ClaimWithdrawFirelightVaultHook not assigned"
        );

        console2.log("All Firelight hooks deployed and validated successfully.");

        return hookAddresses;
    }

    function _deployAlgebraIntegralHooks(
        uint64 chainId,
        uint256 env
    )
        internal
        returns (AlgebraIntegralHookAddresses memory)
    {
        uint256 len = 2;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        bytes memory routerArg = abi.encode(otherHooksConfiguration.algebraSwapRouters[chainId]);

        hooks[0] = HookDeployment(
            SWAP_ALGEBRA_INTEGRAL_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("SwapAlgebraIntegralHook", env), routerArg)
        );
        hooks[1] = HookDeployment(
            APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("ApproveAndSwapAlgebraIntegralHook", env), routerArg)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        AlgebraIntegralHookAddresses memory hookAddresses;
        hookAddresses.swapAlgebraIntegralHook = addresses[0];
        hookAddresses.approveAndSwapAlgebraIntegralHook = addresses[1];

        require(hookAddresses.swapAlgebraIntegralHook != address(0), "SwapAlgebraIntegralHook not assigned");
        require(
            hookAddresses.approveAndSwapAlgebraIntegralHook != address(0),
            "ApproveAndSwapAlgebraIntegralHook not assigned"
        );

        console2.log("All Algebra Integral hooks deployed and validated successfully.");

        return hookAddresses;
    }

    /*//////////////////////////////////////////////////////////////
                          DETH HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy all 3 DETH hooks (no constructor args — AsyncRedeemer/Machine come from calldata)
    function _deployDETHHooks(uint64 chainId, uint256 env) internal returns (DETHHookAddresses memory) {
        uint256 len = 3;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // DETH hooks have no constructor args
        hooks[0] = HookDeployment(
            REQUEST_REDEEM_DETH_HOOK_KEY,
            "",
            __getOtherHooksBytecode("RequestRedeemDETHHook", env)
        );
        hooks[1] = HookDeployment(
            APPROVE_AND_REQUEST_REDEEM_DETH_HOOK_KEY,
            "",
            __getOtherHooksBytecode("ApproveAndRequestRedeemDETHHook", env)
        );
        hooks[2] = HookDeployment(
            CLAIM_ASSETS_DETH_HOOK_KEY,
            "",
            __getOtherHooksBytecode("ClaimAssetsDETHHook", env)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        DETHHookAddresses memory hookAddresses;
        hookAddresses.requestRedeemDETHHook = addresses[0];
        hookAddresses.approveAndRequestRedeemDETHHook = addresses[1];
        hookAddresses.claimAssetsDETHHook = addresses[2];

        require(hookAddresses.requestRedeemDETHHook != address(0), "RequestRedeemDETHHook not assigned");
        require(
            hookAddresses.approveAndRequestRedeemDETHHook != address(0),
            "ApproveAndRequestRedeemDETHHook not assigned"
        );
        require(hookAddresses.claimAssetsDETHHook != address(0), "ClaimAssetsDETHHook not assigned");

        console2.log("All DETH hooks deployed and validated successfully.");

        return hookAddresses;
    }

    /*//////////////////////////////////////////////////////////////
                      ODOS V3 HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployOdosV3Hooks(uint64 chainId, uint256 env) internal returns (OdosV3HookAddresses memory) {
        uint256 len = 2;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        bytes memory routerArg = abi.encode(otherHooksConfiguration.odosRouterV3s[chainId]);

        hooks[0] = HookDeployment(
            SWAP_ODOSV3_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("SwapOdosV3Hook", env), routerArg)
        );
        hooks[1] = HookDeployment(
            APPROVE_AND_SWAP_ODOSV3_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("ApproveAndSwapOdosV3Hook", env), routerArg)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        OdosV3HookAddresses memory hookAddresses;
        hookAddresses.swapOdosV3Hook = addresses[0];
        hookAddresses.approveAndSwapOdosV3Hook = addresses[1];

        require(hookAddresses.swapOdosV3Hook != address(0), "SwapOdosV3Hook not assigned");
        require(hookAddresses.approveAndSwapOdosV3Hook != address(0), "ApproveAndSwapOdosV3Hook not assigned");

        console2.log("All Odos V3 hooks deployed and validated successfully.");

        return hookAddresses;
    }
}
