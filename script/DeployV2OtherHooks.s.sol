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
        address forceDeallocateMorphoHook;
    }

    struct AaveV4HookAddresses {
        address aaveV4SupplyHook;
        address aaveV4WithdrawHook;
        address aaveV4BorrowHook;
        address aaveV4RepayHook;
        address aaveV4SupplyAndBorrowHook;
        address aaveV4RepayAndWithdrawHook;
    }

    struct AaveV3HookAddresses {
        address aaveV3SupplyHook;
        address aaveV3WithdrawHook;
        address aaveV3BorrowHook;
        address aaveV3RepayHook;
        address aaveV3SupplyAndBorrowHook;
        address aaveV3RepayAndWithdrawHook;
        address aaveV3RepayWithATokensHook;
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

    struct SponsorshipAddresses {
        address nativeFeeSponsorship;
        address fetchNativeFeeHook;
    }

    struct RFLRHookAddresses {
        address claimRFLRHook;
        address claimRFLRV2Hook;
        address claimRFLRV3Hook;
        address withdrawRFLRHook;
        address withdrawVestedRFLRHook;
    }

    struct RFLRHookV2Addresses {
        address withdrawRFLRHookV2;
        address withdrawVestedRFLRHookV2;
    }

    struct OdosV3HookAddresses {
        address swapOdosV3Hook;
        address approveAndSwapOdosV3Hook;
    }

    struct SpectraExchangeHookAddresses {
        address spectraExchangeDepositHook;
        address spectraExchangeRedeemHook;
    }

    struct EulerHookAddresses {
        address eulerDepositCollateralHook;
        address eulerBorrowHook;
        address eulerRepayHook;
        address eulerWithdrawCollateralHook;
        address eulerDepositCollateralAndBorrowHook;
        address eulerRepayAndWithdrawHook;
    }

    struct MorphoV2HookAddresses {
        address morphoSupplyAndBorrowHookV2;
        address morphoRepayAndWithdrawHookV2;
    }

    struct WrappedNativeHookAddress {
        address wrappedNativeHook;
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

    function runSponsorship(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Sponsorship contracts on chainId: ", chainId);

        _deploySponsorshipContracts(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runRFLR(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying rFLR Hooks on chainId: ", chainId);

        _deployRFLRHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runRFLRV2(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying rFLR V2 Hooks on chainId: ", chainId);

        _deployRFLRV2Hooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runOdosV3(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Odos V3 Hooks on chainId: ", chainId);

        _deployOdosV3Hooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runSpectraExchange(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Spectra Exchange Hooks on chainId: ", chainId);

        _deploySpectraExchangeHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runEuler(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Euler Hooks on chainId: ", chainId);

        _deployEulerHooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runMorphoV2(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying Morpho V2 Hooks on chainId: ", chainId);

        _deployMorphoV2Hooks(chainId, env);
        _writeExportedContracts(chainId);
    }

    function runWrappedNative(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("Deploying WrappedNativeHook on chainId: ", chainId);

        _deployWrappedNativeHook(chainId, env);
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

        // Aave V3 hooks — only on chains where Aave V3 is deployed
        if (otherHooksConfiguration.aaveV3Pools[chainId] != address(0)) {
            console2.log("Deploying Aave V3 Hooks on chainId: ", chainId);
            _deployAaveV3Hooks(chainId, env);
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

        // Native Fee Sponsorship — all chains (paymaster is deployed everywhere)
        console2.log("Deploying Sponsorship contracts on chainId: ", chainId);
        _deploySponsorshipContracts(chainId, env);

        // rFLR hooks — only on Flare
        if (chainId == FLARE_CHAIN_ID) {
            console2.log("Deploying rFLR Hooks on chainId: ", chainId);
            _deployRFLRHooks(chainId, env);
            console2.log("Deploying rFLR V2 Hooks on chainId: ", chainId);
            _deployRFLRV2Hooks(chainId, env);
            console2.log("Deploying WrappedNativeHook on chainId: ", chainId);
            _deployWrappedNativeHook(chainId, env);
        }

        // Spectra Exchange hooks — on chains where Spectra Router is deployed
        if (otherHooksConfiguration.spectraRouters[chainId] != address(0)) {
            console2.log("Deploying Spectra Exchange Hooks on chainId: ", chainId);
            _deploySpectraExchangeHooks(chainId, env);
        }

        // Odos V3 hooks — on chains where Odos V3 router is deployed
        if (otherHooksConfiguration.odosRouterV3s[chainId] != address(0)) {
            console2.log("Deploying Odos V3 Hooks on chainId: ", chainId);
            _deployOdosV3Hooks(chainId, env);
        }

        // Euler V2 hooks — only on Ethereum mainnet (Euler V2 is mainnet-only)
        if (chainId == MAINNET_CHAIN_ID) {
            console2.log("Deploying Euler Hooks on chainId: ", chainId);
            _deployEulerHooks(chainId, env);
        }

        // Morpho V2 hooks — on chains where Morpho is deployed
        if (otherHooksConfiguration.morphos[chainId] != address(0)) {
            console2.log("Deploying Morpho V2 Hooks on chainId: ", chainId);
            _deployMorphoV2Hooks(chainId, env);
        }
    }

    /// @notice Get bytecode directory based on environment
    function __getOtherHooksBytecodeDirectory(uint256) internal pure returns (string memory) {
        return "script/locked-bytecode/";
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
        uint256 len = 9;
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

        // Morpho Vault V2 force deallocate hook (no constructor args)
        hooks[8] = HookDeployment(
            FORCE_DEALLOCATE_MORPHO_HOOK_KEY, "", __getOtherHooksBytecode("ForceDeallocateMorphoHook", env)
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
        hookAddresses.forceDeallocateMorphoHook =
            Strings.equal(hooks[8].name, FORCE_DEALLOCATE_MORPHO_HOOK_KEY) ? addresses[8] : address(0);

        // Verify no hooks were assigned address(0)
        require(hookAddresses.morphoSupplyAndBorrowHook != address(0), "MorphoSupplyAndBorrowHook not assigned");
        require(hookAddresses.morphoBorrowHook != address(0), "MorphoBorrowHook not assigned");
        require(hookAddresses.morphoRepayHook != address(0), "MorphoRepayHook not assigned");
        require(hookAddresses.morphoRepayAndWithdrawHook != address(0), "MorphoRepayAndWithdrawHook not assigned");
        require(hookAddresses.morphoSupplyHook != address(0), "MorphoSupplyHook not assigned");
        require(hookAddresses.morphoWithdrawHook != address(0), "MorphoWithdrawHook not assigned");
        require(hookAddresses.morphoLendHook != address(0), "MorphoLendHook not assigned");
        require(hookAddresses.metaMorphoReallocateHook != address(0), "MetaMorphoReallocateHook not assigned");
        require(
            hookAddresses.forceDeallocateMorphoHook != address(0), "ForceDeallocateMorphoHook not assigned"
        );

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
                        AAVE V3 HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployAaveV3Hooks(uint64 chainId, uint256 env) internal {
        _deployAaveV3HooksSet(chainId, env);
    }

    /// @notice Deploy all 7 Aave V3 hooks (no constructor args — Pool comes from calldata)
    function _deployAaveV3HooksSet(
        uint64 chainId,
        uint256 env
    )
        private
        returns (AaveV3HookAddresses memory hookAddresses)
    {
        uint256 len = 7;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // Aave V3 hooks have no constructor args
        hooks[0] = HookDeployment(AAVE_V3_SUPPLY_HOOK_KEY, "", __getOtherHooksBytecode("AaveV3SupplyHook", env));
        hooks[1] = HookDeployment(AAVE_V3_WITHDRAW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV3WithdrawHook", env));
        hooks[2] = HookDeployment(AAVE_V3_BORROW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV3BorrowHook", env));
        hooks[3] = HookDeployment(AAVE_V3_REPAY_HOOK_KEY, "", __getOtherHooksBytecode("AaveV3RepayHook", env));
        hooks[4] = HookDeployment(
            AAVE_V3_SUPPLY_AND_BORROW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV3SupplyAndBorrowHook", env)
        );
        hooks[5] = HookDeployment(
            AAVE_V3_REPAY_AND_WITHDRAW_HOOK_KEY, "", __getOtherHooksBytecode("AaveV3RepayAndWithdrawHook", env)
        );
        hooks[6] = HookDeployment(
            AAVE_V3_REPAY_WITH_ATOKENS_HOOK_KEY, "", __getOtherHooksBytecode("AaveV3RepayWithATokensHook", env)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        hookAddresses.aaveV3SupplyHook = addresses[0];
        hookAddresses.aaveV3WithdrawHook = addresses[1];
        hookAddresses.aaveV3BorrowHook = addresses[2];
        hookAddresses.aaveV3RepayHook = addresses[3];
        hookAddresses.aaveV3SupplyAndBorrowHook = addresses[4];
        hookAddresses.aaveV3RepayAndWithdrawHook = addresses[5];
        hookAddresses.aaveV3RepayWithATokensHook = addresses[6];

        require(hookAddresses.aaveV3SupplyHook != address(0), "AaveV3SupplyHook not assigned");
        require(hookAddresses.aaveV3WithdrawHook != address(0), "AaveV3WithdrawHook not assigned");
        require(hookAddresses.aaveV3BorrowHook != address(0), "AaveV3BorrowHook not assigned");
        require(hookAddresses.aaveV3RepayHook != address(0), "AaveV3RepayHook not assigned");
        require(hookAddresses.aaveV3SupplyAndBorrowHook != address(0), "AaveV3SupplyAndBorrowHook not assigned");
        require(hookAddresses.aaveV3RepayAndWithdrawHook != address(0), "AaveV3RepayAndWithdrawHook not assigned");
        require(hookAddresses.aaveV3RepayWithATokensHook != address(0), "AaveV3RepayWithATokensHook not assigned");

        console2.log("All Aave V3 hooks deployed and validated successfully.");

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
                    SPECTRA EXCHANGE HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deploySpectraExchangeHooks(
        uint64 chainId,
        uint256 env
    )
        internal
        returns (SpectraExchangeHookAddresses memory)
    {
        uint256 len = 2;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        bytes memory routerArg = abi.encode(otherHooksConfiguration.spectraRouters[chainId]);

        hooks[0] = HookDeployment(
            SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("SpectraExchangeDepositHook", env), routerArg)
        );
        hooks[1] = HookDeployment(
            SPECTRA_EXCHANGE_REDEEM_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("SpectraExchangeRedeemHook", env), routerArg)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        SpectraExchangeHookAddresses memory hookAddresses;
        hookAddresses.spectraExchangeDepositHook = addresses[0];
        hookAddresses.spectraExchangeRedeemHook = addresses[1];

        require(hookAddresses.spectraExchangeDepositHook != address(0), "SpectraExchangeDepositHook not assigned");
        require(hookAddresses.spectraExchangeRedeemHook != address(0), "SpectraExchangeRedeemHook not assigned");

        console2.log("All Spectra Exchange hooks deployed and validated successfully.");

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
                    SPONSORSHIP CONTRACTS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy NativeFeeSponsorship (no constructor args) and FetchNativeFeeHook (takes sponsorship address)
    function _deploySponsorshipContracts(
        uint64 chainId,
        uint256 env
    )
        internal
        returns (SponsorshipAddresses memory)
    {
        // First deploy NativeFeeSponsorship (no constructor args)
        address sponsorship = __deployContract(
            NATIVE_FEE_SPONSORSHIP_KEY,
            chainId,
            __getSalt(NATIVE_FEE_SPONSORSHIP_KEY),
            __getOtherHooksBytecode("NativeFeeSponsorship", env)
        );

        // Then deploy FetchNativeFeeHook with sponsorship address as constructor arg
        bytes memory sponsorshipArg = abi.encode(sponsorship);
        address fetchHook = __deployContract(
            FETCH_NATIVE_FEE_HOOK_KEY,
            chainId,
            __getSalt(FETCH_NATIVE_FEE_HOOK_KEY),
            abi.encodePacked(__getOtherHooksBytecode("FetchNativeFeeHook", env), sponsorshipArg)
        );

        SponsorshipAddresses memory addresses;
        addresses.nativeFeeSponsorship = sponsorship;
        addresses.fetchNativeFeeHook = fetchHook;

        require(addresses.nativeFeeSponsorship != address(0), "NativeFeeSponsorship not assigned");
        require(addresses.fetchNativeFeeHook != address(0), "FetchNativeFeeHook not assigned");

        console2.log("All Sponsorship contracts deployed and validated successfully.");

        return addresses;
    }

    /*//////////////////////////////////////////////////////////////
                        RFLR HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy 5 rFLR hooks (constructor args: RNAT address, and RNAT+WFLR for withdraw hooks)
    function _deployRFLRHooks(uint64 chainId, uint256 env) internal returns (RFLRHookAddresses memory) {
        uint256 len = 5;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        hooks[0] = HookDeployment(
            CLAIM_RFLR_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("ClaimRFLRHook", env), abi.encode(RNAT_FLARE))
        );
        hooks[1] = HookDeployment(
            CLAIM_RFLRV2_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("ClaimRFLRV2Hook", env), abi.encode(RNAT_FLARE))
        );
        hooks[2] = HookDeployment(
            CLAIM_RFLRV3_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("ClaimRFLRV3Hook", env), abi.encode(RNAT_FLARE))
        );
        hooks[3] = HookDeployment(
            WITHDRAW_RFLR_HOOK_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("WithdrawRFLRHook", env), abi.encode(RNAT_FLARE, WFLR_FLARE))
        );
        hooks[4] = HookDeployment(
            WITHDRAW_VESTED_RFLR_HOOK_KEY,
            "",
            abi.encodePacked(
                __getOtherHooksBytecode("WithdrawVestedRFLRHook", env), abi.encode(RNAT_FLARE, WFLR_FLARE)
            )
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        RFLRHookAddresses memory hookAddresses;
        hookAddresses.claimRFLRHook = addresses[0];
        hookAddresses.claimRFLRV2Hook = addresses[1];
        hookAddresses.claimRFLRV3Hook = addresses[2];
        hookAddresses.withdrawRFLRHook = addresses[3];
        hookAddresses.withdrawVestedRFLRHook = addresses[4];

        require(hookAddresses.claimRFLRHook != address(0), "ClaimRFLRHook not assigned");
        require(hookAddresses.claimRFLRV2Hook != address(0), "ClaimRFLRV2Hook not assigned");
        require(hookAddresses.claimRFLRV3Hook != address(0), "ClaimRFLRV3Hook not assigned");
        require(hookAddresses.withdrawRFLRHook != address(0), "WithdrawRFLRHook not assigned");
        require(hookAddresses.withdrawVestedRFLRHook != address(0), "WithdrawVestedRFLRHook not assigned");

        console2.log("All rFLR hooks deployed and validated successfully.");

        return hookAddresses;
    }

    /// @notice Deploy 2 rFLR V2 withdraw hooks (WithdrawRFLRHookV2 + WithdrawVestedRFLRHookV2)
    function _deployRFLRV2Hooks(uint64 chainId, uint256 env) internal returns (RFLRHookV2Addresses memory) {
        uint256 len = 2;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        bytes memory rnatWflrArgs = abi.encode(RNAT_FLARE, WFLR_FLARE);

        hooks[0] = HookDeployment(
            WITHDRAW_RFLR_HOOK_V2_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("WithdrawRFLRHookV2", env), rnatWflrArgs)
        );
        hooks[1] = HookDeployment(
            WITHDRAW_VESTED_RFLR_HOOK_V2_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("WithdrawVestedRFLRHookV2", env), rnatWflrArgs)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        RFLRHookV2Addresses memory hookAddresses;
        hookAddresses.withdrawRFLRHookV2 = addresses[0];
        hookAddresses.withdrawVestedRFLRHookV2 = addresses[1];

        require(hookAddresses.withdrawRFLRHookV2 != address(0), "WithdrawRFLRHookV2 not assigned");
        require(hookAddresses.withdrawVestedRFLRHookV2 != address(0), "WithdrawVestedRFLRHookV2 not assigned");

        console2.log("All rFLR V2 hooks deployed and validated successfully.");

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

    /*//////////////////////////////////////////////////////////////
              WRAPPED NATIVE HOOK DEPLOYMENT (ETHEREUM + FLARE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy WrappedNativeHook with chain-specific wrapped native address
    /// @dev Ethereum → WETH, Flare → WFLR (same ABI for deposit/withdraw)
    function _deployWrappedNativeHook(uint64 chainId, uint256 env) internal returns (WrappedNativeHookAddress memory) {
        address wrappedNativeToken = chainId == MAINNET_CHAIN_ID ? WETH_ETHEREUM : WFLR_FLARE;
        bytes memory wflrArg = abi.encode(wrappedNativeToken);

        address wrappedNativeHook = __deployContract(
            WRAPPED_NATIVE_HOOK_KEY,
            chainId,
            __getSalt(WRAPPED_NATIVE_HOOK_KEY),
            abi.encodePacked(__getOtherHooksBytecode("WrappedNativeHook", env), wflrArg)
        );

        require(wrappedNativeHook != address(0), "WrappedNativeHook not assigned");

        console2.log("WrappedNativeHook deployed and validated successfully at:", wrappedNativeHook);

        WrappedNativeHookAddress memory hookAddress;
        hookAddress.wrappedNativeHook = wrappedNativeHook;
        return hookAddress;
    }

    /*//////////////////////////////////////////////////////////////
                        EULER HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployEulerHooks(uint64 chainId, uint256 env) internal {
        _deployEulerHooksSet(chainId, env);
    }

    /// @notice Deploy all 6 Euler V2 hooks (no constructor args — EVC and vault come from calldata)
    function _deployEulerHooksSet(
        uint64 chainId,
        uint256 env
    )
        private
        returns (EulerHookAddresses memory hookAddresses)
    {
        uint256 len = 6;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // Euler hooks have no constructor args
        hooks[0] = HookDeployment(
            EULER_DEPOSIT_COLLATERAL_HOOK_KEY, "", __getOtherHooksBytecode("EulerDepositCollateralHook", env)
        );
        hooks[1] = HookDeployment(
            EULER_BORROW_HOOK_KEY, "", __getOtherHooksBytecode("EulerBorrowHook", env)
        );
        hooks[2] = HookDeployment(
            EULER_REPAY_HOOK_KEY, "", __getOtherHooksBytecode("EulerRepayHook", env)
        );
        hooks[3] = HookDeployment(
            EULER_WITHDRAW_COLLATERAL_HOOK_KEY, "", __getOtherHooksBytecode("EulerWithdrawCollateralHook", env)
        );
        hooks[4] = HookDeployment(
            EULER_DEPOSIT_COLLATERAL_AND_BORROW_HOOK_KEY,
            "",
            __getOtherHooksBytecode("EulerDepositCollateralAndBorrowHook", env)
        );
        hooks[5] = HookDeployment(
            EULER_REPAY_AND_WITHDRAW_HOOK_KEY, "", __getOtherHooksBytecode("EulerRepayAndWithdrawHook", env)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        hookAddresses.eulerDepositCollateralHook = addresses[0];
        hookAddresses.eulerBorrowHook = addresses[1];
        hookAddresses.eulerRepayHook = addresses[2];
        hookAddresses.eulerWithdrawCollateralHook = addresses[3];
        hookAddresses.eulerDepositCollateralAndBorrowHook = addresses[4];
        hookAddresses.eulerRepayAndWithdrawHook = addresses[5];

        require(hookAddresses.eulerDepositCollateralHook != address(0), "EulerDepositCollateralHook not assigned");
        require(hookAddresses.eulerBorrowHook != address(0), "EulerBorrowHook not assigned");
        require(hookAddresses.eulerRepayHook != address(0), "EulerRepayHook not assigned");
        require(hookAddresses.eulerWithdrawCollateralHook != address(0), "EulerWithdrawCollateralHook not assigned");
        require(
            hookAddresses.eulerDepositCollateralAndBorrowHook != address(0),
            "EulerDepositCollateralAndBorrowHook not assigned"
        );
        require(hookAddresses.eulerRepayAndWithdrawHook != address(0), "EulerRepayAndWithdrawHook not assigned");

        console2.log("All Euler hooks deployed and validated successfully.");

        return hookAddresses;
    }

    /*//////////////////////////////////////////////////////////////
                      MORPHO V2 HOOKS DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployMorphoV2Hooks(uint64 chainId, uint256 env) internal {
        _deployMorphoV2HooksSet(chainId, env);
    }

    /// @notice Deploy 2 Morpho V2 corrected composite hooks (constructor arg: morpho address)
    function _deployMorphoV2HooksSet(
        uint64 chainId,
        uint256 env
    )
        private
        returns (MorphoV2HookAddresses memory hookAddresses)
    {
        uint256 len = 2;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        bytes memory morphoArg = abi.encode(otherHooksConfiguration.morphos[chainId]);

        hooks[0] = HookDeployment(
            MORPHO_SUPPLY_AND_BORROW_HOOK_V2_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoSupplyAndBorrowHookV2", env), morphoArg)
        );
        hooks[1] = HookDeployment(
            MORPHO_REPAY_AND_WITHDRAW_HOOK_V2_KEY,
            "",
            abi.encodePacked(__getOtherHooksBytecode("MorphoRepayAndWithdrawHookV2", env), morphoArg)
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
        }

        hookAddresses.morphoSupplyAndBorrowHookV2 = addresses[0];
        hookAddresses.morphoRepayAndWithdrawHookV2 = addresses[1];

        require(
            hookAddresses.morphoSupplyAndBorrowHookV2 != address(0), "MorphoSupplyAndBorrowHookV2 not assigned"
        );
        require(
            hookAddresses.morphoRepayAndWithdrawHookV2 != address(0), "MorphoRepayAndWithdrawHookV2 not assigned"
        );

        console2.log("All Morpho V2 hooks deployed and validated successfully.");

        return hookAddresses;
    }
}
