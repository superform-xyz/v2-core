// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package DeployPendlePTAmortizedOracle

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

// DeployPendlePTAmortizedOracleMetaData contains all meta data concerning the DeployPendlePTAmortizedOracle contract.
var DeployPendlePTAmortizedOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"DEBRIDGE_CANCEL_ORDER_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"IS_SCRIPT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"configuration\",\"inputs\":[],\"outputs\":[{\"name\":\"treasury\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dethFoundation\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"contractAddresses\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"contractName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"run\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"runCheck\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"runMultiChain\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainIds\",\"type\":\"uint64[]\",\"internalType\":\"uint64[]\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"DeployFailed\",\"inputs\":[]}]",
}

// DeployPendlePTAmortizedOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use DeployPendlePTAmortizedOracleMetaData.ABI instead.
var DeployPendlePTAmortizedOracleABI = DeployPendlePTAmortizedOracleMetaData.ABI

// DeployPendlePTAmortizedOracle is an auto generated Go binding around an Ethereum contract.
type DeployPendlePTAmortizedOracle struct {
	DeployPendlePTAmortizedOracleCaller     // Read-only binding to the contract
	DeployPendlePTAmortizedOracleTransactor // Write-only binding to the contract
	DeployPendlePTAmortizedOracleFilterer   // Log filterer for contract events
}

// DeployPendlePTAmortizedOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type DeployPendlePTAmortizedOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployPendlePTAmortizedOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type DeployPendlePTAmortizedOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployPendlePTAmortizedOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type DeployPendlePTAmortizedOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployPendlePTAmortizedOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type DeployPendlePTAmortizedOracleSession struct {
	Contract     *DeployPendlePTAmortizedOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                  // Call options to use throughout this session
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// DeployPendlePTAmortizedOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type DeployPendlePTAmortizedOracleCallerSession struct {
	Contract *DeployPendlePTAmortizedOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                        // Call options to use throughout this session
}

// DeployPendlePTAmortizedOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type DeployPendlePTAmortizedOracleTransactorSession struct {
	Contract     *DeployPendlePTAmortizedOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                        // Transaction auth options to use throughout this session
}

// DeployPendlePTAmortizedOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type DeployPendlePTAmortizedOracleRaw struct {
	Contract *DeployPendlePTAmortizedOracle // Generic contract binding to access the raw methods on
}

// DeployPendlePTAmortizedOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type DeployPendlePTAmortizedOracleCallerRaw struct {
	Contract *DeployPendlePTAmortizedOracleCaller // Generic read-only contract binding to access the raw methods on
}

// DeployPendlePTAmortizedOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type DeployPendlePTAmortizedOracleTransactorRaw struct {
	Contract *DeployPendlePTAmortizedOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewDeployPendlePTAmortizedOracle creates a new instance of DeployPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewDeployPendlePTAmortizedOracle(address common.Address, backend bind.ContractBackend) (*DeployPendlePTAmortizedOracle, error) {
	contract, err := bindDeployPendlePTAmortizedOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &DeployPendlePTAmortizedOracle{DeployPendlePTAmortizedOracleCaller: DeployPendlePTAmortizedOracleCaller{contract: contract}, DeployPendlePTAmortizedOracleTransactor: DeployPendlePTAmortizedOracleTransactor{contract: contract}, DeployPendlePTAmortizedOracleFilterer: DeployPendlePTAmortizedOracleFilterer{contract: contract}}, nil
}

// NewDeployPendlePTAmortizedOracleCaller creates a new read-only instance of DeployPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewDeployPendlePTAmortizedOracleCaller(address common.Address, caller bind.ContractCaller) (*DeployPendlePTAmortizedOracleCaller, error) {
	contract, err := bindDeployPendlePTAmortizedOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &DeployPendlePTAmortizedOracleCaller{contract: contract}, nil
}

// NewDeployPendlePTAmortizedOracleTransactor creates a new write-only instance of DeployPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewDeployPendlePTAmortizedOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*DeployPendlePTAmortizedOracleTransactor, error) {
	contract, err := bindDeployPendlePTAmortizedOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &DeployPendlePTAmortizedOracleTransactor{contract: contract}, nil
}

// NewDeployPendlePTAmortizedOracleFilterer creates a new log filterer instance of DeployPendlePTAmortizedOracle, bound to a specific deployed contract.
func NewDeployPendlePTAmortizedOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*DeployPendlePTAmortizedOracleFilterer, error) {
	contract, err := bindDeployPendlePTAmortizedOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &DeployPendlePTAmortizedOracleFilterer{contract: contract}, nil
}

// bindDeployPendlePTAmortizedOracle binds a generic wrapper to an already deployed contract.
func bindDeployPendlePTAmortizedOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := DeployPendlePTAmortizedOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DeployPendlePTAmortizedOracle.Contract.DeployPendlePTAmortizedOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.DeployPendlePTAmortizedOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.DeployPendlePTAmortizedOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DeployPendlePTAmortizedOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.contract.Transact(opts, method, params...)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCaller) DEBRIDGECANCELORDERHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _DeployPendlePTAmortizedOracle.contract.Call(opts, &out, "DEBRIDGE_CANCEL_ORDER_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _DeployPendlePTAmortizedOracle.Contract.DEBRIDGECANCELORDERHOOKKEY(&_DeployPendlePTAmortizedOracle.CallOpts)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCallerSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _DeployPendlePTAmortizedOracle.Contract.DEBRIDGECANCELORDERHOOKKEY(&_DeployPendlePTAmortizedOracle.CallOpts)
}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCaller) ISSCRIPT(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _DeployPendlePTAmortizedOracle.contract.Call(opts, &out, "IS_SCRIPT")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleSession) ISSCRIPT() (bool, error) {
	return _DeployPendlePTAmortizedOracle.Contract.ISSCRIPT(&_DeployPendlePTAmortizedOracle.CallOpts)
}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCallerSession) ISSCRIPT() (bool, error) {
	return _DeployPendlePTAmortizedOracle.Contract.ISSCRIPT(&_DeployPendlePTAmortizedOracle.CallOpts)
}

// Configuration is a free data retrieval call binding the contract method 0x6c70bee9.
//
// Solidity: function configuration() view returns(address treasury, address dethFoundation)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCaller) Configuration(opts *bind.CallOpts) (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	var out []interface{}
	err := _DeployPendlePTAmortizedOracle.contract.Call(opts, &out, "configuration")

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
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleSession) Configuration() (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	return _DeployPendlePTAmortizedOracle.Contract.Configuration(&_DeployPendlePTAmortizedOracle.CallOpts)
}

// Configuration is a free data retrieval call binding the contract method 0x6c70bee9.
//
// Solidity: function configuration() view returns(address treasury, address dethFoundation)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCallerSession) Configuration() (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	return _DeployPendlePTAmortizedOracle.Contract.Configuration(&_DeployPendlePTAmortizedOracle.CallOpts)
}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCaller) ContractAddresses(opts *bind.CallOpts, chainId uint64, contractName string) (common.Address, error) {
	var out []interface{}
	err := _DeployPendlePTAmortizedOracle.contract.Call(opts, &out, "contractAddresses", chainId, contractName)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleSession) ContractAddresses(chainId uint64, contractName string) (common.Address, error) {
	return _DeployPendlePTAmortizedOracle.Contract.ContractAddresses(&_DeployPendlePTAmortizedOracle.CallOpts, chainId, contractName)
}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleCallerSession) ContractAddresses(chainId uint64, contractName string) (common.Address, error) {
	return _DeployPendlePTAmortizedOracle.Contract.ContractAddresses(&_DeployPendlePTAmortizedOracle.CallOpts, chainId, contractName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactor) Run(opts *bind.TransactOpts, env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.contract.Transact(opts, "run", env, chainId, branchName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleSession) Run(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.Run(&_DeployPendlePTAmortizedOracle.TransactOpts, env, chainId, branchName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactorSession) Run(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.Run(&_DeployPendlePTAmortizedOracle.TransactOpts, env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactor) RunCheck(opts *bind.TransactOpts, env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.contract.Transact(opts, "runCheck", env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleSession) RunCheck(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.RunCheck(&_DeployPendlePTAmortizedOracle.TransactOpts, env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactorSession) RunCheck(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.RunCheck(&_DeployPendlePTAmortizedOracle.TransactOpts, env, chainId, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactor) RunMultiChain(opts *bind.TransactOpts, env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.contract.Transact(opts, "runMultiChain", env, chainIds, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleSession) RunMultiChain(env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.RunMultiChain(&_DeployPendlePTAmortizedOracle.TransactOpts, env, chainIds, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployPendlePTAmortizedOracle *DeployPendlePTAmortizedOracleTransactorSession) RunMultiChain(env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployPendlePTAmortizedOracle.Contract.RunMultiChain(&_DeployPendlePTAmortizedOracle.TransactOpts, env, chainIds, branchName)
}
