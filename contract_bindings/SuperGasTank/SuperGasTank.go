// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperGasTank

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

// SuperGasTankMetaData contains all meta data concerning the SuperGasTank contract.
var SuperGasTankMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"owner_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addToAllowlist\",\"inputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isAllowlisted\",\"inputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"removeFromAllowlist\",\"inputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawETH\",\"inputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AllowlistAddressAdded\",\"inputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AllowlistAddressRemoved\",\"inputs\":[{\"name\":\"contractAddress\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ETHWithdrawn\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"NOT_ALLOWLISTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OwnableInvalidOwner\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// SuperGasTankABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperGasTankMetaData.ABI instead.
var SuperGasTankABI = SuperGasTankMetaData.ABI

// SuperGasTank is an auto generated Go binding around an Ethereum contract.
type SuperGasTank struct {
	SuperGasTankCaller     // Read-only binding to the contract
	SuperGasTankTransactor // Write-only binding to the contract
	SuperGasTankFilterer   // Log filterer for contract events
}

// SuperGasTankCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperGasTankCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperGasTankTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperGasTankTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperGasTankFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperGasTankFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperGasTankSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperGasTankSession struct {
	Contract     *SuperGasTank     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperGasTankCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperGasTankCallerSession struct {
	Contract *SuperGasTankCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// SuperGasTankTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperGasTankTransactorSession struct {
	Contract     *SuperGasTankTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// SuperGasTankRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperGasTankRaw struct {
	Contract *SuperGasTank // Generic contract binding to access the raw methods on
}

// SuperGasTankCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperGasTankCallerRaw struct {
	Contract *SuperGasTankCaller // Generic read-only contract binding to access the raw methods on
}

// SuperGasTankTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperGasTankTransactorRaw struct {
	Contract *SuperGasTankTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperGasTank creates a new instance of SuperGasTank, bound to a specific deployed contract.
func NewSuperGasTank(address common.Address, backend bind.ContractBackend) (*SuperGasTank, error) {
	contract, err := bindSuperGasTank(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperGasTank{SuperGasTankCaller: SuperGasTankCaller{contract: contract}, SuperGasTankTransactor: SuperGasTankTransactor{contract: contract}, SuperGasTankFilterer: SuperGasTankFilterer{contract: contract}}, nil
}

// NewSuperGasTankCaller creates a new read-only instance of SuperGasTank, bound to a specific deployed contract.
func NewSuperGasTankCaller(address common.Address, caller bind.ContractCaller) (*SuperGasTankCaller, error) {
	contract, err := bindSuperGasTank(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankCaller{contract: contract}, nil
}

// NewSuperGasTankTransactor creates a new write-only instance of SuperGasTank, bound to a specific deployed contract.
func NewSuperGasTankTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperGasTankTransactor, error) {
	contract, err := bindSuperGasTank(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankTransactor{contract: contract}, nil
}

// NewSuperGasTankFilterer creates a new log filterer instance of SuperGasTank, bound to a specific deployed contract.
func NewSuperGasTankFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperGasTankFilterer, error) {
	contract, err := bindSuperGasTank(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankFilterer{contract: contract}, nil
}

// bindSuperGasTank binds a generic wrapper to an already deployed contract.
func bindSuperGasTank(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperGasTankMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperGasTank *SuperGasTankRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperGasTank.Contract.SuperGasTankCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperGasTank *SuperGasTankRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGasTank.Contract.SuperGasTankTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperGasTank *SuperGasTankRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperGasTank.Contract.SuperGasTankTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperGasTank *SuperGasTankCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperGasTank.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperGasTank *SuperGasTankTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGasTank.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperGasTank *SuperGasTankTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperGasTank.Contract.contract.Transact(opts, method, params...)
}

// IsAllowlisted is a free data retrieval call binding the contract method 0x05a3b809.
//
// Solidity: function isAllowlisted(address contractAddress) view returns(bool)
func (_SuperGasTank *SuperGasTankCaller) IsAllowlisted(opts *bind.CallOpts, contractAddress common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGasTank.contract.Call(opts, &out, "isAllowlisted", contractAddress)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsAllowlisted is a free data retrieval call binding the contract method 0x05a3b809.
//
// Solidity: function isAllowlisted(address contractAddress) view returns(bool)
func (_SuperGasTank *SuperGasTankSession) IsAllowlisted(contractAddress common.Address) (bool, error) {
	return _SuperGasTank.Contract.IsAllowlisted(&_SuperGasTank.CallOpts, contractAddress)
}

// IsAllowlisted is a free data retrieval call binding the contract method 0x05a3b809.
//
// Solidity: function isAllowlisted(address contractAddress) view returns(bool)
func (_SuperGasTank *SuperGasTankCallerSession) IsAllowlisted(contractAddress common.Address) (bool, error) {
	return _SuperGasTank.Contract.IsAllowlisted(&_SuperGasTank.CallOpts, contractAddress)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperGasTank *SuperGasTankCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperGasTank.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperGasTank *SuperGasTankSession) Owner() (common.Address, error) {
	return _SuperGasTank.Contract.Owner(&_SuperGasTank.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperGasTank *SuperGasTankCallerSession) Owner() (common.Address, error) {
	return _SuperGasTank.Contract.Owner(&_SuperGasTank.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperGasTank *SuperGasTankCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperGasTank.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperGasTank *SuperGasTankSession) PendingOwner() (common.Address, error) {
	return _SuperGasTank.Contract.PendingOwner(&_SuperGasTank.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperGasTank *SuperGasTankCallerSession) PendingOwner() (common.Address, error) {
	return _SuperGasTank.Contract.PendingOwner(&_SuperGasTank.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperGasTank *SuperGasTankTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGasTank.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperGasTank *SuperGasTankSession) AcceptOwnership() (*types.Transaction, error) {
	return _SuperGasTank.Contract.AcceptOwnership(&_SuperGasTank.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperGasTank *SuperGasTankTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _SuperGasTank.Contract.AcceptOwnership(&_SuperGasTank.TransactOpts)
}

// AddToAllowlist is a paid mutator transaction binding the contract method 0xf8e86ece.
//
// Solidity: function addToAllowlist(address contractAddress) returns()
func (_SuperGasTank *SuperGasTankTransactor) AddToAllowlist(opts *bind.TransactOpts, contractAddress common.Address) (*types.Transaction, error) {
	return _SuperGasTank.contract.Transact(opts, "addToAllowlist", contractAddress)
}

// AddToAllowlist is a paid mutator transaction binding the contract method 0xf8e86ece.
//
// Solidity: function addToAllowlist(address contractAddress) returns()
func (_SuperGasTank *SuperGasTankSession) AddToAllowlist(contractAddress common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.AddToAllowlist(&_SuperGasTank.TransactOpts, contractAddress)
}

// AddToAllowlist is a paid mutator transaction binding the contract method 0xf8e86ece.
//
// Solidity: function addToAllowlist(address contractAddress) returns()
func (_SuperGasTank *SuperGasTankTransactorSession) AddToAllowlist(contractAddress common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.AddToAllowlist(&_SuperGasTank.TransactOpts, contractAddress)
}

// RemoveFromAllowlist is a paid mutator transaction binding the contract method 0x5da93d7e.
//
// Solidity: function removeFromAllowlist(address contractAddress) returns()
func (_SuperGasTank *SuperGasTankTransactor) RemoveFromAllowlist(opts *bind.TransactOpts, contractAddress common.Address) (*types.Transaction, error) {
	return _SuperGasTank.contract.Transact(opts, "removeFromAllowlist", contractAddress)
}

// RemoveFromAllowlist is a paid mutator transaction binding the contract method 0x5da93d7e.
//
// Solidity: function removeFromAllowlist(address contractAddress) returns()
func (_SuperGasTank *SuperGasTankSession) RemoveFromAllowlist(contractAddress common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.RemoveFromAllowlist(&_SuperGasTank.TransactOpts, contractAddress)
}

// RemoveFromAllowlist is a paid mutator transaction binding the contract method 0x5da93d7e.
//
// Solidity: function removeFromAllowlist(address contractAddress) returns()
func (_SuperGasTank *SuperGasTankTransactorSession) RemoveFromAllowlist(contractAddress common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.RemoveFromAllowlist(&_SuperGasTank.TransactOpts, contractAddress)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperGasTank *SuperGasTankTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGasTank.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperGasTank *SuperGasTankSession) RenounceOwnership() (*types.Transaction, error) {
	return _SuperGasTank.Contract.RenounceOwnership(&_SuperGasTank.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperGasTank *SuperGasTankTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SuperGasTank.Contract.RenounceOwnership(&_SuperGasTank.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperGasTank *SuperGasTankTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SuperGasTank.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperGasTank *SuperGasTankSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.TransferOwnership(&_SuperGasTank.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperGasTank *SuperGasTankTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.TransferOwnership(&_SuperGasTank.TransactOpts, newOwner)
}

// WithdrawETH is a paid mutator transaction binding the contract method 0x36118b52.
//
// Solidity: function withdrawETH(uint256 amount, address receiver) returns()
func (_SuperGasTank *SuperGasTankTransactor) WithdrawETH(opts *bind.TransactOpts, amount *big.Int, receiver common.Address) (*types.Transaction, error) {
	return _SuperGasTank.contract.Transact(opts, "withdrawETH", amount, receiver)
}

// WithdrawETH is a paid mutator transaction binding the contract method 0x36118b52.
//
// Solidity: function withdrawETH(uint256 amount, address receiver) returns()
func (_SuperGasTank *SuperGasTankSession) WithdrawETH(amount *big.Int, receiver common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.WithdrawETH(&_SuperGasTank.TransactOpts, amount, receiver)
}

// WithdrawETH is a paid mutator transaction binding the contract method 0x36118b52.
//
// Solidity: function withdrawETH(uint256 amount, address receiver) returns()
func (_SuperGasTank *SuperGasTankTransactorSession) WithdrawETH(amount *big.Int, receiver common.Address) (*types.Transaction, error) {
	return _SuperGasTank.Contract.WithdrawETH(&_SuperGasTank.TransactOpts, amount, receiver)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperGasTank *SuperGasTankTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGasTank.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperGasTank *SuperGasTankSession) Receive() (*types.Transaction, error) {
	return _SuperGasTank.Contract.Receive(&_SuperGasTank.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperGasTank *SuperGasTankTransactorSession) Receive() (*types.Transaction, error) {
	return _SuperGasTank.Contract.Receive(&_SuperGasTank.TransactOpts)
}

// SuperGasTankAllowlistAddressAddedIterator is returned from FilterAllowlistAddressAdded and is used to iterate over the raw logs and unpacked data for AllowlistAddressAdded events raised by the SuperGasTank contract.
type SuperGasTankAllowlistAddressAddedIterator struct {
	Event *SuperGasTankAllowlistAddressAdded // Event containing the contract specifics and raw log

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
func (it *SuperGasTankAllowlistAddressAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGasTankAllowlistAddressAdded)
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
		it.Event = new(SuperGasTankAllowlistAddressAdded)
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
func (it *SuperGasTankAllowlistAddressAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGasTankAllowlistAddressAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGasTankAllowlistAddressAdded represents a AllowlistAddressAdded event raised by the SuperGasTank contract.
type SuperGasTankAllowlistAddressAdded struct {
	ContractAddress common.Address
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterAllowlistAddressAdded is a free log retrieval operation binding the contract event 0xbf5840c727acdcaceea5154edc82998fa82a490aa3dc7aeb66849c8bbea1f579.
//
// Solidity: event AllowlistAddressAdded(address indexed contractAddress)
func (_SuperGasTank *SuperGasTankFilterer) FilterAllowlistAddressAdded(opts *bind.FilterOpts, contractAddress []common.Address) (*SuperGasTankAllowlistAddressAddedIterator, error) {

	var contractAddressRule []interface{}
	for _, contractAddressItem := range contractAddress {
		contractAddressRule = append(contractAddressRule, contractAddressItem)
	}

	logs, sub, err := _SuperGasTank.contract.FilterLogs(opts, "AllowlistAddressAdded", contractAddressRule)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankAllowlistAddressAddedIterator{contract: _SuperGasTank.contract, event: "AllowlistAddressAdded", logs: logs, sub: sub}, nil
}

// WatchAllowlistAddressAdded is a free log subscription operation binding the contract event 0xbf5840c727acdcaceea5154edc82998fa82a490aa3dc7aeb66849c8bbea1f579.
//
// Solidity: event AllowlistAddressAdded(address indexed contractAddress)
func (_SuperGasTank *SuperGasTankFilterer) WatchAllowlistAddressAdded(opts *bind.WatchOpts, sink chan<- *SuperGasTankAllowlistAddressAdded, contractAddress []common.Address) (event.Subscription, error) {

	var contractAddressRule []interface{}
	for _, contractAddressItem := range contractAddress {
		contractAddressRule = append(contractAddressRule, contractAddressItem)
	}

	logs, sub, err := _SuperGasTank.contract.WatchLogs(opts, "AllowlistAddressAdded", contractAddressRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGasTankAllowlistAddressAdded)
				if err := _SuperGasTank.contract.UnpackLog(event, "AllowlistAddressAdded", log); err != nil {
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

// ParseAllowlistAddressAdded is a log parse operation binding the contract event 0xbf5840c727acdcaceea5154edc82998fa82a490aa3dc7aeb66849c8bbea1f579.
//
// Solidity: event AllowlistAddressAdded(address indexed contractAddress)
func (_SuperGasTank *SuperGasTankFilterer) ParseAllowlistAddressAdded(log types.Log) (*SuperGasTankAllowlistAddressAdded, error) {
	event := new(SuperGasTankAllowlistAddressAdded)
	if err := _SuperGasTank.contract.UnpackLog(event, "AllowlistAddressAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGasTankAllowlistAddressRemovedIterator is returned from FilterAllowlistAddressRemoved and is used to iterate over the raw logs and unpacked data for AllowlistAddressRemoved events raised by the SuperGasTank contract.
type SuperGasTankAllowlistAddressRemovedIterator struct {
	Event *SuperGasTankAllowlistAddressRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGasTankAllowlistAddressRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGasTankAllowlistAddressRemoved)
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
		it.Event = new(SuperGasTankAllowlistAddressRemoved)
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
func (it *SuperGasTankAllowlistAddressRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGasTankAllowlistAddressRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGasTankAllowlistAddressRemoved represents a AllowlistAddressRemoved event raised by the SuperGasTank contract.
type SuperGasTankAllowlistAddressRemoved struct {
	ContractAddress common.Address
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterAllowlistAddressRemoved is a free log retrieval operation binding the contract event 0x89aa0423af0b4cf311bfb79f61549f2b82b335f041e4f7ae674618059b51a4cb.
//
// Solidity: event AllowlistAddressRemoved(address indexed contractAddress)
func (_SuperGasTank *SuperGasTankFilterer) FilterAllowlistAddressRemoved(opts *bind.FilterOpts, contractAddress []common.Address) (*SuperGasTankAllowlistAddressRemovedIterator, error) {

	var contractAddressRule []interface{}
	for _, contractAddressItem := range contractAddress {
		contractAddressRule = append(contractAddressRule, contractAddressItem)
	}

	logs, sub, err := _SuperGasTank.contract.FilterLogs(opts, "AllowlistAddressRemoved", contractAddressRule)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankAllowlistAddressRemovedIterator{contract: _SuperGasTank.contract, event: "AllowlistAddressRemoved", logs: logs, sub: sub}, nil
}

// WatchAllowlistAddressRemoved is a free log subscription operation binding the contract event 0x89aa0423af0b4cf311bfb79f61549f2b82b335f041e4f7ae674618059b51a4cb.
//
// Solidity: event AllowlistAddressRemoved(address indexed contractAddress)
func (_SuperGasTank *SuperGasTankFilterer) WatchAllowlistAddressRemoved(opts *bind.WatchOpts, sink chan<- *SuperGasTankAllowlistAddressRemoved, contractAddress []common.Address) (event.Subscription, error) {

	var contractAddressRule []interface{}
	for _, contractAddressItem := range contractAddress {
		contractAddressRule = append(contractAddressRule, contractAddressItem)
	}

	logs, sub, err := _SuperGasTank.contract.WatchLogs(opts, "AllowlistAddressRemoved", contractAddressRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGasTankAllowlistAddressRemoved)
				if err := _SuperGasTank.contract.UnpackLog(event, "AllowlistAddressRemoved", log); err != nil {
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

// ParseAllowlistAddressRemoved is a log parse operation binding the contract event 0x89aa0423af0b4cf311bfb79f61549f2b82b335f041e4f7ae674618059b51a4cb.
//
// Solidity: event AllowlistAddressRemoved(address indexed contractAddress)
func (_SuperGasTank *SuperGasTankFilterer) ParseAllowlistAddressRemoved(log types.Log) (*SuperGasTankAllowlistAddressRemoved, error) {
	event := new(SuperGasTankAllowlistAddressRemoved)
	if err := _SuperGasTank.contract.UnpackLog(event, "AllowlistAddressRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGasTankETHWithdrawnIterator is returned from FilterETHWithdrawn and is used to iterate over the raw logs and unpacked data for ETHWithdrawn events raised by the SuperGasTank contract.
type SuperGasTankETHWithdrawnIterator struct {
	Event *SuperGasTankETHWithdrawn // Event containing the contract specifics and raw log

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
func (it *SuperGasTankETHWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGasTankETHWithdrawn)
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
		it.Event = new(SuperGasTankETHWithdrawn)
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
func (it *SuperGasTankETHWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGasTankETHWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGasTankETHWithdrawn represents a ETHWithdrawn event raised by the SuperGasTank contract.
type SuperGasTankETHWithdrawn struct {
	Receiver common.Address
	Amount   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterETHWithdrawn is a free log retrieval operation binding the contract event 0x94b2de810873337ed265c5f8cf98c9cffefa06b8607f9a2f1fbaebdfbcfbef1c.
//
// Solidity: event ETHWithdrawn(address indexed receiver, uint256 amount)
func (_SuperGasTank *SuperGasTankFilterer) FilterETHWithdrawn(opts *bind.FilterOpts, receiver []common.Address) (*SuperGasTankETHWithdrawnIterator, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}

	logs, sub, err := _SuperGasTank.contract.FilterLogs(opts, "ETHWithdrawn", receiverRule)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankETHWithdrawnIterator{contract: _SuperGasTank.contract, event: "ETHWithdrawn", logs: logs, sub: sub}, nil
}

// WatchETHWithdrawn is a free log subscription operation binding the contract event 0x94b2de810873337ed265c5f8cf98c9cffefa06b8607f9a2f1fbaebdfbcfbef1c.
//
// Solidity: event ETHWithdrawn(address indexed receiver, uint256 amount)
func (_SuperGasTank *SuperGasTankFilterer) WatchETHWithdrawn(opts *bind.WatchOpts, sink chan<- *SuperGasTankETHWithdrawn, receiver []common.Address) (event.Subscription, error) {

	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}

	logs, sub, err := _SuperGasTank.contract.WatchLogs(opts, "ETHWithdrawn", receiverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGasTankETHWithdrawn)
				if err := _SuperGasTank.contract.UnpackLog(event, "ETHWithdrawn", log); err != nil {
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

// ParseETHWithdrawn is a log parse operation binding the contract event 0x94b2de810873337ed265c5f8cf98c9cffefa06b8607f9a2f1fbaebdfbcfbef1c.
//
// Solidity: event ETHWithdrawn(address indexed receiver, uint256 amount)
func (_SuperGasTank *SuperGasTankFilterer) ParseETHWithdrawn(log types.Log) (*SuperGasTankETHWithdrawn, error) {
	event := new(SuperGasTankETHWithdrawn)
	if err := _SuperGasTank.contract.UnpackLog(event, "ETHWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGasTankOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the SuperGasTank contract.
type SuperGasTankOwnershipTransferStartedIterator struct {
	Event *SuperGasTankOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *SuperGasTankOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGasTankOwnershipTransferStarted)
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
		it.Event = new(SuperGasTankOwnershipTransferStarted)
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
func (it *SuperGasTankOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGasTankOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGasTankOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the SuperGasTank contract.
type SuperGasTankOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperGasTank *SuperGasTankFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SuperGasTankOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperGasTank.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankOwnershipTransferStartedIterator{contract: _SuperGasTank.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperGasTank *SuperGasTankFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *SuperGasTankOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperGasTank.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGasTankOwnershipTransferStarted)
				if err := _SuperGasTank.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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

// ParseOwnershipTransferStarted is a log parse operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperGasTank *SuperGasTankFilterer) ParseOwnershipTransferStarted(log types.Log) (*SuperGasTankOwnershipTransferStarted, error) {
	event := new(SuperGasTankOwnershipTransferStarted)
	if err := _SuperGasTank.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGasTankOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SuperGasTank contract.
type SuperGasTankOwnershipTransferredIterator struct {
	Event *SuperGasTankOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SuperGasTankOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGasTankOwnershipTransferred)
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
		it.Event = new(SuperGasTankOwnershipTransferred)
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
func (it *SuperGasTankOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGasTankOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGasTankOwnershipTransferred represents a OwnershipTransferred event raised by the SuperGasTank contract.
type SuperGasTankOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperGasTank *SuperGasTankFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SuperGasTankOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperGasTank.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SuperGasTankOwnershipTransferredIterator{contract: _SuperGasTank.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperGasTank *SuperGasTankFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SuperGasTankOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperGasTank.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGasTankOwnershipTransferred)
				if err := _SuperGasTank.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperGasTank *SuperGasTankFilterer) ParseOwnershipTransferred(log types.Log) (*SuperGasTankOwnershipTransferred, error) {
	event := new(SuperGasTankOwnershipTransferred)
	if err := _SuperGasTank.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
