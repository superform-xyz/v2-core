// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package IPendlePTAmortizedOracle

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

// IPendlePTAmortizedOracleMetaData contains all meta data concerning the IPendlePTAmortizedOracle contract.
var IPendlePTAmortizedOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getBookValue\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"bookValue\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hasPosition\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"exists\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"recordPurchase\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sySpent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ptAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"recordRedemption\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ptSold\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"}]",
}

// IPendlePTAmortizedOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use IPendlePTAmortizedOracleMetaData.ABI instead.
var IPendlePTAmortizedOracleABI = IPendlePTAmortizedOracleMetaData.ABI

// IPendlePTAmortizedOracle is an auto generated Go binding around an Ethereum contract.
type IPendlePTAmortizedOracle struct {
	IPendlePTAmortizedOracleCaller     // Read-only binding to the contract
	IPendlePTAmortizedOracleTransactor // Write-only binding to the contract
	IPendlePTAmortizedOracleFilterer   // Log filterer for contract events
}

// IPendlePTAmortizedOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type IPendlePTAmortizedOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IPendlePTAmortizedOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IPendlePTAmortizedOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IPendlePTAmortizedOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IPendlePTAmortizedOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IPendlePTAmortizedOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IPendlePTAmortizedOracleSession struct {
	Contract     *IPendlePTAmortizedOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// IPendlePTAmortizedOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IPendlePTAmortizedOracleCallerSession struct {
	Contract *IPendlePTAmortizedOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// IPendlePTAmortizedOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IPendlePTAmortizedOracleTransactorSession struct {
	Contract     *IPendlePTAmortizedOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// IPendlePTAmortizedOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type IPendlePTAmortizedOracleRaw struct {
	Contract *IPendlePTAmortizedOracle // Generic contract binding to access the raw methods on
}

// IPendlePTAmortizedOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IPendlePTAmortizedOracleCallerRaw struct {
	Contract *IPendlePTAmortizedOracleCaller // Generic read-only contract binding to access the raw methods on
}

// IPendlePTAmortizedOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IPendlePTAmortizedOracleTransactorRaw struct {
	Contract *IPendlePTAmortizedOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIPendlePTAmortizedOracle creates a new instance of IPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewIPendlePTAmortizedOracle(address common.Address, backend bind.ContractBackend) (*IPendlePTAmortizedOracle, error) {
	contract, err := bindIPendlePTAmortizedOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IPendlePTAmortizedOracle{IPendlePTAmortizedOracleCaller: IPendlePTAmortizedOracleCaller{contract: contract}, IPendlePTAmortizedOracleTransactor: IPendlePTAmortizedOracleTransactor{contract: contract}, IPendlePTAmortizedOracleFilterer: IPendlePTAmortizedOracleFilterer{contract: contract}}, nil
}

// NewIPendlePTAmortizedOracleCaller creates a new read-only instance of IPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewIPendlePTAmortizedOracleCaller(address common.Address, caller bind.ContractCaller) (*IPendlePTAmortizedOracleCaller, error) {
	contract, err := bindIPendlePTAmortizedOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IPendlePTAmortizedOracleCaller{contract: contract}, nil
}

// NewIPendlePTAmortizedOracleTransactor creates a new write-only instance of IPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewIPendlePTAmortizedOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*IPendlePTAmortizedOracleTransactor, error) {
	contract, err := bindIPendlePTAmortizedOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IPendlePTAmortizedOracleTransactor{contract: contract}, nil
}

// NewIPendlePTAmortizedOracleFilterer creates a new log filterer instance of IPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewIPendlePTAmortizedOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*IPendlePTAmortizedOracleFilterer, error) {
	contract, err := bindIPendlePTAmortizedOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IPendlePTAmortizedOracleFilterer{contract: contract}, nil
}

// bindIPendlePTAmortizedOracle binds a generic wrapper to an already deployed contract.
func bindIPendlePTAmortizedOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := IPendlePTAmortizedOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IPendlePTAmortizedOracle.Contract.IPendlePTAmortizedOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.IPendlePTAmortizedOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.IPendlePTAmortizedOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IPendlePTAmortizedOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.contract.Transact(opts, method, params...)
}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256 bookValue)
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleCaller) GetBookValue(opts *bind.CallOpts, strategy common.Address, market common.Address) (*big.Int, error) {
	var out []interface{}
	err := _IPendlePTAmortizedOracle.contract.Call(opts, &out, "getBookValue", strategy, market)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256 bookValue)
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleSession) GetBookValue(strategy common.Address, market common.Address) (*big.Int, error) {
	return _IPendlePTAmortizedOracle.Contract.GetBookValue(&_IPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256 bookValue)
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleCallerSession) GetBookValue(strategy common.Address, market common.Address) (*big.Int, error) {
	return _IPendlePTAmortizedOracle.Contract.GetBookValue(&_IPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool exists)
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleCaller) HasPosition(opts *bind.CallOpts, strategy common.Address, market common.Address) (bool, error) {
	var out []interface{}
	err := _IPendlePTAmortizedOracle.contract.Call(opts, &out, "hasPosition", strategy, market)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool exists)
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleSession) HasPosition(strategy common.Address, market common.Address) (bool, error) {
	return _IPendlePTAmortizedOracle.Contract.HasPosition(&_IPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool exists)
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleCallerSession) HasPosition(strategy common.Address, market common.Address) (bool, error) {
	return _IPendlePTAmortizedOracle.Contract.HasPosition(&_IPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleTransactor) RecordPurchase(opts *bind.TransactOpts, market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.contract.Transact(opts, "recordPurchase", market, sySpent, ptAmount)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleSession) RecordPurchase(market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.RecordPurchase(&_IPendlePTAmortizedOracle.TransactOpts, market, sySpent, ptAmount)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleTransactorSession) RecordPurchase(market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.RecordPurchase(&_IPendlePTAmortizedOracle.TransactOpts, market, sySpent, ptAmount)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleTransactor) RecordRedemption(opts *bind.TransactOpts, market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.contract.Transact(opts, "recordRedemption", market, ptSold)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleSession) RecordRedemption(market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.RecordRedemption(&_IPendlePTAmortizedOracle.TransactOpts, market, ptSold)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_IPendlePTAmortizedOracle *IPendlePTAmortizedOracleTransactorSession) RecordRedemption(market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _IPendlePTAmortizedOracle.Contract.RecordRedemption(&_IPendlePTAmortizedOracle.TransactOpts, market, ptSold)
}
