// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// @dev all of these are mocks; some values are hardcoded or not using RBAC

contract MockSuperPosition is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint8 private _decimals;

    address public underlying;

    address public factory;
    uint256 public id;

    error INVALID_FACTORY();

    constructor(address factory_, address underlying_, uint256 id_)
        ERC20(
            string.concat(ERC20(underlying_).name(), " Super Position"),
            string.concat(ERC20(underlying_).symbol(), " SP")
        )
    {
        factory = factory_;
        underlying = underlying_;
        _decimals = ERC20(underlying_).decimals();
        id = id_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the number of decimals for the token
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mint tokens to an address
    /// @param to_ The address to mint tokens to
    /// @param amount_ The amount of tokens to mint

    function mint(address to_, uint256 amount_) public {
        if (msg.sender != factory) revert INVALID_FACTORY();
        _mint(to_, amount_);
    }

    /// @notice Burn tokens from an address
    /// @param from_ The address to burn tokens from
    /// @param amount_ The amount of tokens to burn
    function burn(address from_, uint256 amount_) public {
        if (msg.sender != factory) revert INVALID_FACTORY();
        _burn(from_, amount_);
    }
}

contract MockSuperPositionFactory {
    event SuperPositionCreated(
        uint64 indexed chainId,
        address indexed yieldSourceAddress,
        bytes32 indexed yieldSourceOracleId,
        address asset,
        address superPosition
    );

    address[] public allSuperPositions;
    mapping(address => bool) public isSP;
    mapping(uint256 spId => address sp) public createdSPs;

    address public bundler;

    error INVALID_BUNDLER();
    error INVALID_SP_ID();
    error INVALID_SP();

    constructor(address _bundler) {
        bundler = _bundler;
    }

    // ---- view ----
    function spCount() external view returns (uint256) {
        return allSuperPositions.length;
    }

    function getSPId(address yieldSourceAddress, bytes32 yieldSourceOracleId, uint64 chainId)
        external
        pure
        returns (uint256)
    {
        return _getSPId(yieldSourceAddress, yieldSourceOracleId, chainId);
    }

    // ---- write ----
    function mintSuperPosition(
        uint64 chainId,
        address yieldSourceAddress,
        bytes32 yieldSourceOracleId,
        address asset,
        address to,
        uint256 amount
    ) external returns (address) {
        if (msg.sender != bundler) revert INVALID_BUNDLER();
        address _sp = _createSP(asset, yieldSourceAddress, yieldSourceOracleId, chainId);

        _mintSP(_sp, to, amount);
        return _sp;
    }

    function burnSuperPosition(uint256 spId, address from, uint256 amount, bytes32 ) external returns (address) {
        if (msg.sender != bundler) revert INVALID_BUNDLER();

        if (createdSPs[spId] == address(0)) revert INVALID_SP_ID();
        if (!isSP[createdSPs[spId]]) revert INVALID_SP();

        _burnSP(createdSPs[spId], from, amount);
        return createdSPs[spId];
    }

    // ---- private ----
    function _mintSP(address sp, address to, uint256 amount) private {
        MockSuperPosition(sp).mint(to, amount);
    }

    function _burnSP(address sp, address from, uint256 amount) private {
        MockSuperPosition(sp).burn(from, amount);
    }

    function _createSP(address asset, address yieldSourceAddress, bytes32 yieldSourceOracleId, uint64 chainId)
        private
        returns (address)
    {
        uint256 _spId = _getSPId(yieldSourceAddress, yieldSourceOracleId, chainId);
        if (createdSPs[_spId] != address(0)) return createdSPs[_spId];

        address _sp = address(new MockSuperPosition(address(this), asset, _spId));
        createdSPs[_spId] = _sp;
        allSuperPositions.push(_sp);
        isSP[_sp] = true;
        emit SuperPositionCreated(chainId, yieldSourceAddress, yieldSourceOracleId, asset, _sp);
        return _sp;
    }

    function _getSPId(address yieldSourceAddress, bytes32 yieldSourceOracleId, uint64 chainId)
        private
        pure
        returns (uint256)
    {
        /**
         * address yieldSourceAddress (20 bytes)
         *         bytes32 yieldSourceOracleId (4 bytes)
         *         uint64 chainId (8 bytes)
         *         ----
         *         32 bytes
         */
        return uint256(keccak256(abi.encode(yieldSourceAddress, yieldSourceOracleId, chainId)));
    }
}
