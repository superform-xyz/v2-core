// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package IOracle

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

// IOracleMetaData contains all meta data concerning the IOracle contract.
var IOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getQuote\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"OracleUnsupportedPair\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OracleUntrustedData\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// IOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use IOracleMetaData.ABI instead.
var IOracleABI = IOracleMetaData.ABI

// IOracle is an auto generated Go binding around an Ethereum contract.
type IOracle struct {
	IOracleCaller     // Read-only binding to the contract
	IOracleTransactor // Write-only binding to the contract
	IOracleFilterer   // Log filterer for contract events
}

// IOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type IOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IOracleSession struct {
	Contract     *IOracle          // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// IOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IOracleCallerSession struct {
	Contract *IOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts  // Call options to use throughout this session
}

// IOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IOracleTransactorSession struct {
	Contract     *IOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// IOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type IOracleRaw struct {
	Contract *IOracle // Generic contract binding to access the raw methods on
}

// IOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IOracleCallerRaw struct {
	Contract *IOracleCaller // Generic read-only contract binding to access the raw methods on
}

// IOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IOracleTransactorRaw struct {
	Contract *IOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIOracle creates a new instance of IOracle, bound to a specific deployed contract.
func NewIOracle(address common.Address, backend bind.ContractBackend) (*IOracle, error) {
	contract, err := bindIOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IOracle{IOracleCaller: IOracleCaller{contract: contract}, IOracleTransactor: IOracleTransactor{contract: contract}, IOracleFilterer: IOracleFilterer{contract: contract}}, nil
}

// NewIOracleCaller creates a new read-only instance of IOracle, bound to a specific deployed contract.
func NewIOracleCaller(address common.Address, caller bind.ContractCaller) (*IOracleCaller, error) {
	contract, err := bindIOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IOracleCaller{contract: contract}, nil
}

// NewIOracleTransactor creates a new write-only instance of IOracle, bound to a specific deployed contract.
func NewIOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*IOracleTransactor, error) {
	contract, err := bindIOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IOracleTransactor{contract: contract}, nil
}

// NewIOracleFilterer creates a new log filterer instance of IOracle, bound to a specific deployed contract.
func NewIOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*IOracleFilterer, error) {
	contract, err := bindIOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IOracleFilterer{contract: contract}, nil
}

// bindIOracle binds a generic wrapper to an already deployed contract.
func bindIOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := IOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IOracle *IOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IOracle.Contract.IOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IOracle *IOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IOracle.Contract.IOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IOracle *IOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IOracle.Contract.IOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IOracle *IOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IOracle *IOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IOracle *IOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IOracle.Contract.contract.Transact(opts, method, params...)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_IOracle *IOracleCaller) GetQuote(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	var out []interface{}
	err := _IOracle.contract.Call(opts, &out, "getQuote", baseAmount, base, quote)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_IOracle *IOracleSession) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _IOracle.Contract.GetQuote(&_IOracle.CallOpts, baseAmount, base, quote)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_IOracle *IOracleCallerSession) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _IOracle.Contract.GetQuote(&_IOracle.CallOpts, baseAmount, base, quote)
}
