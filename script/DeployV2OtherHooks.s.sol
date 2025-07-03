// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";
import { ConfigOtherHooks } from "./utils/ConfigOtherHooks.sol";

// -- hooks for other deployments (non-early access)
// ---- | claim
import { FluidClaimRewardHook } from "../src/core/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { GearboxClaimRewardHook } from "../src/core/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
import { YearnClaimOneRewardHook } from "../src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol";

// ---- | stake
import { ApproveAndGearboxStakeHook } from "../src/core/hooks/stake/gearbox/ApproveAndGearboxStakeHook.sol";
import { GearboxStakeHook } from "../src/core/hooks/stake/gearbox/GearboxStakeHook.sol";
import { GearboxUnstakeHook } from "../src/core/hooks/stake/gearbox/GearboxUnstakeHook.sol";
import { FluidStakeHook } from "../src/core/hooks/stake/fluid/FluidStakeHook.sol";
import { FluidUnstakeHook } from "../src/core/hooks/stake/fluid/FluidUnstakeHook.sol";
import { ApproveAndFluidStakeHook } from "../src/core/hooks/stake/fluid/ApproveAndFluidStakeHook.sol";

// ---- | loan
import { MorphoSupplyAndBorrowHook } from "../src/core/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { MorphoRepayHook } from "../src/core/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoRepayAndWithdrawHook } from "../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { MorphoBorrowHook } from "../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";

// ---- | swappers/pendle
import { PendleRouterSwapHook } from "../src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol";
import { PendleRouterRedeemHook } from "../src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol";

// ---- | swappers/spectra
import { SpectraExchangeDepositHook } from "../src/core/hooks/swappers/spectra/SpectraExchangeDepositHook.sol";
import { SpectraExchangeRedeemHook } from "../src/core/hooks/swappers/spectra/SpectraExchangeRedeemHook.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployV2OtherHooks is DeployV2Base, ConfigOtherHooks {
    struct OtherHookAddresses {
        address fluidClaimRewardHook;
        address gearboxClaimRewardHook;
        address yearnClaimOneRewardHook;
        address gearboxStakeHook;
        address approveAndGearboxStakeHook;
        address gearboxUnstakeHook;
        address fluidStakeHook;
        address approveAndFluidStakeHook;
        address fluidUnstakeHook;
        address spectraExchangeDepositHook;
        address spectraExchangeRedeemHook;
        address pendleRouterSwapHook;
        address pendleRouterRedeemHook;
        address morphoSupplyAndBorrowHook;
        address morphoRepayHook;
        address morphoRepayAndWithdrawHook;
        address morphoBorrowHook;
    }

    struct HookDeployment {
        string name;
        bytes creationCode;
    }

    /// @notice Sets up complete configuration for other hooks deployment
    /// @param env Environment (0/2 = production, 1 = test)
    /// @param saltNamespace Salt namespace for deterministic deployments
    function _setConfiguration(uint256 env, string memory saltNamespace) internal {
        // Set base configuration (chain names, common addresses)
        _setBaseConfiguration(env, saltNamespace);

        // Set protocol router addresses for hooks
        _setOtherHooksConfiguration();
    }

    function run(uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        console2.log("Deploying V2 Other Hooks on chainId: ", chainId);

        _deployDeployer();

        // deploy other hooks
        _deployOtherHooks(chainId);

        // Write all exported contracts for this chain
        _writeExportedContracts(chainId);
    }

    function _deployOtherHooks(uint64 chainId) internal {
        // retrieve deployer
        ISuperDeployer deployer = ISuperDeployer(configuration.deployer);

        // Deploy Other Hooks
        _deployHooksSet(deployer, chainId);
    }

    function _deployHooksSet(
        ISuperDeployer deployer,
        uint64 chainId
    )
        private
        returns (OtherHookAddresses memory hookAddresses)
    {
        uint256 len = 17;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // Claim hooks
        hooks[0] = HookDeployment(FLUID_CLAIM_REWARD_HOOK_KEY, type(FluidClaimRewardHook).creationCode);
        hooks[1] = HookDeployment(GEARBOX_CLAIM_REWARD_HOOK_KEY, type(GearboxClaimRewardHook).creationCode);
        hooks[2] = HookDeployment(YEARN_CLAIM_ONE_REWARD_HOOK_KEY, type(YearnClaimOneRewardHook).creationCode);

        // Stake hooks
        hooks[3] = HookDeployment(FLUID_STAKE_HOOK_KEY, type(FluidStakeHook).creationCode);
        hooks[4] = HookDeployment(APPROVE_AND_FLUID_STAKE_HOOK_KEY, type(ApproveAndFluidStakeHook).creationCode);
        hooks[5] = HookDeployment(FLUID_UNSTAKE_HOOK_KEY, type(FluidUnstakeHook).creationCode);
        hooks[6] = HookDeployment(GEARBOX_STAKE_HOOK_KEY, type(GearboxStakeHook).creationCode);
        hooks[7] = HookDeployment(GEARBOX_APPROVE_AND_STAKE_HOOK_KEY, type(ApproveAndGearboxStakeHook).creationCode);
        hooks[8] = HookDeployment(GEARBOX_UNSTAKE_HOOK_KEY, type(GearboxUnstakeHook).creationCode);

        // Spectra swapper hooks
        hooks[9] = HookDeployment(
            SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY,
            abi.encodePacked(
                type(SpectraExchangeDepositHook).creationCode, abi.encode(configuration.spectraRouters[chainId])
            )
        );
        hooks[10] = HookDeployment(
            SPECTRA_EXCHANGE_REDEEM_HOOK_KEY,
            abi.encodePacked(
                type(SpectraExchangeRedeemHook).creationCode, abi.encode(configuration.spectraRouters[chainId])
            )
        );

        // Pendle swapper hooks
        hooks[11] = HookDeployment(
            PENDLE_ROUTER_SWAP_HOOK_KEY,
            abi.encodePacked(type(PendleRouterSwapHook).creationCode, abi.encode(configuration.pendleRouters[chainId]))
        );
        hooks[12] = HookDeployment(
            PENDLE_ROUTER_REDEEM_HOOK_KEY,
            abi.encodePacked(
                type(PendleRouterRedeemHook).creationCode, abi.encode(configuration.pendleRouters[chainId])
            )
        );

        // Morpho loan hooks
        hooks[13] = HookDeployment(
            MORPHO_SUPPLY_AND_BORROW_HOOK_KEY,
            abi.encodePacked(type(MorphoSupplyAndBorrowHook).creationCode, abi.encode(MORPHO))
        );
        hooks[14] = HookDeployment(
            MORPHO_REPAY_HOOK_KEY, abi.encodePacked(type(MorphoRepayHook).creationCode, abi.encode(MORPHO))
        );
        hooks[15] = HookDeployment(
            MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY,
            abi.encodePacked(type(MorphoRepayAndWithdrawHook).creationCode, abi.encode(MORPHO))
        );
        hooks[16] = HookDeployment(
            MORPHO_BORROW_ONLY_HOOK_KEY, abi.encodePacked(type(MorphoBorrowHook).creationCode, abi.encode(MORPHO))
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            addresses[i] = __deployContract(
                deployer,
                hook.name,
                chainId,
                __getSalt(configuration.owner, configuration.deployer, hook.name),
                hook.creationCode
            );
        }

        // Assign hook addresses
        hookAddresses.fluidClaimRewardHook =
            Strings.equal(hooks[0].name, FLUID_CLAIM_REWARD_HOOK_KEY) ? addresses[0] : address(0);
        hookAddresses.gearboxClaimRewardHook =
            Strings.equal(hooks[1].name, GEARBOX_CLAIM_REWARD_HOOK_KEY) ? addresses[1] : address(0);
        hookAddresses.yearnClaimOneRewardHook =
            Strings.equal(hooks[2].name, YEARN_CLAIM_ONE_REWARD_HOOK_KEY) ? addresses[2] : address(0);
        hookAddresses.fluidStakeHook = Strings.equal(hooks[3].name, FLUID_STAKE_HOOK_KEY) ? addresses[3] : address(0);
        hookAddresses.approveAndFluidStakeHook =
            Strings.equal(hooks[4].name, APPROVE_AND_FLUID_STAKE_HOOK_KEY) ? addresses[4] : address(0);
        hookAddresses.fluidUnstakeHook =
            Strings.equal(hooks[5].name, FLUID_UNSTAKE_HOOK_KEY) ? addresses[5] : address(0);
        hookAddresses.gearboxStakeHook =
            Strings.equal(hooks[6].name, GEARBOX_STAKE_HOOK_KEY) ? addresses[6] : address(0);
        hookAddresses.approveAndGearboxStakeHook =
            Strings.equal(hooks[7].name, GEARBOX_APPROVE_AND_STAKE_HOOK_KEY) ? addresses[7] : address(0);
        hookAddresses.gearboxUnstakeHook =
            Strings.equal(hooks[8].name, GEARBOX_UNSTAKE_HOOK_KEY) ? addresses[8] : address(0);
        hookAddresses.spectraExchangeDepositHook =
            Strings.equal(hooks[9].name, SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY) ? addresses[9] : address(0);
        hookAddresses.spectraExchangeRedeemHook =
            Strings.equal(hooks[10].name, SPECTRA_EXCHANGE_REDEEM_HOOK_KEY) ? addresses[10] : address(0);
        hookAddresses.pendleRouterSwapHook =
            Strings.equal(hooks[11].name, PENDLE_ROUTER_SWAP_HOOK_KEY) ? addresses[11] : address(0);
        hookAddresses.pendleRouterRedeemHook =
            Strings.equal(hooks[12].name, PENDLE_ROUTER_REDEEM_HOOK_KEY) ? addresses[12] : address(0);
        hookAddresses.morphoSupplyAndBorrowHook =
            Strings.equal(hooks[13].name, MORPHO_SUPPLY_AND_BORROW_HOOK_KEY) ? addresses[13] : address(0);
        hookAddresses.morphoRepayHook =
            Strings.equal(hooks[14].name, MORPHO_REPAY_HOOK_KEY) ? addresses[14] : address(0);
        hookAddresses.morphoRepayAndWithdrawHook =
            Strings.equal(hooks[15].name, MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY) ? addresses[15] : address(0);
        hookAddresses.morphoBorrowHook =
            Strings.equal(hooks[16].name, MORPHO_BORROW_ONLY_HOOK_KEY) ? addresses[16] : address(0);

        // Verify no hooks were assigned address(0)
        require(hookAddresses.fluidClaimRewardHook != address(0), "fluidClaimRewardHook not assigned");
        require(hookAddresses.gearboxClaimRewardHook != address(0), "gearboxClaimRewardHook not assigned");
        require(hookAddresses.yearnClaimOneRewardHook != address(0), "yearnClaimOneRewardHook not assigned");
        require(hookAddresses.fluidStakeHook != address(0), "fluidStakeHook not assigned");
        require(hookAddresses.approveAndFluidStakeHook != address(0), "approveAndFluidStakeHook not assigned");
        require(hookAddresses.fluidUnstakeHook != address(0), "fluidUnstakeHook not assigned");
        require(hookAddresses.gearboxStakeHook != address(0), "gearboxStakeHook not assigned");
        require(hookAddresses.approveAndGearboxStakeHook != address(0), "approveAndGearboxStakeHook not assigned");
        require(hookAddresses.gearboxUnstakeHook != address(0), "gearboxUnstakeHook not assigned");
        require(hookAddresses.spectraExchangeDepositHook != address(0), "spectraExchangeDepositHook not assigned");
        require(hookAddresses.spectraExchangeRedeemHook != address(0), "spectraExchangeRedeemHook not assigned");
        require(hookAddresses.pendleRouterSwapHook != address(0), "pendleRouterSwapHook not assigned");
        require(hookAddresses.pendleRouterRedeemHook != address(0), "pendleRouterRedeemHook not assigned");
        require(hookAddresses.morphoSupplyAndBorrowHook != address(0), "MorphoSupplyAndBorrowHook not assigned");
        require(hookAddresses.morphoRepayHook != address(0), "morphoRepayHook not assigned");
        require(hookAddresses.morphoRepayAndWithdrawHook != address(0), "morphoRepayAndWithdrawHook not assigned");
        require(hookAddresses.morphoBorrowHook != address(0), "morphoBorrowHook not assigned");

        console2.log("All other hooks deployed and validated successfully.");

        return hookAddresses;
    }
}
