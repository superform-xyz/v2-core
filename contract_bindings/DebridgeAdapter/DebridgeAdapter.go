// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package DebridgeAdapter

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

// DebridgeAdapterMetaData contains all meta data concerning the DebridgeAdapter contract.
var DebridgeAdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"dlnDestination\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"DLN_DESTINATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onERC20Received\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_transferredAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_payload\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"callSucceeded\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"callResult\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onEtherReceived\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_payload\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"callSucceeded\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"callResult\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"payable\"},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ONLY_EXTERNAL_CALL_ADAPTER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ON_ETHER_RECEIVED_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// DebridgeAdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use DebridgeAdapterMetaData.ABI instead.
var DebridgeAdapterABI = DebridgeAdapterMetaData.ABI

// DebridgeAdapter is an auto generated Go binding around an Ethereum contract.
type DebridgeAdapter struct {
	DebridgeAdapterCaller     // Read-only binding to the contract
	DebridgeAdapterTransactor // Write-only binding to the contract
	DebridgeAdapterFilterer   // Log filterer for contract events
}

// DebridgeAdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type DebridgeAdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DebridgeAdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type DebridgeAdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DebridgeAdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type DebridgeAdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DebridgeAdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type DebridgeAdapterSession struct {
	Contract     *DebridgeAdapter  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// DebridgeAdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type DebridgeAdapterCallerSession struct {
	Contract *DebridgeAdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// DebridgeAdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type DebridgeAdapterTransactorSession struct {
	Contract     *DebridgeAdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// DebridgeAdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type DebridgeAdapterRaw struct {
	Contract *DebridgeAdapter // Generic contract binding to access the raw methods on
}

// DebridgeAdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type DebridgeAdapterCallerRaw struct {
	Contract *DebridgeAdapterCaller // Generic read-only contract binding to access the raw methods on
}

// DebridgeAdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type DebridgeAdapterTransactorRaw struct {
	Contract *DebridgeAdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewDebridgeAdapter creates a new instance of DebridgeAdapter, bound to a specific deployed contract.
func NewDebridgeAdapter(address common.Address, backend bind.ContractBackend) (*DebridgeAdapter, error) {
	contract, err := bindDebridgeAdapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &DebridgeAdapter{DebridgeAdapterCaller: DebridgeAdapterCaller{contract: contract}, DebridgeAdapterTransactor: DebridgeAdapterTransactor{contract: contract}, DebridgeAdapterFilterer: DebridgeAdapterFilterer{contract: contract}}, nil
}

// NewDebridgeAdapterCaller creates a new read-only instance of DebridgeAdapter, bound to a specific deployed contract.
func NewDebridgeAdapterCaller(address common.Address, caller bind.ContractCaller) (*DebridgeAdapterCaller, error) {
	contract, err := bindDebridgeAdapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &DebridgeAdapterCaller{contract: contract}, nil
}

// NewDebridgeAdapterTransactor creates a new write-only instance of DebridgeAdapter, bound to a specific deployed contract.
func NewDebridgeAdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*DebridgeAdapterTransactor, error) {
	contract, err := bindDebridgeAdapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &DebridgeAdapterTransactor{contract: contract}, nil
}

// NewDebridgeAdapterFilterer creates a new log filterer instance of DebridgeAdapter, bound to a specific deployed contract.
func NewDebridgeAdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*DebridgeAdapterFilterer, error) {
	contract, err := bindDebridgeAdapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &DebridgeAdapterFilterer{contract: contract}, nil
}

// bindDebridgeAdapter binds a generic wrapper to an already deployed contract.
func bindDebridgeAdapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := DebridgeAdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DebridgeAdapter *DebridgeAdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DebridgeAdapter.Contract.DebridgeAdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DebridgeAdapter *DebridgeAdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.DebridgeAdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DebridgeAdapter *DebridgeAdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.DebridgeAdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DebridgeAdapter *DebridgeAdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DebridgeAdapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DebridgeAdapter *DebridgeAdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DebridgeAdapter *DebridgeAdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.contract.Transact(opts, method, params...)
}

// DLNDESTINATION is a free data retrieval call binding the contract method 0xb17081d7.
//
// Solidity: function DLN_DESTINATION() view returns(address)
func (_DebridgeAdapter *DebridgeAdapterCaller) DLNDESTINATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _DebridgeAdapter.contract.Call(opts, &out, "DLN_DESTINATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// DLNDESTINATION is a free data retrieval call binding the contract method 0xb17081d7.
//
// Solidity: function DLN_DESTINATION() view returns(address)
func (_DebridgeAdapter *DebridgeAdapterSession) DLNDESTINATION() (common.Address, error) {
	return _DebridgeAdapter.Contract.DLNDESTINATION(&_DebridgeAdapter.CallOpts)
}

// DLNDESTINATION is a free data retrieval call binding the contract method 0xb17081d7.
//
// Solidity: function DLN_DESTINATION() view returns(address)
func (_DebridgeAdapter *DebridgeAdapterCallerSession) DLNDESTINATION() (common.Address, error) {
	return _DebridgeAdapter.Contract.DLNDESTINATION(&_DebridgeAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_DebridgeAdapter *DebridgeAdapterCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _DebridgeAdapter.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_DebridgeAdapter *DebridgeAdapterSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _DebridgeAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_DebridgeAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_DebridgeAdapter *DebridgeAdapterCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _DebridgeAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_DebridgeAdapter.CallOpts)
}

// OnERC20Received is a paid mutator transaction binding the contract method 0x7cbf7a55.
//
// Solidity: function onERC20Received(bytes32 , address _token, uint256 _transferredAmount, address , bytes _payload) returns(bool callSucceeded, bytes callResult)
func (_DebridgeAdapter *DebridgeAdapterTransactor) OnERC20Received(opts *bind.TransactOpts, arg0 [32]byte, _token common.Address, _transferredAmount *big.Int, arg3 common.Address, _payload []byte) (*types.Transaction, error) {
	return _DebridgeAdapter.contract.Transact(opts, "onERC20Received", arg0, _token, _transferredAmount, arg3, _payload)
}

// OnERC20Received is a paid mutator transaction binding the contract method 0x7cbf7a55.
//
// Solidity: function onERC20Received(bytes32 , address _token, uint256 _transferredAmount, address , bytes _payload) returns(bool callSucceeded, bytes callResult)
func (_DebridgeAdapter *DebridgeAdapterSession) OnERC20Received(arg0 [32]byte, _token common.Address, _transferredAmount *big.Int, arg3 common.Address, _payload []byte) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.OnERC20Received(&_DebridgeAdapter.TransactOpts, arg0, _token, _transferredAmount, arg3, _payload)
}

// OnERC20Received is a paid mutator transaction binding the contract method 0x7cbf7a55.
//
// Solidity: function onERC20Received(bytes32 , address _token, uint256 _transferredAmount, address , bytes _payload) returns(bool callSucceeded, bytes callResult)
func (_DebridgeAdapter *DebridgeAdapterTransactorSession) OnERC20Received(arg0 [32]byte, _token common.Address, _transferredAmount *big.Int, arg3 common.Address, _payload []byte) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.OnERC20Received(&_DebridgeAdapter.TransactOpts, arg0, _token, _transferredAmount, arg3, _payload)
}

// OnEtherReceived is a paid mutator transaction binding the contract method 0x3d266812.
//
// Solidity: function onEtherReceived(bytes32 , address , bytes _payload) payable returns(bool callSucceeded, bytes callResult)
func (_DebridgeAdapter *DebridgeAdapterTransactor) OnEtherReceived(opts *bind.TransactOpts, arg0 [32]byte, arg1 common.Address, _payload []byte) (*types.Transaction, error) {
	return _DebridgeAdapter.contract.Transact(opts, "onEtherReceived", arg0, arg1, _payload)
}

// OnEtherReceived is a paid mutator transaction binding the contract method 0x3d266812.
//
// Solidity: function onEtherReceived(bytes32 , address , bytes _payload) payable returns(bool callSucceeded, bytes callResult)
func (_DebridgeAdapter *DebridgeAdapterSession) OnEtherReceived(arg0 [32]byte, arg1 common.Address, _payload []byte) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.OnEtherReceived(&_DebridgeAdapter.TransactOpts, arg0, arg1, _payload)
}

// OnEtherReceived is a paid mutator transaction binding the contract method 0x3d266812.
//
// Solidity: function onEtherReceived(bytes32 , address , bytes _payload) payable returns(bool callSucceeded, bytes callResult)
func (_DebridgeAdapter *DebridgeAdapterTransactorSession) OnEtherReceived(arg0 [32]byte, arg1 common.Address, _payload []byte) (*types.Transaction, error) {
	return _DebridgeAdapter.Contract.OnEtherReceived(&_DebridgeAdapter.TransactOpts, arg0, arg1, _payload)
}
