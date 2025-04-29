// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperVaultFactory

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

// ISuperVaultFactoryVaultCreationParams is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultFactoryVaultCreationParams struct {
	Asset          common.Address
	Name           string
	Symbol         string
	Manager        common.Address
	Strategist     common.Address
	EmergencyAdmin common.Address
	FeeRecipient   common.Address
	SuperVaultCap  *big.Int
}

// SuperVaultFactoryMetaData contains all meta data concerning the SuperVaultFactory contract.
var SuperVaultFactoryMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"peripheryRegistry_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"createVault\",\"inputs\":[{\"name\":\"params\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultFactory.VaultCreationParams\",\"components\":[{\"name\":\"asset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"manager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"emergencyAdmin\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superVaultCap\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"outputs\":[{\"name\":\"superVault\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"escrow\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"escrowImplementation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"peripheryRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"strategyImplementation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"vaultImplementation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"VaultDeployed\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"escrow\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"asset\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"name\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"BOOTSTRAP_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FailedDeployment\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_NOT_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InsufficientBalance\",\"inputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperVaultFactoryABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperVaultFactoryMetaData.ABI instead.
var SuperVaultFactoryABI = SuperVaultFactoryMetaData.ABI

// SuperVaultFactory is an auto generated Go binding around an Ethereum contract.
type SuperVaultFactory struct {
	SuperVaultFactoryCaller     // Read-only binding to the contract
	SuperVaultFactoryTransactor // Write-only binding to the contract
	SuperVaultFactoryFilterer   // Log filterer for contract events
}

// SuperVaultFactoryCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperVaultFactoryCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultFactoryTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperVaultFactoryTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultFactoryFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperVaultFactoryFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultFactorySession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperVaultFactorySession struct {
	Contract     *SuperVaultFactory // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// SuperVaultFactoryCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperVaultFactoryCallerSession struct {
	Contract *SuperVaultFactoryCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// SuperVaultFactoryTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperVaultFactoryTransactorSession struct {
	Contract     *SuperVaultFactoryTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// SuperVaultFactoryRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperVaultFactoryRaw struct {
	Contract *SuperVaultFactory // Generic contract binding to access the raw methods on
}

// SuperVaultFactoryCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperVaultFactoryCallerRaw struct {
	Contract *SuperVaultFactoryCaller // Generic read-only contract binding to access the raw methods on
}

// SuperVaultFactoryTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperVaultFactoryTransactorRaw struct {
	Contract *SuperVaultFactoryTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperVaultFactory creates a new instance of SuperVaultFactory, bound to a specific deployed contract.
func NewSuperVaultFactory(address common.Address, backend bind.ContractBackend) (*SuperVaultFactory, error) {
	contract, err := bindSuperVaultFactory(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperVaultFactory{SuperVaultFactoryCaller: SuperVaultFactoryCaller{contract: contract}, SuperVaultFactoryTransactor: SuperVaultFactoryTransactor{contract: contract}, SuperVaultFactoryFilterer: SuperVaultFactoryFilterer{contract: contract}}, nil
}

// NewSuperVaultFactoryCaller creates a new read-only instance of SuperVaultFactory, bound to a specific deployed contract.
func NewSuperVaultFactoryCaller(address common.Address, caller bind.ContractCaller) (*SuperVaultFactoryCaller, error) {
	contract, err := bindSuperVaultFactory(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultFactoryCaller{contract: contract}, nil
}

// NewSuperVaultFactoryTransactor creates a new write-only instance of SuperVaultFactory, bound to a specific deployed contract.
func NewSuperVaultFactoryTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperVaultFactoryTransactor, error) {
	contract, err := bindSuperVaultFactory(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultFactoryTransactor{contract: contract}, nil
}

// NewSuperVaultFactoryFilterer creates a new log filterer instance of SuperVaultFactory, bound to a specific deployed contract.
func NewSuperVaultFactoryFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperVaultFactoryFilterer, error) {
	contract, err := bindSuperVaultFactory(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperVaultFactoryFilterer{contract: contract}, nil
}

// bindSuperVaultFactory binds a generic wrapper to an already deployed contract.
func bindSuperVaultFactory(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperVaultFactoryMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultFactory *SuperVaultFactoryRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultFactory.Contract.SuperVaultFactoryCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultFactory *SuperVaultFactoryRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultFactory.Contract.SuperVaultFactoryTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultFactory *SuperVaultFactoryRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultFactory.Contract.SuperVaultFactoryTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultFactory *SuperVaultFactoryCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultFactory.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultFactory *SuperVaultFactoryTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultFactory.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultFactory *SuperVaultFactoryTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultFactory.Contract.contract.Transact(opts, method, params...)
}

// EscrowImplementation is a free data retrieval call binding the contract method 0x4ca8ff5a.
//
// Solidity: function escrowImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCaller) EscrowImplementation(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultFactory.contract.Call(opts, &out, "escrowImplementation")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// EscrowImplementation is a free data retrieval call binding the contract method 0x4ca8ff5a.
//
// Solidity: function escrowImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactorySession) EscrowImplementation() (common.Address, error) {
	return _SuperVaultFactory.Contract.EscrowImplementation(&_SuperVaultFactory.CallOpts)
}

// EscrowImplementation is a free data retrieval call binding the contract method 0x4ca8ff5a.
//
// Solidity: function escrowImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCallerSession) EscrowImplementation() (common.Address, error) {
	return _SuperVaultFactory.Contract.EscrowImplementation(&_SuperVaultFactory.CallOpts)
}

// PeripheryRegistry is a free data retrieval call binding the contract method 0x597c5b5a.
//
// Solidity: function peripheryRegistry() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCaller) PeripheryRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultFactory.contract.Call(opts, &out, "peripheryRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PeripheryRegistry is a free data retrieval call binding the contract method 0x597c5b5a.
//
// Solidity: function peripheryRegistry() view returns(address)
func (_SuperVaultFactory *SuperVaultFactorySession) PeripheryRegistry() (common.Address, error) {
	return _SuperVaultFactory.Contract.PeripheryRegistry(&_SuperVaultFactory.CallOpts)
}

// PeripheryRegistry is a free data retrieval call binding the contract method 0x597c5b5a.
//
// Solidity: function peripheryRegistry() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCallerSession) PeripheryRegistry() (common.Address, error) {
	return _SuperVaultFactory.Contract.PeripheryRegistry(&_SuperVaultFactory.CallOpts)
}

// StrategyImplementation is a free data retrieval call binding the contract method 0xbd922b1c.
//
// Solidity: function strategyImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCaller) StrategyImplementation(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultFactory.contract.Call(opts, &out, "strategyImplementation")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// StrategyImplementation is a free data retrieval call binding the contract method 0xbd922b1c.
//
// Solidity: function strategyImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactorySession) StrategyImplementation() (common.Address, error) {
	return _SuperVaultFactory.Contract.StrategyImplementation(&_SuperVaultFactory.CallOpts)
}

// StrategyImplementation is a free data retrieval call binding the contract method 0xbd922b1c.
//
// Solidity: function strategyImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCallerSession) StrategyImplementation() (common.Address, error) {
	return _SuperVaultFactory.Contract.StrategyImplementation(&_SuperVaultFactory.CallOpts)
}

// VaultImplementation is a free data retrieval call binding the contract method 0xbba48a90.
//
// Solidity: function vaultImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCaller) VaultImplementation(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultFactory.contract.Call(opts, &out, "vaultImplementation")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// VaultImplementation is a free data retrieval call binding the contract method 0xbba48a90.
//
// Solidity: function vaultImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactorySession) VaultImplementation() (common.Address, error) {
	return _SuperVaultFactory.Contract.VaultImplementation(&_SuperVaultFactory.CallOpts)
}

// VaultImplementation is a free data retrieval call binding the contract method 0xbba48a90.
//
// Solidity: function vaultImplementation() view returns(address)
func (_SuperVaultFactory *SuperVaultFactoryCallerSession) VaultImplementation() (common.Address, error) {
	return _SuperVaultFactory.Contract.VaultImplementation(&_SuperVaultFactory.CallOpts)
}

// CreateVault is a paid mutator transaction binding the contract method 0xefb11471.
//
// Solidity: function createVault((address,string,string,address,address,address,address,uint256) params) returns(address superVault, address strategy, address escrow)
func (_SuperVaultFactory *SuperVaultFactoryTransactor) CreateVault(opts *bind.TransactOpts, params ISuperVaultFactoryVaultCreationParams) (*types.Transaction, error) {
	return _SuperVaultFactory.contract.Transact(opts, "createVault", params)
}

// CreateVault is a paid mutator transaction binding the contract method 0xefb11471.
//
// Solidity: function createVault((address,string,string,address,address,address,address,uint256) params) returns(address superVault, address strategy, address escrow)
func (_SuperVaultFactory *SuperVaultFactorySession) CreateVault(params ISuperVaultFactoryVaultCreationParams) (*types.Transaction, error) {
	return _SuperVaultFactory.Contract.CreateVault(&_SuperVaultFactory.TransactOpts, params)
}

// CreateVault is a paid mutator transaction binding the contract method 0xefb11471.
//
// Solidity: function createVault((address,string,string,address,address,address,address,uint256) params) returns(address superVault, address strategy, address escrow)
func (_SuperVaultFactory *SuperVaultFactoryTransactorSession) CreateVault(params ISuperVaultFactoryVaultCreationParams) (*types.Transaction, error) {
	return _SuperVaultFactory.Contract.CreateVault(&_SuperVaultFactory.TransactOpts, params)
}

// SuperVaultFactoryVaultDeployedIterator is returned from FilterVaultDeployed and is used to iterate over the raw logs and unpacked data for VaultDeployed events raised by the SuperVaultFactory contract.
type SuperVaultFactoryVaultDeployedIterator struct {
	Event *SuperVaultFactoryVaultDeployed // Event containing the contract specifics and raw log

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
func (it *SuperVaultFactoryVaultDeployedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultFactoryVaultDeployed)
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
		it.Event = new(SuperVaultFactoryVaultDeployed)
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
func (it *SuperVaultFactoryVaultDeployedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultFactoryVaultDeployedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultFactoryVaultDeployed represents a VaultDeployed event raised by the SuperVaultFactory contract.
type SuperVaultFactoryVaultDeployed struct {
	Vault    common.Address
	Strategy common.Address
	Escrow   common.Address
	Asset    common.Address
	Name     string
	Symbol   string
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterVaultDeployed is a free log retrieval operation binding the contract event 0x4e0ec6694e967b226634747e76e28b7f488cb081ae303528e527f8d4430e62f9.
//
// Solidity: event VaultDeployed(address indexed vault, address indexed strategy, address indexed escrow, address asset, string name, string symbol)
func (_SuperVaultFactory *SuperVaultFactoryFilterer) FilterVaultDeployed(opts *bind.FilterOpts, vault []common.Address, strategy []common.Address, escrow []common.Address) (*SuperVaultFactoryVaultDeployedIterator, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var escrowRule []interface{}
	for _, escrowItem := range escrow {
		escrowRule = append(escrowRule, escrowItem)
	}

	logs, sub, err := _SuperVaultFactory.contract.FilterLogs(opts, "VaultDeployed", vaultRule, strategyRule, escrowRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultFactoryVaultDeployedIterator{contract: _SuperVaultFactory.contract, event: "VaultDeployed", logs: logs, sub: sub}, nil
}

// WatchVaultDeployed is a free log subscription operation binding the contract event 0x4e0ec6694e967b226634747e76e28b7f488cb081ae303528e527f8d4430e62f9.
//
// Solidity: event VaultDeployed(address indexed vault, address indexed strategy, address indexed escrow, address asset, string name, string symbol)
func (_SuperVaultFactory *SuperVaultFactoryFilterer) WatchVaultDeployed(opts *bind.WatchOpts, sink chan<- *SuperVaultFactoryVaultDeployed, vault []common.Address, strategy []common.Address, escrow []common.Address) (event.Subscription, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var escrowRule []interface{}
	for _, escrowItem := range escrow {
		escrowRule = append(escrowRule, escrowItem)
	}

	logs, sub, err := _SuperVaultFactory.contract.WatchLogs(opts, "VaultDeployed", vaultRule, strategyRule, escrowRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultFactoryVaultDeployed)
				if err := _SuperVaultFactory.contract.UnpackLog(event, "VaultDeployed", log); err != nil {
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

// ParseVaultDeployed is a log parse operation binding the contract event 0x4e0ec6694e967b226634747e76e28b7f488cb081ae303528e527f8d4430e62f9.
//
// Solidity: event VaultDeployed(address indexed vault, address indexed strategy, address indexed escrow, address asset, string name, string symbol)
func (_SuperVaultFactory *SuperVaultFactoryFilterer) ParseVaultDeployed(log types.Log) (*SuperVaultFactoryVaultDeployed, error) {
	event := new(SuperVaultFactoryVaultDeployed)
	if err := _SuperVaultFactory.contract.UnpackLog(event, "VaultDeployed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
