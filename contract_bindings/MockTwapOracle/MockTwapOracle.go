// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package MockTwapOracle

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

// MockTwapOracleMetaData contains all meta data concerning the MockTwapOracle contract.
var MockTwapOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"oracleDifference\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"simulateGetAssetOutput\",\"inputs\":[{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"twapRate\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"assetsOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"simulateTVL\",\"inputs\":[{\"name\":\"ptAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"twapRate\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"}]",
}

// MockTwapOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use MockTwapOracleMetaData.ABI instead.
var MockTwapOracleABI = MockTwapOracleMetaData.ABI

// MockTwapOracle is an auto generated Go binding around an Ethereum contract.
type MockTwapOracle struct {
	MockTwapOracleCaller     // Read-only binding to the contract
	MockTwapOracleTransactor // Write-only binding to the contract
	MockTwapOracleFilterer   // Log filterer for contract events
}

// MockTwapOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type MockTwapOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockTwapOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type MockTwapOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockTwapOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type MockTwapOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockTwapOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type MockTwapOracleSession struct {
	Contract     *MockTwapOracle   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// MockTwapOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type MockTwapOracleCallerSession struct {
	Contract *MockTwapOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// MockTwapOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type MockTwapOracleTransactorSession struct {
	Contract     *MockTwapOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// MockTwapOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type MockTwapOracleRaw struct {
	Contract *MockTwapOracle // Generic contract binding to access the raw methods on
}

// MockTwapOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type MockTwapOracleCallerRaw struct {
	Contract *MockTwapOracleCaller // Generic read-only contract binding to access the raw methods on
}

// MockTwapOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type MockTwapOracleTransactorRaw struct {
	Contract *MockTwapOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewMockTwapOracle creates a new instance of MockTwapOracle, bound to a specific deployed contract.
func NewMockTwapOracle(address common.Address, backend bind.ContractBackend) (*MockTwapOracle, error) {
	contract, err := bindMockTwapOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &MockTwapOracle{MockTwapOracleCaller: MockTwapOracleCaller{contract: contract}, MockTwapOracleTransactor: MockTwapOracleTransactor{contract: contract}, MockTwapOracleFilterer: MockTwapOracleFilterer{contract: contract}}, nil
}

// NewMockTwapOracleCaller creates a new read-only instance of MockTwapOracle, bound to a specific deployed contract.
func NewMockTwapOracleCaller(address common.Address, caller bind.ContractCaller) (*MockTwapOracleCaller, error) {
	contract, err := bindMockTwapOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &MockTwapOracleCaller{contract: contract}, nil
}

// NewMockTwapOracleTransactor creates a new write-only instance of MockTwapOracle, bound to a specific deployed contract.
func NewMockTwapOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*MockTwapOracleTransactor, error) {
	contract, err := bindMockTwapOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &MockTwapOracleTransactor{contract: contract}, nil
}

// NewMockTwapOracleFilterer creates a new log filterer instance of MockTwapOracle, bound to a specific deployed contract.
func NewMockTwapOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*MockTwapOracleFilterer, error) {
	contract, err := bindMockTwapOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &MockTwapOracleFilterer{contract: contract}, nil
}

// bindMockTwapOracle binds a generic wrapper to an already deployed contract.
func bindMockTwapOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := MockTwapOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MockTwapOracle *MockTwapOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MockTwapOracle.Contract.MockTwapOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MockTwapOracle *MockTwapOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MockTwapOracle.Contract.MockTwapOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MockTwapOracle *MockTwapOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MockTwapOracle.Contract.MockTwapOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MockTwapOracle *MockTwapOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MockTwapOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MockTwapOracle *MockTwapOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MockTwapOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MockTwapOracle *MockTwapOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MockTwapOracle.Contract.contract.Transact(opts, method, params...)
}

// OracleDifference is a free data retrieval call binding the contract method 0x602217d2.
//
// Solidity: function oracleDifference() pure returns(string)
func (_MockTwapOracle *MockTwapOracleCaller) OracleDifference(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _MockTwapOracle.contract.Call(opts, &out, "oracleDifference")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// OracleDifference is a free data retrieval call binding the contract method 0x602217d2.
//
// Solidity: function oracleDifference() pure returns(string)
func (_MockTwapOracle *MockTwapOracleSession) OracleDifference() (string, error) {
	return _MockTwapOracle.Contract.OracleDifference(&_MockTwapOracle.CallOpts)
}

// OracleDifference is a free data retrieval call binding the contract method 0x602217d2.
//
// Solidity: function oracleDifference() pure returns(string)
func (_MockTwapOracle *MockTwapOracleCallerSession) OracleDifference() (string, error) {
	return _MockTwapOracle.Contract.OracleDifference(&_MockTwapOracle.CallOpts)
}

// SimulateGetAssetOutput is a free data retrieval call binding the contract method 0x7c34d7a3.
//
// Solidity: function simulateGetAssetOutput(uint256 sharesIn, uint256 twapRate) pure returns(uint256 assetsOut)
func (_MockTwapOracle *MockTwapOracleCaller) SimulateGetAssetOutput(opts *bind.CallOpts, sharesIn *big.Int, twapRate *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MockTwapOracle.contract.Call(opts, &out, "simulateGetAssetOutput", sharesIn, twapRate)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SimulateGetAssetOutput is a free data retrieval call binding the contract method 0x7c34d7a3.
//
// Solidity: function simulateGetAssetOutput(uint256 sharesIn, uint256 twapRate) pure returns(uint256 assetsOut)
func (_MockTwapOracle *MockTwapOracleSession) SimulateGetAssetOutput(sharesIn *big.Int, twapRate *big.Int) (*big.Int, error) {
	return _MockTwapOracle.Contract.SimulateGetAssetOutput(&_MockTwapOracle.CallOpts, sharesIn, twapRate)
}

// SimulateGetAssetOutput is a free data retrieval call binding the contract method 0x7c34d7a3.
//
// Solidity: function simulateGetAssetOutput(uint256 sharesIn, uint256 twapRate) pure returns(uint256 assetsOut)
func (_MockTwapOracle *MockTwapOracleCallerSession) SimulateGetAssetOutput(sharesIn *big.Int, twapRate *big.Int) (*big.Int, error) {
	return _MockTwapOracle.Contract.SimulateGetAssetOutput(&_MockTwapOracle.CallOpts, sharesIn, twapRate)
}

// SimulateTVL is a free data retrieval call binding the contract method 0x450e348d.
//
// Solidity: function simulateTVL(uint256 ptAmount, uint256 twapRate) pure returns(uint256 tvl)
func (_MockTwapOracle *MockTwapOracleCaller) SimulateTVL(opts *bind.CallOpts, ptAmount *big.Int, twapRate *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MockTwapOracle.contract.Call(opts, &out, "simulateTVL", ptAmount, twapRate)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SimulateTVL is a free data retrieval call binding the contract method 0x450e348d.
//
// Solidity: function simulateTVL(uint256 ptAmount, uint256 twapRate) pure returns(uint256 tvl)
func (_MockTwapOracle *MockTwapOracleSession) SimulateTVL(ptAmount *big.Int, twapRate *big.Int) (*big.Int, error) {
	return _MockTwapOracle.Contract.SimulateTVL(&_MockTwapOracle.CallOpts, ptAmount, twapRate)
}

// SimulateTVL is a free data retrieval call binding the contract method 0x450e348d.
//
// Solidity: function simulateTVL(uint256 ptAmount, uint256 twapRate) pure returns(uint256 tvl)
func (_MockTwapOracle *MockTwapOracleCallerSession) SimulateTVL(ptAmount *big.Int, twapRate *big.Int) (*big.Int, error) {
	return _MockTwapOracle.Contract.SimulateTVL(&_MockTwapOracle.CallOpts, ptAmount, twapRate)
}
