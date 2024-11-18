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
import { BaseModule } from "src/modules/BaseModule.sol";
import { Deposit4626 } from "src/hooks/erc4626/Deposit4626.sol";
import { ApproveERC20 } from "src/hooks/erc20/ApproveERC20.sol";
import { ISuperformExecutionModule } from "src/interfaces/ISuperformExecutionModule.sol";

contract Deposit4626Module is ERC7579ExecutorBase, BaseModule, ISuperformExecutionModule {
    address private _decoder;
    address public author;

    error AMOUNT_ZERO();

    constructor(address registry_, address decoder_) BaseModule(registry_) {
        _decoder = decoder_;
        author = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperformExecutionModule
    function name() external pure override returns (string memory) {
        return "Deposit4626";
    }

    /// @inheritdoc ISuperformExecutionModule
    function version() external pure override returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }

    function execute(bytes calldata data) external {
        (address vault, address account, uint256 amount) = abi.decode(data, (address, address, uint256));
        if (amount == 0) revert AMOUNT_ZERO();

        uint256 amountBefore = IERC4626(vault).totalAssets();

        // execute the approval
        IERC20 asset = IERC20(address(IERC4626(vault).asset()));
        _approveAction(asset, account, vault, amount);

        // execute the deposit
        _depositAction(account, vault, amount);

        // notify the relayer sentinel
        uint256 amountAfter = IERC4626(vault).totalAssets();
        _notifyRelayerSentinel(
            _decoder,
            superRegistry.getAddress(superRegistry.SUPER_POSITIONS_ID()),
            abi.encode(account, amountAfter - amountBefore),
            true
        );
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _approveAction(IERC20 asset, address account, address vault, uint256 amount) private {
        _execute(account, ApproveERC20.hook(asset, address(vault), amount));
    }

    function _depositAction(address account, address vault, uint256 amount) private {
        _execute(account, Deposit4626.hook(IERC4626(vault), account, amount));
    }
}
