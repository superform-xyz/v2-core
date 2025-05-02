// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISuperAsset} from "../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";

contract MockSuperAsset is ISuperAsset {
    function name() external pure returns (string memory) {
        return "Mock Super Asset";
    }

    function symbol() external pure returns (string memory) {
        return "MSA";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address icc_,
        address ifc_,
        address assetBank_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    ) external {}

    function mint(address, uint256) external {}

    function burn(address, uint256) external {}

    function getAllocations() external view returns (
        uint256[] memory absoluteCurrentAllocation,
        uint256 totalCurrentAllocation,
        uint256[] memory absoluteTargetAllocation,
        uint256 totalTargetAllocation
    ) {
        return (new uint256[](0), 0, new uint256[](0), 0);
    }

    function getAllocationsPrePostOperation(address, int256) external view returns (
        uint256[] memory absoluteAllocationPreOperation,
        uint256 totalAllocationPreOperation,
        uint256[] memory absoluteAllocationPostOperation,
        uint256 totalAllocationPostOperation,
        uint256[] memory absoluteTargetAllocation,
        uint256 totalTargetAllocation,
        uint256[] memory vaultWeights
    ) {
        return (
            new uint256[](0),
            0,
            new uint256[](0),
            0,
            new uint256[](0),
            0,
            new uint256[](0)
        );
    }

    function setSwapFeeInPercentage(uint256) external {}

    function setSwapFeeOutPercentage(uint256) external {}

    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut
    ) external returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit) {
        return (0, 0, 0);
    }

    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    ) external returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem) {
        return (0, 0, 0);
    }

    function swap(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        address tokenOut,
        uint256 minTokenOut
    ) external returns (
        uint256 amountSharesIntermediateStep,
        uint256 amountTokenOutAfterFees,
        uint256 swapFeeIn,
        uint256 swapFeeOut,
        int256 amountIncentivesIn,
        int256 amountIncentivesOut
    ) {
        return (0, 0, 0, 0, 0, 0);
    }

    function whitelistVault(address) external {}

    function removeVault(address) external {}

    function whitelistERC20(address) external {}

    function removeERC20(address) external {}

    function setSuperOracle(address) external {}

    function previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) external view returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD) {
        return (0, 0, 0);
    }

    function previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) external view returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD) {
        return (0, 0, 0);
    }

    function previewSwap(
        address tokenIn,
        uint256 amountTokenToDeposit,
        address tokenOut
    ) external view returns (
        uint256 amountTokenOutAfterFees,
        uint256 swapFeeIn,
        uint256 swapFeeOut,
        int256 amountIncentiveUSDDeposit,
        int256 amountIncentiveUSDRedeem
    ) {
        return (0, 0, 0, 0, 0);
    }

    function getPriceWithCircuitBreakers(address) external pure returns (
        uint256 priceUSD,
        bool isDepeg,
        bool isDispersion,
        bool isOracleOff
    ) {
        return (0, false, false, false);
    }

    function getPrecision() external pure returns (uint256) {
        return 1e18;
    }

    function setWeight(address, uint256) external {}

    function setTargetAllocations(address[] calldata, uint256[] calldata) external {}

    function setTargetAllocation(address, uint256) external {}

    function setEnergyToUSDExchangeRatio(uint256) external {}
}
