// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Addresses, BaseTest } from "../BaseTest.t.sol";

// token hooks
// --- erc20
import { ApproveWithPermit2Hook } from "../../src/hooks/tokens/erc20/ApproveWithPermit2Hook.sol";
import { PermitWithPermit2Hook } from "../../src/hooks/tokens/erc20/PermitWithPermit2Hook.sol";
import { TransferBatchWithPermit2Hook } from "../../src/hooks/tokens/erc20/TransferBatchWithPermit2Hook.sol";
import { TransferWithPermit2Hook } from "../../src/hooks/tokens/erc20/TransferWithPermit2Hook.sol";

// vault hooks
// -- erc7540
import { Deposit7540VaultHook } from "../../src/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../../src/hooks/vaults/7540/Withdraw7540VaultHook.sol";

// Swap hooks
import { Base1InchHook } from "../../src/hooks/swapers/1inch/Base1InchHook.sol";
import { Swap1InchClipperRouterHook } from "../../src/hooks/swapers/1inch/Swap1InchClipperRouterHook.sol";
import { Swap1InchGenericRouterHook } from "../../src/hooks/swapers/1inch/Swap1InchGenericRouterHook.sol";
import { Swap1InchUnoswapHook } from "../../src/hooks/swapers/1inch/Swap1InchUnoswapHook.sol";

// Staking hooks
// --- Gearbox
import { GearboxStakeHook } from "../../src/hooks/stake/gearbox/GearboxStakeHook.sol";
import { GearboxWithdrawHook } from "../../src/hooks/stake/gearbox/GearboxWithdrawHook.sol";
// --- Somelier
import { SomelierStakeHook } from "../../src/hooks/stake/somelier/SomelierStakeHook.sol";
import { SomelierUnbondAllHook } from "../../src/hooks/stake/somelier/SomelierUnbondAllHook.sol";
import { SomelierUnbondHook } from "../../src/hooks/stake/somelier/SomelierUnbondHook.sol";
import { SomelierUnstakeAllHook } from "../../src/hooks/stake/somelier/SomelierUnstakeAllHook.sol";
import { SomelierUnstakeHook } from "../../src/hooks/stake/somelier/SomelierUnstakeHook.sol";
// --- Yearn
// import { YearnStakeHook } from "../../src/hooks/stake/yearn/YearnStakeHook.sol";
import { YearnWithdrawHook } from "../../src/hooks/stake/yearn/YearnWithdrawHook.sol";
// --- Generic
import { YieldExitHook } from "../../src/hooks/stake/YieldExitHook.sol";

// Claim Hooks
// --- Fluid
import { FluidClaimRewardHook } from "../../src/hooks/claim/fluid/FluidClaimRewardHook.sol";
// --- Gearbox
import { GearboxClaimRewardHook } from "../../src/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
// --- Somelier
import { SomelierClaimAllRewardsHook } from "../../src/hooks/claim/somelier/SomelierClaimAllRewardsHook.sol";
import { SomelierClaimOneRewardHook } from "../../src/hooks/claim/somelier/SomelierClaimOneRewardHook.sol";
// --- Yearn
import { YearnClaimAllRewardsHook } from "../../src/hooks/claim/yearn/YearnClaimAllRewardsHook.sol";
import { YearnClaimOneRewardHook } from "../../src/hooks/claim/yearn/YearnClaimOneRewardHook.sol";


contract MockHookRegistry is BaseTest {

    function setUp() public override {
        super.setUp();
        _deployAdditionalHooks();
    }

    function getHook(uint64 chainId, string memory name) public view returns (Hook memory) {
        return hooks[chainId][name];
    }

    function getHookDependancy(uint64 chainId, string memory name) public view returns (HookCategory) {
        return hooks[chainId][name].dependency;
    }

    function getHookByCategory(uint64 chainId, HookCategory category) public view returns (Hook[] memory) {
        return hooksByCategory[chainId][category];
    }

    function _deployAdditionalHooks() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            Addresses memory A;

            A.approveWithPermit2Hook 
            = new ApproveWithPermit2Hook(
                address(A.superRegistry), 
                address(this),
                 0x000000000022D473030F116dDEE9F6B43aC78BA3 // Permit2 address on ETH, Base and OP
            ); 
            vm.label(address(A.approveWithPermit2Hook), "ApproveWithPermit2Hook");
            hookAddresses[chainIds[i]]["ApproveWithPermit2Hook"] = address(A.approveWithPermit2Hook);
            hooks[chainIds[i]]["ApproveWithPermit2Hook"] 
            = Hook(
                "ApproveWithPermit2Hook", 
                HookCategory.TokenApprovals, 
                HookCategory.None, 
                address(A.approveWithPermit2Hook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.TokenApprovals].push(hooks[chainIds[i]]["ApproveWithPermit2Hook"]);

            A.permitWithPermit2Hook = 
            new PermitWithPermit2Hook(
                address(A.superRegistry), 
                address(this), 
                0x000000000022D473030F116dDEE9F6B43aC78BA3
            );
            vm.label(address(A.permitWithPermit2Hook), "PermitWithPermit2Hook");
            hookAddresses[chainIds[i]]["PermitWithPermit2Hook"] = address(A.permitWithPermit2Hook);
            hooks[chainIds[i]]["PermitWithPermit2Hook"] 
            = Hook(
                "PermitWithPermit2Hook", 
                HookCategory.TokenApprovals, 
                HookCategory.None, 
                address(A.permitWithPermit2Hook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.TokenApprovals].push(hooks[chainIds[i]]["PermitWithPermit2Hook"]);
            A.deposit7540VaultHook = new Deposit7540VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.deposit7540VaultHook), "Deposit7540VaultHook");
            hookAddresses[chainIds[i]]["Deposit7540VaultHook"] = address(A.deposit7540VaultHook);
            hooks[chainIds[i]]["Deposit7540VaultHook"] 
            = Hook(
                "Deposit7540VaultHook", 
                HookCategory.VaultDeposits, 
                HookCategory.TokenApprovals, 
                address(A.deposit7540VaultHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(hooks[chainIds[i]]["Deposit7540VaultHook"]);

            A.withdraw7540VaultHook = new Withdraw7540VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.withdraw7540VaultHook), "Withdraw7540VaultHook");
            hookAddresses[chainIds[i]]["Withdraw7540VaultHook"] = address(A.withdraw7540VaultHook);
            hooks[chainIds[i]]["Withdraw7540VaultHook"] 
            = Hook(
                "Withdraw7540VaultHook", 
                HookCategory.VaultWithdrawals, 
                HookCategory.VaultDeposits, 
                address(A.withdraw7540VaultHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(hooks[chainIds[i]]["Withdraw7540VaultHook"]);
            A.swap1InchClipperRouterHook = 
            new Swap1InchClipperRouterHook(
                address(A.superRegistry), 
                address(this), 
                0x111111125421cA6dc452d289314280a0f8842A65
            );
            vm.label(address(A.swap1InchClipperRouterHook), "Swap1InchClipperRouterHook");
            hookAddresses[chainIds[i]]["Swap1InchClipperRouterHook"] = address(A.swap1InchClipperRouterHook);
            hooks[chainIds[i]]["Swap1InchClipperRouterHook"] 
            = Hook(
                "Swap1InchClipperRouterHook", 
                HookCategory.Swaps, 
                HookCategory.TokenApprovals, 
                address(A.swap1InchClipperRouterHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]]["Swap1InchClipperRouterHook"]);

            A.swap1InchGenericRouterHook 
            = new Swap1InchGenericRouterHook(
                address(A.superRegistry), 
                address(this), 
                0x111111125421cA6dc452d289314280a0f8842A65
            );
            vm.label(address(A.swap1InchGenericRouterHook), "Swap1InchGenericRouterHook");
            hookAddresses[chainIds[i]]["Swap1InchGenericRouterHook"] = address(A.swap1InchGenericRouterHook);
            hooks[chainIds[i]]["Swap1InchGenericRouterHook"] 
            = Hook(
                "Swap1InchGenericRouterHook", 
                HookCategory.Swaps, 
                HookCategory.TokenApprovals, 
                address(A.swap1InchGenericRouterHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]]["Swap1InchGenericRouterHook"]);
            A.swap1InchUnoswapHook 
            = new Swap1InchUnoswapHook(
                address(A.superRegistry), 
                address(this), 
                0x111111125421cA6dc452d289314280a0f8842A65
            );
            vm.label(address(A.swap1InchUnoswapHook), "Swap1InchUnoswapHook");
            hookAddresses[chainIds[i]]["Swap1InchUnoswapHook"] = address(A.swap1InchUnoswapHook);
            hooks[chainIds[i]]["Swap1InchUnoswapHook"] 
            = Hook(
                "Swap1InchUnoswapHook", 
                HookCategory.Swaps, 
                HookCategory.TokenApprovals, 
                address(A.swap1InchUnoswapHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]]["Swap1InchUnoswapHook"]);

            A.gearboxStakeHook = new GearboxStakeHook(address(A.superRegistry), address(this));
            vm.label(address(A.gearboxStakeHook), "GearboxStakeHook");
            hookAddresses[chainIds[i]]["GearboxStakeHook"] = address(A.gearboxStakeHook);
            hooks[chainIds[i]]["GearboxStakeHook"] 
            = Hook(
                "GearboxStakeHook", 
                HookCategory.Stakes, 
                HookCategory.VaultDeposits, 
                address(A.gearboxStakeHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Stakes].push(hooks[chainIds[i]]["GearboxStakeHook"]);
            A.gearboxWithdrawHook = new GearboxWithdrawHook(address(A.superRegistry), address(this));
            vm.label(address(A.gearboxWithdrawHook), "GearboxWithdrawHook");
            hookAddresses[chainIds[i]]["GearboxWithdrawHook"] = address(A.gearboxWithdrawHook);
            hooks[chainIds[i]]["GearboxWithdrawHook"] 
            = Hook(
                "GearboxWithdrawHook", 
                HookCategory.Claims, 
                HookCategory.Stakes, 
                address(A.gearboxWithdrawHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]]["GearboxWithdrawHook"]);

            A.somelierStakeHook = new SomelierStakeHook(address(A.superRegistry), address(this));
            vm.label(address(A.somelierStakeHook), "SomelierStakeHook");
            hookAddresses[chainIds[i]]["SomelierStakeHook"] = address(A.somelierStakeHook);
            hooks[chainIds[i]]["SomelierStakeHook"] 
            = Hook(
                "SomelierStakeHook", 
                HookCategory.Stakes, 
                HookCategory.VaultDeposits, 
                address(A.somelierStakeHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Stakes].push(hooks[chainIds[i]]["SomelierStakeHook"]);
            A.somelierUnbondAllHook = new SomelierUnbondAllHook(address(A.superRegistry), address(this));
            vm.label(address(A.somelierUnbondAllHook), "SomelierUnbondAllHook");
            hookAddresses[chainIds[i]]["SomelierUnbondAllHook"] = address(A.somelierUnbondAllHook);
            hooks[chainIds[i]]["SomelierUnbondAllHook"] 
            = Hook(
                "SomelierUnbondAllHook", 
                HookCategory.Claims, 
                HookCategory.Stakes, 
                address(A.somelierUnbondAllHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]]["SomelierUnbondAllHook"]);

            A.somelierUnbondHook = new SomelierUnbondHook(address(A.superRegistry), address(this));
            vm.label(address(A.somelierUnbondHook), "SomelierUnbondHook");
            hookAddresses[chainIds[i]]["SomelierUnbondHook"] = address(A.somelierUnbondHook);
            hooks[chainIds[i]]["SomelierUnbondHook"] 
            = Hook(
                "SomelierUnbondHook", 
                HookCategory.Claims, 
                HookCategory.Stakes, 
                address(A.somelierUnbondHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]]["SomelierUnbondHook"]);
            A.somelierUnstakeAllHook = new SomelierUnstakeAllHook(address(A.superRegistry), address(this));
            vm.label(address(A.somelierUnstakeAllHook), "SomelierUnstakeAllHook");
            hookAddresses[chainIds[i]]["SomelierUnstakeAllHook"] = address(A.somelierUnstakeAllHook);
            hooks[chainIds[i]]["SomelierUnstakeAllHook"] 
            = Hook(
                "SomelierUnstakeAllHook", 
                HookCategory.Stakes, 
                HookCategory.VaultDeposits, 
                address(A.somelierUnstakeAllHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]]["SomelierUnstakeAllHook"]);

            A.yearnClaimOneRewardHook = new YearnClaimOneRewardHook(address(A.superRegistry), address(this));
            vm.label(address(A.yearnClaimOneRewardHook), "YearnClaimOneRewardHook");
            hookAddresses[chainIds[i]]["YearnClaimOneRewardHook"] = address(A.yearnClaimOneRewardHook);
            hooks[chainIds[i]]["YearnClaimOneRewardHook"] 
            = Hook(
                "YearnClaimOneRewardHook", 
                HookCategory.Claims, 
                HookCategory.Stakes, 
                address(A.yearnClaimOneRewardHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]]["YearnClaimOneRewardHook"]);
            A.yearnClaimAllRewardsHook = new YearnClaimAllRewardsHook(address(A.superRegistry), address(this));
            vm.label(address(A.yearnClaimAllRewardsHook), "YearnClaimAllRewardsHook");
            hookAddresses[chainIds[i]]["YearnClaimAllRewardsHook"] = address(A.yearnClaimAllRewardsHook);
            hooks[chainIds[i]]["YearnClaimAllRewardsHook"] 
            = Hook(
                "YearnClaimAllRewardsHook", 
                HookCategory.Claims, 
                HookCategory.Stakes, 
                address(A.yearnClaimAllRewardsHook), 
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]]["YearnClaimAllRewardsHook"]);
        }
    }

}
