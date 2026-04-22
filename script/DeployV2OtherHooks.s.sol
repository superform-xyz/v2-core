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

    /*//////////////////////////////////////////////////////////////
                        AAVE V4 HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Get bytecode directory for Aave V4 hooks based on environment
    function __getAaveV4HooksBytecodeDirectory(uint256 env) internal pure returns (string memory) {
        if (env == 1) {
            return "script/generated-bytecode-other/";
        } else {
            return "script/locked-bytecode-other/";
        }
    }

    /// @notice Get bytecode for Aave V4 hooks from environment-specific artifacts
    function __getAaveV4HooksBytecode(string memory contractName, uint256 env) internal view returns (bytes memory) {
        string memory artifactPath =
            string(abi.encodePacked(__getAaveV4HooksBytecodeDirectory(env), contractName, ".json"));
        return vm.getCode(artifactPath);
    }

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
            AAVE_V4_SUPPLY_HOOK_KEY, "", __getAaveV4HooksBytecode("AaveV4SupplyHook", env)
        );
        hooks[1] = HookDeployment(
            AAVE_V4_WITHDRAW_HOOK_KEY, "", __getAaveV4HooksBytecode("AaveV4WithdrawHook", env)
        );
        hooks[2] = HookDeployment(
            AAVE_V4_BORROW_HOOK_KEY, "", __getAaveV4HooksBytecode("AaveV4BorrowHook", env)
        );
        hooks[3] = HookDeployment(
            AAVE_V4_REPAY_HOOK_KEY, "", __getAaveV4HooksBytecode("AaveV4RepayHook", env)
        );
        hooks[4] = HookDeployment(
            AAVE_V4_SUPPLY_AND_BORROW_HOOK_KEY, "", __getAaveV4HooksBytecode("AaveV4SupplyAndBorrowHook", env)
        );
        hooks[5] = HookDeployment(
            AAVE_V4_REPAY_AND_WITHDRAW_HOOK_KEY, "", __getAaveV4HooksBytecode("AaveV4RepayAndWithdrawHook", env)
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
}
