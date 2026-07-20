// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";

import { ConfigCore } from "../../script/utils/ConfigCore.sol";
import { ConfigStargateOFTs } from "../../script/utils/ConfigStargateOFTs.sol";

contract ConfigStargateOFTsHarness is ConfigCore {
    function initialize() external {
        _setCoreConfiguration(0);
    }

    function allowedOFTCount(uint64 chainId) external view returns (uint256) {
        return configuration.stargateAllowedOFTs[chainId].length;
    }

    function allowedOFTAt(uint64 chainId, uint256 index) external view returns (address) {
        return configuration.stargateAllowedOFTs[chainId][index];
    }
}

contract ConfigStargateOFTsTest is Test {
    ConfigStargateOFTsHarness internal oftConfig;

    function setUp() public {
        oftConfig = new ConfigStargateOFTsHarness();
        oftConfig.initialize();
    }

    function test_PopulatesStableUSDT0OFTsByDestinationChain() public view {
        _assertSingleAllowedOFT(1, 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee);
        _assertSingleAllowedOFT(42_161, 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92);
        _assertSingleAllowedOFT(10, 0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD);
        _assertSingleAllowedOFT(137, 0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13);
        _assertSingleAllowedOFT(130, 0xc07bE8994D035631c36fb4a89C918CeFB2f03EC3);
        _assertSingleAllowedOFT(14, 0x567287d2A9829215a37e3B88843d32f9221E7588);
        _assertSingleAllowedOFT(988, 0xedaba024be4d87974d5aB11C6Dd586963CcCB027);
    }

    function test_LeavesChainsWithoutStablePeersEmpty() public view {
        assertEq(oftConfig.allowedOFTCount(8453), 0, "Base");
        assertEq(oftConfig.allowedOFTCount(56), 0, "BNB");
        assertEq(oftConfig.allowedOFTCount(43_114), 0, "Avalanche");
    }

    function test_ReinitializationRejectsDuplicateOFTs() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ConfigStargateOFTs.StargateOFTAlreadyConfigured.selector,
                uint64(1),
                0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee
            )
        );
        oftConfig.initialize();
    }

    function _assertSingleAllowedOFT(uint64 chainId, address expectedOFT) internal view {
        assertEq(oftConfig.allowedOFTCount(chainId), 1, "allowed OFT count");
        assertEq(oftConfig.allowedOFTAt(chainId, 0), expectedOFT, "allowed OFT");
    }
}
