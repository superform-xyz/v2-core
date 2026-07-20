// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { ConfigBase } from "./ConfigBase.sol";

/// @title ConfigStargateOFTs
/// @notice Canonical registry of non-pool Stargate OFTs accepted by StargateAdapterV2
/// @dev Register each OFT against the chain where that OFT is deployed. The resulting per-chain arrays are supplied to
///      StargateAdapterV2 as constructor arguments, so changing this registry requires deploying a new adapter.
abstract contract ConfigStargateOFTs is ConfigBase {
    error StargateOFTAddressZero(uint64 chainId);
    error StargateOFTAlreadyConfigured(uint64 chainId, address oft);

    // USDT0 OFTs connected to the Stable USDT0 deployment.
    address internal constant USDT0_OFT_ETHEREUM = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee;
    address internal constant USDT0_OFT_ARBITRUM = 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92;
    address internal constant USDT0_OFT_OPTIMISM = 0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD;
    address internal constant USDT0_OFT_POLYGON = 0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13;
    address internal constant USDT0_OFT_UNICHAIN = 0xc07bE8994D035631c36fb4a89C918CeFB2f03EC3;
    address internal constant USDT0_OFT_FLARE = 0x567287d2A9829215a37e3B88843d32f9221E7588;
    address internal constant USDT0_OFT_STABLE = 0xedaba024be4d87974d5aB11C6Dd586963CcCB027;

    /// @notice Populates the per-chain OFT allowlists consumed by StargateAdapterV2 deployments
    function _setStargateOFTConfiguration() internal {
        _allowStargateOFT(MAINNET_CHAIN_ID, USDT0_OFT_ETHEREUM);
        _allowStargateOFT(ARBITRUM_CHAIN_ID, USDT0_OFT_ARBITRUM);
        _allowStargateOFT(OPTIMISM_CHAIN_ID, USDT0_OFT_OPTIMISM);
        _allowStargateOFT(POLYGON_CHAIN_ID, USDT0_OFT_POLYGON);
        _allowStargateOFT(UNICHAIN_CHAIN_ID, USDT0_OFT_UNICHAIN);
        _allowStargateOFT(FLARE_CHAIN_ID, USDT0_OFT_FLARE);
        _allowStargateOFT(STABLE_CHAIN_ID, USDT0_OFT_STABLE);
    }

    function _allowStargateOFT(uint64 chainId, address oft) private {
        if (oft == address(0)) revert StargateOFTAddressZero(chainId);

        address[] storage configuredOFTs = configuration.stargateAllowedOFTs[chainId];
        for (uint256 i; i < configuredOFTs.length; ++i) {
            if (configuredOFTs[i] == oft) revert StargateOFTAlreadyConfigured(chainId, oft);
        }

        configuredOFTs.push(oft);
    }
}
