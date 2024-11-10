// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuardTransient } from "../utils/ReentrancyGuardTransient.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform
import { ISuperformVault } from "../interfaces/ISuperformVault.sol";

contract SuperformVault is ERC20, ReentrancyGuardTransient, ISuperformVault {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable asset;

    constructor(IERC20 asset_, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        asset = asset_;
    }
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperformVault

    function previewDeposit(uint256 assets_) public view override returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            return assets_;
        } else {
            return (assets_ * totalSupply_) / totalAssets();
        }
    }

    /// @inheritdoc ISuperformVault
    function previewWithdraw(uint256 assets_) public view override returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) revert NO_SHARES_MINTED();
        return (assets_ * totalSupply_) / totalAssets();
    }

    /// @inheritdoc ISuperformVault
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperformVault
    function deposit(uint256 assets_, address receiver_) external override nonReentrant returns (uint256 shares_) {
        if (assets_ == 0) revert DEPOSIT_ZERO();
        shares_ = previewDeposit(assets_);
        if (shares_ == 0) revert SHARES_ZERO();

        asset.safeTransferFrom(msg.sender, address(this), assets_);
        _mint(receiver_, shares_);

        emit Deposit(msg.sender, receiver_, assets_, shares_);
    }

    /// @inheritdoc ISuperformVault
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    )
        external
        override
        nonReentrant
        returns (uint256 shares_)
    {
        shares_ = previewWithdraw(assets_);
        if (shares_ == 0) revert SHARES_ZERO();

        if (msg.sender != owner_) {
            uint256 allowed_ = allowance(owner_, msg.sender);
            if (allowed_ < shares_) revert INSUFFICIENT_ALLOWANCE();
            _approve(owner_, msg.sender, allowed_ - shares_);
        }

        _burn(owner_, shares_);
        asset.safeTransfer(receiver_, assets_);

        emit Withdraw(msg.sender, receiver_, owner_, assets_, shares_);
    }
}
