// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

abstract contract Data {
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
    uint64 public constant ARBITRUM_CHAIN_ID = 42161;
    // testnets
    uint64 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint64 public constant ARB_SEPOLIA_CHAIN_ID = 421613;

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _setConfiguration(uint64 chainId) internal {
        // common configuration
        configuration.deployer = 0x4b38341B1126F45614B26319787CA98aeC1b6f57;    
        configuration.chainId = chainId;
        configuration.owner = 0x168910Ea470113A07Ec777769E76D9C8C80A402f;
        configuration.paymaster = 0x168910Ea470113A07Ec777769E76D9C8C80A402f;

        // chain specific configuration
        if (chainId == MAINNET_CHAIN_ID) {
            configuration.acrossSpokePoolV3 = 0x0000000000000000000000000000000000000000;
        } else if (chainId == ARBITRUM_CHAIN_ID) {
            configuration.acrossSpokePoolV3 = 0xE248B1deEb12828788eB0e27F3BF8f0e18cfd362;
        } else if (chainId == ARB_SEPOLIA_CHAIN_ID) {
            configuration.acrossSpokePoolV3 = 0x0000000000000000000000000000000000000000;
        } else {
            revert INVALID_CONFIG();
        }
    }
}
