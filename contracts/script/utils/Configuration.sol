// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

abstract contract Configuration {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    error INVALID_CONFIG();

    struct SuperPositionData {
        string name;
        string symbol;
        uint8 decimals;
    }

    struct RolesData {
        bytes32 role;
        address addr;
    }

    struct EnvironmentData {
        address deployer;
        address owner;
        address paymaster;
        address bundler;
        mapping(uint64 chainId => address acrossSpokePoolV3) acrossSpokePoolV3s;
        SuperPositionData[] superPositions;
        RolesData[] externalRoles;
    }

    EnvironmentData public configuration;

    // mainnets
    uint64 public constant MAINNET_CHAIN_ID = 1;
    uint64 public constant BASE_CHAIN_ID = 8453;
    uint64 public constant OPTIMISM_CHAIN_ID = 10;
    uint64 public constant POLYGON_CHAIN_ID = 137;
    uint64 public constant ARBITRUM_CHAIN_ID = 42_161;
    // testnets
    uint64 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint64 public constant ARB_SEPOLIA_CHAIN_ID = 421_613;
    uint64 public constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint64 public constant OP_SEPOLIA_CHAIN_ID = 11_155_420;

    mapping(uint64 chainId => string chainName) internal chainNames;
    string internal constant SALT_NAMESPACE = "v2-core.v1.0.10";
    string internal constant MNEMONIC = "test test test test test test test test test test test junk";

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _setConfiguration(uint256 env) internal {
        chainNames[MAINNET_CHAIN_ID] = "Ethereum";
        chainNames[BASE_CHAIN_ID] = "Base";
        chainNames[OPTIMISM_CHAIN_ID] = "Optimism";
        chainNames[POLYGON_CHAIN_ID] = "Polygon";
        chainNames[ARBITRUM_CHAIN_ID] = "Arbitrum";
        chainNames[SEPOLIA_CHAIN_ID] = "Sepolia";
        chainNames[ARB_SEPOLIA_CHAIN_ID] = "Arbitrum_Sepolia";
        chainNames[BASE_SEPOLIA_CHAIN_ID] = "Base_Sepolia";
        chainNames[OP_SEPOLIA_CHAIN_ID] = "OP_Sepolia";

        // common configuration
        // this is the SuperDeployer address
        configuration.deployer = 0x4b38341B1126F45614B26319787CA98aeC1b6f57;

        if (env == 0) {
            configuration.owner = 0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA;
            configuration.paymaster = 0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA;
            configuration.bundler = 0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA;
        } else {
            configuration.owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
            configuration.paymaster = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
            configuration.bundler = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        }

        // chain specific configuration
        configuration.acrossSpokePoolV3s[MAINNET_CHAIN_ID] = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
        configuration.acrossSpokePoolV3s[ARB_SEPOLIA_CHAIN_ID] = 0xE248B1deEb12828788eB0e27F3BF8f0e18cfd362;
        configuration.acrossSpokePoolV3s[ARB_SEPOLIA_CHAIN_ID] = 0x7E63A5f1a8F0B4d0934B2f2327DAED3F6bb2ee75;
        configuration.acrossSpokePoolV3s[BASE_SEPOLIA_CHAIN_ID] = 0x82B564983aE7274c86695917BBf8C99ECb6F0F8F;
        configuration.acrossSpokePoolV3s[OP_SEPOLIA_CHAIN_ID] = 0x4e8E101924eDE233C13e2D8622DC8aED2872d505;
        configuration.acrossSpokePoolV3s[BASE_CHAIN_ID] = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
    }
}
