// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package IPPYLpOracle

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

// IPPYLpOracleMetaData contains all meta data concerning the IPPYLpOracle contract.
var IPPYLpOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"blockCycleNumerator\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint16\",\"internalType\":\"uint16\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLpToAssetRate\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"duration\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLpToSyRate\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"duration\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOracleState\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"duration\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"increaseCardinalityRequired\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"cardinalityRequired\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"oldestObservationSatisfied\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPtToAssetRate\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"duration\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPtToSyRate\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"duration\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYtToAssetRate\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"duration\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYtToSyRate\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"duration\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"SetBlockCycleNumerator\",\"inputs\":[{\"name\":\"newBlockCycleNumerator\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false}]",
}

// IPPYLpOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use IPPYLpOracleMetaData.ABI instead.
var IPPYLpOracleABI = IPPYLpOracleMetaData.ABI

// IPPYLpOracle is an auto generated Go binding around an Ethereum contract.
type IPPYLpOracle struct {
	IPPYLpOracleCaller     // Read-only binding to the contract
	IPPYLpOracleTransactor // Write-only binding to the contract
	IPPYLpOracleFilterer   // Log filterer for contract events
}

// IPPYLpOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type IPPYLpOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IPPYLpOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IPPYLpOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IPPYLpOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IPPYLpOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IPPYLpOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IPPYLpOracleSession struct {
	Contract     *IPPYLpOracle     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// IPPYLpOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IPPYLpOracleCallerSession struct {
	Contract *IPPYLpOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// IPPYLpOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IPPYLpOracleTransactorSession struct {
	Contract     *IPPYLpOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// IPPYLpOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type IPPYLpOracleRaw struct {
	Contract *IPPYLpOracle // Generic contract binding to access the raw methods on
}

// IPPYLpOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IPPYLpOracleCallerRaw struct {
	Contract *IPPYLpOracleCaller // Generic read-only contract binding to access the raw methods on
}

// IPPYLpOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IPPYLpOracleTransactorRaw struct {
	Contract *IPPYLpOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIPPYLpOracle creates a new instance of IPPYLpOracle, bound to a specific deployed contract.
func NewIPPYLpOracle(address common.Address, backend bind.ContractBackend) (*IPPYLpOracle, error) {
	contract, err := bindIPPYLpOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IPPYLpOracle{IPPYLpOracleCaller: IPPYLpOracleCaller{contract: contract}, IPPYLpOracleTransactor: IPPYLpOracleTransactor{contract: contract}, IPPYLpOracleFilterer: IPPYLpOracleFilterer{contract: contract}}, nil
}

// NewIPPYLpOracleCaller creates a new read-only instance of IPPYLpOracle, bound to a specific deployed contract.
func NewIPPYLpOracleCaller(address common.Address, caller bind.ContractCaller) (*IPPYLpOracleCaller, error) {
	contract, err := bindIPPYLpOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IPPYLpOracleCaller{contract: contract}, nil
}

// NewIPPYLpOracleTransactor creates a new write-only instance of IPPYLpOracle, bound to a specific deployed contract.
func NewIPPYLpOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*IPPYLpOracleTransactor, error) {
	contract, err := bindIPPYLpOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IPPYLpOracleTransactor{contract: contract}, nil
}

// NewIPPYLpOracleFilterer creates a new log filterer instance of IPPYLpOracle, bound to a specific deployed contract.
func NewIPPYLpOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*IPPYLpOracleFilterer, error) {
	contract, err := bindIPPYLpOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IPPYLpOracleFilterer{contract: contract}, nil
}

// bindIPPYLpOracle binds a generic wrapper to an already deployed contract.
func bindIPPYLpOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := IPPYLpOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IPPYLpOracle *IPPYLpOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IPPYLpOracle.Contract.IPPYLpOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IPPYLpOracle *IPPYLpOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IPPYLpOracle.Contract.IPPYLpOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IPPYLpOracle *IPPYLpOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IPPYLpOracle.Contract.IPPYLpOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IPPYLpOracle *IPPYLpOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IPPYLpOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IPPYLpOracle *IPPYLpOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IPPYLpOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IPPYLpOracle *IPPYLpOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IPPYLpOracle.Contract.contract.Transact(opts, method, params...)
}

// BlockCycleNumerator is a free data retrieval call binding the contract method 0x58f6e5a1.
//
// Solidity: function blockCycleNumerator() view returns(uint16)
func (_IPPYLpOracle *IPPYLpOracleCaller) BlockCycleNumerator(opts *bind.CallOpts) (uint16, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "blockCycleNumerator")

	if err != nil {
		return *new(uint16), err
	}

	out0 := *abi.ConvertType(out[0], new(uint16)).(*uint16)

	return out0, err

}

// BlockCycleNumerator is a free data retrieval call binding the contract method 0x58f6e5a1.
//
// Solidity: function blockCycleNumerator() view returns(uint16)
func (_IPPYLpOracle *IPPYLpOracleSession) BlockCycleNumerator() (uint16, error) {
	return _IPPYLpOracle.Contract.BlockCycleNumerator(&_IPPYLpOracle.CallOpts)
}

// BlockCycleNumerator is a free data retrieval call binding the contract method 0x58f6e5a1.
//
// Solidity: function blockCycleNumerator() view returns(uint16)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) BlockCycleNumerator() (uint16, error) {
	return _IPPYLpOracle.Contract.BlockCycleNumerator(&_IPPYLpOracle.CallOpts)
}

// GetLpToAssetRate is a free data retrieval call binding the contract method 0x6cda9833.
//
// Solidity: function getLpToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCaller) GetLpToAssetRate(opts *bind.CallOpts, market common.Address, duration uint32) (*big.Int, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "getLpToAssetRate", market, duration)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetLpToAssetRate is a free data retrieval call binding the contract method 0x6cda9833.
//
// Solidity: function getLpToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleSession) GetLpToAssetRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetLpToAssetRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetLpToAssetRate is a free data retrieval call binding the contract method 0x6cda9833.
//
// Solidity: function getLpToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) GetLpToAssetRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetLpToAssetRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetLpToSyRate is a free data retrieval call binding the contract method 0x4d44ca89.
//
// Solidity: function getLpToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCaller) GetLpToSyRate(opts *bind.CallOpts, market common.Address, duration uint32) (*big.Int, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "getLpToSyRate", market, duration)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetLpToSyRate is a free data retrieval call binding the contract method 0x4d44ca89.
//
// Solidity: function getLpToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleSession) GetLpToSyRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetLpToSyRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetLpToSyRate is a free data retrieval call binding the contract method 0x4d44ca89.
//
// Solidity: function getLpToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) GetLpToSyRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetLpToSyRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetOracleState is a free data retrieval call binding the contract method 0x873e9600.
//
// Solidity: function getOracleState(address market, uint32 duration) view returns(bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied)
func (_IPPYLpOracle *IPPYLpOracleCaller) GetOracleState(opts *bind.CallOpts, market common.Address, duration uint32) (struct {
	IncreaseCardinalityRequired bool
	CardinalityRequired         uint16
	OldestObservationSatisfied  bool
}, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "getOracleState", market, duration)

	outstruct := new(struct {
		IncreaseCardinalityRequired bool
		CardinalityRequired         uint16
		OldestObservationSatisfied  bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.IncreaseCardinalityRequired = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.CardinalityRequired = *abi.ConvertType(out[1], new(uint16)).(*uint16)
	outstruct.OldestObservationSatisfied = *abi.ConvertType(out[2], new(bool)).(*bool)

	return *outstruct, err

}

// GetOracleState is a free data retrieval call binding the contract method 0x873e9600.
//
// Solidity: function getOracleState(address market, uint32 duration) view returns(bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied)
func (_IPPYLpOracle *IPPYLpOracleSession) GetOracleState(market common.Address, duration uint32) (struct {
	IncreaseCardinalityRequired bool
	CardinalityRequired         uint16
	OldestObservationSatisfied  bool
}, error) {
	return _IPPYLpOracle.Contract.GetOracleState(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetOracleState is a free data retrieval call binding the contract method 0x873e9600.
//
// Solidity: function getOracleState(address market, uint32 duration) view returns(bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) GetOracleState(market common.Address, duration uint32) (struct {
	IncreaseCardinalityRequired bool
	CardinalityRequired         uint16
	OldestObservationSatisfied  bool
}, error) {
	return _IPPYLpOracle.Contract.GetOracleState(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetPtToAssetRate is a free data retrieval call binding the contract method 0xabca0eab.
//
// Solidity: function getPtToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCaller) GetPtToAssetRate(opts *bind.CallOpts, market common.Address, duration uint32) (*big.Int, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "getPtToAssetRate", market, duration)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPtToAssetRate is a free data retrieval call binding the contract method 0xabca0eab.
//
// Solidity: function getPtToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleSession) GetPtToAssetRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetPtToAssetRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetPtToAssetRate is a free data retrieval call binding the contract method 0xabca0eab.
//
// Solidity: function getPtToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) GetPtToAssetRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetPtToAssetRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetPtToSyRate is a free data retrieval call binding the contract method 0xa31426d1.
//
// Solidity: function getPtToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCaller) GetPtToSyRate(opts *bind.CallOpts, market common.Address, duration uint32) (*big.Int, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "getPtToSyRate", market, duration)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPtToSyRate is a free data retrieval call binding the contract method 0xa31426d1.
//
// Solidity: function getPtToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleSession) GetPtToSyRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetPtToSyRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetPtToSyRate is a free data retrieval call binding the contract method 0xa31426d1.
//
// Solidity: function getPtToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) GetPtToSyRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetPtToSyRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetYtToAssetRate is a free data retrieval call binding the contract method 0xbb0856fe.
//
// Solidity: function getYtToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCaller) GetYtToAssetRate(opts *bind.CallOpts, market common.Address, duration uint32) (*big.Int, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "getYtToAssetRate", market, duration)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetYtToAssetRate is a free data retrieval call binding the contract method 0xbb0856fe.
//
// Solidity: function getYtToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleSession) GetYtToAssetRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetYtToAssetRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetYtToAssetRate is a free data retrieval call binding the contract method 0xbb0856fe.
//
// Solidity: function getYtToAssetRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) GetYtToAssetRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetYtToAssetRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetYtToSyRate is a free data retrieval call binding the contract method 0xffec4407.
//
// Solidity: function getYtToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCaller) GetYtToSyRate(opts *bind.CallOpts, market common.Address, duration uint32) (*big.Int, error) {
	var out []interface{}
	err := _IPPYLpOracle.contract.Call(opts, &out, "getYtToSyRate", market, duration)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetYtToSyRate is a free data retrieval call binding the contract method 0xffec4407.
//
// Solidity: function getYtToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleSession) GetYtToSyRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetYtToSyRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// GetYtToSyRate is a free data retrieval call binding the contract method 0xffec4407.
//
// Solidity: function getYtToSyRate(address market, uint32 duration) view returns(uint256)
func (_IPPYLpOracle *IPPYLpOracleCallerSession) GetYtToSyRate(market common.Address, duration uint32) (*big.Int, error) {
	return _IPPYLpOracle.Contract.GetYtToSyRate(&_IPPYLpOracle.CallOpts, market, duration)
}

// IPPYLpOracleSetBlockCycleNumeratorIterator is returned from FilterSetBlockCycleNumerator and is used to iterate over the raw logs and unpacked data for SetBlockCycleNumerator events raised by the IPPYLpOracle contract.
type IPPYLpOracleSetBlockCycleNumeratorIterator struct {
	Event *IPPYLpOracleSetBlockCycleNumerator // Event containing the contract specifics and raw log

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
func (it *IPPYLpOracleSetBlockCycleNumeratorIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IPPYLpOracleSetBlockCycleNumerator)
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
		it.Event = new(IPPYLpOracleSetBlockCycleNumerator)
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
func (it *IPPYLpOracleSetBlockCycleNumeratorIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IPPYLpOracleSetBlockCycleNumeratorIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IPPYLpOracleSetBlockCycleNumerator represents a SetBlockCycleNumerator event raised by the IPPYLpOracle contract.
type IPPYLpOracleSetBlockCycleNumerator struct {
	NewBlockCycleNumerator uint16
	Raw                    types.Log // Blockchain specific contextual infos
}

// FilterSetBlockCycleNumerator is a free log retrieval operation binding the contract event 0x30b0568b152eb73b8d1104ca045f37e64f7eae07b09ea9607ab1bdf475012c53.
//
// Solidity: event SetBlockCycleNumerator(uint16 newBlockCycleNumerator)
func (_IPPYLpOracle *IPPYLpOracleFilterer) FilterSetBlockCycleNumerator(opts *bind.FilterOpts) (*IPPYLpOracleSetBlockCycleNumeratorIterator, error) {

	logs, sub, err := _IPPYLpOracle.contract.FilterLogs(opts, "SetBlockCycleNumerator")
	if err != nil {
		return nil, err
	}
	return &IPPYLpOracleSetBlockCycleNumeratorIterator{contract: _IPPYLpOracle.contract, event: "SetBlockCycleNumerator", logs: logs, sub: sub}, nil
}

// WatchSetBlockCycleNumerator is a free log subscription operation binding the contract event 0x30b0568b152eb73b8d1104ca045f37e64f7eae07b09ea9607ab1bdf475012c53.
//
// Solidity: event SetBlockCycleNumerator(uint16 newBlockCycleNumerator)
func (_IPPYLpOracle *IPPYLpOracleFilterer) WatchSetBlockCycleNumerator(opts *bind.WatchOpts, sink chan<- *IPPYLpOracleSetBlockCycleNumerator) (event.Subscription, error) {

	logs, sub, err := _IPPYLpOracle.contract.WatchLogs(opts, "SetBlockCycleNumerator")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IPPYLpOracleSetBlockCycleNumerator)
				if err := _IPPYLpOracle.contract.UnpackLog(event, "SetBlockCycleNumerator", log); err != nil {
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

// ParseSetBlockCycleNumerator is a log parse operation binding the contract event 0x30b0568b152eb73b8d1104ca045f37e64f7eae07b09ea9607ab1bdf475012c53.
//
// Solidity: event SetBlockCycleNumerator(uint16 newBlockCycleNumerator)
func (_IPPYLpOracle *IPPYLpOracleFilterer) ParseSetBlockCycleNumerator(log types.Log) (*IPPYLpOracleSetBlockCycleNumerator, error) {
	event := new(IPPYLpOracleSetBlockCycleNumerator)
	if err := _IPPYLpOracle.contract.UnpackLog(event, "SetBlockCycleNumerator", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
