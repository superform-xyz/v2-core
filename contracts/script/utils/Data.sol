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

    struct EnvironmentData {
        address deployer;
        uint256 chainId;
        address owner;
        address acrossSpokePoolV3;
        SuperPositionData[] superPositions;
    }
    // add rest of the data

    enum DeployChain {
        MAINNET,
        TESTNET1,
        TESTNET2
    }

    EnvironmentData public configuration;

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _setConfiguration(uint8 config) internal {
        if (config == uint8(DeployChain.MAINNET)) {
            configuration.deployer = 0x0000000000000000000000000000000000000000;
            configuration.chainId = 1;
            configuration.owner = 0x0000000000000000000000000000000000000000;
            configuration.acrossSpokePoolV3 = 0x0000000000000000000000000000000000000000;
        } else if (config == uint8(DeployChain.TESTNET1)) {
            configuration.deployer = 0x0000000000000000000000000000000000000000;
            configuration.chainId = 1;
            configuration.owner = 0x0000000000000000000000000000000000000000;
            configuration.acrossSpokePoolV3 = 0x0000000000000000000000000000000000000000;
        } else if (config == uint8(DeployChain.TESTNET2)) {
        } else {
            revert INVALID_CONFIG();
        }
    }
}
