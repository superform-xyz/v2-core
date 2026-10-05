// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package DeployUniV3CLPOracle

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

// DeployUniV3CLPOracleMetaData contains all meta data concerning the DeployUniV3CLPOracle contract.
var DeployUniV3CLPOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"DEBRIDGE_CANCEL_ORDER_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"IS_SCRIPT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"configuration\",\"inputs\":[],\"outputs\":[{\"name\":\"treasury\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dethFoundation\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"contractAddresses\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"contractName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"run\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"runCheck\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"runMultiChain\",\"inputs\":[{\"name\":\"env\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"chainIds\",\"type\":\"uint64[]\",\"internalType\":\"uint64[]\"},{\"name\":\"branchName\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"DeployFailed\",\"inputs\":[]}]",
}

// DeployUniV3CLPOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use DeployUniV3CLPOracleMetaData.ABI instead.
var DeployUniV3CLPOracleABI = DeployUniV3CLPOracleMetaData.ABI

// DeployUniV3CLPOracle is an auto generated Go binding around an Ethereum contract.
type DeployUniV3CLPOracle struct {
	DeployUniV3CLPOracleCaller     // Read-only binding to the contract
	DeployUniV3CLPOracleTransactor // Write-only binding to the contract
	DeployUniV3CLPOracleFilterer   // Log filterer for contract events
}

// DeployUniV3CLPOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type DeployUniV3CLPOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployUniV3CLPOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type DeployUniV3CLPOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployUniV3CLPOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type DeployUniV3CLPOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DeployUniV3CLPOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type DeployUniV3CLPOracleSession struct {
	Contract     *DeployUniV3CLPOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// DeployUniV3CLPOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type DeployUniV3CLPOracleCallerSession struct {
	Contract *DeployUniV3CLPOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// DeployUniV3CLPOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type DeployUniV3CLPOracleTransactorSession struct {
	Contract     *DeployUniV3CLPOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// DeployUniV3CLPOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type DeployUniV3CLPOracleRaw struct {
	Contract *DeployUniV3CLPOracle // Generic contract binding to access the raw methods on
}

// DeployUniV3CLPOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type DeployUniV3CLPOracleCallerRaw struct {
	Contract *DeployUniV3CLPOracleCaller // Generic read-only contract binding to access the raw methods on
}

// DeployUniV3CLPOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type DeployUniV3CLPOracleTransactorRaw struct {
	Contract *DeployUniV3CLPOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewDeployUniV3CLPOracle creates a new instance of DeployUniV3CLPOracle, bound to a specific deployed contract.
func NewDeployUniV3CLPOracle(address common.Address, backend bind.ContractBackend) (*DeployUniV3CLPOracle, error) {
	contract, err := bindDeployUniV3CLPOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &DeployUniV3CLPOracle{DeployUniV3CLPOracleCaller: DeployUniV3CLPOracleCaller{contract: contract}, DeployUniV3CLPOracleTransactor: DeployUniV3CLPOracleTransactor{contract: contract}, DeployUniV3CLPOracleFilterer: DeployUniV3CLPOracleFilterer{contract: contract}}, nil
}

// NewDeployUniV3CLPOracleCaller creates a new read-only instance of DeployUniV3CLPOracle, bound to a specific deployed contract.
func NewDeployUniV3CLPOracleCaller(address common.Address, caller bind.ContractCaller) (*DeployUniV3CLPOracleCaller, error) {
	contract, err := bindDeployUniV3CLPOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &DeployUniV3CLPOracleCaller{contract: contract}, nil
}

// NewDeployUniV3CLPOracleTransactor creates a new write-only instance of DeployUniV3CLPOracle, bound to a specific deployed contract.
func NewDeployUniV3CLPOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*DeployUniV3CLPOracleTransactor, error) {
	contract, err := bindDeployUniV3CLPOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &DeployUniV3CLPOracleTransactor{contract: contract}, nil
}

// NewDeployUniV3CLPOracleFilterer creates a new log filterer instance of DeployUniV3CLPOracle, bound to a specific deployed contract.
func NewDeployUniV3CLPOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*DeployUniV3CLPOracleFilterer, error) {
	contract, err := bindDeployUniV3CLPOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &DeployUniV3CLPOracleFilterer{contract: contract}, nil
}

// bindDeployUniV3CLPOracle binds a generic wrapper to an already deployed contract.
func bindDeployUniV3CLPOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := DeployUniV3CLPOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DeployUniV3CLPOracle.Contract.DeployUniV3CLPOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.DeployUniV3CLPOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.DeployUniV3CLPOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DeployUniV3CLPOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.contract.Transact(opts, method, params...)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCaller) DEBRIDGECANCELORDERHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _DeployUniV3CLPOracle.contract.Call(opts, &out, "DEBRIDGE_CANCEL_ORDER_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _DeployUniV3CLPOracle.Contract.DEBRIDGECANCELORDERHOOKKEY(&_DeployUniV3CLPOracle.CallOpts)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCallerSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _DeployUniV3CLPOracle.Contract.DEBRIDGECANCELORDERHOOKKEY(&_DeployUniV3CLPOracle.CallOpts)
}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCaller) ISSCRIPT(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _DeployUniV3CLPOracle.contract.Call(opts, &out, "IS_SCRIPT")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleSession) ISSCRIPT() (bool, error) {
	return _DeployUniV3CLPOracle.Contract.ISSCRIPT(&_DeployUniV3CLPOracle.CallOpts)
}

// ISSCRIPT is a free data retrieval call binding the contract method 0xf8ccbf47.
//
// Solidity: function IS_SCRIPT() view returns(bool)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCallerSession) ISSCRIPT() (bool, error) {
	return _DeployUniV3CLPOracle.Contract.ISSCRIPT(&_DeployUniV3CLPOracle.CallOpts)
}

// Configuration is a free data retrieval call binding the contract method 0x6c70bee9.
//
// Solidity: function configuration() view returns(address treasury, address dethFoundation)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCaller) Configuration(opts *bind.CallOpts) (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	var out []interface{}
	err := _DeployUniV3CLPOracle.contract.Call(opts, &out, "configuration")

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
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleSession) Configuration() (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	return _DeployUniV3CLPOracle.Contract.Configuration(&_DeployUniV3CLPOracle.CallOpts)
}

// Configuration is a free data retrieval call binding the contract method 0x6c70bee9.
//
// Solidity: function configuration() view returns(address treasury, address dethFoundation)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCallerSession) Configuration() (struct {
	Treasury       common.Address
	DethFoundation common.Address
}, error) {
	return _DeployUniV3CLPOracle.Contract.Configuration(&_DeployUniV3CLPOracle.CallOpts)
}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCaller) ContractAddresses(opts *bind.CallOpts, chainId uint64, contractName string) (common.Address, error) {
	var out []interface{}
	err := _DeployUniV3CLPOracle.contract.Call(opts, &out, "contractAddresses", chainId, contractName)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleSession) ContractAddresses(chainId uint64, contractName string) (common.Address, error) {
	return _DeployUniV3CLPOracle.Contract.ContractAddresses(&_DeployUniV3CLPOracle.CallOpts, chainId, contractName)
}

// ContractAddresses is a free data retrieval call binding the contract method 0x3dadb2fd.
//
// Solidity: function contractAddresses(uint64 chainId, string contractName) view returns(address contractAddress)
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleCallerSession) ContractAddresses(chainId uint64, contractName string) (common.Address, error) {
	return _DeployUniV3CLPOracle.Contract.ContractAddresses(&_DeployUniV3CLPOracle.CallOpts, chainId, contractName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactor) Run(opts *bind.TransactOpts, env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.contract.Transact(opts, "run", env, chainId, branchName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleSession) Run(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.Run(&_DeployUniV3CLPOracle.TransactOpts, env, chainId, branchName)
}

// Run is a paid mutator transaction binding the contract method 0x3d7b3c7f.
//
// Solidity: function run(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactorSession) Run(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.Run(&_DeployUniV3CLPOracle.TransactOpts, env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactor) RunCheck(opts *bind.TransactOpts, env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.contract.Transact(opts, "runCheck", env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleSession) RunCheck(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.RunCheck(&_DeployUniV3CLPOracle.TransactOpts, env, chainId, branchName)
}

// RunCheck is a paid mutator transaction binding the contract method 0x7b66d706.
//
// Solidity: function runCheck(uint256 env, uint64 chainId, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactorSession) RunCheck(env *big.Int, chainId uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.RunCheck(&_DeployUniV3CLPOracle.TransactOpts, env, chainId, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactor) RunMultiChain(opts *bind.TransactOpts, env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.contract.Transact(opts, "runMultiChain", env, chainIds, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleSession) RunMultiChain(env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.RunMultiChain(&_DeployUniV3CLPOracle.TransactOpts, env, chainIds, branchName)
}

// RunMultiChain is a paid mutator transaction binding the contract method 0x49d80dae.
//
// Solidity: function runMultiChain(uint256 env, uint64[] chainIds, string branchName) returns()
func (_DeployUniV3CLPOracle *DeployUniV3CLPOracleTransactorSession) RunMultiChain(env *big.Int, chainIds []uint64, branchName string) (*types.Transaction, error) {
	return _DeployUniV3CLPOracle.Contract.RunMultiChain(&_DeployUniV3CLPOracle.TransactOpts, env, chainIds, branchName)
}
