// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package contracts

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

// HooksRegistryMetaData contains all meta data concerning the HooksRegistry contract.
var HooksRegistryMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getRegisteredHooks\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isHookRegistered\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"registerHook\",\"inputs\":[{\"name\":\"hook_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"registeredHooks\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"unregisterHook\",\"inputs\":[{\"name\":\"hook_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"HookRegistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookUnregistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"HOOK_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_NOT_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]}]",
}

// HooksRegistryABI is the input ABI used to generate the binding from.
// Deprecated: Use HooksRegistryMetaData.ABI instead.
var HooksRegistryABI = HooksRegistryMetaData.ABI

// HooksRegistry is an auto generated Go binding around an Ethereum contract.
type HooksRegistry struct {
	HooksRegistryCaller     // Read-only binding to the contract
	HooksRegistryTransactor // Write-only binding to the contract
	HooksRegistryFilterer   // Log filterer for contract events
}

// HooksRegistryCaller is an auto generated read-only Go binding around an Ethereum contract.
type HooksRegistryCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// HooksRegistryTransactor is an auto generated write-only Go binding around an Ethereum contract.
type HooksRegistryTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// HooksRegistryFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type HooksRegistryFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// HooksRegistrySession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type HooksRegistrySession struct {
	Contract     *HooksRegistry    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// HooksRegistryCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type HooksRegistryCallerSession struct {
	Contract *HooksRegistryCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// HooksRegistryTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type HooksRegistryTransactorSession struct {
	Contract     *HooksRegistryTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// HooksRegistryRaw is an auto generated low-level Go binding around an Ethereum contract.
type HooksRegistryRaw struct {
	Contract *HooksRegistry // Generic contract binding to access the raw methods on
}

// HooksRegistryCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type HooksRegistryCallerRaw struct {
	Contract *HooksRegistryCaller // Generic read-only contract binding to access the raw methods on
}

// HooksRegistryTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type HooksRegistryTransactorRaw struct {
	Contract *HooksRegistryTransactor // Generic write-only contract binding to access the raw methods on
}

// NewHooksRegistry creates a new instance of HooksRegistry, bound to a specific deployed contract.
func NewHooksRegistry(address common.Address, backend bind.ContractBackend) (*HooksRegistry, error) {
	contract, err := bindHooksRegistry(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &HooksRegistry{HooksRegistryCaller: HooksRegistryCaller{contract: contract}, HooksRegistryTransactor: HooksRegistryTransactor{contract: contract}, HooksRegistryFilterer: HooksRegistryFilterer{contract: contract}}, nil
}

// NewHooksRegistryCaller creates a new read-only instance of HooksRegistry, bound to a specific deployed contract.
func NewHooksRegistryCaller(address common.Address, caller bind.ContractCaller) (*HooksRegistryCaller, error) {
	contract, err := bindHooksRegistry(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &HooksRegistryCaller{contract: contract}, nil
}

// NewHooksRegistryTransactor creates a new write-only instance of HooksRegistry, bound to a specific deployed contract.
func NewHooksRegistryTransactor(address common.Address, transactor bind.ContractTransactor) (*HooksRegistryTransactor, error) {
	contract, err := bindHooksRegistry(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &HooksRegistryTransactor{contract: contract}, nil
}

// NewHooksRegistryFilterer creates a new log filterer instance of HooksRegistry, bound to a specific deployed contract.
func NewHooksRegistryFilterer(address common.Address, filterer bind.ContractFilterer) (*HooksRegistryFilterer, error) {
	contract, err := bindHooksRegistry(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &HooksRegistryFilterer{contract: contract}, nil
}

// bindHooksRegistry binds a generic wrapper to an already deployed contract.
func bindHooksRegistry(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := HooksRegistryMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_HooksRegistry *HooksRegistryRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _HooksRegistry.Contract.HooksRegistryCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_HooksRegistry *HooksRegistryRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _HooksRegistry.Contract.HooksRegistryTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_HooksRegistry *HooksRegistryRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _HooksRegistry.Contract.HooksRegistryTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_HooksRegistry *HooksRegistryCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _HooksRegistry.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_HooksRegistry *HooksRegistryTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _HooksRegistry.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_HooksRegistry *HooksRegistryTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _HooksRegistry.Contract.contract.Transact(opts, method, params...)
}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_HooksRegistry *HooksRegistryCaller) GetRegisteredHooks(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _HooksRegistry.contract.Call(opts, &out, "getRegisteredHooks")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_HooksRegistry *HooksRegistrySession) GetRegisteredHooks() ([]common.Address, error) {
	return _HooksRegistry.Contract.GetRegisteredHooks(&_HooksRegistry.CallOpts)
}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_HooksRegistry *HooksRegistryCallerSession) GetRegisteredHooks() ([]common.Address, error) {
	return _HooksRegistry.Contract.GetRegisteredHooks(&_HooksRegistry.CallOpts)
}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address ) view returns(bool)
func (_HooksRegistry *HooksRegistryCaller) IsHookRegistered(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _HooksRegistry.contract.Call(opts, &out, "isHookRegistered", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address ) view returns(bool)
func (_HooksRegistry *HooksRegistrySession) IsHookRegistered(arg0 common.Address) (bool, error) {
	return _HooksRegistry.Contract.IsHookRegistered(&_HooksRegistry.CallOpts, arg0)
}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address ) view returns(bool)
func (_HooksRegistry *HooksRegistryCallerSession) IsHookRegistered(arg0 common.Address) (bool, error) {
	return _HooksRegistry.Contract.IsHookRegistered(&_HooksRegistry.CallOpts, arg0)
}

// RegisteredHooks is a free data retrieval call binding the contract method 0xc754336c.
//
// Solidity: function registeredHooks(uint256 ) view returns(address)
func (_HooksRegistry *HooksRegistryCaller) RegisteredHooks(opts *bind.CallOpts, arg0 *big.Int) (common.Address, error) {
	var out []interface{}
	err := _HooksRegistry.contract.Call(opts, &out, "registeredHooks", arg0)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// RegisteredHooks is a free data retrieval call binding the contract method 0xc754336c.
//
// Solidity: function registeredHooks(uint256 ) view returns(address)
func (_HooksRegistry *HooksRegistrySession) RegisteredHooks(arg0 *big.Int) (common.Address, error) {
	return _HooksRegistry.Contract.RegisteredHooks(&_HooksRegistry.CallOpts, arg0)
}

// RegisteredHooks is a free data retrieval call binding the contract method 0xc754336c.
//
// Solidity: function registeredHooks(uint256 ) view returns(address)
func (_HooksRegistry *HooksRegistryCallerSession) RegisteredHooks(arg0 *big.Int) (common.Address, error) {
	return _HooksRegistry.Contract.RegisteredHooks(&_HooksRegistry.CallOpts, arg0)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_HooksRegistry *HooksRegistryCaller) SuperRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _HooksRegistry.contract.Call(opts, &out, "superRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_HooksRegistry *HooksRegistrySession) SuperRegistry() (common.Address, error) {
	return _HooksRegistry.Contract.SuperRegistry(&_HooksRegistry.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_HooksRegistry *HooksRegistryCallerSession) SuperRegistry() (common.Address, error) {
	return _HooksRegistry.Contract.SuperRegistry(&_HooksRegistry.CallOpts)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x6354b661.
//
// Solidity: function registerHook(address hook_) returns()
func (_HooksRegistry *HooksRegistryTransactor) RegisterHook(opts *bind.TransactOpts, hook_ common.Address) (*types.Transaction, error) {
	return _HooksRegistry.contract.Transact(opts, "registerHook", hook_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x6354b661.
//
// Solidity: function registerHook(address hook_) returns()
func (_HooksRegistry *HooksRegistrySession) RegisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _HooksRegistry.Contract.RegisterHook(&_HooksRegistry.TransactOpts, hook_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x6354b661.
//
// Solidity: function registerHook(address hook_) returns()
func (_HooksRegistry *HooksRegistryTransactorSession) RegisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _HooksRegistry.Contract.RegisterHook(&_HooksRegistry.TransactOpts, hook_)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xf76f48cb.
//
// Solidity: function unregisterHook(address hook_) returns()
func (_HooksRegistry *HooksRegistryTransactor) UnregisterHook(opts *bind.TransactOpts, hook_ common.Address) (*types.Transaction, error) {
	return _HooksRegistry.contract.Transact(opts, "unregisterHook", hook_)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xf76f48cb.
//
// Solidity: function unregisterHook(address hook_) returns()
func (_HooksRegistry *HooksRegistrySession) UnregisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _HooksRegistry.Contract.UnregisterHook(&_HooksRegistry.TransactOpts, hook_)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xf76f48cb.
//
// Solidity: function unregisterHook(address hook_) returns()
func (_HooksRegistry *HooksRegistryTransactorSession) UnregisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _HooksRegistry.Contract.UnregisterHook(&_HooksRegistry.TransactOpts, hook_)
}

// HooksRegistryHookRegisteredIterator is returned from FilterHookRegistered and is used to iterate over the raw logs and unpacked data for HookRegistered events raised by the HooksRegistry contract.
type HooksRegistryHookRegisteredIterator struct {
	Event *HooksRegistryHookRegistered // Event containing the contract specifics and raw log

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
func (it *HooksRegistryHookRegisteredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(HooksRegistryHookRegistered)
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
		it.Event = new(HooksRegistryHookRegistered)
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
func (it *HooksRegistryHookRegisteredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *HooksRegistryHookRegisteredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// HooksRegistryHookRegistered represents a HookRegistered event raised by the HooksRegistry contract.
type HooksRegistryHookRegistered struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterHookRegistered is a free log retrieval operation binding the contract event 0xc32bc16f2ad4b9008fd1cda71adb222d318bd824de7796c6970a76ca3fdbd604.
//
// Solidity: event HookRegistered(address indexed hook)
func (_HooksRegistry *HooksRegistryFilterer) FilterHookRegistered(opts *bind.FilterOpts, hook []common.Address) (*HooksRegistryHookRegisteredIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _HooksRegistry.contract.FilterLogs(opts, "HookRegistered", hookRule)
	if err != nil {
		return nil, err
	}
	return &HooksRegistryHookRegisteredIterator{contract: _HooksRegistry.contract, event: "HookRegistered", logs: logs, sub: sub}, nil
}

// WatchHookRegistered is a free log subscription operation binding the contract event 0xc32bc16f2ad4b9008fd1cda71adb222d318bd824de7796c6970a76ca3fdbd604.
//
// Solidity: event HookRegistered(address indexed hook)
func (_HooksRegistry *HooksRegistryFilterer) WatchHookRegistered(opts *bind.WatchOpts, sink chan<- *HooksRegistryHookRegistered, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _HooksRegistry.contract.WatchLogs(opts, "HookRegistered", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(HooksRegistryHookRegistered)
				if err := _HooksRegistry.contract.UnpackLog(event, "HookRegistered", log); err != nil {
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

// ParseHookRegistered is a log parse operation binding the contract event 0xc32bc16f2ad4b9008fd1cda71adb222d318bd824de7796c6970a76ca3fdbd604.
//
// Solidity: event HookRegistered(address indexed hook)
func (_HooksRegistry *HooksRegistryFilterer) ParseHookRegistered(log types.Log) (*HooksRegistryHookRegistered, error) {
	event := new(HooksRegistryHookRegistered)
	if err := _HooksRegistry.contract.UnpackLog(event, "HookRegistered", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// HooksRegistryHookUnregisteredIterator is returned from FilterHookUnregistered and is used to iterate over the raw logs and unpacked data for HookUnregistered events raised by the HooksRegistry contract.
type HooksRegistryHookUnregisteredIterator struct {
	Event *HooksRegistryHookUnregistered // Event containing the contract specifics and raw log

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
func (it *HooksRegistryHookUnregisteredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(HooksRegistryHookUnregistered)
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
		it.Event = new(HooksRegistryHookUnregistered)
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
func (it *HooksRegistryHookUnregisteredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *HooksRegistryHookUnregisteredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// HooksRegistryHookUnregistered represents a HookUnregistered event raised by the HooksRegistry contract.
type HooksRegistryHookUnregistered struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterHookUnregistered is a free log retrieval operation binding the contract event 0xcab1186db73fd6ffc8a180fe72ddc46758a3d793140e0946340e92998cd0a8b3.
//
// Solidity: event HookUnregistered(address indexed hook)
func (_HooksRegistry *HooksRegistryFilterer) FilterHookUnregistered(opts *bind.FilterOpts, hook []common.Address) (*HooksRegistryHookUnregisteredIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _HooksRegistry.contract.FilterLogs(opts, "HookUnregistered", hookRule)
	if err != nil {
		return nil, err
	}
	return &HooksRegistryHookUnregisteredIterator{contract: _HooksRegistry.contract, event: "HookUnregistered", logs: logs, sub: sub}, nil
}

// WatchHookUnregistered is a free log subscription operation binding the contract event 0xcab1186db73fd6ffc8a180fe72ddc46758a3d793140e0946340e92998cd0a8b3.
//
// Solidity: event HookUnregistered(address indexed hook)
func (_HooksRegistry *HooksRegistryFilterer) WatchHookUnregistered(opts *bind.WatchOpts, sink chan<- *HooksRegistryHookUnregistered, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _HooksRegistry.contract.WatchLogs(opts, "HookUnregistered", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(HooksRegistryHookUnregistered)
				if err := _HooksRegistry.contract.UnpackLog(event, "HookUnregistered", log); err != nil {
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

// ParseHookUnregistered is a log parse operation binding the contract event 0xcab1186db73fd6ffc8a180fe72ddc46758a3d793140e0946340e92998cd0a8b3.
//
// Solidity: event HookUnregistered(address indexed hook)
func (_HooksRegistry *HooksRegistryFilterer) ParseHookUnregistered(log types.Log) (*HooksRegistryHookUnregistered, error) {
	event := new(HooksRegistryHookUnregistered)
	if err := _HooksRegistry.contract.UnpackLog(event, "HookUnregistered", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
