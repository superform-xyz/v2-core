// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package MockPendlePTAmortizedOracle

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

// MockPendlePTAmortizedOraclePurchaseRecord is an auto generated low-level Go binding around an user-defined struct.
type MockPendlePTAmortizedOraclePurchaseRecord struct {
	Caller    common.Address
	Market    common.Address
	SySpent   *big.Int
	PtAmount  *big.Int
	Timestamp *big.Int
}

// MockPendlePTAmortizedOracleRedemptionRecord is an auto generated low-level Go binding around an user-defined struct.
type MockPendlePTAmortizedOracleRedemptionRecord struct {
	Caller    common.Address
	Market    common.Address
	PtSold    *big.Int
	Timestamp *big.Int
}

// MockPendlePTAmortizedOracleMetaData contains all meta data concerning the MockPendlePTAmortizedOracle contract.
var MockPendlePTAmortizedOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"bookValueStorage\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBookValue\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastPurchase\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structMockPendlePTAmortizedOracle.PurchaseRecord\",\"components\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sySpent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ptAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastRedemption\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structMockPendlePTAmortizedOracle.RedemptionRecord\",\"components\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ptSold\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPurchaseCount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRedemptionCount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hasPosition\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"positionExists\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"purchases\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sySpent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ptAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"recordPurchase\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sySpent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ptAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"recordRedemption\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ptSold\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"redemptions\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ptSold\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"}]",
}

// MockPendlePTAmortizedOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use MockPendlePTAmortizedOracleMetaData.ABI instead.
var MockPendlePTAmortizedOracleABI = MockPendlePTAmortizedOracleMetaData.ABI

// MockPendlePTAmortizedOracle is an auto generated Go binding around an Ethereum contract.
type MockPendlePTAmortizedOracle struct {
	MockPendlePTAmortizedOracleCaller     // Read-only binding to the contract
	MockPendlePTAmortizedOracleTransactor // Write-only binding to the contract
	MockPendlePTAmortizedOracleFilterer   // Log filterer for contract events
}

// MockPendlePTAmortizedOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type MockPendlePTAmortizedOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockPendlePTAmortizedOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type MockPendlePTAmortizedOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockPendlePTAmortizedOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type MockPendlePTAmortizedOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockPendlePTAmortizedOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type MockPendlePTAmortizedOracleSession struct {
	Contract     *MockPendlePTAmortizedOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                // Call options to use throughout this session
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// MockPendlePTAmortizedOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type MockPendlePTAmortizedOracleCallerSession struct {
	Contract *MockPendlePTAmortizedOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                      // Call options to use throughout this session
}

// MockPendlePTAmortizedOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type MockPendlePTAmortizedOracleTransactorSession struct {
	Contract     *MockPendlePTAmortizedOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                      // Transaction auth options to use throughout this session
}

// MockPendlePTAmortizedOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type MockPendlePTAmortizedOracleRaw struct {
	Contract *MockPendlePTAmortizedOracle // Generic contract binding to access the raw methods on
}

// MockPendlePTAmortizedOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type MockPendlePTAmortizedOracleCallerRaw struct {
	Contract *MockPendlePTAmortizedOracleCaller // Generic read-only contract binding to access the raw methods on
}

// MockPendlePTAmortizedOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type MockPendlePTAmortizedOracleTransactorRaw struct {
	Contract *MockPendlePTAmortizedOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewMockPendlePTAmortizedOracle creates a new instance of MockPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewMockPendlePTAmortizedOracle(address common.Address, backend bind.ContractBackend) (*MockPendlePTAmortizedOracle, error) {
	contract, err := bindMockPendlePTAmortizedOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &MockPendlePTAmortizedOracle{MockPendlePTAmortizedOracleCaller: MockPendlePTAmortizedOracleCaller{contract: contract}, MockPendlePTAmortizedOracleTransactor: MockPendlePTAmortizedOracleTransactor{contract: contract}, MockPendlePTAmortizedOracleFilterer: MockPendlePTAmortizedOracleFilterer{contract: contract}}, nil
}

// NewMockPendlePTAmortizedOracleCaller creates a new read-only instance of MockPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewMockPendlePTAmortizedOracleCaller(address common.Address, caller bind.ContractCaller) (*MockPendlePTAmortizedOracleCaller, error) {
	contract, err := bindMockPendlePTAmortizedOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &MockPendlePTAmortizedOracleCaller{contract: contract}, nil
}

// NewMockPendlePTAmortizedOracleTransactor creates a new write-only instance of MockPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewMockPendlePTAmortizedOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*MockPendlePTAmortizedOracleTransactor, error) {
	contract, err := bindMockPendlePTAmortizedOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &MockPendlePTAmortizedOracleTransactor{contract: contract}, nil
}

// NewMockPendlePTAmortizedOracleFilterer creates a new log filterer instance of MockPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewMockPendlePTAmortizedOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*MockPendlePTAmortizedOracleFilterer, error) {
	contract, err := bindMockPendlePTAmortizedOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &MockPendlePTAmortizedOracleFilterer{contract: contract}, nil
}

// bindMockPendlePTAmortizedOracle binds a generic wrapper to an already deployed contract.
func bindMockPendlePTAmortizedOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := MockPendlePTAmortizedOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MockPendlePTAmortizedOracle.Contract.MockPendlePTAmortizedOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.MockPendlePTAmortizedOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.MockPendlePTAmortizedOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MockPendlePTAmortizedOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.contract.Transact(opts, method, params...)
}

// BookValueStorage is a free data retrieval call binding the contract method 0xa903dca9.
//
// Solidity: function bookValueStorage(address , address ) view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) BookValueStorage(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "bookValueStorage", arg0, arg1)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BookValueStorage is a free data retrieval call binding the contract method 0xa903dca9.
//
// Solidity: function bookValueStorage(address , address ) view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) BookValueStorage(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.BookValueStorage(&_MockPendlePTAmortizedOracle.CallOpts, arg0, arg1)
}

// BookValueStorage is a free data retrieval call binding the contract method 0xa903dca9.
//
// Solidity: function bookValueStorage(address , address ) view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) BookValueStorage(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.BookValueStorage(&_MockPendlePTAmortizedOracle.CallOpts, arg0, arg1)
}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) GetBookValue(opts *bind.CallOpts, strategy common.Address, market common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "getBookValue", strategy, market)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) GetBookValue(strategy common.Address, market common.Address) (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetBookValue(&_MockPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) GetBookValue(strategy common.Address, market common.Address) (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetBookValue(&_MockPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// GetLastPurchase is a free data retrieval call binding the contract method 0xf2a3c867.
//
// Solidity: function getLastPurchase() view returns((address,address,uint256,uint256,uint256))
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) GetLastPurchase(opts *bind.CallOpts) (MockPendlePTAmortizedOraclePurchaseRecord, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "getLastPurchase")

	if err != nil {
		return *new(MockPendlePTAmortizedOraclePurchaseRecord), err
	}

	out0 := *abi.ConvertType(out[0], new(MockPendlePTAmortizedOraclePurchaseRecord)).(*MockPendlePTAmortizedOraclePurchaseRecord)

	return out0, err

}

// GetLastPurchase is a free data retrieval call binding the contract method 0xf2a3c867.
//
// Solidity: function getLastPurchase() view returns((address,address,uint256,uint256,uint256))
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) GetLastPurchase() (MockPendlePTAmortizedOraclePurchaseRecord, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetLastPurchase(&_MockPendlePTAmortizedOracle.CallOpts)
}

// GetLastPurchase is a free data retrieval call binding the contract method 0xf2a3c867.
//
// Solidity: function getLastPurchase() view returns((address,address,uint256,uint256,uint256))
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) GetLastPurchase() (MockPendlePTAmortizedOraclePurchaseRecord, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetLastPurchase(&_MockPendlePTAmortizedOracle.CallOpts)
}

// GetLastRedemption is a free data retrieval call binding the contract method 0x7d747924.
//
// Solidity: function getLastRedemption() view returns((address,address,uint256,uint256))
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) GetLastRedemption(opts *bind.CallOpts) (MockPendlePTAmortizedOracleRedemptionRecord, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "getLastRedemption")

	if err != nil {
		return *new(MockPendlePTAmortizedOracleRedemptionRecord), err
	}

	out0 := *abi.ConvertType(out[0], new(MockPendlePTAmortizedOracleRedemptionRecord)).(*MockPendlePTAmortizedOracleRedemptionRecord)

	return out0, err

}

// GetLastRedemption is a free data retrieval call binding the contract method 0x7d747924.
//
// Solidity: function getLastRedemption() view returns((address,address,uint256,uint256))
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) GetLastRedemption() (MockPendlePTAmortizedOracleRedemptionRecord, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetLastRedemption(&_MockPendlePTAmortizedOracle.CallOpts)
}

// GetLastRedemption is a free data retrieval call binding the contract method 0x7d747924.
//
// Solidity: function getLastRedemption() view returns((address,address,uint256,uint256))
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) GetLastRedemption() (MockPendlePTAmortizedOracleRedemptionRecord, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetLastRedemption(&_MockPendlePTAmortizedOracle.CallOpts)
}

// GetPurchaseCount is a free data retrieval call binding the contract method 0xbecd283f.
//
// Solidity: function getPurchaseCount() view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) GetPurchaseCount(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "getPurchaseCount")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPurchaseCount is a free data retrieval call binding the contract method 0xbecd283f.
//
// Solidity: function getPurchaseCount() view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) GetPurchaseCount() (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetPurchaseCount(&_MockPendlePTAmortizedOracle.CallOpts)
}

// GetPurchaseCount is a free data retrieval call binding the contract method 0xbecd283f.
//
// Solidity: function getPurchaseCount() view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) GetPurchaseCount() (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetPurchaseCount(&_MockPendlePTAmortizedOracle.CallOpts)
}

// GetRedemptionCount is a free data retrieval call binding the contract method 0xe5456255.
//
// Solidity: function getRedemptionCount() view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) GetRedemptionCount(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "getRedemptionCount")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetRedemptionCount is a free data retrieval call binding the contract method 0xe5456255.
//
// Solidity: function getRedemptionCount() view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) GetRedemptionCount() (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetRedemptionCount(&_MockPendlePTAmortizedOracle.CallOpts)
}

// GetRedemptionCount is a free data retrieval call binding the contract method 0xe5456255.
//
// Solidity: function getRedemptionCount() view returns(uint256)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) GetRedemptionCount() (*big.Int, error) {
	return _MockPendlePTAmortizedOracle.Contract.GetRedemptionCount(&_MockPendlePTAmortizedOracle.CallOpts)
}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) HasPosition(opts *bind.CallOpts, strategy common.Address, market common.Address) (bool, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "hasPosition", strategy, market)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) HasPosition(strategy common.Address, market common.Address) (bool, error) {
	return _MockPendlePTAmortizedOracle.Contract.HasPosition(&_MockPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) HasPosition(strategy common.Address, market common.Address) (bool, error) {
	return _MockPendlePTAmortizedOracle.Contract.HasPosition(&_MockPendlePTAmortizedOracle.CallOpts, strategy, market)
}

// PositionExists is a free data retrieval call binding the contract method 0x86f67fa5.
//
// Solidity: function positionExists(address , address ) view returns(bool)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) PositionExists(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address) (bool, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "positionExists", arg0, arg1)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// PositionExists is a free data retrieval call binding the contract method 0x86f67fa5.
//
// Solidity: function positionExists(address , address ) view returns(bool)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) PositionExists(arg0 common.Address, arg1 common.Address) (bool, error) {
	return _MockPendlePTAmortizedOracle.Contract.PositionExists(&_MockPendlePTAmortizedOracle.CallOpts, arg0, arg1)
}

// PositionExists is a free data retrieval call binding the contract method 0x86f67fa5.
//
// Solidity: function positionExists(address , address ) view returns(bool)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) PositionExists(arg0 common.Address, arg1 common.Address) (bool, error) {
	return _MockPendlePTAmortizedOracle.Contract.PositionExists(&_MockPendlePTAmortizedOracle.CallOpts, arg0, arg1)
}

// Purchases is a free data retrieval call binding the contract method 0x8392fe31.
//
// Solidity: function purchases(uint256 ) view returns(address caller, address market, uint256 sySpent, uint256 ptAmount, uint256 timestamp)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) Purchases(opts *bind.CallOpts, arg0 *big.Int) (struct {
	Caller    common.Address
	Market    common.Address
	SySpent   *big.Int
	PtAmount  *big.Int
	Timestamp *big.Int
}, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "purchases", arg0)

	outstruct := new(struct {
		Caller    common.Address
		Market    common.Address
		SySpent   *big.Int
		PtAmount  *big.Int
		Timestamp *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Caller = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.Market = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.SySpent = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)
	outstruct.PtAmount = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)
	outstruct.Timestamp = *abi.ConvertType(out[4], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// Purchases is a free data retrieval call binding the contract method 0x8392fe31.
//
// Solidity: function purchases(uint256 ) view returns(address caller, address market, uint256 sySpent, uint256 ptAmount, uint256 timestamp)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) Purchases(arg0 *big.Int) (struct {
	Caller    common.Address
	Market    common.Address
	SySpent   *big.Int
	PtAmount  *big.Int
	Timestamp *big.Int
}, error) {
	return _MockPendlePTAmortizedOracle.Contract.Purchases(&_MockPendlePTAmortizedOracle.CallOpts, arg0)
}

// Purchases is a free data retrieval call binding the contract method 0x8392fe31.
//
// Solidity: function purchases(uint256 ) view returns(address caller, address market, uint256 sySpent, uint256 ptAmount, uint256 timestamp)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) Purchases(arg0 *big.Int) (struct {
	Caller    common.Address
	Market    common.Address
	SySpent   *big.Int
	PtAmount  *big.Int
	Timestamp *big.Int
}, error) {
	return _MockPendlePTAmortizedOracle.Contract.Purchases(&_MockPendlePTAmortizedOracle.CallOpts, arg0)
}

// Redemptions is a free data retrieval call binding the contract method 0xbeb65893.
//
// Solidity: function redemptions(uint256 ) view returns(address caller, address market, uint256 ptSold, uint256 timestamp)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCaller) Redemptions(opts *bind.CallOpts, arg0 *big.Int) (struct {
	Caller    common.Address
	Market    common.Address
	PtSold    *big.Int
	Timestamp *big.Int
}, error) {
	var out []interface{}
	err := _MockPendlePTAmortizedOracle.contract.Call(opts, &out, "redemptions", arg0)

	outstruct := new(struct {
		Caller    common.Address
		Market    common.Address
		PtSold    *big.Int
		Timestamp *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Caller = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.Market = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.PtSold = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)
	outstruct.Timestamp = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// Redemptions is a free data retrieval call binding the contract method 0xbeb65893.
//
// Solidity: function redemptions(uint256 ) view returns(address caller, address market, uint256 ptSold, uint256 timestamp)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) Redemptions(arg0 *big.Int) (struct {
	Caller    common.Address
	Market    common.Address
	PtSold    *big.Int
	Timestamp *big.Int
}, error) {
	return _MockPendlePTAmortizedOracle.Contract.Redemptions(&_MockPendlePTAmortizedOracle.CallOpts, arg0)
}

// Redemptions is a free data retrieval call binding the contract method 0xbeb65893.
//
// Solidity: function redemptions(uint256 ) view returns(address caller, address market, uint256 ptSold, uint256 timestamp)
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleCallerSession) Redemptions(arg0 *big.Int) (struct {
	Caller    common.Address
	Market    common.Address
	PtSold    *big.Int
	Timestamp *big.Int
}, error) {
	return _MockPendlePTAmortizedOracle.Contract.Redemptions(&_MockPendlePTAmortizedOracle.CallOpts, arg0)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleTransactor) RecordPurchase(opts *bind.TransactOpts, market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.contract.Transact(opts, "recordPurchase", market, sySpent, ptAmount)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) RecordPurchase(market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.RecordPurchase(&_MockPendlePTAmortizedOracle.TransactOpts, market, sySpent, ptAmount)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleTransactorSession) RecordPurchase(market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.RecordPurchase(&_MockPendlePTAmortizedOracle.TransactOpts, market, sySpent, ptAmount)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleTransactor) RecordRedemption(opts *bind.TransactOpts, market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.contract.Transact(opts, "recordRedemption", market, ptSold)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleSession) RecordRedemption(market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.RecordRedemption(&_MockPendlePTAmortizedOracle.TransactOpts, market, ptSold)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_MockPendlePTAmortizedOracle *MockPendlePTAmortizedOracleTransactorSession) RecordRedemption(market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _MockPendlePTAmortizedOracle.Contract.RecordRedemption(&_MockPendlePTAmortizedOracle.TransactOpts, market, ptSold)
}
