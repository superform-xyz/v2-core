// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// modulekit
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { IERC7579Account, Execution } from "modulekit/Accounts.sol";

// Superform
import { ApproveERC20 } from "src/hooks/ApproveERC20.sol";
import { Deposit4626 } from "src/hooks/Deposit4626.sol";
import { BaseModule } from "src/modules/BaseModule.sol";
import { ISuperformVault } from "src/interfaces/ISuperformVault.sol";

import "forge-std/console.sol";

contract Deposit4626Module is ERC7579ExecutorBase, BaseModule {
    address private _decoder;

    error AMOUNT_ZERO();

    constructor(address registry_, address decoder_) BaseModule(registry_) {
        _decoder = decoder_;
    }

    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }

    function isInitialized(address) external view returns (bool) {
        return true;
    }

    function name() external pure returns (string memory) {
        return "Deposit4626";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function execute(bytes calldata data) external {
        (address vault, address account, uint256 amount) = abi.decode(data, (address, address, uint256));
        if (amount == 0) revert AMOUNT_ZERO();

        uint256 amountBefore = ISuperformVault(vault).totalAssets();
        console.log("           |____________");
        console.log("           execution started; amount before %s", amountBefore);

        IERC20 asset = IERC20(address(ISuperformVault(vault).asset()));
        // execute the approval
        _approveAction(asset, account, vault, amount);
        console.log("                approve asset");

        // execute the deposit
        _depositAction(account, vault, amount);

        console.log("                deposit asset");
        uint256 amountAfter = ISuperformVault(vault).totalAssets();
        console.log("           execution ended; amount after %s", amountAfter);
        console.log("           relayer notified - example call");
        _notifyRelayerSentinel(_decoder, abi.encode(account, amountAfter - amountBefore), true);
        console.log("           _|");
    }

    function _approveAction(IERC20 asset, address account, address vault, uint256 amount) private {
        _execute(account, ApproveERC20.hook(asset, address(vault), amount));
    }

    function _depositAction(address account, address vault, uint256 amount) private {
        _execute(account, Deposit4626.hook(IERC4626(vault), account, amount));
    }
}
