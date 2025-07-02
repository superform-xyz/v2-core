// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SpectraPTYieldSourceOracle

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

// SpectraPTYieldSourceOracleMetaData contains all meta data concerning the SpectraPTYieldSourceOracle contract.
var SpectraPTYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"ptAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"ptAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"ptAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"ptAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"ptAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"ptAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"ptAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAsset\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"expectedUnderlying\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAssets\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"expectedUnderlying\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"isValid\",\"type\":\"bool[]\",\"internalType\":\"bool[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superLedgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// SpectraPTYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use SpectraPTYieldSourceOracleMetaData.ABI instead.
var SpectraPTYieldSourceOracleABI = SpectraPTYieldSourceOracleMetaData.ABI

// SpectraPTYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type SpectraPTYieldSourceOracle struct {
	SpectraPTYieldSourceOracleCaller     // Read-only binding to the contract
	SpectraPTYieldSourceOracleTransactor // Write-only binding to the contract
	SpectraPTYieldSourceOracleFilterer   // Log filterer for contract events
}

// SpectraPTYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type SpectraPTYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SpectraPTYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SpectraPTYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SpectraPTYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SpectraPTYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SpectraPTYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SpectraPTYieldSourceOracleSession struct {
	Contract     *SpectraPTYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts               // Call options to use throughout this session
	TransactOpts bind.TransactOpts           // Transaction auth options to use throughout this session
}

// SpectraPTYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SpectraPTYieldSourceOracleCallerSession struct {
	Contract *SpectraPTYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                     // Call options to use throughout this session
}

// SpectraPTYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SpectraPTYieldSourceOracleTransactorSession struct {
	Contract     *SpectraPTYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                     // Transaction auth options to use throughout this session
}

// SpectraPTYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type SpectraPTYieldSourceOracleRaw struct {
	Contract *SpectraPTYieldSourceOracle // Generic contract binding to access the raw methods on
}

// SpectraPTYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SpectraPTYieldSourceOracleCallerRaw struct {
	Contract *SpectraPTYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// SpectraPTYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SpectraPTYieldSourceOracleTransactorRaw struct {
	Contract *SpectraPTYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSpectraPTYieldSourceOracle creates a new instance of SpectraPTYieldSourceOracle, bound to a specific deployed contract.
func NewSpectraPTYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*SpectraPTYieldSourceOracle, error) {
	contract, err := bindSpectraPTYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SpectraPTYieldSourceOracle{SpectraPTYieldSourceOracleCaller: SpectraPTYieldSourceOracleCaller{contract: contract}, SpectraPTYieldSourceOracleTransactor: SpectraPTYieldSourceOracleTransactor{contract: contract}, SpectraPTYieldSourceOracleFilterer: SpectraPTYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewSpectraPTYieldSourceOracleCaller creates a new read-only instance of SpectraPTYieldSourceOracle, bound to a specific deployed contract.
func NewSpectraPTYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*SpectraPTYieldSourceOracleCaller, error) {
	contract, err := bindSpectraPTYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SpectraPTYieldSourceOracleCaller{contract: contract}, nil
}

// NewSpectraPTYieldSourceOracleTransactor creates a new write-only instance of SpectraPTYieldSourceOracle, bound to a specific deployed contract.
func NewSpectraPTYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*SpectraPTYieldSourceOracleTransactor, error) {
	contract, err := bindSpectraPTYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SpectraPTYieldSourceOracleTransactor{contract: contract}, nil
}

// NewSpectraPTYieldSourceOracleFilterer creates a new log filterer instance of SpectraPTYieldSourceOracle, bound to a specific deployed contract.
func NewSpectraPTYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*SpectraPTYieldSourceOracleFilterer, error) {
	contract, err := bindSpectraPTYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SpectraPTYieldSourceOracleFilterer{contract: contract}, nil
}

// bindSpectraPTYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindSpectraPTYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SpectraPTYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SpectraPTYieldSourceOracle.Contract.SpectraPTYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SpectraPTYieldSourceOracle.Contract.SpectraPTYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SpectraPTYieldSourceOracle.Contract.SpectraPTYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SpectraPTYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SpectraPTYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SpectraPTYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ptAddress) view returns(uint8)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, ptAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "decimals", ptAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ptAddress) view returns(uint8)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) Decimals(ptAddress common.Address) (uint8, error) {
	return _SpectraPTYieldSourceOracle.Contract.Decimals(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ptAddress) view returns(uint8)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) Decimals(ptAddress common.Address) (uint8, error) {
	return _SpectraPTYieldSourceOracle.Contract.Decimals(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address ptAddress, address , uint256 sharesIn) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, ptAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", ptAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address ptAddress, address , uint256 sharesIn) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetAssetOutput(ptAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetAssetOutput(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address ptAddress, address , uint256 sharesIn) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetAssetOutput(ptAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetAssetOutput(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetAssetOutputWithFees(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetAssetOutputWithFees(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address ptAddress, address ownerOfShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, ptAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", ptAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address ptAddress, address ownerOfShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetBalanceOfOwner(ptAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetBalanceOfOwner(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address ptAddress, address ownerOfShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetBalanceOfOwner(ptAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetBalanceOfOwner(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ptAddress) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, ptAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", ptAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ptAddress) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetPricePerShare(ptAddress common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetPricePerShare(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ptAddress) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetPricePerShare(ptAddress common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetPricePerShare(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetPricePerShareMultiple(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetPricePerShareMultiple(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address ptAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, ptAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", ptAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address ptAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetShareOutput(ptAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetShareOutput(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address ptAddress, address , uint256 assetsIn) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetShareOutput(ptAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetShareOutput(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address ptAddress) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, ptAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getTVL", ptAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address ptAddress) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetTVL(ptAddress common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVL(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address ptAddress) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetTVL(ptAddress common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVL(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address ptAddress, address ownerOfShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, ptAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", ptAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address ptAddress, address ownerOfShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetTVLByOwnerOfShares(ptAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address ptAddress, address ownerOfShares) view returns(uint256)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(ptAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_SpectraPTYieldSourceOracle.CallOpts, ptAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVLMultiple(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SpectraPTYieldSourceOracle.Contract.GetTVLMultiple(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) IsValidUnderlyingAsset(opts *bind.CallOpts, yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAsset", yieldSourceAddress, expectedUnderlying)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) IsValidUnderlyingAsset(yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	return _SpectraPTYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddress, expectedUnderlying)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) IsValidUnderlyingAsset(yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	return _SpectraPTYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddress, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) IsValidUnderlyingAssets(opts *bind.CallOpts, yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAssets", yieldSourceAddresses, expectedUnderlying)

	if err != nil {
		return *new([]bool), err
	}

	out0 := *abi.ConvertType(out[0], new([]bool)).(*[]bool)

	return out0, err

}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _SpectraPTYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _SpectraPTYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_SpectraPTYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCaller) SuperLedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SpectraPTYieldSourceOracle.contract.Call(opts, &out, "superLedgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleSession) SuperLedgerConfiguration() (common.Address, error) {
	return _SpectraPTYieldSourceOracle.Contract.SuperLedgerConfiguration(&_SpectraPTYieldSourceOracle.CallOpts)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_SpectraPTYieldSourceOracle *SpectraPTYieldSourceOracleCallerSession) SuperLedgerConfiguration() (common.Address, error) {
	return _SpectraPTYieldSourceOracle.Contract.SuperLedgerConfiguration(&_SpectraPTYieldSourceOracle.CallOpts)
}
