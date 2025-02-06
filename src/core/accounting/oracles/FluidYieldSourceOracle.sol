// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

// Superform
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { IFluidLendingStakingRewards } from "../../interfaces/vendors/fluid/IFluidLendingStakingRewards.sol";
import { IOracle } from "../../interfaces/vendors/awesome-oracles/IOracle.sol";
import { SuperRegistryImplementer } from "../../utils/SuperRegistryImplementer.sol";
import { SuperRegistry } from "../../settings/SuperRegistry.sol";

/// @title FluidYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Fluid yield source
contract FluidYieldSourceOracle is SuperRegistryImplementer, IYieldSourceOracle {
    /// @notice USD address constant based on ISO 4217 code
    address public constant USD = address(840);

    constructor(address _superRegistry) SuperRegistryImplementer(_superRegistry) { }

    /// @inheritdoc IYieldSourceOracle
    function decimals(address yieldSourceAddress) external view returns (uint8) {
        address rewardsToken = IFluidLendingStakingRewards(yieldSourceAddress).rewardsToken();
        return IERC20Metadata(rewardsToken).decimals();
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 pricePerShare) {
        pricePerShare = IFluidLendingStakingRewards(yieldSourceAddress).rewardPerToken();
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory pricesPerShare)
    {
        uint256 length = yieldSourceAddresses.length;
        pricesPerShare = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            address yieldAddress = yieldSourceAddresses[i];
            pricesPerShare[i] = IFluidLendingStakingRewards(yieldAddress).rewardPerToken();
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view returns (uint256 tvl) {
        tvl = IFluidLendingStakingRewards(yieldSourceAddress).balanceOf(ownerOfShares)
            * IFluidLendingStakingRewards(yieldSourceAddress).rewardPerToken();
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultiple(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares
    )
        external
        view
        returns (uint256[][] memory userTvls, uint256[] memory totalTvls)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != ownersOfShares.length) revert ARRAY_LENGTH_MISMATCH();

        userTvls = new uint256[][](length);
        totalTvls = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            address yieldSource = yieldSourceAddresses[i];
            address[] memory owners = ownersOfShares[i];
            uint256 ownersLength = owners.length;

            userTvls[i] = new uint256[](ownersLength);
            uint256 totalTvl = 0;

            for (uint256 j = 0; j < ownersLength;) {
                uint256 userTvl = getTVL(yieldSource, owners[j]);
                userTvls[i][j] = userTvl;
                totalTvl += userTvl;
                unchecked {
                    ++j;
                }
            }

            totalTvls[i] = totalTvl;
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareUSD(
        address yieldSourceAddress,
        address base
    )
        external
        view
        returns (uint256 pricePerShareUSD)
    {
        // For Fluid, base must match the staking token
        if (base != IFluidLendingStakingRewards(yieldSourceAddress).stakingToken()) revert INVALID_BASE_ASSET();

        // Get price per share in base asset terms
        uint256 baseAmount = getPricePerShare(yieldSourceAddress);

        // Convert to USD using oracle registry
        pricePerShareUSD = _getOracleRegistry().getQuote(baseAmount, base, USD);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses
    )
        external
        view
        returns (uint256[] memory pricesPerShareUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != baseAddresses.length) revert ARRAY_LENGTH_MISMATCH();

        pricesPerShareUSD = new uint256[](length);
        IOracle registry = _getOracleRegistry();

        for (uint256 i = 0; i < length;) {
            // For Fluid, base must match the staking token
            if (baseAddresses[i] != IFluidLendingStakingRewards(yieldSourceAddresses[i]).stakingToken()) {
                revert INVALID_BASE_ASSET();
            }

            // Get price per share in base asset terms
            uint256 baseAmount = getPricePerShare(yieldSourceAddresses[i]);

            // Convert to USD using oracle registry
            pricesPerShareUSD[i] = registry.getQuote(baseAmount, baseAddresses[i], USD);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLUSD(
        address yieldSourceAddress,
        address ownerOfShares,
        address base
    )
        external
        view
        returns (uint256 tvlUSD)
    {
        // For Fluid, base must match the staking token
        if (base != IFluidLendingStakingRewards(yieldSourceAddress).stakingToken()) revert INVALID_BASE_ASSET();

        // Get TVL in base asset terms
        uint256 baseAmount = getTVL(yieldSourceAddress, ownerOfShares);

        // Convert to USD using oracle registry
        tvlUSD = _getOracleRegistry().getQuote(baseAmount, base, USD);
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses
    )
        external
        view
        returns (uint256[][] memory userTvlsUSD, uint256[] memory totalTvlsUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != ownersOfShares.length || length != baseAddresses.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        userTvlsUSD = new uint256[][](length);
        totalTvlsUSD = new uint256[](length);
        IOracle registry = _getOracleRegistry();

        for (uint256 i = 0; i < length;) {
            // For Fluid, base must match the staking token
            if (baseAddresses[i] != IFluidLendingStakingRewards(yieldSourceAddresses[i]).stakingToken()) {
                revert INVALID_BASE_ASSET();
            }

            address yieldSource = yieldSourceAddresses[i];
            address[] memory owners = ownersOfShares[i];
            uint256 ownersLength = owners.length;

            userTvlsUSD[i] = new uint256[](ownersLength);
            uint256 totalTvlUSD = 0;

            for (uint256 j = 0; j < ownersLength;) {
                // Get TVL in base asset terms
                uint256 baseAmount = getTVL(yieldSource, owners[j]);

                // Convert to USD using oracle registry
                uint256 userTvlUSD = registry.getQuote(baseAmount, baseAddresses[i], USD);
                userTvlsUSD[i][j] = userTvlUSD;
                totalTvlUSD += userTvlUSD;

                unchecked {
                    ++j;
                }
            }

            totalTvlsUSD[i] = totalTvlUSD;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns the oracle registry from SuperRegistry
    /// @return registry The oracle registry contract
    function _getOracleRegistry() internal view returns (IOracle) {
        return IOracle(superRegistry.getAddress(superRegistry.ORACLE_REGISTRY_ID()));
    }
}
