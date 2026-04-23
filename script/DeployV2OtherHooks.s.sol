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

    struct FirelightHookAddresses {
        address redeemFirelightVaultHook;
        address claimWithdrawFirelightVaultHook;
    }

    struct AlgebraIntegralHookAddresses {
        address swapAlgebraIntegralHook;
        address approveAndSwapAlgebraIntegralHook;
    }

    struct HookDeployment {
        string name;
        string saltOverride; // Optional custom salt (empty = use name for salt)
        bytes creationCode;
    }

    /// @notice Sets up complete configuration for Morpho hooks deployment
    /// @param env_ Environment (0/2 = production, 1 = test)
    /// @param saltNamespace_ Salt namespace for deployment (if empty, uses production default)
    function _setConfiguration(uint256 env_, string memory saltNamespace_) internal {
        _setBaseConfiguration(env_, saltNamespace_);
        _setOtherHooksConfiguration();
    }

    function run(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Morpho Hooks on chainId: ", chainId);

        _deployMorphoHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function run(uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        console2.log("Deploying Morpho Hooks on chainId: ", chainId);

        _deployMorphoHooks(chainId, env);
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

    /// @notice Get bytecode directory based on environment
    function __getMorphoHooksBytecodeDirectory(uint256 env) internal pure returns (string memory) {
        if (env == 1) {
            return "script/generated-bytecode-other/";
        } else {
            return "script/locked-bytecode-other/";
        }
    }

    /// @notice Get bytecode from environment-specific artifacts
    function __getMorphoHooksBytecode(string memory contractName, uint256 env) internal view returns (bytes memory) {
        string memory artifactPath =
            string(abi.encodePacked(__getMorphoHooksBytecodeDirectory(env), contractName, ".json"));
        return vm.getCode(artifactPath);
    }

    function _deployMorphoHooks(uint64 chainId, uint256 env) internal {
        _deployHooksSet(chainId, env);
    }

    function _deployHooksSet(
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
            abi.encodePacked(__getMorphoHooksBytecode("MorphoSupplyAndBorrowHook", env), morphoArg)
        );
        hooks[1] = HookDeployment(
            MORPHO_BORROW_ONLY_HOOK_KEY,
            "",
            abi.encodePacked(__getMorphoHooksBytecode("MorphoBorrowHook", env), morphoArg)
        );
        hooks[2] = HookDeployment(
            MORPHO_REPAY_HOOK_KEY,
            "",
            abi.encodePacked(__getMorphoHooksBytecode("MorphoRepayHook", env), morphoArg)
        );
        hooks[3] = HookDeployment(
            MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY,
            "",
            abi.encodePacked(__getMorphoHooksBytecode("MorphoRepayAndWithdrawHook", env), morphoArg)
        );
        hooks[4] = HookDeployment(
            MORPHO_SUPPLY_HOOK_KEY,
            "",
            abi.encodePacked(__getMorphoHooksBytecode("MorphoSupplyHook", env), morphoArg)
        );
        hooks[5] = HookDeployment(
            MORPHO_WITHDRAW_HOOK_KEY,
            "",
            abi.encodePacked(__getMorphoHooksBytecode("MorphoWithdrawHook", env), morphoArg)
        );

        // Lender-side hook
        hooks[6] = HookDeployment(
            MORPHO_LEND_HOOK_KEY,
            "",
            abi.encodePacked(__getMorphoHooksBytecode("MorphoLendHook", env), morphoArg)
        );

        // MetaMorpho reallocate hook (no constructor args)
        hooks[7] = HookDeployment(
            META_MORPHO_REALLOCATE_HOOK_KEY, "", __getMorphoHooksBytecode("MetaMorphoReallocateHook", env)
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

    function _deployFirelightHooks(uint64 chainId, uint256 env) internal returns (FirelightHookAddresses memory) {
        uint256 len = 2;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // Firelight hooks have no constructor args
        hooks[0] = HookDeployment(
            REDEEM_FIRELIGHT_VAULT_HOOK_KEY,
            "",
            __getMorphoHooksBytecode("RedeemFirelightVaultHook", env)
        );
        hooks[1] = HookDeployment(
            CLAIM_WITHDRAW_FIRELIGHT_VAULT_HOOK_KEY,
            "",
            __getMorphoHooksBytecode("ClaimWithdrawFirelightVaultHook", env)
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
            abi.encodePacked(__getMorphoHooksBytecode("SwapAlgebraIntegralHook", env), routerArg)
        );
        hooks[1] = HookDeployment(
            APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY,
            "",
            abi.encodePacked(__getMorphoHooksBytecode("ApproveAndSwapAlgebraIntegralHook", env), routerArg)
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
}
