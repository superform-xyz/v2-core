// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { AccountInstance } from "modulekit/ModuleKit.sol";

import { Helpers } from "./utils/Helpers.sol";

import { SpokePoolV3Mock } from "./mocks/SpokePoolV3Mock.sol";

import { SuperRegistry } from "../src/settings/SuperRegistry.sol";
import { ISuperRegistry } from "../src/interfaces/ISuperRegistry.sol";

// tokens hooks
// --- erc20
import { ApproveERC20Hook } from "../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/hooks/tokens/erc20/TransferERC20Hook.sol";
// vault hooks
// --- erc5115
import { Deposit5115VaultHook } from "../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Withdraw5115VaultHook } from "../src/hooks/vaults/5115/Withdraw5115VaultHook.sol";
// --- erc4626
import { Deposit4626VaultHook } from "../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Withdraw4626VaultHook } from "../src/hooks/vaults/4626/Withdraw4626VaultHook.sol";
// -- erc7540
import { RequestDeposit7540VaultHook } from "../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { RequestWithdraw7540VaultHook } from "../src/hooks/vaults/7540/RequestWithdraw7540VaultHook.sol";
// bridges hooks
import { AcrossExecuteOnDestinationHook } from "../src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";

abstract contract BaseTest is Helpers {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public SUPER_ACTIONS_CONFIGURATOR;
    address public user1;
    address public user2;

    uint256 public mainnetFork;
    uint256 public arbitrumFork;
    string public mainnetUrl = vm.envString("ETHEREUM_RPC_URL");
    string public arbitrumUrl = vm.envString("ARBITRUM_RPC_URL");

    ISuperRegistry public superRegistry;

    SpokePoolV3Mock public spokePoolV3Mock;

    // hooks
    address public ACTION_ORACLE_TEMP = address(0x111112);
    ApproveERC20Hook public approveErc20Hook;
    TransferERC20Hook public transferErc20Hook;
    Deposit4626VaultHook public deposit4626VaultHook;
    Withdraw4626VaultHook public withdraw4626VaultHook;
    Deposit5115VaultHook public deposit5115VaultHook;
    Withdraw5115VaultHook public withdraw5115VaultHook;
    RequestDeposit7540VaultHook public requestDeposit7540VaultHook;
    RequestWithdraw7540VaultHook public requestWithdraw7540VaultHook;
    AcrossExecuteOnDestinationHook public acrossExecuteOnDestinationHook;

    function setUp() public virtual {
        arbitrumFork = vm.createSelectFork(arbitrumUrl);
        mainnetFork = vm.createSelectFork(mainnetUrl);

        // deploy accounts
        user1 = _deployAccount(USER1_KEY, "USER1");
        user2 = _deployAccount(USER2_KEY, "USER2");
        SUPER_ACTIONS_CONFIGURATOR = _deployAccount(SUPER_ACTIONS_CONFIGURATOR_KEY, "SUPER_ACTIONS_CONFIGURATOR");

        superRegistry = ISuperRegistry(address(new SuperRegistry(address(this))));
        vm.label(address(superRegistry), "superRegistry");

        // mocks
        spokePoolV3Mock = new SpokePoolV3Mock();
        vm.label(address(spokePoolV3Mock), "SpokePoolV3Mock");

        // deploy hooks
        approveErc20Hook = new ApproveERC20Hook(address(superRegistry), address(this));
        vm.label(address(approveErc20Hook), "ApproveERC20Hook");
        transferErc20Hook = new TransferERC20Hook(address(superRegistry), address(this));
        vm.label(address(transferErc20Hook), "TransferERC20Hook");
        deposit4626VaultHook = new Deposit4626VaultHook(address(superRegistry), address(this));
        vm.label(address(deposit4626VaultHook), "Deposit4626VaultHook");
        withdraw4626VaultHook = new Withdraw4626VaultHook(address(superRegistry), address(this));
        vm.label(address(withdraw4626VaultHook), "Withdraw4626VaultHook");
        deposit5115VaultHook = new Deposit5115VaultHook(address(superRegistry), address(this));
        vm.label(address(deposit5115VaultHook), "Deposit5115VaultHook");
        withdraw5115VaultHook = new Withdraw5115VaultHook(address(superRegistry), address(this));
        vm.label(address(withdraw5115VaultHook), "Withdraw5115VaultHook");
        requestDeposit7540VaultHook = new RequestDeposit7540VaultHook(address(superRegistry), address(this));
        vm.label(address(requestDeposit7540VaultHook), "RequestDeposit7540VaultHook");
        requestWithdraw7540VaultHook = new RequestWithdraw7540VaultHook(address(superRegistry), address(this));
        vm.label(address(requestWithdraw7540VaultHook), "RequestWithdraw7540VaultHook");
        acrossExecuteOnDestinationHook =
            new AcrossExecuteOnDestinationHook(address(superRegistry), address(this), address(spokePoolV3Mock));
        vm.label(address(acrossExecuteOnDestinationHook), "AcrossExecuteOnDestinationHook");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/
    function _bound(uint256 amount_) internal pure returns (uint256) {
        amount_ = bound(amount_, SMALL, LARGE);
        return amount_;
    }

    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier inRange(uint256 amount_) {
        vm.assume(amount_ > SMALL && amount_ <= LARGE);
        _;
    }

    modifier whenAccountHasTokens(AccountInstance memory instance_, address token_) {
        _getTokens(token_, instance_.account, EXTRA_LARGE);
        _;
    }
}
