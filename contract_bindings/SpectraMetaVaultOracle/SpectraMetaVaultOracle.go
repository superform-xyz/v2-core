// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SpectraMetaVaultOracle

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

// SpectraMetaVaultOracleMetaData contains all meta data concerning the SpectraMetaVaultOracle contract.
var SpectraMetaVaultOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"requestId_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"REQUEST_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAsyncStateBreakdown\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"heldValue\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"pendingRedeemValue\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"claimableRedeemValue\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"pendingDepositValue\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"claimableDepositValue\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// SpectraMetaVaultOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use SpectraMetaVaultOracleMetaData.ABI instead.
var SpectraMetaVaultOracleABI = SpectraMetaVaultOracleMetaData.ABI

// SpectraMetaVaultOracle is an auto generated Go binding around an Ethereum contract.
type SpectraMetaVaultOracle struct {
	SpectraMetaVaultOracleCaller     // Read-only binding to the contract
	SpectraMetaVaultOracleTransactor // Write-only binding to the contract
	SpectraMetaVaultOracleFilterer   // Log filterer for contract events
}

// SpectraMetaVaultOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type SpectraMetaVaultOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SpectraMetaVaultOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SpectraMetaVaultOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SpectraMetaVaultOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SpectraMetaVaultOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SpectraMetaVaultOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SpectraMetaVaultOracleSession struct {
	Contract     *SpectraMetaVaultOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts           // Call options to use throughout this session
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// SpectraMetaVaultOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SpectraMetaVaultOracleCallerSession struct {
	Contract *SpectraMetaVaultOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                 // Call options to use throughout this session
}

// SpectraMetaVaultOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SpectraMetaVaultOracleTransactorSession struct {
	Contract     *SpectraMetaVaultOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                 // Transaction auth options to use throughout this session
}

// SpectraMetaVaultOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type SpectraMetaVaultOracleRaw struct {
	Contract *SpectraMetaVaultOracle // Generic contract binding to access the raw methods on
}

// SpectraMetaVaultOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SpectraMetaVaultOracleCallerRaw struct {
	Contract *SpectraMetaVaultOracleCaller // Generic read-only contract binding to access the raw methods on
}

// SpectraMetaVaultOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SpectraMetaVaultOracleTransactorRaw struct {
	Contract *SpectraMetaVaultOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSpectraMetaVaultOracle creates a new instance of SpectraMetaVaultOracle, bound to a specific deployed contract.
func NewSpectraMetaVaultOracle(address common.Address, backend bind.ContractBackend) (*SpectraMetaVaultOracle, error) {
	contract, err := bindSpectraMetaVaultOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SpectraMetaVaultOracle{SpectraMetaVaultOracleCaller: SpectraMetaVaultOracleCaller{contract: contract}, SpectraMetaVaultOracleTransactor: SpectraMetaVaultOracleTransactor{contract: contract}, SpectraMetaVaultOracleFilterer: SpectraMetaVaultOracleFilterer{contract: contract}}, nil
}

// NewSpectraMetaVaultOracleCaller creates a new read-only instance of SpectraMetaVaultOracle, bound to a specific deployed contract.
func NewSpectraMetaVaultOracleCaller(address common.Address, caller bind.ContractCaller) (*SpectraMetaVaultOracleCaller, error) {
	contract, err := bindSpectraMetaVaultOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SpectraMetaVaultOracleCaller{contract: contract}, nil
}

// NewSpectraMetaVaultOracleTransactor creates a new write-only instance of SpectraMetaVaultOracle, bound to a specific deployed contract.
func NewSpectraMetaVaultOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*SpectraMetaVaultOracleTransactor, error) {
	contract, err := bindSpectraMetaVaultOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SpectraMetaVaultOracleTransactor{contract: contract}, nil
}

// NewSpectraMetaVaultOracleFilterer creates a new log filterer instance of SpectraMetaVaultOracle, bound to a specific deployed contract.
func NewSpectraMetaVaultOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*SpectraMetaVaultOracleFilterer, error) {
	contract, err := bindSpectraMetaVaultOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SpectraMetaVaultOracleFilterer{contract: contract}, nil
}

// bindSpectraMetaVaultOracle binds a generic wrapper to an already deployed contract.
func bindSpectraMetaVaultOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SpectraMetaVaultOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SpectraMetaVaultOracle.Contract.SpectraMetaVaultOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SpectraMetaVaultOracle.Contract.SpectraMetaVaultOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SpectraMetaVaultOracle.Contract.SpectraMetaVaultOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SpectraMetaVaultOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SpectraMetaVaultOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SpectraMetaVaultOracle.Contract.contract.Transact(opts, method, params...)
}

// REQUESTID is a free data retrieval call binding the contract method 0x792c2348.
//
// Solidity: function REQUEST_ID() view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) REQUESTID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "REQUEST_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// REQUESTID is a free data retrieval call binding the contract method 0x792c2348.
//
// Solidity: function REQUEST_ID() view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) REQUESTID() (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.REQUESTID(&_SpectraMetaVaultOracle.CallOpts)
}

// REQUESTID is a free data retrieval call binding the contract method 0x792c2348.
//
// Solidity: function REQUEST_ID() view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) REQUESTID() (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.REQUESTID(&_SpectraMetaVaultOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _SpectraMetaVaultOracle.Contract.SUPERLEDGERCONFIGURATION(&_SpectraMetaVaultOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _SpectraMetaVaultOracle.Contract.SUPERLEDGERCONFIGURATION(&_SpectraMetaVaultOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _SpectraMetaVaultOracle.Contract.Decimals(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _SpectraMetaVaultOracle.Contract.Decimals(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetAssetOutput(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetAssetOutput(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetAssetOutputWithFees(&_SpectraMetaVaultOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetAssetOutputWithFees(&_SpectraMetaVaultOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAsyncStateBreakdown is a free data retrieval call binding the contract method 0x188519d0.
//
// Solidity: function getAsyncStateBreakdown(address yieldSourceAddress, address owner) view returns(uint256 heldValue, uint256 pendingRedeemValue, uint256 claimableRedeemValue, uint256 pendingDepositValue, uint256 claimableDepositValue)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetAsyncStateBreakdown(opts *bind.CallOpts, yieldSourceAddress common.Address, owner common.Address) (struct {
	HeldValue             *big.Int
	PendingRedeemValue    *big.Int
	ClaimableRedeemValue  *big.Int
	PendingDepositValue   *big.Int
	ClaimableDepositValue *big.Int
}, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getAsyncStateBreakdown", yieldSourceAddress, owner)

	outstruct := new(struct {
		HeldValue             *big.Int
		PendingRedeemValue    *big.Int
		ClaimableRedeemValue  *big.Int
		PendingDepositValue   *big.Int
		ClaimableDepositValue *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.HeldValue = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.PendingRedeemValue = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.ClaimableRedeemValue = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)
	outstruct.PendingDepositValue = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)
	outstruct.ClaimableDepositValue = *abi.ConvertType(out[4], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetAsyncStateBreakdown is a free data retrieval call binding the contract method 0x188519d0.
//
// Solidity: function getAsyncStateBreakdown(address yieldSourceAddress, address owner) view returns(uint256 heldValue, uint256 pendingRedeemValue, uint256 claimableRedeemValue, uint256 pendingDepositValue, uint256 claimableDepositValue)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetAsyncStateBreakdown(yieldSourceAddress common.Address, owner common.Address) (struct {
	HeldValue             *big.Int
	PendingRedeemValue    *big.Int
	ClaimableRedeemValue  *big.Int
	PendingDepositValue   *big.Int
	ClaimableDepositValue *big.Int
}, error) {
	return _SpectraMetaVaultOracle.Contract.GetAsyncStateBreakdown(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, owner)
}

// GetAsyncStateBreakdown is a free data retrieval call binding the contract method 0x188519d0.
//
// Solidity: function getAsyncStateBreakdown(address yieldSourceAddress, address owner) view returns(uint256 heldValue, uint256 pendingRedeemValue, uint256 claimableRedeemValue, uint256 pendingDepositValue, uint256 claimableDepositValue)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetAsyncStateBreakdown(yieldSourceAddress common.Address, owner common.Address) (struct {
	HeldValue             *big.Int
	PendingRedeemValue    *big.Int
	ClaimableRedeemValue  *big.Int
	PendingDepositValue   *big.Int
	ClaimableDepositValue *big.Int
}, error) {
	return _SpectraMetaVaultOracle.Contract.GetAsyncStateBreakdown(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, owner)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetBalanceOfOwner(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetBalanceOfOwner(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetPricePerShare(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetPricePerShare(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetPricePerShareMultiple(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetPricePerShareMultiple(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetShareOutput(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetShareOutput(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVL(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVL(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVLByOwnerOfShares(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVLByOwnerOfShares(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVLMultiple(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetTVLMultiple(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SpectraMetaVaultOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetWithdrawalShareOutput(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraMetaVaultOracle *SpectraMetaVaultOracleCallerSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SpectraMetaVaultOracle.Contract.GetWithdrawalShareOutput(&_SpectraMetaVaultOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}
