// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package DeployYoYieldSourceOracle

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

// DeployYoYieldSourceOracleMetaData contains all meta data concerning the DeployYoYieldSourceOracle contract.
var DeployYoYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"DEBRIDGE_CANCEL_ORDER_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"IS_SCRIPT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"configuration\",\"inputs\":[],\"outputs\":[{\"name\":\"treasury\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dethFoundation\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"contractAddresses\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"contractName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"run\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"runCheck\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"runMultiChain\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainIds\",\"type\":\"uint64[]\",\"internalType\":\"uint64[]\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"DeployFailed\",\"inputs\":[]}]",
}

// DeployYoYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use DeployYoYieldSourceOracleMetaData.ABI instead.
var DeployYoYieldSourceOracleABI = DeployYoYieldSourceOracleMetaData.ABI

// DeployYoYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type DeployYoYieldSourceOracle struct {
	DeployYoYieldSourceOracleCaller     // Read-only binding to the contract
	DeployYoYieldSourceOracleTransactor // Write-only binding to the contract
	DeployYoYieldSourceOracleFilterer   // Log filterer for contract events
}

// DeployYoYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type DeployYoYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployYoYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type DeployYoYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployYoYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type DeployYoYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployYoYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type DeployYoYieldSourceOracleSession struct {
	Contract     *DeployYoYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts              // Call options to use throughout this session
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// DeployYoYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type DeployYoYieldSourceOracleCallerSession struct {
	Contract *DeployYoYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                    // Call options to use throughout this session
}

// DeployYoYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type DeployYoYieldSourceOracleTransactorSession struct {
	Contract     *DeployYoYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// DeployYoYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type DeployYoYieldSourceOracleRaw struct {
	Contract *DeployYoYieldSourceOracle // Generic contract binding to access the raw methods on
}

// DeployYoYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type DeployYoYieldSourceOracleCallerRaw struct {
	Contract *DeployYoYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// DeployYoYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type DeployYoYieldSourceOracleTransactorRaw struct {
	Contract *DeployYoYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewDeployYoYieldSourceOracle creates a new instance of DeployYoYieldSourceOracle, bound to a specific deployed contract.
func NewDeployYoYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*DeployYoYieldSourceOracle, error) {
	contract, err := bindDeployYoYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &DeployYoYieldSourceOracle{DeployYoYieldSourceOracleCaller: DeployYoYieldSourceOracleCaller{contract: contract}, DeployYoYieldSourceOracleTransactor: DeployYoYieldSourceOracleTransactor{contract: contract}, DeployYoYieldSourceOracleFilterer: DeployYoYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewDeployYoYieldSourceOracleCaller creates a new read-only instance of DeployYoYieldSourceOracle, bound to a specific deployed contract.
func NewDeployYoYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*DeployYoYieldSourceOracleCaller, error) {
	contract, err := bindDeployYoYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &DeployYoYieldSourceOracleCaller{contract: contract}, nil
}

// NewDeployYoYieldSourceOracleTransactor creates a new write-only instance of DeployYoYieldSourceOracle, bound to a specific deployed contract.
func NewDeployYoYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*DeployYoYieldSourceOracleTransactor, error) {
	contract, err := bindDeployYoYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &DeployYoYieldSourceOracleTransactor{contract: contract}, nil
}

// NewDeployYoYieldSourceOracleFilterer creates a new log filterer instance of DeployYoYieldSourceOracle, bound to a specific deployed contract.
func NewDeployYoYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*DeployYoYieldSourceOracleFilterer, error) {
	contract, err := bindDeployYoYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &DeployYoYieldSourceOracleFilterer{contract: contract}, nil
}

// bindDeployYoYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindDeployYoYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := DeployYoYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DeployYoYieldSourceOracle.Contract.DeployYoYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.DeployYoYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.DeployYoYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DeployYoYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCaller) DEBRIDGECANCELORDERHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _DeployYoYieldSourceOracle.contract.Call(opts, &out, "DEBRIDGE_CANCEL_ORDER_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _DeployYoYieldSourceOracle.Contract.DEBRIDGECANCELORDERHOOKKEY(&_DeployYoYieldSourceOracle.CallOpts)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCallerSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _DeployYoYieldSourceOracle.Contract.DEBRIDGECANCELORDERHOOKKEY(&_DeployYoYieldSourceOracle.CallOpts)
}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCaller) ISSCRIPT(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _DeployYoYieldSourceOracle.contract.Call(opts, &out, "IS_SCRIPT")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleSession) ISSCRIPT() (bool, error) {
	return _DeployYoYieldSourceOracle.Contract.ISSCRIPT(&_DeployYoYieldSourceOracle.CallOpts)
}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCallerSession) ISSCRIPT() (bool, error) {
	return _DeployYoYieldSourceOracle.Contract.ISSCRIPT(&_DeployYoYieldSourceOracle.CallOpts)
}

// Configuration is a free data retrieval call binding the contract method 0x6c70bee9.
//
// Solidity: function configuration() view returns(address treasury, address dethFoundation)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCaller) Configuration(opts *bind.CallOpts) (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	var out []interface{}
	err := _DeployYoYieldSourceOracle.contract.Call(opts, &out, "configuration")

	outstruct := new(struct {
		Treasury       common.Address
		DethFoundation common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Treasury = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.DethFoundation = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// Configuration is a free data retrieval call binding the contract method 0x6c70bee9.
//
// Solidity: function configuration() view returns(address treasury, address dethFoundation)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleSession) Configuration() (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	return _DeployYoYieldSourceOracle.Contract.Configuration(&_DeployYoYieldSourceOracle.CallOpts)
}

// Configuration is a free data retrieval call binding the contract method 0x6c70bee9.
//
// Solidity: function configuration() view returns(address treasury, address dethFoundation)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCallerSession) Configuration() (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	return _DeployYoYieldSourceOracle.Contract.Configuration(&_DeployYoYieldSourceOracle.CallOpts)
}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCaller) ContractAddresses(opts *bind.CallOpts, chainId uint64, contractName string) (common.Address, error) {
	var out []interface{}
	err := _DeployYoYieldSourceOracle.contract.Call(opts, &out, "contractAddresses", chainId, contractName)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleSession) ContractAddresses(chainId uint64, contractName string) (common.Address, error) {
	return _DeployYoYieldSourceOracle.Contract.ContractAddresses(&_DeployYoYieldSourceOracle.CallOpts, chainId, contractName)
}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleCallerSession) ContractAddresses(chainId uint64, contractName string) (common.Address, error) {
	return _DeployYoYieldSourceOracle.Contract.ContractAddresses(&_DeployYoYieldSourceOracle.CallOpts, chainId, contractName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactor) Run(opts *bind.TransactOpts, env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.contract.Transact(opts, "run", env, chainId, branchName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleSession) Run(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.Run(&_DeployYoYieldSourceOracle.TransactOpts, env, chainId, branchName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactorSession) Run(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.Run(&_DeployYoYieldSourceOracle.TransactOpts, env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactor) RunCheck(opts *bind.TransactOpts, env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.contract.Transact(opts, "runCheck", env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleSession) RunCheck(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.RunCheck(&_DeployYoYieldSourceOracle.TransactOpts, env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactorSession) RunCheck(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.RunCheck(&_DeployYoYieldSourceOracle.TransactOpts, env, chainId, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactor) RunMultiChain(opts *bind.TransactOpts, env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.contract.Transact(opts, "runMultiChain", env, chainIds, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleSession) RunMultiChain(env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.RunMultiChain(&_DeployYoYieldSourceOracle.TransactOpts, env, chainIds, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployYoYieldSourceOracle *DeployYoYieldSourceOracleTransactorSession) RunMultiChain(env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployYoYieldSourceOracle.Contract.RunMultiChain(&_DeployYoYieldSourceOracle.TransactOpts, env, chainIds, branchName)
}
