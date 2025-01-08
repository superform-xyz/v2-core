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
        uint64 chainId;
        address owner;
        address acrossSpokePoolV3;
        address paymaster;
        SuperPositionData[] superPositions;
        RolesData[] externalRoles;
    }

    enum DeployChain {
        MAINNET,
        TESTNET1,
        TESTNET2
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

    mapping(uint64 chainId => string chainName) internal chainNames;
    string internal constant SALT_NAMESPACE = "v2-core.v1.4";

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _setAllChainsConfiguration() internal {
        chainNames[MAINNET_CHAIN_ID] = "Ethereum";
        chainNames[BASE_CHAIN_ID] = "Base";
        chainNames[OPTIMISM_CHAIN_ID] = "Optimism";
        chainNames[POLYGON_CHAIN_ID] = "Polygon";
        chainNames[ARBITRUM_CHAIN_ID] = "Arbitrum";
        chainNames[SEPOLIA_CHAIN_ID] = "Sepolia";
        chainNames[ARB_SEPOLIA_CHAIN_ID] = "Arbitrum_Sepolia";
        chainNames[BASE_SEPOLIA_CHAIN_ID] = "Base_Sepolia";
    }

    function _setConfiguration(uint64 chainId) internal {
        // common configuration
        // this is the SuperDeployer address
        configuration.deployer = 0x4b38341B1126F45614B26319787CA98aeC1b6f57;
        configuration.chainId = chainId;
        // this is the owner of the codebase
        configuration.owner = 0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA;
        // paymaster keeper
        configuration.paymaster = 0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA;

        // chain specific configuration
        if (chainId == MAINNET_CHAIN_ID) {
            configuration.acrossSpokePoolV3 = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
        } else if (chainId == ARBITRUM_CHAIN_ID) {
            configuration.acrossSpokePoolV3 = 0xE248B1deEb12828788eB0e27F3BF8f0e18cfd362;
        } else if (chainId == ARB_SEPOLIA_CHAIN_ID) {
            configuration.acrossSpokePoolV3 = 0x7E63A5f1a8F0B4d0934B2f2327DAED3F6bb2ee75;
        } else if (chainId == BASE_SEPOLIA_CHAIN_ID) {
            configuration.acrossSpokePoolV3 = 0x82B564983aE7274c86695917BBf8C99ECb6F0F8F;
        } else {
            revert INVALID_CONFIG();
        }
    }
}
