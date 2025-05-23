// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ISuperVaultPPSOracle

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

// ISuperVaultPPSOracleMetaData contains all meta data concerning the ISuperVaultPPSOracle contract.
var ISuperVaultPPSOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"calculateReferencePPS\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pps\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"OracleCalculationFailed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VaultNotSupported\",\"inputs\":[]}]",
}

// ISuperVaultPPSOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use ISuperVaultPPSOracleMetaData.ABI instead.
var ISuperVaultPPSOracleABI = ISuperVaultPPSOracleMetaData.ABI

// ISuperVaultPPSOracle is an auto generated Go binding around an Ethereum contract.
type ISuperVaultPPSOracle struct {
	ISuperVaultPPSOracleCaller     // Read-only binding to the contract
	ISuperVaultPPSOracleTransactor // Write-only binding to the contract
	ISuperVaultPPSOracleFilterer   // Log filterer for contract events
}

// ISuperVaultPPSOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type ISuperVaultPPSOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperVaultPPSOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ISuperVaultPPSOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperVaultPPSOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ISuperVaultPPSOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperVaultPPSOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ISuperVaultPPSOracleSession struct {
	Contract     *ISuperVaultPPSOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// ISuperVaultPPSOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ISuperVaultPPSOracleCallerSession struct {
	Contract *ISuperVaultPPSOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// ISuperVaultPPSOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ISuperVaultPPSOracleTransactorSession struct {
	Contract     *ISuperVaultPPSOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// ISuperVaultPPSOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type ISuperVaultPPSOracleRaw struct {
	Contract *ISuperVaultPPSOracle // Generic contract binding to access the raw methods on
}

// ISuperVaultPPSOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ISuperVaultPPSOracleCallerRaw struct {
	Contract *ISuperVaultPPSOracleCaller // Generic read-only contract binding to access the raw methods on
}

// ISuperVaultPPSOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ISuperVaultPPSOracleTransactorRaw struct {
	Contract *ISuperVaultPPSOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewISuperVaultPPSOracle creates a new instance of ISuperVaultPPSOracle, bound to a specific deployed contract.
func NewISuperVaultPPSOracle(address common.Address, backend bind.ContractBackend) (*ISuperVaultPPSOracle, error) {
	contract, err := bindISuperVaultPPSOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ISuperVaultPPSOracle{ISuperVaultPPSOracleCaller: ISuperVaultPPSOracleCaller{contract: contract}, ISuperVaultPPSOracleTransactor: ISuperVaultPPSOracleTransactor{contract: contract}, ISuperVaultPPSOracleFilterer: ISuperVaultPPSOracleFilterer{contract: contract}}, nil
}

// NewISuperVaultPPSOracleCaller creates a new read-only instance of ISuperVaultPPSOracle, bound to a specific deployed contract.
func NewISuperVaultPPSOracleCaller(address common.Address, caller bind.ContractCaller) (*ISuperVaultPPSOracleCaller, error) {
	contract, err := bindISuperVaultPPSOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperVaultPPSOracleCaller{contract: contract}, nil
}

// NewISuperVaultPPSOracleTransactor creates a new write-only instance of ISuperVaultPPSOracle, bound to a specific deployed contract.
func NewISuperVaultPPSOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*ISuperVaultPPSOracleTransactor, error) {
	contract, err := bindISuperVaultPPSOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperVaultPPSOracleTransactor{contract: contract}, nil
}

// NewISuperVaultPPSOracleFilterer creates a new log filterer instance of ISuperVaultPPSOracle, bound to a specific deployed contract.
func NewISuperVaultPPSOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*ISuperVaultPPSOracleFilterer, error) {
	contract, err := bindISuperVaultPPSOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ISuperVaultPPSOracleFilterer{contract: contract}, nil
}

// bindISuperVaultPPSOracle binds a generic wrapper to an already deployed contract.
func bindISuperVaultPPSOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ISuperVaultPPSOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperVaultPPSOracle.Contract.ISuperVaultPPSOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperVaultPPSOracle.Contract.ISuperVaultPPSOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperVaultPPSOracle.Contract.ISuperVaultPPSOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperVaultPPSOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperVaultPPSOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperVaultPPSOracle.Contract.contract.Transact(opts, method, params...)
}

// CalculateReferencePPS is a free data retrieval call binding the contract method 0xf2c26a29.
//
// Solidity: function calculateReferencePPS(address vault) view returns(uint256 pps)
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleCaller) CalculateReferencePPS(opts *bind.CallOpts, vault common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ISuperVaultPPSOracle.contract.Call(opts, &out, "calculateReferencePPS", vault)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// CalculateReferencePPS is a free data retrieval call binding the contract method 0xf2c26a29.
//
// Solidity: function calculateReferencePPS(address vault) view returns(uint256 pps)
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleSession) CalculateReferencePPS(vault common.Address) (*big.Int, error) {
	return _ISuperVaultPPSOracle.Contract.CalculateReferencePPS(&_ISuperVaultPPSOracle.CallOpts, vault)
}

// CalculateReferencePPS is a free data retrieval call binding the contract method 0xf2c26a29.
//
// Solidity: function calculateReferencePPS(address vault) view returns(uint256 pps)
func (_ISuperVaultPPSOracle *ISuperVaultPPSOracleCallerSession) CalculateReferencePPS(vault common.Address) (*big.Int, error) {
	return _ISuperVaultPPSOracle.Contract.CalculateReferencePPS(&_ISuperVaultPPSOracle.CallOpts, vault)
}
