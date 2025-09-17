// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperDestinationExecutorSimulations

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

// Execution is an auto generated low-level Go binding around an user-defined struct.
type Execution struct {
	Target   common.Address
	Value    *big.Int
	CallData []byte
}

// SuperDestinationExecutorSimulationsMetaData contains all meta data concerning the SuperDestinationExecutorSimulations contract.
var SuperDestinationExecutorSimulationsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"ledgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationValidator_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isMerkleRootUsed\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"ledgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"markRootsAsUsed\",\"inputs\":[{\"name\":\"roots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"processBridgedExecution\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dstTokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"intentAmounts\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"initData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"executorCalldata\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"userSignatureData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"usedMerkleRoots\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"used\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"validateHookCompliance\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hookData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"event\",\"name\":\"AccountCreated\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorInvalidIntentAmount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"intentAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorMarkRootsAsUsed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"roots\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButNoHooks\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"intentAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"available\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButRootUsedAlready\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperPositionMintRequested\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"dstChainId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_CREATED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FEE_NOT_TRANSFERRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE_FOR_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CALLER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SIGNATURE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_YIELD_SOURCE_ORACLE_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MALICIOUS_HOOK_DETECTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MERKLE_ROOT_ALREADY_USED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_HOOKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SENDER_CREATOR_NOT_VALID\",\"inputs\":[]}]",
}

// SuperDestinationExecutorSimulationsABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperDestinationExecutorSimulationsMetaData.ABI instead.
var SuperDestinationExecutorSimulationsABI = SuperDestinationExecutorSimulationsMetaData.ABI

// SuperDestinationExecutorSimulations is an auto generated Go binding around an Ethereum contract.
type SuperDestinationExecutorSimulations struct {
	SuperDestinationExecutorSimulationsCaller     // Read-only binding to the contract
	SuperDestinationExecutorSimulationsTransactor // Write-only binding to the contract
	SuperDestinationExecutorSimulationsFilterer   // Log filterer for contract events
}

// SuperDestinationExecutorSimulationsCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperDestinationExecutorSimulationsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationExecutorSimulationsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperDestinationExecutorSimulationsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationExecutorSimulationsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperDestinationExecutorSimulationsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationExecutorSimulationsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperDestinationExecutorSimulationsSession struct {
	Contract     *SuperDestinationExecutorSimulations // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                        // Call options to use throughout this session
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// SuperDestinationExecutorSimulationsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperDestinationExecutorSimulationsCallerSession struct {
	Contract *SuperDestinationExecutorSimulationsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                              // Call options to use throughout this session
}

// SuperDestinationExecutorSimulationsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperDestinationExecutorSimulationsTransactorSession struct {
	Contract     *SuperDestinationExecutorSimulationsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                              // Transaction auth options to use throughout this session
}

// SuperDestinationExecutorSimulationsRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperDestinationExecutorSimulationsRaw struct {
	Contract *SuperDestinationExecutorSimulations // Generic contract binding to access the raw methods on
}

// SuperDestinationExecutorSimulationsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperDestinationExecutorSimulationsCallerRaw struct {
	Contract *SuperDestinationExecutorSimulationsCaller // Generic read-only contract binding to access the raw methods on
}

// SuperDestinationExecutorSimulationsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperDestinationExecutorSimulationsTransactorRaw struct {
	Contract *SuperDestinationExecutorSimulationsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperDestinationExecutorSimulations creates a new instance of SuperDestinationExecutorSimulations, bound to a specific deployed contract.
func NewSuperDestinationExecutorSimulations(address common.Address, backend bind.ContractBackend) (*SuperDestinationExecutorSimulations, error) {
	contract, err := bindSuperDestinationExecutorSimulations(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulations{SuperDestinationExecutorSimulationsCaller: SuperDestinationExecutorSimulationsCaller{contract: contract}, SuperDestinationExecutorSimulationsTransactor: SuperDestinationExecutorSimulationsTransactor{contract: contract}, SuperDestinationExecutorSimulationsFilterer: SuperDestinationExecutorSimulationsFilterer{contract: contract}}, nil
}

// NewSuperDestinationExecutorSimulationsCaller creates a new read-only instance of SuperDestinationExecutorSimulations, bound to a specific deployed contract.
func NewSuperDestinationExecutorSimulationsCaller(address common.Address, caller bind.ContractCaller) (*SuperDestinationExecutorSimulationsCaller, error) {
	contract, err := bindSuperDestinationExecutorSimulations(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsCaller{contract: contract}, nil
}

// NewSuperDestinationExecutorSimulationsTransactor creates a new write-only instance of SuperDestinationExecutorSimulations, bound to a specific deployed contract.
func NewSuperDestinationExecutorSimulationsTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperDestinationExecutorSimulationsTransactor, error) {
	contract, err := bindSuperDestinationExecutorSimulations(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsTransactor{contract: contract}, nil
}

// NewSuperDestinationExecutorSimulationsFilterer creates a new log filterer instance of SuperDestinationExecutorSimulations, bound to a specific deployed contract.
func NewSuperDestinationExecutorSimulationsFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperDestinationExecutorSimulationsFilterer, error) {
	contract, err := bindSuperDestinationExecutorSimulations(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsFilterer{contract: contract}, nil
}

// bindSuperDestinationExecutorSimulations binds a generic wrapper to an already deployed contract.
func bindSuperDestinationExecutorSimulations(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperDestinationExecutorSimulationsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDestinationExecutorSimulations.Contract.SuperDestinationExecutorSimulationsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.SuperDestinationExecutorSimulationsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.SuperDestinationExecutorSimulationsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDestinationExecutorSimulations.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.contract.Transact(opts, method, params...)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) SUPERDESTINATIONVALIDATOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _SuperDestinationExecutorSimulations.Contract.SUPERDESTINATIONVALIDATOR(&_SuperDestinationExecutorSimulations.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _SuperDestinationExecutorSimulations.Contract.SUPERDESTINATIONVALIDATOR(&_SuperDestinationExecutorSimulations.CallOpts)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.IsInitialized(&_SuperDestinationExecutorSimulations.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.IsInitialized(&_SuperDestinationExecutorSimulations.CallOpts, account)
}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) IsMerkleRootUsed(opts *bind.CallOpts, user common.Address, merkleRoot [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "isMerkleRootUsed", user, merkleRoot)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) IsMerkleRootUsed(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.IsMerkleRootUsed(&_SuperDestinationExecutorSimulations.CallOpts, user, merkleRoot)
}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) IsMerkleRootUsed(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.IsMerkleRootUsed(&_SuperDestinationExecutorSimulations.CallOpts, user, merkleRoot)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) IsModuleType(opts *bind.CallOpts, typeId *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "isModuleType", typeId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.IsModuleType(&_SuperDestinationExecutorSimulations.CallOpts, typeId)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.IsModuleType(&_SuperDestinationExecutorSimulations.CallOpts, typeId)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) LedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "ledgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) LedgerConfiguration() (common.Address, error) {
	return _SuperDestinationExecutorSimulations.Contract.LedgerConfiguration(&_SuperDestinationExecutorSimulations.CallOpts)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) LedgerConfiguration() (common.Address, error) {
	return _SuperDestinationExecutorSimulations.Contract.LedgerConfiguration(&_SuperDestinationExecutorSimulations.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) Name() (string, error) {
	return _SuperDestinationExecutorSimulations.Contract.Name(&_SuperDestinationExecutorSimulations.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) Name() (string, error) {
	return _SuperDestinationExecutorSimulations.Contract.Name(&_SuperDestinationExecutorSimulations.CallOpts)
}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) UsedMerkleRoots(opts *bind.CallOpts, user common.Address, merkleRoot [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "usedMerkleRoots", user, merkleRoot)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) UsedMerkleRoots(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.UsedMerkleRoots(&_SuperDestinationExecutorSimulations.CallOpts, user, merkleRoot)
}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) UsedMerkleRoots(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutorSimulations.Contract.UsedMerkleRoots(&_SuperDestinationExecutorSimulations.CallOpts, user, merkleRoot)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) ValidateHookCompliance(opts *bind.CallOpts, hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "validateHookCompliance", hook, prevHook, account, hookData)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperDestinationExecutorSimulations.Contract.ValidateHookCompliance(&_SuperDestinationExecutorSimulations.CallOpts, hook, prevHook, account, hookData)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperDestinationExecutorSimulations.Contract.ValidateHookCompliance(&_SuperDestinationExecutorSimulations.CallOpts, hook, prevHook, account, hookData)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperDestinationExecutorSimulations.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) Version() (string, error) {
	return _SuperDestinationExecutorSimulations.Contract.Version(&_SuperDestinationExecutorSimulations.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsCallerSession) Version() (string, error) {
	return _SuperDestinationExecutorSimulations.Contract.Version(&_SuperDestinationExecutorSimulations.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.Execute(&_SuperDestinationExecutorSimulations.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.Execute(&_SuperDestinationExecutorSimulations.TransactOpts, data)
}

// MarkRootsAsUsed is a paid mutator transaction binding the contract method 0xa5c08d3d.
//
// Solidity: function markRootsAsUsed(bytes32[] roots) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactor) MarkRootsAsUsed(opts *bind.TransactOpts, roots [][32]byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.contract.Transact(opts, "markRootsAsUsed", roots)
}

// MarkRootsAsUsed is a paid mutator transaction binding the contract method 0xa5c08d3d.
//
// Solidity: function markRootsAsUsed(bytes32[] roots) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) MarkRootsAsUsed(roots [][32]byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.MarkRootsAsUsed(&_SuperDestinationExecutorSimulations.TransactOpts, roots)
}

// MarkRootsAsUsed is a paid mutator transaction binding the contract method 0xa5c08d3d.
//
// Solidity: function markRootsAsUsed(bytes32[] roots) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactorSession) MarkRootsAsUsed(roots [][32]byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.MarkRootsAsUsed(&_SuperDestinationExecutorSimulations.TransactOpts, roots)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.OnInstall(&_SuperDestinationExecutorSimulations.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.OnInstall(&_SuperDestinationExecutorSimulations.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.OnUninstall(&_SuperDestinationExecutorSimulations.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.OnUninstall(&_SuperDestinationExecutorSimulations.TransactOpts, arg0)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address account, address[] dstTokens, uint256[] intentAmounts, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactor) ProcessBridgedExecution(opts *bind.TransactOpts, arg0 common.Address, account common.Address, dstTokens []common.Address, intentAmounts []*big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.contract.Transact(opts, "processBridgedExecution", arg0, account, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address account, address[] dstTokens, uint256[] intentAmounts, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsSession) ProcessBridgedExecution(arg0 common.Address, account common.Address, dstTokens []common.Address, intentAmounts []*big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.ProcessBridgedExecution(&_SuperDestinationExecutorSimulations.TransactOpts, arg0, account, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address account, address[] dstTokens, uint256[] intentAmounts, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsTransactorSession) ProcessBridgedExecution(arg0 common.Address, account common.Address, dstTokens []common.Address, intentAmounts []*big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutorSimulations.Contract.ProcessBridgedExecution(&_SuperDestinationExecutorSimulations.TransactOpts, arg0, account, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData)
}

// SuperDestinationExecutorSimulationsAccountCreatedIterator is returned from FilterAccountCreated and is used to iterate over the raw logs and unpacked data for AccountCreated events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsAccountCreatedIterator struct {
	Event *SuperDestinationExecutorSimulationsAccountCreated // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsAccountCreatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsAccountCreated)
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
		it.Event = new(SuperDestinationExecutorSimulationsAccountCreated)
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
func (it *SuperDestinationExecutorSimulationsAccountCreatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsAccountCreatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsAccountCreated represents a AccountCreated event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsAccountCreated struct {
	Account common.Address
	Salt    [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountCreated is a free log retrieval operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterAccountCreated(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSimulationsAccountCreatedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "AccountCreated", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsAccountCreatedIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "AccountCreated", logs: logs, sub: sub}, nil
}

// WatchAccountCreated is a free log subscription operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchAccountCreated(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsAccountCreated, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "AccountCreated", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsAccountCreated)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "AccountCreated", log); err != nil {
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

// ParseAccountCreated is a log parse operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseAccountCreated(log types.Log) (*SuperDestinationExecutorSimulationsAccountCreated, error) {
	event := new(SuperDestinationExecutorSimulationsAccountCreated)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "AccountCreated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorExecutedIterator is returned from FilterSuperDestinationExecutorExecuted and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorExecuted events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorExecutedIterator struct {
	Event *SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted)
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
		it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted)
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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted represents a SuperDestinationExecutorExecuted event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorExecuted is a free log retrieval operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterSuperDestinationExecutorExecuted(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "SuperDestinationExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsSuperDestinationExecutorExecutedIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "SuperDestinationExecutorExecuted", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorExecuted is a free log subscription operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchSuperDestinationExecutorExecuted(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "SuperDestinationExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorExecuted", log); err != nil {
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

// ParseSuperDestinationExecutorExecuted is a log parse operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseSuperDestinationExecutorExecuted(log types.Log) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted, error) {
	event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorExecuted)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmountIterator is returned from FilterSuperDestinationExecutorInvalidIntentAmount and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorInvalidIntentAmount events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmountIterator struct {
	Event *SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmountIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount)
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
		it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount)
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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmountIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmountIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount represents a SuperDestinationExecutorInvalidIntentAmount event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount struct {
	Account      common.Address
	Token        common.Address
	IntentAmount *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorInvalidIntentAmount is a free log retrieval operation binding the contract event 0xfe3e30b591c8199a91f575b16b49e2d2b7d947c4e1490f570b41f1aa448decb8.
//
// Solidity: event SuperDestinationExecutorInvalidIntentAmount(address indexed account, address indexed token, uint256 intentAmount)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterSuperDestinationExecutorInvalidIntentAmount(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmountIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "SuperDestinationExecutorInvalidIntentAmount", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmountIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "SuperDestinationExecutorInvalidIntentAmount", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorInvalidIntentAmount is a free log subscription operation binding the contract event 0xfe3e30b591c8199a91f575b16b49e2d2b7d947c4e1490f570b41f1aa448decb8.
//
// Solidity: event SuperDestinationExecutorInvalidIntentAmount(address indexed account, address indexed token, uint256 intentAmount)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchSuperDestinationExecutorInvalidIntentAmount(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "SuperDestinationExecutorInvalidIntentAmount", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorInvalidIntentAmount", log); err != nil {
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

// ParseSuperDestinationExecutorInvalidIntentAmount is a log parse operation binding the contract event 0xfe3e30b591c8199a91f575b16b49e2d2b7d947c4e1490f570b41f1aa448decb8.
//
// Solidity: event SuperDestinationExecutorInvalidIntentAmount(address indexed account, address indexed token, uint256 intentAmount)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseSuperDestinationExecutorInvalidIntentAmount(log types.Log) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount, error) {
	event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorInvalidIntentAmount)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorInvalidIntentAmount", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsedIterator is returned from FilterSuperDestinationExecutorMarkRootsAsUsed and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorMarkRootsAsUsed events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsedIterator struct {
	Event *SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed)
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
		it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed)
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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed represents a SuperDestinationExecutorMarkRootsAsUsed event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed struct {
	Account common.Address
	Roots   [][32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorMarkRootsAsUsed is a free log retrieval operation binding the contract event 0x2a2e76694cfe1777579407d33b992a385876cdac566ec14689232edd2425d40e.
//
// Solidity: event SuperDestinationExecutorMarkRootsAsUsed(address indexed account, bytes32[] roots)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterSuperDestinationExecutorMarkRootsAsUsed(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "SuperDestinationExecutorMarkRootsAsUsed", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsedIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "SuperDestinationExecutorMarkRootsAsUsed", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorMarkRootsAsUsed is a free log subscription operation binding the contract event 0x2a2e76694cfe1777579407d33b992a385876cdac566ec14689232edd2425d40e.
//
// Solidity: event SuperDestinationExecutorMarkRootsAsUsed(address indexed account, bytes32[] roots)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchSuperDestinationExecutorMarkRootsAsUsed(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "SuperDestinationExecutorMarkRootsAsUsed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorMarkRootsAsUsed", log); err != nil {
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

// ParseSuperDestinationExecutorMarkRootsAsUsed is a log parse operation binding the contract event 0x2a2e76694cfe1777579407d33b992a385876cdac566ec14689232edd2425d40e.
//
// Solidity: event SuperDestinationExecutorMarkRootsAsUsed(address indexed account, bytes32[] roots)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseSuperDestinationExecutorMarkRootsAsUsed(log types.Log) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed, error) {
	event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorMarkRootsAsUsed)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorMarkRootsAsUsed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooksIterator is returned from FilterSuperDestinationExecutorReceivedButNoHooks and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButNoHooks events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooksIterator struct {
	Event *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooksIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks)
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
		it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks)
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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooksIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooksIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks represents a SuperDestinationExecutorReceivedButNoHooks event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButNoHooks is a free log retrieval operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterSuperDestinationExecutorReceivedButNoHooks(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooksIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButNoHooks", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooksIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "SuperDestinationExecutorReceivedButNoHooks", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButNoHooks is a free log subscription operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchSuperDestinationExecutorReceivedButNoHooks(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButNoHooks", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNoHooks", log); err != nil {
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

// ParseSuperDestinationExecutorReceivedButNoHooks is a log parse operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseSuperDestinationExecutorReceivedButNoHooks(log types.Log) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks, error) {
	event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNoHooks)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNoHooks", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalanceIterator is returned from FilterSuperDestinationExecutorReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButNotEnoughBalance events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalanceIterator struct {
	Event *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance)
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
		it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance)
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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance represents a SuperDestinationExecutorReceivedButNotEnoughBalance event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance struct {
	Account      common.Address
	Token        common.Address
	IntentAmount *big.Int
	Available    *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0x2a147d47d8d7c5f6b2c7eebb350802ba5ed6008e8eb811f40b78d2090b329c86.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account, address indexed token, uint256 intentAmount, uint256 available)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterSuperDestinationExecutorReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButNotEnoughBalance", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalanceIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "SuperDestinationExecutorReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0x2a147d47d8d7c5f6b2c7eebb350802ba5ed6008e8eb811f40b78d2090b329c86.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account, address indexed token, uint256 intentAmount, uint256 available)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchSuperDestinationExecutorReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButNotEnoughBalance", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNotEnoughBalance", log); err != nil {
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

// ParseSuperDestinationExecutorReceivedButNotEnoughBalance is a log parse operation binding the contract event 0x2a147d47d8d7c5f6b2c7eebb350802ba5ed6008e8eb811f40b78d2090b329c86.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account, address indexed token, uint256 intentAmount, uint256 available)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseSuperDestinationExecutorReceivedButNotEnoughBalance(log types.Log) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance, error) {
	event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButNotEnoughBalance)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlreadyIterator is returned from FilterSuperDestinationExecutorReceivedButRootUsedAlready and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButRootUsedAlready events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlreadyIterator struct {
	Event *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlreadyIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready)
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
		it.Event = new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready)
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
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlreadyIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlreadyIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready represents a SuperDestinationExecutorReceivedButRootUsedAlready event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready struct {
	Account common.Address
	Root    [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButRootUsedAlready is a free log retrieval operation binding the contract event 0xc85a4c9cf6ceb3da81d38c466e43c8b89a7f2857440772a73d2189d718b57841.
//
// Solidity: event SuperDestinationExecutorReceivedButRootUsedAlready(address indexed account, bytes32 indexed root)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterSuperDestinationExecutorReceivedButRootUsedAlready(opts *bind.FilterOpts, account []common.Address, root [][32]byte) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlreadyIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButRootUsedAlready", accountRule, rootRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlreadyIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "SuperDestinationExecutorReceivedButRootUsedAlready", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButRootUsedAlready is a free log subscription operation binding the contract event 0xc85a4c9cf6ceb3da81d38c466e43c8b89a7f2857440772a73d2189d718b57841.
//
// Solidity: event SuperDestinationExecutorReceivedButRootUsedAlready(address indexed account, bytes32 indexed root)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchSuperDestinationExecutorReceivedButRootUsedAlready(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready, account []common.Address, root [][32]byte) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButRootUsedAlready", accountRule, rootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButRootUsedAlready", log); err != nil {
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

// ParseSuperDestinationExecutorReceivedButRootUsedAlready is a log parse operation binding the contract event 0xc85a4c9cf6ceb3da81d38c466e43c8b89a7f2857440772a73d2189d718b57841.
//
// Solidity: event SuperDestinationExecutorReceivedButRootUsedAlready(address indexed account, bytes32 indexed root)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseSuperDestinationExecutorReceivedButRootUsedAlready(log types.Log) (*SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready, error) {
	event := new(SuperDestinationExecutorSimulationsSuperDestinationExecutorReceivedButRootUsedAlready)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButRootUsedAlready", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSimulationsSuperPositionMintRequestedIterator is returned from FilterSuperPositionMintRequested and is used to iterate over the raw logs and unpacked data for SuperPositionMintRequested events raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperPositionMintRequestedIterator struct {
	Event *SuperDestinationExecutorSimulationsSuperPositionMintRequested // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSimulationsSuperPositionMintRequestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSimulationsSuperPositionMintRequested)
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
		it.Event = new(SuperDestinationExecutorSimulationsSuperPositionMintRequested)
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
func (it *SuperDestinationExecutorSimulationsSuperPositionMintRequestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSimulationsSuperPositionMintRequestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSimulationsSuperPositionMintRequested represents a SuperPositionMintRequested event raised by the SuperDestinationExecutorSimulations contract.
type SuperDestinationExecutorSimulationsSuperPositionMintRequested struct {
	Account    common.Address
	SpToken    common.Address
	Amount     *big.Int
	DstChainId *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionMintRequested is a free log retrieval operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) FilterSuperPositionMintRequested(opts *bind.FilterOpts, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (*SuperDestinationExecutorSimulationsSuperPositionMintRequestedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	var dstChainIdRule []interface{}
	for _, dstChainIdItem := range dstChainId {
		dstChainIdRule = append(dstChainIdRule, dstChainIdItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.FilterLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSimulationsSuperPositionMintRequestedIterator{contract: _SuperDestinationExecutorSimulations.contract, event: "SuperPositionMintRequested", logs: logs, sub: sub}, nil
}

// WatchSuperPositionMintRequested is a free log subscription operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) WatchSuperPositionMintRequested(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSimulationsSuperPositionMintRequested, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	var dstChainIdRule []interface{}
	for _, dstChainIdItem := range dstChainId {
		dstChainIdRule = append(dstChainIdRule, dstChainIdItem)
	}

	logs, sub, err := _SuperDestinationExecutorSimulations.contract.WatchLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSimulationsSuperPositionMintRequested)
				if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
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

// ParseSuperPositionMintRequested is a log parse operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperDestinationExecutorSimulations *SuperDestinationExecutorSimulationsFilterer) ParseSuperPositionMintRequested(log types.Log) (*SuperDestinationExecutorSimulationsSuperPositionMintRequested, error) {
	event := new(SuperDestinationExecutorSimulationsSuperPositionMintRequested)
	if err := _SuperDestinationExecutorSimulations.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
