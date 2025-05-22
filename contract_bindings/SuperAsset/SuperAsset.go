// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperAsset

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
	_ = abi.ConvertType
)

// SuperAssetMetaData contains all meta data concerning the SuperAsset contract.
var SuperAssetMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"AVERAGE_PROVIDER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BURNER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEFAULT_ADMIN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPEG_LOWER_THRESHOLD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPEG_UPPER_THRESHOLD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DISPERSION_THRESHOLD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"INCENTIVE_FUND_MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAX_SWAP_FEE_PERCENTAGE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MINTER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PRECISION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_FEE_MANAGER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_FEE_PERC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"VAULT_MANAGER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"allowance\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"approve\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"assetBank\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"balanceOf\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"burn\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"deposit\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceShare\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountTokenToDeposit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"minSharesOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"amountSharesMinted\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amountIncentiveUSDDeposit\",\"type\":\"int256\",\"internalType\":\"int256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"emergencyPrices\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"priceUSD\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"energyToUSDExchangeRatio\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAllocations\",\"inputs\":[],\"outputs\":[{\"name\":\"absoluteCurrentAllocation\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"totalCurrentAllocation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"absoluteTargetAllocation\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"totalTargetAllocation\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAllocationsPrePostOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"deltaToken\",\"type\":\"int256\",\"internalType\":\"int256\"},{\"name\":\"isSoft\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"absoluteAllocationPreOperation\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"totalAllocationPreOperation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"absoluteAllocationPostOperation\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"totalAllocationPostOperation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"absoluteTargetAllocation\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"totalTargetAllocation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"vaultWeights\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"isSuccess\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPrecision\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getPriceWithCircuitBreakers\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"priceUSD\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"isDepeg\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"isDispersion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"isOracleOff\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRoleAdmin\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"grantRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"hasRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"incentiveCalculationContract\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"incentiveFundContract\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":[{\"name\":\"name_\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"symbol_\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"icc_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ifc_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetBank_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"swapFeeInPercentage_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFeeOutPercentage_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isSupportedERC20\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isSupported\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isSupportedUnderlyingVault\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isSupported\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mint\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"previewDeposit\",\"inputs\":[{\"name\":\"tokenIn\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountTokenToDeposit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"isSoft\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"amountSharesMinted\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amountIncentiveUSD\",\"type\":\"int256\",\"internalType\":\"int256\"},{\"name\":\"isSuccess\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"previewRedeem\",\"inputs\":[{\"name\":\"tokenOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountSharesToRedeem\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"isSoft\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"amountTokenOutAfterFees\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amountIncentiveUSD\",\"type\":\"int256\",\"internalType\":\"int256\"},{\"name\":\"isSuccess\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"previewSwap\",\"inputs\":[{\"name\":\"tokenIn\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountTokenToDeposit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"tokenOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isSoft\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"amountTokenOutAfterFees\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFeeIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFeeOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amountIncentiveUSDDeposit\",\"type\":\"int256\",\"internalType\":\"int256\"},{\"name\":\"amountIncentiveUSDRedeem\",\"type\":\"int256\",\"internalType\":\"int256\"},{\"name\":\"isSuccess\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"redeem\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountSharesToRedeem\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"tokenOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"minTokenOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"amountTokenOutAfterFees\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amountIncentiveUSDRedeem\",\"type\":\"int256\",\"internalType\":\"int256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeERC20\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeVault\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"callerConfirmation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"revokeRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setEnergyToUSDExchangeRatio\",\"inputs\":[{\"name\":\"newRatio\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSuperOracle\",\"inputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSwapFeeInPercentage\",\"inputs\":[{\"name\":\"_feePercentage\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSwapFeeOutPercentage\",\"inputs\":[{\"name\":\"_feePercentage\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setTargetAllocation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"allocation\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setTargetAllocations\",\"inputs\":[{\"name\":\"tokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"allocations\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setWeight\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"weight\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superOracle\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperOracle\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"supportsInterface\",\"inputs\":[{\"name\":\"interfaceId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"swap\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokenIn\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountTokenToDeposit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"tokenOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"minTokenOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"amountSharesIntermediateStep\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amountTokenOutAfterFees\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFeeIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFeeOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amountIncentivesIn\",\"type\":\"int256\",\"internalType\":\"int256\"},{\"name\":\"amountIncentivesOut\",\"type\":\"int256\",\"internalType\":\"int256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"swapFeeInPercentage\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"swapFeeOutPercentage\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"symbol\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetAllocations\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"allocation\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"totalSupply\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transfer\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferFrom\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"weights\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"allocation\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"whitelistERC20\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"whitelistVault\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"Approval\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Deposit\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenIn\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amountTokenToDeposit\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amountSharesOut\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"swapFee\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amountIncentives\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ERC20Removed\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ERC20Whitelisted\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EnergyToUSDExchangeRatioSet\",\"inputs\":[{\"name\":\"newRatio\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Redeem\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenOut\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amountSharesToRedeem\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amountTokenOut\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"swapFee\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amountIncentives\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleAdminChanged\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"previousAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleGranted\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleRevoked\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SettlementTokenInSet\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SettlementTokenOutSet\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperOracleSet\",\"inputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Swap\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenIn\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amountTokenToDeposit\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"tokenOut\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amountSharesIntermediateStep\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amountTokenOutAfterFees\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"swapFeeIn\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"swapFeeOut\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amountIncentivesIn\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"},{\"name\":\"amountIncentivesOut\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TargetAllocationSet\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"allocation\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Transfer\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultRemoved\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultWhitelisted\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WeightSet\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"weight\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_WHITELISTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AccessControlBadConfirmation\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AccessControlUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"neededRole\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"CONTRACT_PAUSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EMERGENCY_PRICE_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ERC20InsufficientAllowance\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"allowance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ERC20InsufficientBalance\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidApprover\",\"inputs\":[{\"name\":\"approver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidReceiver\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidSender\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidSpender\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"INCENTIVE_CALCULATION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_ALLOWANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ALLOCATION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_INPUT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_OPERATION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ORACLE_PRICE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SWAP_FEE_PERCENTAGE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_TOTAL_ALLOCATION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_ERC20_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_SUPPORTED_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_VAULT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_WHITELISTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PRICE_USD_ZERO\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SLIPPAGE_PROTECTION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNDERLYING_SV_ASSET_PRICE_DEPEG\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNDERLYING_SV_ASSET_PRICE_DISPERSION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNDERLYING_SV_ASSET_PRICE_ORACLE_OFF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNDERLYING_SV_ASSET_PRICE_ZERO\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// SuperAssetABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperAssetMetaData.ABI instead.
var SuperAssetABI = SuperAssetMetaData.ABI

// SuperAsset is an auto generated Go binding around an Ethereum contract.
type SuperAsset struct {
	SuperAssetCaller     // Read-only binding to the contract
	SuperAssetTransactor // Write-only binding to the contract
	SuperAssetFilterer   // Log filterer for contract events
}

// SuperAssetCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperAssetCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperAssetTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperAssetFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperAssetSession struct {
	Contract     *SuperAsset       // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperAssetCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperAssetCallerSession struct {
	Contract *SuperAssetCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts     // Call options to use throughout this session
}

// SuperAssetTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperAssetTransactorSession struct {
	Contract     *SuperAssetTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// SuperAssetRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperAssetRaw struct {
	Contract *SuperAsset // Generic contract binding to access the raw methods on
}

// SuperAssetCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperAssetCallerRaw struct {
	Contract *SuperAssetCaller // Generic read-only contract binding to access the raw methods on
}

// SuperAssetTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperAssetTransactorRaw struct {
	Contract *SuperAssetTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperAsset creates a new instance of SuperAsset, bound to a specific deployed contract.
func NewSuperAsset(address common.Address, backend bind.ContractBackend) (*SuperAsset, error) {
	contract, err := bindSuperAsset(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperAsset{SuperAssetCaller: SuperAssetCaller{contract: contract}, SuperAssetTransactor: SuperAssetTransactor{contract: contract}, SuperAssetFilterer: SuperAssetFilterer{contract: contract}}, nil
}

// NewSuperAssetCaller creates a new read-only instance of SuperAsset, bound to a specific deployed contract.
func NewSuperAssetCaller(address common.Address, caller bind.ContractCaller) (*SuperAssetCaller, error) {
	contract, err := bindSuperAsset(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperAssetCaller{contract: contract}, nil
}

// NewSuperAssetTransactor creates a new write-only instance of SuperAsset, bound to a specific deployed contract.
func NewSuperAssetTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperAssetTransactor, error) {
	contract, err := bindSuperAsset(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperAssetTransactor{contract: contract}, nil
}

// NewSuperAssetFilterer creates a new log filterer instance of SuperAsset, bound to a specific deployed contract.
func NewSuperAssetFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperAssetFilterer, error) {
	contract, err := bindSuperAsset(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFilterer{contract: contract}, nil
}

// bindSuperAsset binds a generic wrapper to an already deployed contract.
func bindSuperAsset(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperAssetMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperAsset *SuperAssetRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperAsset.Contract.SuperAssetCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperAsset *SuperAssetRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperAsset.Contract.SuperAssetTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperAsset *SuperAssetRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperAsset.Contract.SuperAssetTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperAsset *SuperAssetCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperAsset.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperAsset *SuperAssetTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperAsset.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperAsset *SuperAssetTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperAsset.Contract.contract.Transact(opts, method, params...)
}

// AVERAGEPROVIDER is a free data retrieval call binding the contract method 0x12faab85.
//
// Solidity: function AVERAGE_PROVIDER() view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) AVERAGEPROVIDER(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "AVERAGE_PROVIDER")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// AVERAGEPROVIDER is a free data retrieval call binding the contract method 0x12faab85.
//
// Solidity: function AVERAGE_PROVIDER() view returns(bytes32)
func (_SuperAsset *SuperAssetSession) AVERAGEPROVIDER() ([32]byte, error) {
	return _SuperAsset.Contract.AVERAGEPROVIDER(&_SuperAsset.CallOpts)
}

// AVERAGEPROVIDER is a free data retrieval call binding the contract method 0x12faab85.
//
// Solidity: function AVERAGE_PROVIDER() view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) AVERAGEPROVIDER() ([32]byte, error) {
	return _SuperAsset.Contract.AVERAGEPROVIDER(&_SuperAsset.CallOpts)
}

// BURNERROLE is a free data retrieval call binding the contract method 0x282c51f3.
//
// Solidity: function BURNER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) BURNERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "BURNER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// BURNERROLE is a free data retrieval call binding the contract method 0x282c51f3.
//
// Solidity: function BURNER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetSession) BURNERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.BURNERROLE(&_SuperAsset.CallOpts)
}

// BURNERROLE is a free data retrieval call binding the contract method 0x282c51f3.
//
// Solidity: function BURNER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) BURNERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.BURNERROLE(&_SuperAsset.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) DEFAULTADMINROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "DEFAULT_ADMIN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperAsset.Contract.DEFAULTADMINROLE(&_SuperAsset.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperAsset.Contract.DEFAULTADMINROLE(&_SuperAsset.CallOpts)
}

// DEPEGLOWERTHRESHOLD is a free data retrieval call binding the contract method 0x5753296f.
//
// Solidity: function DEPEG_LOWER_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) DEPEGLOWERTHRESHOLD(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "DEPEG_LOWER_THRESHOLD")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// DEPEGLOWERTHRESHOLD is a free data retrieval call binding the contract method 0x5753296f.
//
// Solidity: function DEPEG_LOWER_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetSession) DEPEGLOWERTHRESHOLD() (*big.Int, error) {
	return _SuperAsset.Contract.DEPEGLOWERTHRESHOLD(&_SuperAsset.CallOpts)
}

// DEPEGLOWERTHRESHOLD is a free data retrieval call binding the contract method 0x5753296f.
//
// Solidity: function DEPEG_LOWER_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) DEPEGLOWERTHRESHOLD() (*big.Int, error) {
	return _SuperAsset.Contract.DEPEGLOWERTHRESHOLD(&_SuperAsset.CallOpts)
}

// DEPEGUPPERTHRESHOLD is a free data retrieval call binding the contract method 0x6b6c46a5.
//
// Solidity: function DEPEG_UPPER_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) DEPEGUPPERTHRESHOLD(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "DEPEG_UPPER_THRESHOLD")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// DEPEGUPPERTHRESHOLD is a free data retrieval call binding the contract method 0x6b6c46a5.
//
// Solidity: function DEPEG_UPPER_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetSession) DEPEGUPPERTHRESHOLD() (*big.Int, error) {
	return _SuperAsset.Contract.DEPEGUPPERTHRESHOLD(&_SuperAsset.CallOpts)
}

// DEPEGUPPERTHRESHOLD is a free data retrieval call binding the contract method 0x6b6c46a5.
//
// Solidity: function DEPEG_UPPER_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) DEPEGUPPERTHRESHOLD() (*big.Int, error) {
	return _SuperAsset.Contract.DEPEGUPPERTHRESHOLD(&_SuperAsset.CallOpts)
}

// DISPERSIONTHRESHOLD is a free data retrieval call binding the contract method 0x520b85b0.
//
// Solidity: function DISPERSION_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) DISPERSIONTHRESHOLD(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "DISPERSION_THRESHOLD")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// DISPERSIONTHRESHOLD is a free data retrieval call binding the contract method 0x520b85b0.
//
// Solidity: function DISPERSION_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetSession) DISPERSIONTHRESHOLD() (*big.Int, error) {
	return _SuperAsset.Contract.DISPERSIONTHRESHOLD(&_SuperAsset.CallOpts)
}

// DISPERSIONTHRESHOLD is a free data retrieval call binding the contract method 0x520b85b0.
//
// Solidity: function DISPERSION_THRESHOLD() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) DISPERSIONTHRESHOLD() (*big.Int, error) {
	return _SuperAsset.Contract.DISPERSIONTHRESHOLD(&_SuperAsset.CallOpts)
}

// INCENTIVEFUNDMANAGER is a free data retrieval call binding the contract method 0x209518e0.
//
// Solidity: function INCENTIVE_FUND_MANAGER() view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) INCENTIVEFUNDMANAGER(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "INCENTIVE_FUND_MANAGER")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// INCENTIVEFUNDMANAGER is a free data retrieval call binding the contract method 0x209518e0.
//
// Solidity: function INCENTIVE_FUND_MANAGER() view returns(bytes32)
func (_SuperAsset *SuperAssetSession) INCENTIVEFUNDMANAGER() ([32]byte, error) {
	return _SuperAsset.Contract.INCENTIVEFUNDMANAGER(&_SuperAsset.CallOpts)
}

// INCENTIVEFUNDMANAGER is a free data retrieval call binding the contract method 0x209518e0.
//
// Solidity: function INCENTIVE_FUND_MANAGER() view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) INCENTIVEFUNDMANAGER() ([32]byte, error) {
	return _SuperAsset.Contract.INCENTIVEFUNDMANAGER(&_SuperAsset.CallOpts)
}

// MAXSWAPFEEPERCENTAGE is a free data retrieval call binding the contract method 0x4730507a.
//
// Solidity: function MAX_SWAP_FEE_PERCENTAGE() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) MAXSWAPFEEPERCENTAGE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "MAX_SWAP_FEE_PERCENTAGE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MAXSWAPFEEPERCENTAGE is a free data retrieval call binding the contract method 0x4730507a.
//
// Solidity: function MAX_SWAP_FEE_PERCENTAGE() view returns(uint256)
func (_SuperAsset *SuperAssetSession) MAXSWAPFEEPERCENTAGE() (*big.Int, error) {
	return _SuperAsset.Contract.MAXSWAPFEEPERCENTAGE(&_SuperAsset.CallOpts)
}

// MAXSWAPFEEPERCENTAGE is a free data retrieval call binding the contract method 0x4730507a.
//
// Solidity: function MAX_SWAP_FEE_PERCENTAGE() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) MAXSWAPFEEPERCENTAGE() (*big.Int, error) {
	return _SuperAsset.Contract.MAXSWAPFEEPERCENTAGE(&_SuperAsset.CallOpts)
}

// MINTERROLE is a free data retrieval call binding the contract method 0xd5391393.
//
// Solidity: function MINTER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) MINTERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "MINTER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// MINTERROLE is a free data retrieval call binding the contract method 0xd5391393.
//
// Solidity: function MINTER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetSession) MINTERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.MINTERROLE(&_SuperAsset.CallOpts)
}

// MINTERROLE is a free data retrieval call binding the contract method 0xd5391393.
//
// Solidity: function MINTER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) MINTERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.MINTERROLE(&_SuperAsset.CallOpts)
}

// PRECISION is a free data retrieval call binding the contract method 0xaaf5eb68.
//
// Solidity: function PRECISION() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) PRECISION(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "PRECISION")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PRECISION is a free data retrieval call binding the contract method 0xaaf5eb68.
//
// Solidity: function PRECISION() view returns(uint256)
func (_SuperAsset *SuperAssetSession) PRECISION() (*big.Int, error) {
	return _SuperAsset.Contract.PRECISION(&_SuperAsset.CallOpts)
}

// PRECISION is a free data retrieval call binding the contract method 0xaaf5eb68.
//
// Solidity: function PRECISION() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) PRECISION() (*big.Int, error) {
	return _SuperAsset.Contract.PRECISION(&_SuperAsset.CallOpts)
}

// SWAPFEEMANAGERROLE is a free data retrieval call binding the contract method 0xa3b47ab5.
//
// Solidity: function SWAP_FEE_MANAGER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) SWAPFEEMANAGERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "SWAP_FEE_MANAGER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SWAPFEEMANAGERROLE is a free data retrieval call binding the contract method 0xa3b47ab5.
//
// Solidity: function SWAP_FEE_MANAGER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetSession) SWAPFEEMANAGERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.SWAPFEEMANAGERROLE(&_SuperAsset.CallOpts)
}

// SWAPFEEMANAGERROLE is a free data retrieval call binding the contract method 0xa3b47ab5.
//
// Solidity: function SWAP_FEE_MANAGER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) SWAPFEEMANAGERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.SWAPFEEMANAGERROLE(&_SuperAsset.CallOpts)
}

// SWAPFEEPERC is a free data retrieval call binding the contract method 0x409cdfb1.
//
// Solidity: function SWAP_FEE_PERC() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) SWAPFEEPERC(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "SWAP_FEE_PERC")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SWAPFEEPERC is a free data retrieval call binding the contract method 0x409cdfb1.
//
// Solidity: function SWAP_FEE_PERC() view returns(uint256)
func (_SuperAsset *SuperAssetSession) SWAPFEEPERC() (*big.Int, error) {
	return _SuperAsset.Contract.SWAPFEEPERC(&_SuperAsset.CallOpts)
}

// SWAPFEEPERC is a free data retrieval call binding the contract method 0x409cdfb1.
//
// Solidity: function SWAP_FEE_PERC() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) SWAPFEEPERC() (*big.Int, error) {
	return _SuperAsset.Contract.SWAPFEEPERC(&_SuperAsset.CallOpts)
}

// USD is a free data retrieval call binding the contract method 0x1bf6c21b.
//
// Solidity: function USD() view returns(address)
func (_SuperAsset *SuperAssetCaller) USD(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "USD")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// USD is a free data retrieval call binding the contract method 0x1bf6c21b.
//
// Solidity: function USD() view returns(address)
func (_SuperAsset *SuperAssetSession) USD() (common.Address, error) {
	return _SuperAsset.Contract.USD(&_SuperAsset.CallOpts)
}

// USD is a free data retrieval call binding the contract method 0x1bf6c21b.
//
// Solidity: function USD() view returns(address)
func (_SuperAsset *SuperAssetCallerSession) USD() (common.Address, error) {
	return _SuperAsset.Contract.USD(&_SuperAsset.CallOpts)
}

// VAULTMANAGERROLE is a free data retrieval call binding the contract method 0x5e5a24a4.
//
// Solidity: function VAULT_MANAGER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) VAULTMANAGERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "VAULT_MANAGER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// VAULTMANAGERROLE is a free data retrieval call binding the contract method 0x5e5a24a4.
//
// Solidity: function VAULT_MANAGER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetSession) VAULTMANAGERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.VAULTMANAGERROLE(&_SuperAsset.CallOpts)
}

// VAULTMANAGERROLE is a free data retrieval call binding the contract method 0x5e5a24a4.
//
// Solidity: function VAULT_MANAGER_ROLE() view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) VAULTMANAGERROLE() ([32]byte, error) {
	return _SuperAsset.Contract.VAULTMANAGERROLE(&_SuperAsset.CallOpts)
}

// Allowance is a free data retrieval call binding the contract method 0xdd62ed3e.
//
// Solidity: function allowance(address owner, address spender) view returns(uint256)
func (_SuperAsset *SuperAssetCaller) Allowance(opts *bind.CallOpts, owner common.Address, spender common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "allowance", owner, spender)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Allowance is a free data retrieval call binding the contract method 0xdd62ed3e.
//
// Solidity: function allowance(address owner, address spender) view returns(uint256)
func (_SuperAsset *SuperAssetSession) Allowance(owner common.Address, spender common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.Allowance(&_SuperAsset.CallOpts, owner, spender)
}

// Allowance is a free data retrieval call binding the contract method 0xdd62ed3e.
//
// Solidity: function allowance(address owner, address spender) view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) Allowance(owner common.Address, spender common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.Allowance(&_SuperAsset.CallOpts, owner, spender)
}

// AssetBank is a free data retrieval call binding the contract method 0x4d75f51c.
//
// Solidity: function assetBank() view returns(address)
func (_SuperAsset *SuperAssetCaller) AssetBank(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "assetBank")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AssetBank is a free data retrieval call binding the contract method 0x4d75f51c.
//
// Solidity: function assetBank() view returns(address)
func (_SuperAsset *SuperAssetSession) AssetBank() (common.Address, error) {
	return _SuperAsset.Contract.AssetBank(&_SuperAsset.CallOpts)
}

// AssetBank is a free data retrieval call binding the contract method 0x4d75f51c.
//
// Solidity: function assetBank() view returns(address)
func (_SuperAsset *SuperAssetCallerSession) AssetBank() (common.Address, error) {
	return _SuperAsset.Contract.AssetBank(&_SuperAsset.CallOpts)
}

// BalanceOf is a free data retrieval call binding the contract method 0x70a08231.
//
// Solidity: function balanceOf(address account) view returns(uint256)
func (_SuperAsset *SuperAssetCaller) BalanceOf(opts *bind.CallOpts, account common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "balanceOf", account)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BalanceOf is a free data retrieval call binding the contract method 0x70a08231.
//
// Solidity: function balanceOf(address account) view returns(uint256)
func (_SuperAsset *SuperAssetSession) BalanceOf(account common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.BalanceOf(&_SuperAsset.CallOpts, account)
}

// BalanceOf is a free data retrieval call binding the contract method 0x70a08231.
//
// Solidity: function balanceOf(address account) view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) BalanceOf(account common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.BalanceOf(&_SuperAsset.CallOpts, account)
}

// Decimals is a free data retrieval call binding the contract method 0x313ce567.
//
// Solidity: function decimals() view returns(uint8)
func (_SuperAsset *SuperAssetCaller) Decimals(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "decimals")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0x313ce567.
//
// Solidity: function decimals() view returns(uint8)
func (_SuperAsset *SuperAssetSession) Decimals() (uint8, error) {
	return _SuperAsset.Contract.Decimals(&_SuperAsset.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0x313ce567.
//
// Solidity: function decimals() view returns(uint8)
func (_SuperAsset *SuperAssetCallerSession) Decimals() (uint8, error) {
	return _SuperAsset.Contract.Decimals(&_SuperAsset.CallOpts)
}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 priceUSD)
func (_SuperAsset *SuperAssetCaller) EmergencyPrices(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "emergencyPrices", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 priceUSD)
func (_SuperAsset *SuperAssetSession) EmergencyPrices(token common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.EmergencyPrices(&_SuperAsset.CallOpts, token)
}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 priceUSD)
func (_SuperAsset *SuperAssetCallerSession) EmergencyPrices(token common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.EmergencyPrices(&_SuperAsset.CallOpts, token)
}

// EnergyToUSDExchangeRatio is a free data retrieval call binding the contract method 0x81a605b0.
//
// Solidity: function energyToUSDExchangeRatio() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) EnergyToUSDExchangeRatio(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "energyToUSDExchangeRatio")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// EnergyToUSDExchangeRatio is a free data retrieval call binding the contract method 0x81a605b0.
//
// Solidity: function energyToUSDExchangeRatio() view returns(uint256)
func (_SuperAsset *SuperAssetSession) EnergyToUSDExchangeRatio() (*big.Int, error) {
	return _SuperAsset.Contract.EnergyToUSDExchangeRatio(&_SuperAsset.CallOpts)
}

// EnergyToUSDExchangeRatio is a free data retrieval call binding the contract method 0x81a605b0.
//
// Solidity: function energyToUSDExchangeRatio() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) EnergyToUSDExchangeRatio() (*big.Int, error) {
	return _SuperAsset.Contract.EnergyToUSDExchangeRatio(&_SuperAsset.CallOpts)
}

// GetAllocations is a free data retrieval call binding the contract method 0x65ed6e23.
//
// Solidity: function getAllocations() view returns(uint256[] absoluteCurrentAllocation, uint256 totalCurrentAllocation, uint256[] absoluteTargetAllocation, uint256 totalTargetAllocation)
func (_SuperAsset *SuperAssetCaller) GetAllocations(opts *bind.CallOpts) (struct {
	AbsoluteCurrentAllocation []*big.Int
	TotalCurrentAllocation    *big.Int
	AbsoluteTargetAllocation  []*big.Int
	TotalTargetAllocation     *big.Int
}, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "getAllocations")

	outstruct := new(struct {
		AbsoluteCurrentAllocation []*big.Int
		TotalCurrentAllocation    *big.Int
		AbsoluteTargetAllocation  []*big.Int
		TotalTargetAllocation     *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.AbsoluteCurrentAllocation = *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)
	outstruct.TotalCurrentAllocation = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.AbsoluteTargetAllocation = *abi.ConvertType(out[2], new([]*big.Int)).(*[]*big.Int)
	outstruct.TotalTargetAllocation = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetAllocations is a free data retrieval call binding the contract method 0x65ed6e23.
//
// Solidity: function getAllocations() view returns(uint256[] absoluteCurrentAllocation, uint256 totalCurrentAllocation, uint256[] absoluteTargetAllocation, uint256 totalTargetAllocation)
func (_SuperAsset *SuperAssetSession) GetAllocations() (struct {
	AbsoluteCurrentAllocation []*big.Int
	TotalCurrentAllocation    *big.Int
	AbsoluteTargetAllocation  []*big.Int
	TotalTargetAllocation     *big.Int
}, error) {
	return _SuperAsset.Contract.GetAllocations(&_SuperAsset.CallOpts)
}

// GetAllocations is a free data retrieval call binding the contract method 0x65ed6e23.
//
// Solidity: function getAllocations() view returns(uint256[] absoluteCurrentAllocation, uint256 totalCurrentAllocation, uint256[] absoluteTargetAllocation, uint256 totalTargetAllocation)
func (_SuperAsset *SuperAssetCallerSession) GetAllocations() (struct {
	AbsoluteCurrentAllocation []*big.Int
	TotalCurrentAllocation    *big.Int
	AbsoluteTargetAllocation  []*big.Int
	TotalTargetAllocation     *big.Int
}, error) {
	return _SuperAsset.Contract.GetAllocations(&_SuperAsset.CallOpts)
}

// GetAllocationsPrePostOperation is a free data retrieval call binding the contract method 0x9e37b464.
//
// Solidity: function getAllocationsPrePostOperation(address token, int256 deltaToken, bool isSoft) view returns(uint256[] absoluteAllocationPreOperation, uint256 totalAllocationPreOperation, uint256[] absoluteAllocationPostOperation, uint256 totalAllocationPostOperation, uint256[] absoluteTargetAllocation, uint256 totalTargetAllocation, uint256[] vaultWeights, bool isSuccess)
func (_SuperAsset *SuperAssetCaller) GetAllocationsPrePostOperation(opts *bind.CallOpts, token common.Address, deltaToken *big.Int, isSoft bool) (struct {
	AbsoluteAllocationPreOperation  []*big.Int
	TotalAllocationPreOperation     *big.Int
	AbsoluteAllocationPostOperation []*big.Int
	TotalAllocationPostOperation    *big.Int
	AbsoluteTargetAllocation        []*big.Int
	TotalTargetAllocation           *big.Int
	VaultWeights                    []*big.Int
	IsSuccess                       bool
}, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "getAllocationsPrePostOperation", token, deltaToken, isSoft)

	outstruct := new(struct {
		AbsoluteAllocationPreOperation  []*big.Int
		TotalAllocationPreOperation     *big.Int
		AbsoluteAllocationPostOperation []*big.Int
		TotalAllocationPostOperation    *big.Int
		AbsoluteTargetAllocation        []*big.Int
		TotalTargetAllocation           *big.Int
		VaultWeights                    []*big.Int
		IsSuccess                       bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.AbsoluteAllocationPreOperation = *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)
	outstruct.TotalAllocationPreOperation = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.AbsoluteAllocationPostOperation = *abi.ConvertType(out[2], new([]*big.Int)).(*[]*big.Int)
	outstruct.TotalAllocationPostOperation = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)
	outstruct.AbsoluteTargetAllocation = *abi.ConvertType(out[4], new([]*big.Int)).(*[]*big.Int)
	outstruct.TotalTargetAllocation = *abi.ConvertType(out[5], new(*big.Int)).(**big.Int)
	outstruct.VaultWeights = *abi.ConvertType(out[6], new([]*big.Int)).(*[]*big.Int)
	outstruct.IsSuccess = *abi.ConvertType(out[7], new(bool)).(*bool)

	return *outstruct, err

}

// GetAllocationsPrePostOperation is a free data retrieval call binding the contract method 0x9e37b464.
//
// Solidity: function getAllocationsPrePostOperation(address token, int256 deltaToken, bool isSoft) view returns(uint256[] absoluteAllocationPreOperation, uint256 totalAllocationPreOperation, uint256[] absoluteAllocationPostOperation, uint256 totalAllocationPostOperation, uint256[] absoluteTargetAllocation, uint256 totalTargetAllocation, uint256[] vaultWeights, bool isSuccess)
func (_SuperAsset *SuperAssetSession) GetAllocationsPrePostOperation(token common.Address, deltaToken *big.Int, isSoft bool) (struct {
	AbsoluteAllocationPreOperation  []*big.Int
	TotalAllocationPreOperation     *big.Int
	AbsoluteAllocationPostOperation []*big.Int
	TotalAllocationPostOperation    *big.Int
	AbsoluteTargetAllocation        []*big.Int
	TotalTargetAllocation           *big.Int
	VaultWeights                    []*big.Int
	IsSuccess                       bool
}, error) {
	return _SuperAsset.Contract.GetAllocationsPrePostOperation(&_SuperAsset.CallOpts, token, deltaToken, isSoft)
}

// GetAllocationsPrePostOperation is a free data retrieval call binding the contract method 0x9e37b464.
//
// Solidity: function getAllocationsPrePostOperation(address token, int256 deltaToken, bool isSoft) view returns(uint256[] absoluteAllocationPreOperation, uint256 totalAllocationPreOperation, uint256[] absoluteAllocationPostOperation, uint256 totalAllocationPostOperation, uint256[] absoluteTargetAllocation, uint256 totalTargetAllocation, uint256[] vaultWeights, bool isSuccess)
func (_SuperAsset *SuperAssetCallerSession) GetAllocationsPrePostOperation(token common.Address, deltaToken *big.Int, isSoft bool) (struct {
	AbsoluteAllocationPreOperation  []*big.Int
	TotalAllocationPreOperation     *big.Int
	AbsoluteAllocationPostOperation []*big.Int
	TotalAllocationPostOperation    *big.Int
	AbsoluteTargetAllocation        []*big.Int
	TotalTargetAllocation           *big.Int
	VaultWeights                    []*big.Int
	IsSuccess                       bool
}, error) {
	return _SuperAsset.Contract.GetAllocationsPrePostOperation(&_SuperAsset.CallOpts, token, deltaToken, isSoft)
}

// GetPrecision is a free data retrieval call binding the contract method 0x9670c0bc.
//
// Solidity: function getPrecision() pure returns(uint256)
func (_SuperAsset *SuperAssetCaller) GetPrecision(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "getPrecision")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPrecision is a free data retrieval call binding the contract method 0x9670c0bc.
//
// Solidity: function getPrecision() pure returns(uint256)
func (_SuperAsset *SuperAssetSession) GetPrecision() (*big.Int, error) {
	return _SuperAsset.Contract.GetPrecision(&_SuperAsset.CallOpts)
}

// GetPrecision is a free data retrieval call binding the contract method 0x9670c0bc.
//
// Solidity: function getPrecision() pure returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) GetPrecision() (*big.Int, error) {
	return _SuperAsset.Contract.GetPrecision(&_SuperAsset.CallOpts)
}

// GetPriceWithCircuitBreakers is a free data retrieval call binding the contract method 0xb98cf2cc.
//
// Solidity: function getPriceWithCircuitBreakers(address token) view returns(uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
func (_SuperAsset *SuperAssetCaller) GetPriceWithCircuitBreakers(opts *bind.CallOpts, token common.Address) (struct {
	PriceUSD     *big.Int
	IsDepeg      bool
	IsDispersion bool
	IsOracleOff  bool
}, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "getPriceWithCircuitBreakers", token)

	outstruct := new(struct {
		PriceUSD     *big.Int
		IsDepeg      bool
		IsDispersion bool
		IsOracleOff  bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.PriceUSD = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.IsDepeg = *abi.ConvertType(out[1], new(bool)).(*bool)
	outstruct.IsDispersion = *abi.ConvertType(out[2], new(bool)).(*bool)
	outstruct.IsOracleOff = *abi.ConvertType(out[3], new(bool)).(*bool)

	return *outstruct, err

}

// GetPriceWithCircuitBreakers is a free data retrieval call binding the contract method 0xb98cf2cc.
//
// Solidity: function getPriceWithCircuitBreakers(address token) view returns(uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
func (_SuperAsset *SuperAssetSession) GetPriceWithCircuitBreakers(token common.Address) (struct {
	PriceUSD     *big.Int
	IsDepeg      bool
	IsDispersion bool
	IsOracleOff  bool
}, error) {
	return _SuperAsset.Contract.GetPriceWithCircuitBreakers(&_SuperAsset.CallOpts, token)
}

// GetPriceWithCircuitBreakers is a free data retrieval call binding the contract method 0xb98cf2cc.
//
// Solidity: function getPriceWithCircuitBreakers(address token) view returns(uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
func (_SuperAsset *SuperAssetCallerSession) GetPriceWithCircuitBreakers(token common.Address) (struct {
	PriceUSD     *big.Int
	IsDepeg      bool
	IsDispersion bool
	IsOracleOff  bool
}, error) {
	return _SuperAsset.Contract.GetPriceWithCircuitBreakers(&_SuperAsset.CallOpts, token)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperAsset *SuperAssetCaller) GetRoleAdmin(opts *bind.CallOpts, role [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "getRoleAdmin", role)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperAsset *SuperAssetSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperAsset.Contract.GetRoleAdmin(&_SuperAsset.CallOpts, role)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperAsset *SuperAssetCallerSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperAsset.Contract.GetRoleAdmin(&_SuperAsset.CallOpts, role)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperAsset *SuperAssetCaller) HasRole(opts *bind.CallOpts, role [32]byte, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "hasRole", role, account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperAsset *SuperAssetSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperAsset.Contract.HasRole(&_SuperAsset.CallOpts, role, account)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperAsset *SuperAssetCallerSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperAsset.Contract.HasRole(&_SuperAsset.CallOpts, role, account)
}

// IncentiveCalculationContract is a free data retrieval call binding the contract method 0xd3b472c5.
//
// Solidity: function incentiveCalculationContract() view returns(address)
func (_SuperAsset *SuperAssetCaller) IncentiveCalculationContract(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "incentiveCalculationContract")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// IncentiveCalculationContract is a free data retrieval call binding the contract method 0xd3b472c5.
//
// Solidity: function incentiveCalculationContract() view returns(address)
func (_SuperAsset *SuperAssetSession) IncentiveCalculationContract() (common.Address, error) {
	return _SuperAsset.Contract.IncentiveCalculationContract(&_SuperAsset.CallOpts)
}

// IncentiveCalculationContract is a free data retrieval call binding the contract method 0xd3b472c5.
//
// Solidity: function incentiveCalculationContract() view returns(address)
func (_SuperAsset *SuperAssetCallerSession) IncentiveCalculationContract() (common.Address, error) {
	return _SuperAsset.Contract.IncentiveCalculationContract(&_SuperAsset.CallOpts)
}

// IncentiveFundContract is a free data retrieval call binding the contract method 0x5a86ee6f.
//
// Solidity: function incentiveFundContract() view returns(address)
func (_SuperAsset *SuperAssetCaller) IncentiveFundContract(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "incentiveFundContract")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// IncentiveFundContract is a free data retrieval call binding the contract method 0x5a86ee6f.
//
// Solidity: function incentiveFundContract() view returns(address)
func (_SuperAsset *SuperAssetSession) IncentiveFundContract() (common.Address, error) {
	return _SuperAsset.Contract.IncentiveFundContract(&_SuperAsset.CallOpts)
}

// IncentiveFundContract is a free data retrieval call binding the contract method 0x5a86ee6f.
//
// Solidity: function incentiveFundContract() view returns(address)
func (_SuperAsset *SuperAssetCallerSession) IncentiveFundContract() (common.Address, error) {
	return _SuperAsset.Contract.IncentiveFundContract(&_SuperAsset.CallOpts)
}

// IsSupportedERC20 is a free data retrieval call binding the contract method 0xa1e0765a.
//
// Solidity: function isSupportedERC20(address token) view returns(bool isSupported)
func (_SuperAsset *SuperAssetCaller) IsSupportedERC20(opts *bind.CallOpts, token common.Address) (bool, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "isSupportedERC20", token)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsSupportedERC20 is a free data retrieval call binding the contract method 0xa1e0765a.
//
// Solidity: function isSupportedERC20(address token) view returns(bool isSupported)
func (_SuperAsset *SuperAssetSession) IsSupportedERC20(token common.Address) (bool, error) {
	return _SuperAsset.Contract.IsSupportedERC20(&_SuperAsset.CallOpts, token)
}

// IsSupportedERC20 is a free data retrieval call binding the contract method 0xa1e0765a.
//
// Solidity: function isSupportedERC20(address token) view returns(bool isSupported)
func (_SuperAsset *SuperAssetCallerSession) IsSupportedERC20(token common.Address) (bool, error) {
	return _SuperAsset.Contract.IsSupportedERC20(&_SuperAsset.CallOpts, token)
}

// IsSupportedUnderlyingVault is a free data retrieval call binding the contract method 0x3a6b87df.
//
// Solidity: function isSupportedUnderlyingVault(address token) view returns(bool isSupported)
func (_SuperAsset *SuperAssetCaller) IsSupportedUnderlyingVault(opts *bind.CallOpts, token common.Address) (bool, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "isSupportedUnderlyingVault", token)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsSupportedUnderlyingVault is a free data retrieval call binding the contract method 0x3a6b87df.
//
// Solidity: function isSupportedUnderlyingVault(address token) view returns(bool isSupported)
func (_SuperAsset *SuperAssetSession) IsSupportedUnderlyingVault(token common.Address) (bool, error) {
	return _SuperAsset.Contract.IsSupportedUnderlyingVault(&_SuperAsset.CallOpts, token)
}

// IsSupportedUnderlyingVault is a free data retrieval call binding the contract method 0x3a6b87df.
//
// Solidity: function isSupportedUnderlyingVault(address token) view returns(bool isSupported)
func (_SuperAsset *SuperAssetCallerSession) IsSupportedUnderlyingVault(token common.Address) (bool, error) {
	return _SuperAsset.Contract.IsSupportedUnderlyingVault(&_SuperAsset.CallOpts, token)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperAsset *SuperAssetCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperAsset *SuperAssetSession) Name() (string, error) {
	return _SuperAsset.Contract.Name(&_SuperAsset.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperAsset *SuperAssetCallerSession) Name() (string, error) {
	return _SuperAsset.Contract.Name(&_SuperAsset.CallOpts)
}

// PreviewDeposit is a free data retrieval call binding the contract method 0x8d8a9911.
//
// Solidity: function previewDeposit(address tokenIn, uint256 amountTokenToDeposit, bool isSoft) view returns(uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
func (_SuperAsset *SuperAssetCaller) PreviewDeposit(opts *bind.CallOpts, tokenIn common.Address, amountTokenToDeposit *big.Int, isSoft bool) (struct {
	AmountSharesMinted *big.Int
	SwapFee            *big.Int
	AmountIncentiveUSD *big.Int
	IsSuccess          bool
}, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "previewDeposit", tokenIn, amountTokenToDeposit, isSoft)

	outstruct := new(struct {
		AmountSharesMinted *big.Int
		SwapFee            *big.Int
		AmountIncentiveUSD *big.Int
		IsSuccess          bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.AmountSharesMinted = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.SwapFee = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.AmountIncentiveUSD = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)
	outstruct.IsSuccess = *abi.ConvertType(out[3], new(bool)).(*bool)

	return *outstruct, err

}

// PreviewDeposit is a free data retrieval call binding the contract method 0x8d8a9911.
//
// Solidity: function previewDeposit(address tokenIn, uint256 amountTokenToDeposit, bool isSoft) view returns(uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
func (_SuperAsset *SuperAssetSession) PreviewDeposit(tokenIn common.Address, amountTokenToDeposit *big.Int, isSoft bool) (struct {
	AmountSharesMinted *big.Int
	SwapFee            *big.Int
	AmountIncentiveUSD *big.Int
	IsSuccess          bool
}, error) {
	return _SuperAsset.Contract.PreviewDeposit(&_SuperAsset.CallOpts, tokenIn, amountTokenToDeposit, isSoft)
}

// PreviewDeposit is a free data retrieval call binding the contract method 0x8d8a9911.
//
// Solidity: function previewDeposit(address tokenIn, uint256 amountTokenToDeposit, bool isSoft) view returns(uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
func (_SuperAsset *SuperAssetCallerSession) PreviewDeposit(tokenIn common.Address, amountTokenToDeposit *big.Int, isSoft bool) (struct {
	AmountSharesMinted *big.Int
	SwapFee            *big.Int
	AmountIncentiveUSD *big.Int
	IsSuccess          bool
}, error) {
	return _SuperAsset.Contract.PreviewDeposit(&_SuperAsset.CallOpts, tokenIn, amountTokenToDeposit, isSoft)
}

// PreviewRedeem is a free data retrieval call binding the contract method 0xfa9a23e5.
//
// Solidity: function previewRedeem(address tokenOut, uint256 amountSharesToRedeem, bool isSoft) view returns(uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
func (_SuperAsset *SuperAssetCaller) PreviewRedeem(opts *bind.CallOpts, tokenOut common.Address, amountSharesToRedeem *big.Int, isSoft bool) (struct {
	AmountTokenOutAfterFees *big.Int
	SwapFee                 *big.Int
	AmountIncentiveUSD      *big.Int
	IsSuccess               bool
}, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "previewRedeem", tokenOut, amountSharesToRedeem, isSoft)

	outstruct := new(struct {
		AmountTokenOutAfterFees *big.Int
		SwapFee                 *big.Int
		AmountIncentiveUSD      *big.Int
		IsSuccess               bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.AmountTokenOutAfterFees = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.SwapFee = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.AmountIncentiveUSD = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)
	outstruct.IsSuccess = *abi.ConvertType(out[3], new(bool)).(*bool)

	return *outstruct, err

}

// PreviewRedeem is a free data retrieval call binding the contract method 0xfa9a23e5.
//
// Solidity: function previewRedeem(address tokenOut, uint256 amountSharesToRedeem, bool isSoft) view returns(uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
func (_SuperAsset *SuperAssetSession) PreviewRedeem(tokenOut common.Address, amountSharesToRedeem *big.Int, isSoft bool) (struct {
	AmountTokenOutAfterFees *big.Int
	SwapFee                 *big.Int
	AmountIncentiveUSD      *big.Int
	IsSuccess               bool
}, error) {
	return _SuperAsset.Contract.PreviewRedeem(&_SuperAsset.CallOpts, tokenOut, amountSharesToRedeem, isSoft)
}

// PreviewRedeem is a free data retrieval call binding the contract method 0xfa9a23e5.
//
// Solidity: function previewRedeem(address tokenOut, uint256 amountSharesToRedeem, bool isSoft) view returns(uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
func (_SuperAsset *SuperAssetCallerSession) PreviewRedeem(tokenOut common.Address, amountSharesToRedeem *big.Int, isSoft bool) (struct {
	AmountTokenOutAfterFees *big.Int
	SwapFee                 *big.Int
	AmountIncentiveUSD      *big.Int
	IsSuccess               bool
}, error) {
	return _SuperAsset.Contract.PreviewRedeem(&_SuperAsset.CallOpts, tokenOut, amountSharesToRedeem, isSoft)
}

// PreviewSwap is a free data retrieval call binding the contract method 0x746651de.
//
// Solidity: function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokenOut, bool isSoft) view returns(uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentiveUSDDeposit, int256 amountIncentiveUSDRedeem, bool isSuccess)
func (_SuperAsset *SuperAssetCaller) PreviewSwap(opts *bind.CallOpts, tokenIn common.Address, amountTokenToDeposit *big.Int, tokenOut common.Address, isSoft bool) (struct {
	AmountTokenOutAfterFees   *big.Int
	SwapFeeIn                 *big.Int
	SwapFeeOut                *big.Int
	AmountIncentiveUSDDeposit *big.Int
	AmountIncentiveUSDRedeem  *big.Int
	IsSuccess                 bool
}, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "previewSwap", tokenIn, amountTokenToDeposit, tokenOut, isSoft)

	outstruct := new(struct {
		AmountTokenOutAfterFees   *big.Int
		SwapFeeIn                 *big.Int
		SwapFeeOut                *big.Int
		AmountIncentiveUSDDeposit *big.Int
		AmountIncentiveUSDRedeem  *big.Int
		IsSuccess                 bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.AmountTokenOutAfterFees = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.SwapFeeIn = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.SwapFeeOut = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)
	outstruct.AmountIncentiveUSDDeposit = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)
	outstruct.AmountIncentiveUSDRedeem = *abi.ConvertType(out[4], new(*big.Int)).(**big.Int)
	outstruct.IsSuccess = *abi.ConvertType(out[5], new(bool)).(*bool)

	return *outstruct, err

}

// PreviewSwap is a free data retrieval call binding the contract method 0x746651de.
//
// Solidity: function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokenOut, bool isSoft) view returns(uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentiveUSDDeposit, int256 amountIncentiveUSDRedeem, bool isSuccess)
func (_SuperAsset *SuperAssetSession) PreviewSwap(tokenIn common.Address, amountTokenToDeposit *big.Int, tokenOut common.Address, isSoft bool) (struct {
	AmountTokenOutAfterFees   *big.Int
	SwapFeeIn                 *big.Int
	SwapFeeOut                *big.Int
	AmountIncentiveUSDDeposit *big.Int
	AmountIncentiveUSDRedeem  *big.Int
	IsSuccess                 bool
}, error) {
	return _SuperAsset.Contract.PreviewSwap(&_SuperAsset.CallOpts, tokenIn, amountTokenToDeposit, tokenOut, isSoft)
}

// PreviewSwap is a free data retrieval call binding the contract method 0x746651de.
//
// Solidity: function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokenOut, bool isSoft) view returns(uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentiveUSDDeposit, int256 amountIncentiveUSDRedeem, bool isSuccess)
func (_SuperAsset *SuperAssetCallerSession) PreviewSwap(tokenIn common.Address, amountTokenToDeposit *big.Int, tokenOut common.Address, isSoft bool) (struct {
	AmountTokenOutAfterFees   *big.Int
	SwapFeeIn                 *big.Int
	SwapFeeOut                *big.Int
	AmountIncentiveUSDDeposit *big.Int
	AmountIncentiveUSDRedeem  *big.Int
	IsSuccess                 bool
}, error) {
	return _SuperAsset.Contract.PreviewSwap(&_SuperAsset.CallOpts, tokenIn, amountTokenToDeposit, tokenOut, isSoft)
}

// SuperOracle is a free data retrieval call binding the contract method 0x3fbfddce.
//
// Solidity: function superOracle() view returns(address)
func (_SuperAsset *SuperAssetCaller) SuperOracle(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "superOracle")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperOracle is a free data retrieval call binding the contract method 0x3fbfddce.
//
// Solidity: function superOracle() view returns(address)
func (_SuperAsset *SuperAssetSession) SuperOracle() (common.Address, error) {
	return _SuperAsset.Contract.SuperOracle(&_SuperAsset.CallOpts)
}

// SuperOracle is a free data retrieval call binding the contract method 0x3fbfddce.
//
// Solidity: function superOracle() view returns(address)
func (_SuperAsset *SuperAssetCallerSession) SuperOracle() (common.Address, error) {
	return _SuperAsset.Contract.SuperOracle(&_SuperAsset.CallOpts)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperAsset *SuperAssetCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperAsset *SuperAssetSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperAsset.Contract.SupportsInterface(&_SuperAsset.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperAsset *SuperAssetCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperAsset.Contract.SupportsInterface(&_SuperAsset.CallOpts, interfaceId)
}

// SwapFeeInPercentage is a free data retrieval call binding the contract method 0xe606efeb.
//
// Solidity: function swapFeeInPercentage() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) SwapFeeInPercentage(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "swapFeeInPercentage")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SwapFeeInPercentage is a free data retrieval call binding the contract method 0xe606efeb.
//
// Solidity: function swapFeeInPercentage() view returns(uint256)
func (_SuperAsset *SuperAssetSession) SwapFeeInPercentage() (*big.Int, error) {
	return _SuperAsset.Contract.SwapFeeInPercentage(&_SuperAsset.CallOpts)
}

// SwapFeeInPercentage is a free data retrieval call binding the contract method 0xe606efeb.
//
// Solidity: function swapFeeInPercentage() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) SwapFeeInPercentage() (*big.Int, error) {
	return _SuperAsset.Contract.SwapFeeInPercentage(&_SuperAsset.CallOpts)
}

// SwapFeeOutPercentage is a free data retrieval call binding the contract method 0xb9158694.
//
// Solidity: function swapFeeOutPercentage() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) SwapFeeOutPercentage(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "swapFeeOutPercentage")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SwapFeeOutPercentage is a free data retrieval call binding the contract method 0xb9158694.
//
// Solidity: function swapFeeOutPercentage() view returns(uint256)
func (_SuperAsset *SuperAssetSession) SwapFeeOutPercentage() (*big.Int, error) {
	return _SuperAsset.Contract.SwapFeeOutPercentage(&_SuperAsset.CallOpts)
}

// SwapFeeOutPercentage is a free data retrieval call binding the contract method 0xb9158694.
//
// Solidity: function swapFeeOutPercentage() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) SwapFeeOutPercentage() (*big.Int, error) {
	return _SuperAsset.Contract.SwapFeeOutPercentage(&_SuperAsset.CallOpts)
}

// Symbol is a free data retrieval call binding the contract method 0x95d89b41.
//
// Solidity: function symbol() view returns(string)
func (_SuperAsset *SuperAssetCaller) Symbol(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "symbol")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Symbol is a free data retrieval call binding the contract method 0x95d89b41.
//
// Solidity: function symbol() view returns(string)
func (_SuperAsset *SuperAssetSession) Symbol() (string, error) {
	return _SuperAsset.Contract.Symbol(&_SuperAsset.CallOpts)
}

// Symbol is a free data retrieval call binding the contract method 0x95d89b41.
//
// Solidity: function symbol() view returns(string)
func (_SuperAsset *SuperAssetCallerSession) Symbol() (string, error) {
	return _SuperAsset.Contract.Symbol(&_SuperAsset.CallOpts)
}

// TargetAllocations is a free data retrieval call binding the contract method 0xe8f8080c.
//
// Solidity: function targetAllocations(address token) view returns(uint256 allocation)
func (_SuperAsset *SuperAssetCaller) TargetAllocations(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "targetAllocations", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TargetAllocations is a free data retrieval call binding the contract method 0xe8f8080c.
//
// Solidity: function targetAllocations(address token) view returns(uint256 allocation)
func (_SuperAsset *SuperAssetSession) TargetAllocations(token common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.TargetAllocations(&_SuperAsset.CallOpts, token)
}

// TargetAllocations is a free data retrieval call binding the contract method 0xe8f8080c.
//
// Solidity: function targetAllocations(address token) view returns(uint256 allocation)
func (_SuperAsset *SuperAssetCallerSession) TargetAllocations(token common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.TargetAllocations(&_SuperAsset.CallOpts, token)
}

// TotalSupply is a free data retrieval call binding the contract method 0x18160ddd.
//
// Solidity: function totalSupply() view returns(uint256)
func (_SuperAsset *SuperAssetCaller) TotalSupply(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "totalSupply")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TotalSupply is a free data retrieval call binding the contract method 0x18160ddd.
//
// Solidity: function totalSupply() view returns(uint256)
func (_SuperAsset *SuperAssetSession) TotalSupply() (*big.Int, error) {
	return _SuperAsset.Contract.TotalSupply(&_SuperAsset.CallOpts)
}

// TotalSupply is a free data retrieval call binding the contract method 0x18160ddd.
//
// Solidity: function totalSupply() view returns(uint256)
func (_SuperAsset *SuperAssetCallerSession) TotalSupply() (*big.Int, error) {
	return _SuperAsset.Contract.TotalSupply(&_SuperAsset.CallOpts)
}

// Weights is a free data retrieval call binding the contract method 0xa7cac846.
//
// Solidity: function weights(address token) view returns(uint256 allocation)
func (_SuperAsset *SuperAssetCaller) Weights(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperAsset.contract.Call(opts, &out, "weights", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Weights is a free data retrieval call binding the contract method 0xa7cac846.
//
// Solidity: function weights(address token) view returns(uint256 allocation)
func (_SuperAsset *SuperAssetSession) Weights(token common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.Weights(&_SuperAsset.CallOpts, token)
}

// Weights is a free data retrieval call binding the contract method 0xa7cac846.
//
// Solidity: function weights(address token) view returns(uint256 allocation)
func (_SuperAsset *SuperAssetCallerSession) Weights(token common.Address) (*big.Int, error) {
	return _SuperAsset.Contract.Weights(&_SuperAsset.CallOpts, token)
}

// Approve is a paid mutator transaction binding the contract method 0x095ea7b3.
//
// Solidity: function approve(address spender, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetTransactor) Approve(opts *bind.TransactOpts, spender common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "approve", spender, value)
}

// Approve is a paid mutator transaction binding the contract method 0x095ea7b3.
//
// Solidity: function approve(address spender, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetSession) Approve(spender common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Approve(&_SuperAsset.TransactOpts, spender, value)
}

// Approve is a paid mutator transaction binding the contract method 0x095ea7b3.
//
// Solidity: function approve(address spender, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetTransactorSession) Approve(spender common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Approve(&_SuperAsset.TransactOpts, spender, value)
}

// Burn is a paid mutator transaction binding the contract method 0x9dc29fac.
//
// Solidity: function burn(address from, uint256 amount) returns()
func (_SuperAsset *SuperAssetTransactor) Burn(opts *bind.TransactOpts, from common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "burn", from, amount)
}

// Burn is a paid mutator transaction binding the contract method 0x9dc29fac.
//
// Solidity: function burn(address from, uint256 amount) returns()
func (_SuperAsset *SuperAssetSession) Burn(from common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Burn(&_SuperAsset.TransactOpts, from, amount)
}

// Burn is a paid mutator transaction binding the contract method 0x9dc29fac.
//
// Solidity: function burn(address from, uint256 amount) returns()
func (_SuperAsset *SuperAssetTransactorSession) Burn(from common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Burn(&_SuperAsset.TransactOpts, from, amount)
}

// Deposit is a paid mutator transaction binding the contract method 0x20e8c565.
//
// Solidity: function deposit(address receiver, address yieldSourceShare, uint256 amountTokenToDeposit, uint256 minSharesOut) returns(uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit)
func (_SuperAsset *SuperAssetTransactor) Deposit(opts *bind.TransactOpts, receiver common.Address, yieldSourceShare common.Address, amountTokenToDeposit *big.Int, minSharesOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "deposit", receiver, yieldSourceShare, amountTokenToDeposit, minSharesOut)
}

// Deposit is a paid mutator transaction binding the contract method 0x20e8c565.
//
// Solidity: function deposit(address receiver, address yieldSourceShare, uint256 amountTokenToDeposit, uint256 minSharesOut) returns(uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit)
func (_SuperAsset *SuperAssetSession) Deposit(receiver common.Address, yieldSourceShare common.Address, amountTokenToDeposit *big.Int, minSharesOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Deposit(&_SuperAsset.TransactOpts, receiver, yieldSourceShare, amountTokenToDeposit, minSharesOut)
}

// Deposit is a paid mutator transaction binding the contract method 0x20e8c565.
//
// Solidity: function deposit(address receiver, address yieldSourceShare, uint256 amountTokenToDeposit, uint256 minSharesOut) returns(uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit)
func (_SuperAsset *SuperAssetTransactorSession) Deposit(receiver common.Address, yieldSourceShare common.Address, amountTokenToDeposit *big.Int, minSharesOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Deposit(&_SuperAsset.TransactOpts, receiver, yieldSourceShare, amountTokenToDeposit, minSharesOut)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperAsset *SuperAssetTransactor) GrantRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "grantRole", role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperAsset *SuperAssetSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.GrantRole(&_SuperAsset.TransactOpts, role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperAsset *SuperAssetTransactorSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.GrantRole(&_SuperAsset.TransactOpts, role, account)
}

// Initialize is a paid mutator transaction binding the contract method 0xcd3fa04b.
//
// Solidity: function initialize(string name_, string symbol_, address icc_, address ifc_, address assetBank_, uint256 swapFeeInPercentage_, uint256 swapFeeOutPercentage_) returns()
func (_SuperAsset *SuperAssetTransactor) Initialize(opts *bind.TransactOpts, name_ string, symbol_ string, icc_ common.Address, ifc_ common.Address, assetBank_ common.Address, swapFeeInPercentage_ *big.Int, swapFeeOutPercentage_ *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "initialize", name_, symbol_, icc_, ifc_, assetBank_, swapFeeInPercentage_, swapFeeOutPercentage_)
}

// Initialize is a paid mutator transaction binding the contract method 0xcd3fa04b.
//
// Solidity: function initialize(string name_, string symbol_, address icc_, address ifc_, address assetBank_, uint256 swapFeeInPercentage_, uint256 swapFeeOutPercentage_) returns()
func (_SuperAsset *SuperAssetSession) Initialize(name_ string, symbol_ string, icc_ common.Address, ifc_ common.Address, assetBank_ common.Address, swapFeeInPercentage_ *big.Int, swapFeeOutPercentage_ *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Initialize(&_SuperAsset.TransactOpts, name_, symbol_, icc_, ifc_, assetBank_, swapFeeInPercentage_, swapFeeOutPercentage_)
}

// Initialize is a paid mutator transaction binding the contract method 0xcd3fa04b.
//
// Solidity: function initialize(string name_, string symbol_, address icc_, address ifc_, address assetBank_, uint256 swapFeeInPercentage_, uint256 swapFeeOutPercentage_) returns()
func (_SuperAsset *SuperAssetTransactorSession) Initialize(name_ string, symbol_ string, icc_ common.Address, ifc_ common.Address, assetBank_ common.Address, swapFeeInPercentage_ *big.Int, swapFeeOutPercentage_ *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Initialize(&_SuperAsset.TransactOpts, name_, symbol_, icc_, ifc_, assetBank_, swapFeeInPercentage_, swapFeeOutPercentage_)
}

// Mint is a paid mutator transaction binding the contract method 0x40c10f19.
//
// Solidity: function mint(address to, uint256 amount) returns()
func (_SuperAsset *SuperAssetTransactor) Mint(opts *bind.TransactOpts, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "mint", to, amount)
}

// Mint is a paid mutator transaction binding the contract method 0x40c10f19.
//
// Solidity: function mint(address to, uint256 amount) returns()
func (_SuperAsset *SuperAssetSession) Mint(to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Mint(&_SuperAsset.TransactOpts, to, amount)
}

// Mint is a paid mutator transaction binding the contract method 0x40c10f19.
//
// Solidity: function mint(address to, uint256 amount) returns()
func (_SuperAsset *SuperAssetTransactorSession) Mint(to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Mint(&_SuperAsset.TransactOpts, to, amount)
}

// Redeem is a paid mutator transaction binding the contract method 0xf3f094a1.
//
// Solidity: function redeem(address receiver, uint256 amountSharesToRedeem, address tokenOut, uint256 minTokenOut) returns(uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem)
func (_SuperAsset *SuperAssetTransactor) Redeem(opts *bind.TransactOpts, receiver common.Address, amountSharesToRedeem *big.Int, tokenOut common.Address, minTokenOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "redeem", receiver, amountSharesToRedeem, tokenOut, minTokenOut)
}

// Redeem is a paid mutator transaction binding the contract method 0xf3f094a1.
//
// Solidity: function redeem(address receiver, uint256 amountSharesToRedeem, address tokenOut, uint256 minTokenOut) returns(uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem)
func (_SuperAsset *SuperAssetSession) Redeem(receiver common.Address, amountSharesToRedeem *big.Int, tokenOut common.Address, minTokenOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Redeem(&_SuperAsset.TransactOpts, receiver, amountSharesToRedeem, tokenOut, minTokenOut)
}

// Redeem is a paid mutator transaction binding the contract method 0xf3f094a1.
//
// Solidity: function redeem(address receiver, uint256 amountSharesToRedeem, address tokenOut, uint256 minTokenOut) returns(uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem)
func (_SuperAsset *SuperAssetTransactorSession) Redeem(receiver common.Address, amountSharesToRedeem *big.Int, tokenOut common.Address, minTokenOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Redeem(&_SuperAsset.TransactOpts, receiver, amountSharesToRedeem, tokenOut, minTokenOut)
}

// RemoveERC20 is a paid mutator transaction binding the contract method 0xa67755c2.
//
// Solidity: function removeERC20(address token) returns()
func (_SuperAsset *SuperAssetTransactor) RemoveERC20(opts *bind.TransactOpts, token common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "removeERC20", token)
}

// RemoveERC20 is a paid mutator transaction binding the contract method 0xa67755c2.
//
// Solidity: function removeERC20(address token) returns()
func (_SuperAsset *SuperAssetSession) RemoveERC20(token common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RemoveERC20(&_SuperAsset.TransactOpts, token)
}

// RemoveERC20 is a paid mutator transaction binding the contract method 0xa67755c2.
//
// Solidity: function removeERC20(address token) returns()
func (_SuperAsset *SuperAssetTransactorSession) RemoveERC20(token common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RemoveERC20(&_SuperAsset.TransactOpts, token)
}

// RemoveVault is a paid mutator transaction binding the contract method 0xceb68c23.
//
// Solidity: function removeVault(address vault) returns()
func (_SuperAsset *SuperAssetTransactor) RemoveVault(opts *bind.TransactOpts, vault common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "removeVault", vault)
}

// RemoveVault is a paid mutator transaction binding the contract method 0xceb68c23.
//
// Solidity: function removeVault(address vault) returns()
func (_SuperAsset *SuperAssetSession) RemoveVault(vault common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RemoveVault(&_SuperAsset.TransactOpts, vault)
}

// RemoveVault is a paid mutator transaction binding the contract method 0xceb68c23.
//
// Solidity: function removeVault(address vault) returns()
func (_SuperAsset *SuperAssetTransactorSession) RemoveVault(vault common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RemoveVault(&_SuperAsset.TransactOpts, vault)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperAsset *SuperAssetTransactor) RenounceRole(opts *bind.TransactOpts, role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "renounceRole", role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperAsset *SuperAssetSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RenounceRole(&_SuperAsset.TransactOpts, role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperAsset *SuperAssetTransactorSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RenounceRole(&_SuperAsset.TransactOpts, role, callerConfirmation)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperAsset *SuperAssetTransactor) RevokeRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "revokeRole", role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperAsset *SuperAssetSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RevokeRole(&_SuperAsset.TransactOpts, role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperAsset *SuperAssetTransactorSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.RevokeRole(&_SuperAsset.TransactOpts, role, account)
}

// SetEnergyToUSDExchangeRatio is a paid mutator transaction binding the contract method 0xb57ad03a.
//
// Solidity: function setEnergyToUSDExchangeRatio(uint256 newRatio) returns()
func (_SuperAsset *SuperAssetTransactor) SetEnergyToUSDExchangeRatio(opts *bind.TransactOpts, newRatio *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "setEnergyToUSDExchangeRatio", newRatio)
}

// SetEnergyToUSDExchangeRatio is a paid mutator transaction binding the contract method 0xb57ad03a.
//
// Solidity: function setEnergyToUSDExchangeRatio(uint256 newRatio) returns()
func (_SuperAsset *SuperAssetSession) SetEnergyToUSDExchangeRatio(newRatio *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetEnergyToUSDExchangeRatio(&_SuperAsset.TransactOpts, newRatio)
}

// SetEnergyToUSDExchangeRatio is a paid mutator transaction binding the contract method 0xb57ad03a.
//
// Solidity: function setEnergyToUSDExchangeRatio(uint256 newRatio) returns()
func (_SuperAsset *SuperAssetTransactorSession) SetEnergyToUSDExchangeRatio(newRatio *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetEnergyToUSDExchangeRatio(&_SuperAsset.TransactOpts, newRatio)
}

// SetSuperOracle is a paid mutator transaction binding the contract method 0x1e86e46b.
//
// Solidity: function setSuperOracle(address oracle) returns()
func (_SuperAsset *SuperAssetTransactor) SetSuperOracle(opts *bind.TransactOpts, oracle common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "setSuperOracle", oracle)
}

// SetSuperOracle is a paid mutator transaction binding the contract method 0x1e86e46b.
//
// Solidity: function setSuperOracle(address oracle) returns()
func (_SuperAsset *SuperAssetSession) SetSuperOracle(oracle common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetSuperOracle(&_SuperAsset.TransactOpts, oracle)
}

// SetSuperOracle is a paid mutator transaction binding the contract method 0x1e86e46b.
//
// Solidity: function setSuperOracle(address oracle) returns()
func (_SuperAsset *SuperAssetTransactorSession) SetSuperOracle(oracle common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetSuperOracle(&_SuperAsset.TransactOpts, oracle)
}

// SetSwapFeeInPercentage is a paid mutator transaction binding the contract method 0x9183ecd9.
//
// Solidity: function setSwapFeeInPercentage(uint256 _feePercentage) returns()
func (_SuperAsset *SuperAssetTransactor) SetSwapFeeInPercentage(opts *bind.TransactOpts, _feePercentage *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "setSwapFeeInPercentage", _feePercentage)
}

// SetSwapFeeInPercentage is a paid mutator transaction binding the contract method 0x9183ecd9.
//
// Solidity: function setSwapFeeInPercentage(uint256 _feePercentage) returns()
func (_SuperAsset *SuperAssetSession) SetSwapFeeInPercentage(_feePercentage *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetSwapFeeInPercentage(&_SuperAsset.TransactOpts, _feePercentage)
}

// SetSwapFeeInPercentage is a paid mutator transaction binding the contract method 0x9183ecd9.
//
// Solidity: function setSwapFeeInPercentage(uint256 _feePercentage) returns()
func (_SuperAsset *SuperAssetTransactorSession) SetSwapFeeInPercentage(_feePercentage *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetSwapFeeInPercentage(&_SuperAsset.TransactOpts, _feePercentage)
}

// SetSwapFeeOutPercentage is a paid mutator transaction binding the contract method 0x5bab5b1a.
//
// Solidity: function setSwapFeeOutPercentage(uint256 _feePercentage) returns()
func (_SuperAsset *SuperAssetTransactor) SetSwapFeeOutPercentage(opts *bind.TransactOpts, _feePercentage *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "setSwapFeeOutPercentage", _feePercentage)
}

// SetSwapFeeOutPercentage is a paid mutator transaction binding the contract method 0x5bab5b1a.
//
// Solidity: function setSwapFeeOutPercentage(uint256 _feePercentage) returns()
func (_SuperAsset *SuperAssetSession) SetSwapFeeOutPercentage(_feePercentage *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetSwapFeeOutPercentage(&_SuperAsset.TransactOpts, _feePercentage)
}

// SetSwapFeeOutPercentage is a paid mutator transaction binding the contract method 0x5bab5b1a.
//
// Solidity: function setSwapFeeOutPercentage(uint256 _feePercentage) returns()
func (_SuperAsset *SuperAssetTransactorSession) SetSwapFeeOutPercentage(_feePercentage *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetSwapFeeOutPercentage(&_SuperAsset.TransactOpts, _feePercentage)
}

// SetTargetAllocation is a paid mutator transaction binding the contract method 0x443990fa.
//
// Solidity: function setTargetAllocation(address token, uint256 allocation) returns()
func (_SuperAsset *SuperAssetTransactor) SetTargetAllocation(opts *bind.TransactOpts, token common.Address, allocation *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "setTargetAllocation", token, allocation)
}

// SetTargetAllocation is a paid mutator transaction binding the contract method 0x443990fa.
//
// Solidity: function setTargetAllocation(address token, uint256 allocation) returns()
func (_SuperAsset *SuperAssetSession) SetTargetAllocation(token common.Address, allocation *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetTargetAllocation(&_SuperAsset.TransactOpts, token, allocation)
}

// SetTargetAllocation is a paid mutator transaction binding the contract method 0x443990fa.
//
// Solidity: function setTargetAllocation(address token, uint256 allocation) returns()
func (_SuperAsset *SuperAssetTransactorSession) SetTargetAllocation(token common.Address, allocation *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetTargetAllocation(&_SuperAsset.TransactOpts, token, allocation)
}

// SetTargetAllocations is a paid mutator transaction binding the contract method 0xbbebbf14.
//
// Solidity: function setTargetAllocations(address[] tokens, uint256[] allocations) returns()
func (_SuperAsset *SuperAssetTransactor) SetTargetAllocations(opts *bind.TransactOpts, tokens []common.Address, allocations []*big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "setTargetAllocations", tokens, allocations)
}

// SetTargetAllocations is a paid mutator transaction binding the contract method 0xbbebbf14.
//
// Solidity: function setTargetAllocations(address[] tokens, uint256[] allocations) returns()
func (_SuperAsset *SuperAssetSession) SetTargetAllocations(tokens []common.Address, allocations []*big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetTargetAllocations(&_SuperAsset.TransactOpts, tokens, allocations)
}

// SetTargetAllocations is a paid mutator transaction binding the contract method 0xbbebbf14.
//
// Solidity: function setTargetAllocations(address[] tokens, uint256[] allocations) returns()
func (_SuperAsset *SuperAssetTransactorSession) SetTargetAllocations(tokens []common.Address, allocations []*big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetTargetAllocations(&_SuperAsset.TransactOpts, tokens, allocations)
}

// SetWeight is a paid mutator transaction binding the contract method 0x05ba0cf1.
//
// Solidity: function setWeight(address vault, uint256 weight) returns()
func (_SuperAsset *SuperAssetTransactor) SetWeight(opts *bind.TransactOpts, vault common.Address, weight *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "setWeight", vault, weight)
}

// SetWeight is a paid mutator transaction binding the contract method 0x05ba0cf1.
//
// Solidity: function setWeight(address vault, uint256 weight) returns()
func (_SuperAsset *SuperAssetSession) SetWeight(vault common.Address, weight *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetWeight(&_SuperAsset.TransactOpts, vault, weight)
}

// SetWeight is a paid mutator transaction binding the contract method 0x05ba0cf1.
//
// Solidity: function setWeight(address vault, uint256 weight) returns()
func (_SuperAsset *SuperAssetTransactorSession) SetWeight(vault common.Address, weight *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.SetWeight(&_SuperAsset.TransactOpts, vault, weight)
}

// Swap is a paid mutator transaction binding the contract method 0x17d88f46.
//
// Solidity: function swap(address receiver, address tokenIn, uint256 amountTokenToDeposit, address tokenOut, uint256 minTokenOut) returns(uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut)
func (_SuperAsset *SuperAssetTransactor) Swap(opts *bind.TransactOpts, receiver common.Address, tokenIn common.Address, amountTokenToDeposit *big.Int, tokenOut common.Address, minTokenOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "swap", receiver, tokenIn, amountTokenToDeposit, tokenOut, minTokenOut)
}

// Swap is a paid mutator transaction binding the contract method 0x17d88f46.
//
// Solidity: function swap(address receiver, address tokenIn, uint256 amountTokenToDeposit, address tokenOut, uint256 minTokenOut) returns(uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut)
func (_SuperAsset *SuperAssetSession) Swap(receiver common.Address, tokenIn common.Address, amountTokenToDeposit *big.Int, tokenOut common.Address, minTokenOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Swap(&_SuperAsset.TransactOpts, receiver, tokenIn, amountTokenToDeposit, tokenOut, minTokenOut)
}

// Swap is a paid mutator transaction binding the contract method 0x17d88f46.
//
// Solidity: function swap(address receiver, address tokenIn, uint256 amountTokenToDeposit, address tokenOut, uint256 minTokenOut) returns(uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut)
func (_SuperAsset *SuperAssetTransactorSession) Swap(receiver common.Address, tokenIn common.Address, amountTokenToDeposit *big.Int, tokenOut common.Address, minTokenOut *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Swap(&_SuperAsset.TransactOpts, receiver, tokenIn, amountTokenToDeposit, tokenOut, minTokenOut)
}

// Transfer is a paid mutator transaction binding the contract method 0xa9059cbb.
//
// Solidity: function transfer(address to, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetTransactor) Transfer(opts *bind.TransactOpts, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "transfer", to, value)
}

// Transfer is a paid mutator transaction binding the contract method 0xa9059cbb.
//
// Solidity: function transfer(address to, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetSession) Transfer(to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Transfer(&_SuperAsset.TransactOpts, to, value)
}

// Transfer is a paid mutator transaction binding the contract method 0xa9059cbb.
//
// Solidity: function transfer(address to, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetTransactorSession) Transfer(to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.Transfer(&_SuperAsset.TransactOpts, to, value)
}

// TransferFrom is a paid mutator transaction binding the contract method 0x23b872dd.
//
// Solidity: function transferFrom(address from, address to, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetTransactor) TransferFrom(opts *bind.TransactOpts, from common.Address, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "transferFrom", from, to, value)
}

// TransferFrom is a paid mutator transaction binding the contract method 0x23b872dd.
//
// Solidity: function transferFrom(address from, address to, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetSession) TransferFrom(from common.Address, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.TransferFrom(&_SuperAsset.TransactOpts, from, to, value)
}

// TransferFrom is a paid mutator transaction binding the contract method 0x23b872dd.
//
// Solidity: function transferFrom(address from, address to, uint256 value) returns(bool)
func (_SuperAsset *SuperAssetTransactorSession) TransferFrom(from common.Address, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperAsset.Contract.TransferFrom(&_SuperAsset.TransactOpts, from, to, value)
}

// WhitelistERC20 is a paid mutator transaction binding the contract method 0xe104ae59.
//
// Solidity: function whitelistERC20(address token) returns()
func (_SuperAsset *SuperAssetTransactor) WhitelistERC20(opts *bind.TransactOpts, token common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "whitelistERC20", token)
}

// WhitelistERC20 is a paid mutator transaction binding the contract method 0xe104ae59.
//
// Solidity: function whitelistERC20(address token) returns()
func (_SuperAsset *SuperAssetSession) WhitelistERC20(token common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.WhitelistERC20(&_SuperAsset.TransactOpts, token)
}

// WhitelistERC20 is a paid mutator transaction binding the contract method 0xe104ae59.
//
// Solidity: function whitelistERC20(address token) returns()
func (_SuperAsset *SuperAssetTransactorSession) WhitelistERC20(token common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.WhitelistERC20(&_SuperAsset.TransactOpts, token)
}

// WhitelistVault is a paid mutator transaction binding the contract method 0xe9d006ab.
//
// Solidity: function whitelistVault(address vault) returns()
func (_SuperAsset *SuperAssetTransactor) WhitelistVault(opts *bind.TransactOpts, vault common.Address) (*types.Transaction, error) {
	return _SuperAsset.contract.Transact(opts, "whitelistVault", vault)
}

// WhitelistVault is a paid mutator transaction binding the contract method 0xe9d006ab.
//
// Solidity: function whitelistVault(address vault) returns()
func (_SuperAsset *SuperAssetSession) WhitelistVault(vault common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.WhitelistVault(&_SuperAsset.TransactOpts, vault)
}

// WhitelistVault is a paid mutator transaction binding the contract method 0xe9d006ab.
//
// Solidity: function whitelistVault(address vault) returns()
func (_SuperAsset *SuperAssetTransactorSession) WhitelistVault(vault common.Address) (*types.Transaction, error) {
	return _SuperAsset.Contract.WhitelistVault(&_SuperAsset.TransactOpts, vault)
}

// SuperAssetApprovalIterator is returned from FilterApproval and is used to iterate over the raw logs and unpacked data for Approval events raised by the SuperAsset contract.
type SuperAssetApprovalIterator struct {
	Event *SuperAssetApproval // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetApprovalIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetApproval)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetApproval)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetApprovalIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetApprovalIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetApproval represents a Approval event raised by the SuperAsset contract.
type SuperAssetApproval struct {
	Owner   common.Address
	Spender common.Address
	Value   *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterApproval is a free log retrieval operation binding the contract event 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 value)
func (_SuperAsset *SuperAssetFilterer) FilterApproval(opts *bind.FilterOpts, owner []common.Address, spender []common.Address) (*SuperAssetApprovalIterator, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var spenderRule []interface{}
	for _, spenderItem := range spender {
		spenderRule = append(spenderRule, spenderItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "Approval", ownerRule, spenderRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetApprovalIterator{contract: _SuperAsset.contract, event: "Approval", logs: logs, sub: sub}, nil
}

// WatchApproval is a free log subscription operation binding the contract event 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 value)
func (_SuperAsset *SuperAssetFilterer) WatchApproval(opts *bind.WatchOpts, sink chan<- *SuperAssetApproval, owner []common.Address, spender []common.Address) (event.Subscription, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var spenderRule []interface{}
	for _, spenderItem := range spender {
		spenderRule = append(spenderRule, spenderItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "Approval", ownerRule, spenderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetApproval)
				if err := _SuperAsset.contract.UnpackLog(event, "Approval", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseApproval is a log parse operation binding the contract event 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 value)
func (_SuperAsset *SuperAssetFilterer) ParseApproval(log types.Log) (*SuperAssetApproval, error) {
	event := new(SuperAssetApproval)
	if err := _SuperAsset.contract.UnpackLog(event, "Approval", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetDepositIterator is returned from FilterDeposit and is used to iterate over the raw logs and unpacked data for Deposit events raised by the SuperAsset contract.
type SuperAssetDepositIterator struct {
	Event *SuperAssetDeposit // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetDepositIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetDeposit)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetDeposit)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetDepositIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetDepositIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetDeposit represents a Deposit event raised by the SuperAsset contract.
type SuperAssetDeposit struct {
	Receiver             common.Address
	TokenIn              common.Address
	AmountTokenToDeposit *big.Int
	AmountSharesOut      *big.Int
	SwapFee              *big.Int
	AmountIncentives     *big.Int
	Raw                  types.Log // Blockchain specific contextual infos
}

// FilterDeposit is a free log retrieval operation binding the contract event 0x4964a2f3ff9ebb89031ad424d9db5f7da0503c19e6838289ff78c0bf694c0790.
//
// Solidity: event Deposit(address indexed receiver, address indexed tokenIn, uint256 amountTokenToDeposit, uint256 amountSharesOut, uint256 swapFee, int256 amountIncentives)
func (_SuperAsset *SuperAssetFilterer) FilterDeposit(opts *bind.FilterOpts, receiver []common.Address, tokenIn []common.Address) (*SuperAssetDepositIterator, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}
	var tokenInRule []interface{}
	for _, tokenInItem := range tokenIn {
		tokenInRule = append(tokenInRule, tokenInItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "Deposit", receiverRule, tokenInRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetDepositIterator{contract: _SuperAsset.contract, event: "Deposit", logs: logs, sub: sub}, nil
}

// WatchDeposit is a free log subscription operation binding the contract event 0x4964a2f3ff9ebb89031ad424d9db5f7da0503c19e6838289ff78c0bf694c0790.
//
// Solidity: event Deposit(address indexed receiver, address indexed tokenIn, uint256 amountTokenToDeposit, uint256 amountSharesOut, uint256 swapFee, int256 amountIncentives)
func (_SuperAsset *SuperAssetFilterer) WatchDeposit(opts *bind.WatchOpts, sink chan<- *SuperAssetDeposit, receiver []common.Address, tokenIn []common.Address) (event.Subscription, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}
	var tokenInRule []interface{}
	for _, tokenInItem := range tokenIn {
		tokenInRule = append(tokenInRule, tokenInItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "Deposit", receiverRule, tokenInRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetDeposit)
				if err := _SuperAsset.contract.UnpackLog(event, "Deposit", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseDeposit is a log parse operation binding the contract event 0x4964a2f3ff9ebb89031ad424d9db5f7da0503c19e6838289ff78c0bf694c0790.
//
// Solidity: event Deposit(address indexed receiver, address indexed tokenIn, uint256 amountTokenToDeposit, uint256 amountSharesOut, uint256 swapFee, int256 amountIncentives)
func (_SuperAsset *SuperAssetFilterer) ParseDeposit(log types.Log) (*SuperAssetDeposit, error) {
	event := new(SuperAssetDeposit)
	if err := _SuperAsset.contract.UnpackLog(event, "Deposit", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetERC20RemovedIterator is returned from FilterERC20Removed and is used to iterate over the raw logs and unpacked data for ERC20Removed events raised by the SuperAsset contract.
type SuperAssetERC20RemovedIterator struct {
	Event *SuperAssetERC20Removed // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetERC20RemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetERC20Removed)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetERC20Removed)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetERC20RemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetERC20RemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetERC20Removed represents a ERC20Removed event raised by the SuperAsset contract.
type SuperAssetERC20Removed struct {
	Token common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterERC20Removed is a free log retrieval operation binding the contract event 0xf3f339312eadf076716643b0d29a97871056e9b21dc50fac35a10231ef5d0879.
//
// Solidity: event ERC20Removed(address indexed token)
func (_SuperAsset *SuperAssetFilterer) FilterERC20Removed(opts *bind.FilterOpts, token []common.Address) (*SuperAssetERC20RemovedIterator, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "ERC20Removed", tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetERC20RemovedIterator{contract: _SuperAsset.contract, event: "ERC20Removed", logs: logs, sub: sub}, nil
}

// WatchERC20Removed is a free log subscription operation binding the contract event 0xf3f339312eadf076716643b0d29a97871056e9b21dc50fac35a10231ef5d0879.
//
// Solidity: event ERC20Removed(address indexed token)
func (_SuperAsset *SuperAssetFilterer) WatchERC20Removed(opts *bind.WatchOpts, sink chan<- *SuperAssetERC20Removed, token []common.Address) (event.Subscription, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "ERC20Removed", tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetERC20Removed)
				if err := _SuperAsset.contract.UnpackLog(event, "ERC20Removed", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseERC20Removed is a log parse operation binding the contract event 0xf3f339312eadf076716643b0d29a97871056e9b21dc50fac35a10231ef5d0879.
//
// Solidity: event ERC20Removed(address indexed token)
func (_SuperAsset *SuperAssetFilterer) ParseERC20Removed(log types.Log) (*SuperAssetERC20Removed, error) {
	event := new(SuperAssetERC20Removed)
	if err := _SuperAsset.contract.UnpackLog(event, "ERC20Removed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetERC20WhitelistedIterator is returned from FilterERC20Whitelisted and is used to iterate over the raw logs and unpacked data for ERC20Whitelisted events raised by the SuperAsset contract.
type SuperAssetERC20WhitelistedIterator struct {
	Event *SuperAssetERC20Whitelisted // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetERC20WhitelistedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetERC20Whitelisted)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetERC20Whitelisted)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetERC20WhitelistedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetERC20WhitelistedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetERC20Whitelisted represents a ERC20Whitelisted event raised by the SuperAsset contract.
type SuperAssetERC20Whitelisted struct {
	Token common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterERC20Whitelisted is a free log retrieval operation binding the contract event 0x0de2c71f6403e65bf9458c0d3e7cf4f10d3ee09edefef5b742314c02d9a757b1.
//
// Solidity: event ERC20Whitelisted(address indexed token)
func (_SuperAsset *SuperAssetFilterer) FilterERC20Whitelisted(opts *bind.FilterOpts, token []common.Address) (*SuperAssetERC20WhitelistedIterator, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "ERC20Whitelisted", tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetERC20WhitelistedIterator{contract: _SuperAsset.contract, event: "ERC20Whitelisted", logs: logs, sub: sub}, nil
}

// WatchERC20Whitelisted is a free log subscription operation binding the contract event 0x0de2c71f6403e65bf9458c0d3e7cf4f10d3ee09edefef5b742314c02d9a757b1.
//
// Solidity: event ERC20Whitelisted(address indexed token)
func (_SuperAsset *SuperAssetFilterer) WatchERC20Whitelisted(opts *bind.WatchOpts, sink chan<- *SuperAssetERC20Whitelisted, token []common.Address) (event.Subscription, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "ERC20Whitelisted", tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetERC20Whitelisted)
				if err := _SuperAsset.contract.UnpackLog(event, "ERC20Whitelisted", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseERC20Whitelisted is a log parse operation binding the contract event 0x0de2c71f6403e65bf9458c0d3e7cf4f10d3ee09edefef5b742314c02d9a757b1.
//
// Solidity: event ERC20Whitelisted(address indexed token)
func (_SuperAsset *SuperAssetFilterer) ParseERC20Whitelisted(log types.Log) (*SuperAssetERC20Whitelisted, error) {
	event := new(SuperAssetERC20Whitelisted)
	if err := _SuperAsset.contract.UnpackLog(event, "ERC20Whitelisted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetEnergyToUSDExchangeRatioSetIterator is returned from FilterEnergyToUSDExchangeRatioSet and is used to iterate over the raw logs and unpacked data for EnergyToUSDExchangeRatioSet events raised by the SuperAsset contract.
type SuperAssetEnergyToUSDExchangeRatioSetIterator struct {
	Event *SuperAssetEnergyToUSDExchangeRatioSet // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetEnergyToUSDExchangeRatioSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetEnergyToUSDExchangeRatioSet)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetEnergyToUSDExchangeRatioSet)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetEnergyToUSDExchangeRatioSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetEnergyToUSDExchangeRatioSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetEnergyToUSDExchangeRatioSet represents a EnergyToUSDExchangeRatioSet event raised by the SuperAsset contract.
type SuperAssetEnergyToUSDExchangeRatioSet struct {
	NewRatio *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterEnergyToUSDExchangeRatioSet is a free log retrieval operation binding the contract event 0x841940e565763ea6b2882dfc936b6d599f71dfe0fed5ad3a7cd13384ef4160ef.
//
// Solidity: event EnergyToUSDExchangeRatioSet(uint256 newRatio)
func (_SuperAsset *SuperAssetFilterer) FilterEnergyToUSDExchangeRatioSet(opts *bind.FilterOpts) (*SuperAssetEnergyToUSDExchangeRatioSetIterator, error) {

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "EnergyToUSDExchangeRatioSet")
	if err != nil {
		return nil, err
	}
	return &SuperAssetEnergyToUSDExchangeRatioSetIterator{contract: _SuperAsset.contract, event: "EnergyToUSDExchangeRatioSet", logs: logs, sub: sub}, nil
}

// WatchEnergyToUSDExchangeRatioSet is a free log subscription operation binding the contract event 0x841940e565763ea6b2882dfc936b6d599f71dfe0fed5ad3a7cd13384ef4160ef.
//
// Solidity: event EnergyToUSDExchangeRatioSet(uint256 newRatio)
func (_SuperAsset *SuperAssetFilterer) WatchEnergyToUSDExchangeRatioSet(opts *bind.WatchOpts, sink chan<- *SuperAssetEnergyToUSDExchangeRatioSet) (event.Subscription, error) {

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "EnergyToUSDExchangeRatioSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetEnergyToUSDExchangeRatioSet)
				if err := _SuperAsset.contract.UnpackLog(event, "EnergyToUSDExchangeRatioSet", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseEnergyToUSDExchangeRatioSet is a log parse operation binding the contract event 0x841940e565763ea6b2882dfc936b6d599f71dfe0fed5ad3a7cd13384ef4160ef.
//
// Solidity: event EnergyToUSDExchangeRatioSet(uint256 newRatio)
func (_SuperAsset *SuperAssetFilterer) ParseEnergyToUSDExchangeRatioSet(log types.Log) (*SuperAssetEnergyToUSDExchangeRatioSet, error) {
	event := new(SuperAssetEnergyToUSDExchangeRatioSet)
	if err := _SuperAsset.contract.UnpackLog(event, "EnergyToUSDExchangeRatioSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetRedeemIterator is returned from FilterRedeem and is used to iterate over the raw logs and unpacked data for Redeem events raised by the SuperAsset contract.
type SuperAssetRedeemIterator struct {
	Event *SuperAssetRedeem // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetRedeemIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetRedeem)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetRedeem)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetRedeemIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetRedeemIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetRedeem represents a Redeem event raised by the SuperAsset contract.
type SuperAssetRedeem struct {
	Receiver             common.Address
	TokenOut             common.Address
	AmountSharesToRedeem *big.Int
	AmountTokenOut       *big.Int
	SwapFee              *big.Int
	AmountIncentives     *big.Int
	Raw                  types.Log // Blockchain specific contextual infos
}

// FilterRedeem is a free log retrieval operation binding the contract event 0xea1274ab64720b875ab7be826147069e98dc2b4f1b0ba87428f7fecc4b018e3b.
//
// Solidity: event Redeem(address indexed receiver, address indexed tokenOut, uint256 amountSharesToRedeem, uint256 amountTokenOut, uint256 swapFee, int256 amountIncentives)
func (_SuperAsset *SuperAssetFilterer) FilterRedeem(opts *bind.FilterOpts, receiver []common.Address, tokenOut []common.Address) (*SuperAssetRedeemIterator, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}
	var tokenOutRule []interface{}
	for _, tokenOutItem := range tokenOut {
		tokenOutRule = append(tokenOutRule, tokenOutItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "Redeem", receiverRule, tokenOutRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetRedeemIterator{contract: _SuperAsset.contract, event: "Redeem", logs: logs, sub: sub}, nil
}

// WatchRedeem is a free log subscription operation binding the contract event 0xea1274ab64720b875ab7be826147069e98dc2b4f1b0ba87428f7fecc4b018e3b.
//
// Solidity: event Redeem(address indexed receiver, address indexed tokenOut, uint256 amountSharesToRedeem, uint256 amountTokenOut, uint256 swapFee, int256 amountIncentives)
func (_SuperAsset *SuperAssetFilterer) WatchRedeem(opts *bind.WatchOpts, sink chan<- *SuperAssetRedeem, receiver []common.Address, tokenOut []common.Address) (event.Subscription, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}
	var tokenOutRule []interface{}
	for _, tokenOutItem := range tokenOut {
		tokenOutRule = append(tokenOutRule, tokenOutItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "Redeem", receiverRule, tokenOutRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetRedeem)
				if err := _SuperAsset.contract.UnpackLog(event, "Redeem", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRedeem is a log parse operation binding the contract event 0xea1274ab64720b875ab7be826147069e98dc2b4f1b0ba87428f7fecc4b018e3b.
//
// Solidity: event Redeem(address indexed receiver, address indexed tokenOut, uint256 amountSharesToRedeem, uint256 amountTokenOut, uint256 swapFee, int256 amountIncentives)
func (_SuperAsset *SuperAssetFilterer) ParseRedeem(log types.Log) (*SuperAssetRedeem, error) {
	event := new(SuperAssetRedeem)
	if err := _SuperAsset.contract.UnpackLog(event, "Redeem", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetRoleAdminChangedIterator is returned from FilterRoleAdminChanged and is used to iterate over the raw logs and unpacked data for RoleAdminChanged events raised by the SuperAsset contract.
type SuperAssetRoleAdminChangedIterator struct {
	Event *SuperAssetRoleAdminChanged // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetRoleAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetRoleAdminChanged)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetRoleAdminChanged)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetRoleAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetRoleAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetRoleAdminChanged represents a RoleAdminChanged event raised by the SuperAsset contract.
type SuperAssetRoleAdminChanged struct {
	Role              [32]byte
	PreviousAdminRole [32]byte
	NewAdminRole      [32]byte
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterRoleAdminChanged is a free log retrieval operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperAsset *SuperAssetFilterer) FilterRoleAdminChanged(opts *bind.FilterOpts, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (*SuperAssetRoleAdminChangedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetRoleAdminChangedIterator{contract: _SuperAsset.contract, event: "RoleAdminChanged", logs: logs, sub: sub}, nil
}

// WatchRoleAdminChanged is a free log subscription operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperAsset *SuperAssetFilterer) WatchRoleAdminChanged(opts *bind.WatchOpts, sink chan<- *SuperAssetRoleAdminChanged, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetRoleAdminChanged)
				if err := _SuperAsset.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRoleAdminChanged is a log parse operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperAsset *SuperAssetFilterer) ParseRoleAdminChanged(log types.Log) (*SuperAssetRoleAdminChanged, error) {
	event := new(SuperAssetRoleAdminChanged)
	if err := _SuperAsset.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetRoleGrantedIterator is returned from FilterRoleGranted and is used to iterate over the raw logs and unpacked data for RoleGranted events raised by the SuperAsset contract.
type SuperAssetRoleGrantedIterator struct {
	Event *SuperAssetRoleGranted // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetRoleGrantedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetRoleGranted)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetRoleGranted)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetRoleGrantedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetRoleGrantedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetRoleGranted represents a RoleGranted event raised by the SuperAsset contract.
type SuperAssetRoleGranted struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleGranted is a free log retrieval operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAsset *SuperAssetFilterer) FilterRoleGranted(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperAssetRoleGrantedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetRoleGrantedIterator{contract: _SuperAsset.contract, event: "RoleGranted", logs: logs, sub: sub}, nil
}

// WatchRoleGranted is a free log subscription operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAsset *SuperAssetFilterer) WatchRoleGranted(opts *bind.WatchOpts, sink chan<- *SuperAssetRoleGranted, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetRoleGranted)
				if err := _SuperAsset.contract.UnpackLog(event, "RoleGranted", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRoleGranted is a log parse operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAsset *SuperAssetFilterer) ParseRoleGranted(log types.Log) (*SuperAssetRoleGranted, error) {
	event := new(SuperAssetRoleGranted)
	if err := _SuperAsset.contract.UnpackLog(event, "RoleGranted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetRoleRevokedIterator is returned from FilterRoleRevoked and is used to iterate over the raw logs and unpacked data for RoleRevoked events raised by the SuperAsset contract.
type SuperAssetRoleRevokedIterator struct {
	Event *SuperAssetRoleRevoked // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetRoleRevokedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetRoleRevoked)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetRoleRevoked)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetRoleRevokedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetRoleRevokedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetRoleRevoked represents a RoleRevoked event raised by the SuperAsset contract.
type SuperAssetRoleRevoked struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleRevoked is a free log retrieval operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAsset *SuperAssetFilterer) FilterRoleRevoked(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperAssetRoleRevokedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetRoleRevokedIterator{contract: _SuperAsset.contract, event: "RoleRevoked", logs: logs, sub: sub}, nil
}

// WatchRoleRevoked is a free log subscription operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAsset *SuperAssetFilterer) WatchRoleRevoked(opts *bind.WatchOpts, sink chan<- *SuperAssetRoleRevoked, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetRoleRevoked)
				if err := _SuperAsset.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRoleRevoked is a log parse operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAsset *SuperAssetFilterer) ParseRoleRevoked(log types.Log) (*SuperAssetRoleRevoked, error) {
	event := new(SuperAssetRoleRevoked)
	if err := _SuperAsset.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetSettlementTokenInSetIterator is returned from FilterSettlementTokenInSet and is used to iterate over the raw logs and unpacked data for SettlementTokenInSet events raised by the SuperAsset contract.
type SuperAssetSettlementTokenInSetIterator struct {
	Event *SuperAssetSettlementTokenInSet // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetSettlementTokenInSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetSettlementTokenInSet)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetSettlementTokenInSet)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetSettlementTokenInSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetSettlementTokenInSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetSettlementTokenInSet represents a SettlementTokenInSet event raised by the SuperAsset contract.
type SuperAssetSettlementTokenInSet struct {
	Token common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterSettlementTokenInSet is a free log retrieval operation binding the contract event 0x9280740a4be3119e9a07d28766b243f8525c7015b42daf156542da55a9b58203.
//
// Solidity: event SettlementTokenInSet(address indexed token)
func (_SuperAsset *SuperAssetFilterer) FilterSettlementTokenInSet(opts *bind.FilterOpts, token []common.Address) (*SuperAssetSettlementTokenInSetIterator, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "SettlementTokenInSet", tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetSettlementTokenInSetIterator{contract: _SuperAsset.contract, event: "SettlementTokenInSet", logs: logs, sub: sub}, nil
}

// WatchSettlementTokenInSet is a free log subscription operation binding the contract event 0x9280740a4be3119e9a07d28766b243f8525c7015b42daf156542da55a9b58203.
//
// Solidity: event SettlementTokenInSet(address indexed token)
func (_SuperAsset *SuperAssetFilterer) WatchSettlementTokenInSet(opts *bind.WatchOpts, sink chan<- *SuperAssetSettlementTokenInSet, token []common.Address) (event.Subscription, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "SettlementTokenInSet", tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetSettlementTokenInSet)
				if err := _SuperAsset.contract.UnpackLog(event, "SettlementTokenInSet", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSettlementTokenInSet is a log parse operation binding the contract event 0x9280740a4be3119e9a07d28766b243f8525c7015b42daf156542da55a9b58203.
//
// Solidity: event SettlementTokenInSet(address indexed token)
func (_SuperAsset *SuperAssetFilterer) ParseSettlementTokenInSet(log types.Log) (*SuperAssetSettlementTokenInSet, error) {
	event := new(SuperAssetSettlementTokenInSet)
	if err := _SuperAsset.contract.UnpackLog(event, "SettlementTokenInSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetSettlementTokenOutSetIterator is returned from FilterSettlementTokenOutSet and is used to iterate over the raw logs and unpacked data for SettlementTokenOutSet events raised by the SuperAsset contract.
type SuperAssetSettlementTokenOutSetIterator struct {
	Event *SuperAssetSettlementTokenOutSet // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetSettlementTokenOutSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetSettlementTokenOutSet)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetSettlementTokenOutSet)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetSettlementTokenOutSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetSettlementTokenOutSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetSettlementTokenOutSet represents a SettlementTokenOutSet event raised by the SuperAsset contract.
type SuperAssetSettlementTokenOutSet struct {
	Token common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterSettlementTokenOutSet is a free log retrieval operation binding the contract event 0xac4359a171ef59f09ed4d5572ef77fcbb40548d6898482ef37f4d368e842f79f.
//
// Solidity: event SettlementTokenOutSet(address indexed token)
func (_SuperAsset *SuperAssetFilterer) FilterSettlementTokenOutSet(opts *bind.FilterOpts, token []common.Address) (*SuperAssetSettlementTokenOutSetIterator, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "SettlementTokenOutSet", tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetSettlementTokenOutSetIterator{contract: _SuperAsset.contract, event: "SettlementTokenOutSet", logs: logs, sub: sub}, nil
}

// WatchSettlementTokenOutSet is a free log subscription operation binding the contract event 0xac4359a171ef59f09ed4d5572ef77fcbb40548d6898482ef37f4d368e842f79f.
//
// Solidity: event SettlementTokenOutSet(address indexed token)
func (_SuperAsset *SuperAssetFilterer) WatchSettlementTokenOutSet(opts *bind.WatchOpts, sink chan<- *SuperAssetSettlementTokenOutSet, token []common.Address) (event.Subscription, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "SettlementTokenOutSet", tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetSettlementTokenOutSet)
				if err := _SuperAsset.contract.UnpackLog(event, "SettlementTokenOutSet", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSettlementTokenOutSet is a log parse operation binding the contract event 0xac4359a171ef59f09ed4d5572ef77fcbb40548d6898482ef37f4d368e842f79f.
//
// Solidity: event SettlementTokenOutSet(address indexed token)
func (_SuperAsset *SuperAssetFilterer) ParseSettlementTokenOutSet(log types.Log) (*SuperAssetSettlementTokenOutSet, error) {
	event := new(SuperAssetSettlementTokenOutSet)
	if err := _SuperAsset.contract.UnpackLog(event, "SettlementTokenOutSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetSuperOracleSetIterator is returned from FilterSuperOracleSet and is used to iterate over the raw logs and unpacked data for SuperOracleSet events raised by the SuperAsset contract.
type SuperAssetSuperOracleSetIterator struct {
	Event *SuperAssetSuperOracleSet // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetSuperOracleSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetSuperOracleSet)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetSuperOracleSet)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetSuperOracleSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetSuperOracleSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetSuperOracleSet represents a SuperOracleSet event raised by the SuperAsset contract.
type SuperAssetSuperOracleSet struct {
	Oracle common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterSuperOracleSet is a free log retrieval operation binding the contract event 0x6c12a5311793d064baa52a7654d2b3c552d024e515923fbb065926d93909486d.
//
// Solidity: event SuperOracleSet(address indexed oracle)
func (_SuperAsset *SuperAssetFilterer) FilterSuperOracleSet(opts *bind.FilterOpts, oracle []common.Address) (*SuperAssetSuperOracleSetIterator, error) {

	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "SuperOracleSet", oracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetSuperOracleSetIterator{contract: _SuperAsset.contract, event: "SuperOracleSet", logs: logs, sub: sub}, nil
}

// WatchSuperOracleSet is a free log subscription operation binding the contract event 0x6c12a5311793d064baa52a7654d2b3c552d024e515923fbb065926d93909486d.
//
// Solidity: event SuperOracleSet(address indexed oracle)
func (_SuperAsset *SuperAssetFilterer) WatchSuperOracleSet(opts *bind.WatchOpts, sink chan<- *SuperAssetSuperOracleSet, oracle []common.Address) (event.Subscription, error) {

	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "SuperOracleSet", oracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetSuperOracleSet)
				if err := _SuperAsset.contract.UnpackLog(event, "SuperOracleSet", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSuperOracleSet is a log parse operation binding the contract event 0x6c12a5311793d064baa52a7654d2b3c552d024e515923fbb065926d93909486d.
//
// Solidity: event SuperOracleSet(address indexed oracle)
func (_SuperAsset *SuperAssetFilterer) ParseSuperOracleSet(log types.Log) (*SuperAssetSuperOracleSet, error) {
	event := new(SuperAssetSuperOracleSet)
	if err := _SuperAsset.contract.UnpackLog(event, "SuperOracleSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetSwapIterator is returned from FilterSwap and is used to iterate over the raw logs and unpacked data for Swap events raised by the SuperAsset contract.
type SuperAssetSwapIterator struct {
	Event *SuperAssetSwap // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetSwapIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetSwap)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetSwap)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetSwapIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetSwapIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetSwap represents a Swap event raised by the SuperAsset contract.
type SuperAssetSwap struct {
	Receiver                     common.Address
	TokenIn                      common.Address
	AmountTokenToDeposit         *big.Int
	TokenOut                     common.Address
	AmountSharesIntermediateStep *big.Int
	AmountTokenOutAfterFees      *big.Int
	SwapFeeIn                    *big.Int
	SwapFeeOut                   *big.Int
	AmountIncentivesIn           *big.Int
	AmountIncentivesOut          *big.Int
	Raw                          types.Log // Blockchain specific contextual infos
}

// FilterSwap is a free log retrieval operation binding the contract event 0xf3841a335a601c0540abcab1dcfec39e11af51d103b94a273350d5f4b01a522d.
//
// Solidity: event Swap(address indexed receiver, address indexed tokenIn, uint256 amountTokenToDeposit, address indexed tokenOut, uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut)
func (_SuperAsset *SuperAssetFilterer) FilterSwap(opts *bind.FilterOpts, receiver []common.Address, tokenIn []common.Address, tokenOut []common.Address) (*SuperAssetSwapIterator, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}
	var tokenInRule []interface{}
	for _, tokenInItem := range tokenIn {
		tokenInRule = append(tokenInRule, tokenInItem)
	}

	var tokenOutRule []interface{}
	for _, tokenOutItem := range tokenOut {
		tokenOutRule = append(tokenOutRule, tokenOutItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "Swap", receiverRule, tokenInRule, tokenOutRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetSwapIterator{contract: _SuperAsset.contract, event: "Swap", logs: logs, sub: sub}, nil
}

// WatchSwap is a free log subscription operation binding the contract event 0xf3841a335a601c0540abcab1dcfec39e11af51d103b94a273350d5f4b01a522d.
//
// Solidity: event Swap(address indexed receiver, address indexed tokenIn, uint256 amountTokenToDeposit, address indexed tokenOut, uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut)
func (_SuperAsset *SuperAssetFilterer) WatchSwap(opts *bind.WatchOpts, sink chan<- *SuperAssetSwap, receiver []common.Address, tokenIn []common.Address, tokenOut []common.Address) (event.Subscription, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}
	var tokenInRule []interface{}
	for _, tokenInItem := range tokenIn {
		tokenInRule = append(tokenInRule, tokenInItem)
	}

	var tokenOutRule []interface{}
	for _, tokenOutItem := range tokenOut {
		tokenOutRule = append(tokenOutRule, tokenOutItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "Swap", receiverRule, tokenInRule, tokenOutRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetSwap)
				if err := _SuperAsset.contract.UnpackLog(event, "Swap", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSwap is a log parse operation binding the contract event 0xf3841a335a601c0540abcab1dcfec39e11af51d103b94a273350d5f4b01a522d.
//
// Solidity: event Swap(address indexed receiver, address indexed tokenIn, uint256 amountTokenToDeposit, address indexed tokenOut, uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut)
func (_SuperAsset *SuperAssetFilterer) ParseSwap(log types.Log) (*SuperAssetSwap, error) {
	event := new(SuperAssetSwap)
	if err := _SuperAsset.contract.UnpackLog(event, "Swap", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetTargetAllocationSetIterator is returned from FilterTargetAllocationSet and is used to iterate over the raw logs and unpacked data for TargetAllocationSet events raised by the SuperAsset contract.
type SuperAssetTargetAllocationSetIterator struct {
	Event *SuperAssetTargetAllocationSet // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetTargetAllocationSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetTargetAllocationSet)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetTargetAllocationSet)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetTargetAllocationSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetTargetAllocationSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetTargetAllocationSet represents a TargetAllocationSet event raised by the SuperAsset contract.
type SuperAssetTargetAllocationSet struct {
	Token      common.Address
	Allocation *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterTargetAllocationSet is a free log retrieval operation binding the contract event 0x2274983f32de42686983a73ed0073c243e316806ed84b08c92299a976e30fa74.
//
// Solidity: event TargetAllocationSet(address indexed token, uint256 allocation)
func (_SuperAsset *SuperAssetFilterer) FilterTargetAllocationSet(opts *bind.FilterOpts, token []common.Address) (*SuperAssetTargetAllocationSetIterator, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "TargetAllocationSet", tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetTargetAllocationSetIterator{contract: _SuperAsset.contract, event: "TargetAllocationSet", logs: logs, sub: sub}, nil
}

// WatchTargetAllocationSet is a free log subscription operation binding the contract event 0x2274983f32de42686983a73ed0073c243e316806ed84b08c92299a976e30fa74.
//
// Solidity: event TargetAllocationSet(address indexed token, uint256 allocation)
func (_SuperAsset *SuperAssetFilterer) WatchTargetAllocationSet(opts *bind.WatchOpts, sink chan<- *SuperAssetTargetAllocationSet, token []common.Address) (event.Subscription, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "TargetAllocationSet", tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetTargetAllocationSet)
				if err := _SuperAsset.contract.UnpackLog(event, "TargetAllocationSet", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTargetAllocationSet is a log parse operation binding the contract event 0x2274983f32de42686983a73ed0073c243e316806ed84b08c92299a976e30fa74.
//
// Solidity: event TargetAllocationSet(address indexed token, uint256 allocation)
func (_SuperAsset *SuperAssetFilterer) ParseTargetAllocationSet(log types.Log) (*SuperAssetTargetAllocationSet, error) {
	event := new(SuperAssetTargetAllocationSet)
	if err := _SuperAsset.contract.UnpackLog(event, "TargetAllocationSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetTransferIterator is returned from FilterTransfer and is used to iterate over the raw logs and unpacked data for Transfer events raised by the SuperAsset contract.
type SuperAssetTransferIterator struct {
	Event *SuperAssetTransfer // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetTransferIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetTransfer)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetTransfer)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetTransferIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetTransferIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetTransfer represents a Transfer event raised by the SuperAsset contract.
type SuperAssetTransfer struct {
	From  common.Address
	To    common.Address
	Value *big.Int
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterTransfer is a free log retrieval operation binding the contract event 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef.
//
// Solidity: event Transfer(address indexed from, address indexed to, uint256 value)
func (_SuperAsset *SuperAssetFilterer) FilterTransfer(opts *bind.FilterOpts, from []common.Address, to []common.Address) (*SuperAssetTransferIterator, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "Transfer", fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetTransferIterator{contract: _SuperAsset.contract, event: "Transfer", logs: logs, sub: sub}, nil
}

// WatchTransfer is a free log subscription operation binding the contract event 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef.
//
// Solidity: event Transfer(address indexed from, address indexed to, uint256 value)
func (_SuperAsset *SuperAssetFilterer) WatchTransfer(opts *bind.WatchOpts, sink chan<- *SuperAssetTransfer, from []common.Address, to []common.Address) (event.Subscription, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "Transfer", fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetTransfer)
				if err := _SuperAsset.contract.UnpackLog(event, "Transfer", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTransfer is a log parse operation binding the contract event 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef.
//
// Solidity: event Transfer(address indexed from, address indexed to, uint256 value)
func (_SuperAsset *SuperAssetFilterer) ParseTransfer(log types.Log) (*SuperAssetTransfer, error) {
	event := new(SuperAssetTransfer)
	if err := _SuperAsset.contract.UnpackLog(event, "Transfer", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetVaultRemovedIterator is returned from FilterVaultRemoved and is used to iterate over the raw logs and unpacked data for VaultRemoved events raised by the SuperAsset contract.
type SuperAssetVaultRemovedIterator struct {
	Event *SuperAssetVaultRemoved // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetVaultRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetVaultRemoved)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetVaultRemoved)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetVaultRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetVaultRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetVaultRemoved represents a VaultRemoved event raised by the SuperAsset contract.
type SuperAssetVaultRemoved struct {
	Vault common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterVaultRemoved is a free log retrieval operation binding the contract event 0xe71f3a50e5ad81964f352c411f1d45e35438ecd1acecef59ac81d9fbbf6cbc0a.
//
// Solidity: event VaultRemoved(address indexed vault)
func (_SuperAsset *SuperAssetFilterer) FilterVaultRemoved(opts *bind.FilterOpts, vault []common.Address) (*SuperAssetVaultRemovedIterator, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "VaultRemoved", vaultRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetVaultRemovedIterator{contract: _SuperAsset.contract, event: "VaultRemoved", logs: logs, sub: sub}, nil
}

// WatchVaultRemoved is a free log subscription operation binding the contract event 0xe71f3a50e5ad81964f352c411f1d45e35438ecd1acecef59ac81d9fbbf6cbc0a.
//
// Solidity: event VaultRemoved(address indexed vault)
func (_SuperAsset *SuperAssetFilterer) WatchVaultRemoved(opts *bind.WatchOpts, sink chan<- *SuperAssetVaultRemoved, vault []common.Address) (event.Subscription, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "VaultRemoved", vaultRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetVaultRemoved)
				if err := _SuperAsset.contract.UnpackLog(event, "VaultRemoved", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseVaultRemoved is a log parse operation binding the contract event 0xe71f3a50e5ad81964f352c411f1d45e35438ecd1acecef59ac81d9fbbf6cbc0a.
//
// Solidity: event VaultRemoved(address indexed vault)
func (_SuperAsset *SuperAssetFilterer) ParseVaultRemoved(log types.Log) (*SuperAssetVaultRemoved, error) {
	event := new(SuperAssetVaultRemoved)
	if err := _SuperAsset.contract.UnpackLog(event, "VaultRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetVaultWhitelistedIterator is returned from FilterVaultWhitelisted and is used to iterate over the raw logs and unpacked data for VaultWhitelisted events raised by the SuperAsset contract.
type SuperAssetVaultWhitelistedIterator struct {
	Event *SuperAssetVaultWhitelisted // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetVaultWhitelistedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetVaultWhitelisted)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetVaultWhitelisted)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetVaultWhitelistedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetVaultWhitelistedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetVaultWhitelisted represents a VaultWhitelisted event raised by the SuperAsset contract.
type SuperAssetVaultWhitelisted struct {
	Vault common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterVaultWhitelisted is a free log retrieval operation binding the contract event 0x38d094f76db4ce8ab60616bcae40bb573cf915fb14ff891b1b87eacbf045e6b8.
//
// Solidity: event VaultWhitelisted(address indexed vault)
func (_SuperAsset *SuperAssetFilterer) FilterVaultWhitelisted(opts *bind.FilterOpts, vault []common.Address) (*SuperAssetVaultWhitelistedIterator, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "VaultWhitelisted", vaultRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetVaultWhitelistedIterator{contract: _SuperAsset.contract, event: "VaultWhitelisted", logs: logs, sub: sub}, nil
}

// WatchVaultWhitelisted is a free log subscription operation binding the contract event 0x38d094f76db4ce8ab60616bcae40bb573cf915fb14ff891b1b87eacbf045e6b8.
//
// Solidity: event VaultWhitelisted(address indexed vault)
func (_SuperAsset *SuperAssetFilterer) WatchVaultWhitelisted(opts *bind.WatchOpts, sink chan<- *SuperAssetVaultWhitelisted, vault []common.Address) (event.Subscription, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "VaultWhitelisted", vaultRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetVaultWhitelisted)
				if err := _SuperAsset.contract.UnpackLog(event, "VaultWhitelisted", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseVaultWhitelisted is a log parse operation binding the contract event 0x38d094f76db4ce8ab60616bcae40bb573cf915fb14ff891b1b87eacbf045e6b8.
//
// Solidity: event VaultWhitelisted(address indexed vault)
func (_SuperAsset *SuperAssetFilterer) ParseVaultWhitelisted(log types.Log) (*SuperAssetVaultWhitelisted, error) {
	event := new(SuperAssetVaultWhitelisted)
	if err := _SuperAsset.contract.UnpackLog(event, "VaultWhitelisted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetWeightSetIterator is returned from FilterWeightSet and is used to iterate over the raw logs and unpacked data for WeightSet events raised by the SuperAsset contract.
type SuperAssetWeightSetIterator struct {
	Event *SuperAssetWeightSet // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetWeightSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetWeightSet)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetWeightSet)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetWeightSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetWeightSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetWeightSet represents a WeightSet event raised by the SuperAsset contract.
type SuperAssetWeightSet struct {
	Vault  common.Address
	Weight *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterWeightSet is a free log retrieval operation binding the contract event 0x575839b376847794dfe4a5dec7346995f843243620c29b9386ed3cdc996d14e2.
//
// Solidity: event WeightSet(address indexed vault, uint256 weight)
func (_SuperAsset *SuperAssetFilterer) FilterWeightSet(opts *bind.FilterOpts, vault []common.Address) (*SuperAssetWeightSetIterator, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}

	logs, sub, err := _SuperAsset.contract.FilterLogs(opts, "WeightSet", vaultRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetWeightSetIterator{contract: _SuperAsset.contract, event: "WeightSet", logs: logs, sub: sub}, nil
}

// WatchWeightSet is a free log subscription operation binding the contract event 0x575839b376847794dfe4a5dec7346995f843243620c29b9386ed3cdc996d14e2.
//
// Solidity: event WeightSet(address indexed vault, uint256 weight)
func (_SuperAsset *SuperAssetFilterer) WatchWeightSet(opts *bind.WatchOpts, sink chan<- *SuperAssetWeightSet, vault []common.Address) (event.Subscription, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}

	logs, sub, err := _SuperAsset.contract.WatchLogs(opts, "WeightSet", vaultRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetWeightSet)
				if err := _SuperAsset.contract.UnpackLog(event, "WeightSet", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseWeightSet is a log parse operation binding the contract event 0x575839b376847794dfe4a5dec7346995f843243620c29b9386ed3cdc996d14e2.
//
// Solidity: event WeightSet(address indexed vault, uint256 weight)
func (_SuperAsset *SuperAssetFilterer) ParseWeightSet(log types.Log) (*SuperAssetWeightSet, error) {
	event := new(SuperAssetWeightSet)
	if err := _SuperAsset.contract.UnpackLog(event, "WeightSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
