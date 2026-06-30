// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package AcrossV3AdapterV2

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

// AcrossV3AdapterV2MetaData contains all meta data concerning the AcrossV3AdapterV2 contract.
var AcrossV3AdapterV2MetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"acrossSpokePool_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"ACROSS_SPOKE_POOL\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleV3AcrossMessage\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedAndExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_DST_PROOF_FOR_CHAIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// AcrossV3AdapterV2ABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossV3AdapterV2MetaData.ABI instead.
var AcrossV3AdapterV2ABI = AcrossV3AdapterV2MetaData.ABI

// AcrossV3AdapterV2 is an auto generated Go binding around an Ethereum contract.
type AcrossV3AdapterV2 struct {
	AcrossV3AdapterV2Caller     // Read-only binding to the contract
	AcrossV3AdapterV2Transactor // Write-only binding to the contract
	AcrossV3AdapterV2Filterer   // Log filterer for contract events
}

// AcrossV3AdapterV2Caller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterV2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterV2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossV3AdapterV2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterV2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossV3AdapterV2Session struct {
	Contract     *AcrossV3AdapterV2 // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// AcrossV3AdapterV2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossV3AdapterV2CallerSession struct {
	Contract *AcrossV3AdapterV2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// AcrossV3AdapterV2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossV3AdapterV2TransactorSession struct {
	Contract     *AcrossV3AdapterV2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// AcrossV3AdapterV2Raw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossV3AdapterV2Raw struct {
	Contract *AcrossV3AdapterV2 // Generic contract binding to access the raw methods on
}

// AcrossV3AdapterV2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2CallerRaw struct {
	Contract *AcrossV3AdapterV2Caller // Generic read-only contract binding to access the raw methods on
}

// AcrossV3AdapterV2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2TransactorRaw struct {
	Contract *AcrossV3AdapterV2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossV3AdapterV2 creates a new instance of AcrossV3AdapterV2, bound to a specific deployed contract.
func NewAcrossV3AdapterV2(address common.Address, backend bind.ContractBackend) (*AcrossV3AdapterV2, error) {
	contract, err := bindAcrossV3AdapterV2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2{AcrossV3AdapterV2Caller: AcrossV3AdapterV2Caller{contract: contract}, AcrossV3AdapterV2Transactor: AcrossV3AdapterV2Transactor{contract: contract}, AcrossV3AdapterV2Filterer: AcrossV3AdapterV2Filterer{contract: contract}}, nil
}

// NewAcrossV3AdapterV2Caller creates a new read-only instance of AcrossV3AdapterV2, bound to a specific deployed contract.
func NewAcrossV3AdapterV2Caller(address common.Address, caller bind.ContractCaller) (*AcrossV3AdapterV2Caller, error) {
	contract, err := bindAcrossV3AdapterV2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2Caller{contract: contract}, nil
}

// NewAcrossV3AdapterV2Transactor creates a new write-only instance of AcrossV3AdapterV2, bound to a specific deployed contract.
func NewAcrossV3AdapterV2Transactor(address common.Address, transactor bind.ContractTransactor) (*AcrossV3AdapterV2Transactor, error) {
	contract, err := bindAcrossV3AdapterV2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2Transactor{contract: contract}, nil
}

// NewAcrossV3AdapterV2Filterer creates a new log filterer instance of AcrossV3AdapterV2, bound to a specific deployed contract.
func NewAcrossV3AdapterV2Filterer(address common.Address, filterer bind.ContractFilterer) (*AcrossV3AdapterV2Filterer, error) {
	contract, err := bindAcrossV3AdapterV2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2Filterer{contract: contract}, nil
}

// bindAcrossV3AdapterV2 binds a generic wrapper to an already deployed contract.
func bindAcrossV3AdapterV2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossV3AdapterV2MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3AdapterV2.Contract.AcrossV3AdapterV2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.AcrossV3AdapterV2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.AcrossV3AdapterV2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3AdapterV2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.contract.Transact(opts, method, params...)
}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Caller) ACROSSSPOKEPOOL(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterV2.contract.Call(opts, &out, "ACROSS_SPOKE_POOL")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Session) ACROSSSPOKEPOOL() (common.Address, error) {
	return _AcrossV3AdapterV2.Contract.ACROSSSPOKEPOOL(&_AcrossV3AdapterV2.CallOpts)
}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2CallerSession) ACROSSSPOKEPOOL() (common.Address, error) {
	return _AcrossV3AdapterV2.Contract.ACROSSSPOKEPOOL(&_AcrossV3AdapterV2.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Caller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterV2.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Session) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _AcrossV3AdapterV2.Contract.SUPERDESTINATIONEXECUTOR(&_AcrossV3AdapterV2.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2CallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _AcrossV3AdapterV2.Contract.SUPERDESTINATIONEXECUTOR(&_AcrossV3AdapterV2.CallOpts)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Caller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterV2.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Session) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _AcrossV3AdapterV2.Contract.FailedTransfers(&_AcrossV3AdapterV2.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2CallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _AcrossV3AdapterV2.Contract.FailedTransfers(&_AcrossV3AdapterV2.CallOpts, account, token)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Transactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Session) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.ClaimFailedTransfer(&_AcrossV3AdapterV2.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2TransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.ClaimFailedTransfer(&_AcrossV3AdapterV2.TransactOpts, token, amount)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Transactor) HandleV3AcrossMessage(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.contract.Transact(opts, "handleV3AcrossMessage", tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Session) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.HandleV3AcrossMessage(&_AcrossV3AdapterV2.TransactOpts, tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2TransactorSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3AdapterV2.Contract.HandleV3AcrossMessage(&_AcrossV3AdapterV2.TransactOpts, tokenSent, amount, arg2, message)
}

// AcrossV3AdapterV2AcrossFundsReceivedAndExecutedIterator is returned from FilterAcrossFundsReceivedAndExecuted and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedAndExecuted events raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2AcrossFundsReceivedAndExecutedIterator struct {
	Event *AcrossV3AdapterV2AcrossFundsReceivedAndExecuted // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2AcrossFundsReceivedAndExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2AcrossFundsReceivedAndExecuted)
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
		it.Event = new(AcrossV3AdapterV2AcrossFundsReceivedAndExecuted)
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
func (it *AcrossV3AdapterV2AcrossFundsReceivedAndExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2AcrossFundsReceivedAndExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2AcrossFundsReceivedAndExecuted represents a AcrossFundsReceivedAndExecuted event raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2AcrossFundsReceivedAndExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedAndExecuted is a free log retrieval operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) FilterAcrossFundsReceivedAndExecuted(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterV2AcrossFundsReceivedAndExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.FilterLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2AcrossFundsReceivedAndExecutedIterator{contract: _AcrossV3AdapterV2.contract, event: "AcrossFundsReceivedAndExecuted", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedAndExecuted is a free log subscription operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) WatchAcrossFundsReceivedAndExecuted(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2AcrossFundsReceivedAndExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.WatchLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2AcrossFundsReceivedAndExecuted)
				if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
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

// ParseAcrossFundsReceivedAndExecuted is a log parse operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) ParseAcrossFundsReceivedAndExecuted(log types.Log) (*AcrossV3AdapterV2AcrossFundsReceivedAndExecuted, error) {
	event := new(AcrossV3AdapterV2AcrossFundsReceivedAndExecuted)
	if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailedIterator is returned from FilterAcrossFundsReceivedButExecutionFailed and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButExecutionFailed events raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailedIterator struct {
	Event *AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed)
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
		it.Event = new(AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed)
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
func (it *AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed represents a AcrossFundsReceivedButExecutionFailed event raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButExecutionFailed is a free log retrieval operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) FilterAcrossFundsReceivedButExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.FilterLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailedIterator{contract: _AcrossV3AdapterV2.contract, event: "AcrossFundsReceivedButExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButExecutionFailed is a free log subscription operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) WatchAcrossFundsReceivedButExecutionFailed(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.WatchLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed)
				if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
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

// ParseAcrossFundsReceivedButExecutionFailed is a log parse operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) ParseAcrossFundsReceivedButExecutionFailed(log types.Log) (*AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed, error) {
	event := new(AcrossV3AdapterV2AcrossFundsReceivedButExecutionFailed)
	if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalanceIterator is returned from FilterAcrossFundsReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButNotEnoughBalance events raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalanceIterator struct {
	Event *AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance)
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
		it.Event = new(AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance)
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
func (it *AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance represents a AcrossFundsReceivedButNotEnoughBalance event raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) FilterAcrossFundsReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.FilterLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalanceIterator{contract: _AcrossV3AdapterV2.contract, event: "AcrossFundsReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) WatchAcrossFundsReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.WatchLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance)
				if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
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

// ParseAcrossFundsReceivedButNotEnoughBalance is a log parse operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) ParseAcrossFundsReceivedButNotEnoughBalance(log types.Log) (*AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance, error) {
	event := new(AcrossV3AdapterV2AcrossFundsReceivedButNotEnoughBalance)
	if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2ExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2ExecutionFailedIterator struct {
	Event *AcrossV3AdapterV2ExecutionFailed // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2ExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2ExecutionFailed)
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
		it.Event = new(AcrossV3AdapterV2ExecutionFailed)
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
func (it *AcrossV3AdapterV2ExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2ExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2ExecutionFailed represents a ExecutionFailed event raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2ExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0x0cddc7f3a22f81520638293af12599a9ad1cc7a1a0b41c4e49b85d3ed8fdafad.
//
// Solidity: event ExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) FilterExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterV2ExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.FilterLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2ExecutionFailedIterator{contract: _AcrossV3AdapterV2.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0x0cddc7f3a22f81520638293af12599a9ad1cc7a1a0b41c4e49b85d3ed8fdafad.
//
// Solidity: event ExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2ExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.WatchLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2ExecutionFailed)
				if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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

// ParseExecutionFailed is a log parse operation binding the contract event 0x0cddc7f3a22f81520638293af12599a9ad1cc7a1a0b41c4e49b85d3ed8fdafad.
//
// Solidity: event ExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) ParseExecutionFailed(log types.Log) (*AcrossV3AdapterV2ExecutionFailed, error) {
	event := new(AcrossV3AdapterV2ExecutionFailed)
	if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2FailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2FailedTransferClaimedIterator struct {
	Event *AcrossV3AdapterV2FailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2FailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2FailedTransferClaimed)
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
		it.Event = new(AcrossV3AdapterV2FailedTransferClaimed)
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
func (it *AcrossV3AdapterV2FailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2FailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2FailedTransferClaimed represents a FailedTransferClaimed event raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2FailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*AcrossV3AdapterV2FailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2FailedTransferClaimedIterator{contract: _AcrossV3AdapterV2.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2FailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2FailedTransferClaimed)
				if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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

// ParseFailedTransferClaimed is a log parse operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) ParseFailedTransferClaimed(log types.Log) (*AcrossV3AdapterV2FailedTransferClaimed, error) {
	event := new(AcrossV3AdapterV2FailedTransferClaimed)
	if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2TransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2TransferFailedIterator struct {
	Event *AcrossV3AdapterV2TransferFailed // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2TransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2TransferFailed)
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
		it.Event = new(AcrossV3AdapterV2TransferFailed)
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
func (it *AcrossV3AdapterV2TransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2TransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2TransferFailed represents a TransferFailed event raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2TransferFailed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) FilterTransferFailed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*AcrossV3AdapterV2TransferFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.FilterLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2TransferFailedIterator{contract: _AcrossV3AdapterV2.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2TransferFailed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.WatchLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2TransferFailed)
				if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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

// ParseTransferFailed is a log parse operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) ParseTransferFailed(log types.Log) (*AcrossV3AdapterV2TransferFailed, error) {
	event := new(AcrossV3AdapterV2TransferFailed)
	if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2TransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2TransferSucceededIterator struct {
	Event *AcrossV3AdapterV2TransferSucceeded // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2TransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2TransferSucceeded)
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
		it.Event = new(AcrossV3AdapterV2TransferSucceeded)
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
func (it *AcrossV3AdapterV2TransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2TransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2TransferSucceeded represents a TransferSucceeded event raised by the AcrossV3AdapterV2 contract.
type AcrossV3AdapterV2TransferSucceeded struct {
	Account   common.Address
	TokenSent common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) FilterTransferSucceeded(opts *bind.FilterOpts, account []common.Address, tokenSent []common.Address) (*AcrossV3AdapterV2TransferSucceededIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.FilterLogs(opts, "TransferSucceeded", accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2TransferSucceededIterator{contract: _AcrossV3AdapterV2.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2TransferSucceeded, account []common.Address, tokenSent []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _AcrossV3AdapterV2.contract.WatchLogs(opts, "TransferSucceeded", accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2TransferSucceeded)
				if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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

// ParseTransferSucceeded is a log parse operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount)
func (_AcrossV3AdapterV2 *AcrossV3AdapterV2Filterer) ParseTransferSucceeded(log types.Log) (*AcrossV3AdapterV2TransferSucceeded, error) {
	event := new(AcrossV3AdapterV2TransferSucceeded)
	if err := _AcrossV3AdapterV2.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
