// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IBundlerRegistry} from "./interfaces/IBundlerRegistry.sol";

contract BundlerRegistry is IBundlerRegistry, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address bundlerAddress => Bundler bundlerData) public bundlers;
    mapping(uint256 bundlerId => address bundlerAddress) public bundlerIds;

    constructor(address owner_) Ownable(owner_) {}

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IBundlerRegistry
    function isBundlerRegistered(address bundler) external view returns (bool) {
        return bundlers[bundler].bundlerAddress != address(0);
    }

    /// @inheritdoc IBundlerRegistry
    function isBundlerActive(address bundler) external view returns (bool) {
        return bundlers[bundler].isActive;
    }

    /// @inheritdoc IBundlerRegistry
    function getBundler(uint256 _bundlerId) external view returns (Bundler memory) {
        return bundlers[bundlerIds[_bundlerId]];
    }

    /// @inheritdoc IBundlerRegistry
    function getBundlerByAddress(address _addr) external view returns (Bundler memory) {
        return bundlers[_addr];
    }

    /*//////////////////////////////////////////////////////////////
                                OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Register a new bundler
    /// @param _extraData Extra data for off-chain use
    function registerBundler(bytes calldata _extraData) external onlyOwner {
        IBundlerRegistry.Bundler memory bundler = IBundlerRegistry.Bundler({
            id: uint256(keccak256(abi.encodePacked(_extraData, block.timestamp, block.chainid))),
            bundlerAddress: msg.sender,
            isActive: true,
            extraData: _extraData
        });

        bundlers[msg.sender] = bundler;
        bundlerIds[bundler.id] = msg.sender;

        emit BundlerRegistered(bundler.id, msg.sender);
    }

    /// @notice Update a bundler's address
    /// @param _bundlerId The id of the bundler
    /// @param _newAddress The new address of the bundler
    function updateBundlerAddress(uint256 _bundlerId, address _newAddress) external onlyOwner {
        address bundlerAddress = bundlerIds[_bundlerId];

        // Copy the bundler data to the new address
        IBundlerRegistry.Bundler memory bundler = bundlers[bundlerAddress];
        bundler.bundlerAddress = _newAddress;

        // Update mappings
        delete bundlers[bundlerAddress];
        bundlers[_newAddress] = bundler;
        bundlerIds[_bundlerId] = _newAddress;

        emit BundlerAddressUpdated(_bundlerId, bundlerAddress, _newAddress);
    }

    /// @notice Update a bundler's extra data
    /// @param _bundlerId The id of the bundler
    /// @param _extraData The new extra data for the bundler
    function updateBundlerExtraData(uint256 _bundlerId, bytes calldata _extraData) external onlyOwner {
        address bundlerAddress = bundlerIds[_bundlerId];

        bundlers[bundlerAddress].extraData = _extraData;

        emit BundlerExtraDataUpdated(_bundlerId, bundlerAddress, _extraData);
    }

    /// @notice Update a bundler's status
    /// @param _bundlerId The id of the bundler
    /// @param _isActive The new status of the bundler
    function updateBundlerStatus(uint256 _bundlerId, bool _isActive) external onlyOwner {
        address bundlerAddress = bundlerIds[_bundlerId];

        bundlers[bundlerAddress].isActive = _isActive;

        emit BundlerStatusChanged(_bundlerId, bundlerAddress, _isActive);
    }
}
