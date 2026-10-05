// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package RelayAdapter

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

// RelayAdapterMetaData contains all meta data concerning the RelayAdapter contract.
var RelayAdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"processRelayExecution\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"totalEscrowed\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FUNDS_RECEIVED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MSG_VALUE_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_DST_PROOF_FOR_CHAIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// RelayAdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use RelayAdapterMetaData.ABI instead.
var RelayAdapterABI = RelayAdapterMetaData.ABI

// RelayAdapter is an auto generated Go binding around an Ethereum contract.
type RelayAdapter struct {
	RelayAdapterCaller     // Read-only binding to the contract
	RelayAdapterTransactor // Write-only binding to the contract
	RelayAdapterFilterer   // Log filterer for contract events
}

// RelayAdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type RelayAdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayAdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type RelayAdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayAdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RelayAdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayAdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type RelayAdapterSession struct {
	Contract     *RelayAdapter     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// RelayAdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type RelayAdapterCallerSession struct {
	Contract *RelayAdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// RelayAdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type RelayAdapterTransactorSession struct {
	Contract     *RelayAdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// RelayAdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type RelayAdapterRaw struct {
	Contract *RelayAdapter // Generic contract binding to access the raw methods on
}

// RelayAdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RelayAdapterCallerRaw struct {
	Contract *RelayAdapterCaller // Generic read-only contract binding to access the raw methods on
}

// RelayAdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RelayAdapterTransactorRaw struct {
	Contract *RelayAdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewRelayAdapter creates a new instance of RelayAdapter, bound to a specific deployed contract.
func NewRelayAdapter(address common.Address, backend bind.ContractBackend) (*RelayAdapter, error) {
	contract, err := bindRelayAdapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &RelayAdapter{RelayAdapterCaller: RelayAdapterCaller{contract: contract}, RelayAdapterTransactor: RelayAdapterTransactor{contract: contract}, RelayAdapterFilterer: RelayAdapterFilterer{contract: contract}}, nil
}

// NewRelayAdapterCaller creates a new read-only instance of RelayAdapter, bound to a specific deployed contract.
func NewRelayAdapterCaller(address common.Address, caller bind.ContractCaller) (*RelayAdapterCaller, error) {
	contract, err := bindRelayAdapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterCaller{contract: contract}, nil
}

// NewRelayAdapterTransactor creates a new write-only instance of RelayAdapter, bound to a specific deployed contract.
func NewRelayAdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*RelayAdapterTransactor, error) {
	contract, err := bindRelayAdapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterTransactor{contract: contract}, nil
}

// NewRelayAdapterFilterer creates a new log filterer instance of RelayAdapter, bound to a specific deployed contract.
func NewRelayAdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*RelayAdapterFilterer, error) {
	contract, err := bindRelayAdapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterFilterer{contract: contract}, nil
}

// bindRelayAdapter binds a generic wrapper to an already deployed contract.
func bindRelayAdapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := RelayAdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RelayAdapter *RelayAdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RelayAdapter.Contract.RelayAdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RelayAdapter *RelayAdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayAdapter.Contract.RelayAdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RelayAdapter *RelayAdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RelayAdapter.Contract.RelayAdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RelayAdapter *RelayAdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RelayAdapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RelayAdapter *RelayAdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayAdapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RelayAdapter *RelayAdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RelayAdapter.Contract.contract.Transact(opts, method, params...)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_RelayAdapter *RelayAdapterCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RelayAdapter.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_RelayAdapter *RelayAdapterSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _RelayAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_RelayAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_RelayAdapter *RelayAdapterCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _RelayAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_RelayAdapter.CallOpts)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_RelayAdapter *RelayAdapterCaller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _RelayAdapter.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_RelayAdapter *RelayAdapterSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _RelayAdapter.Contract.FailedTransfers(&_RelayAdapter.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_RelayAdapter *RelayAdapterCallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _RelayAdapter.Contract.FailedTransfers(&_RelayAdapter.CallOpts, account, token)
}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_RelayAdapter *RelayAdapterCaller) TotalEscrowed(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _RelayAdapter.contract.Call(opts, &out, "totalEscrowed", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_RelayAdapter *RelayAdapterSession) TotalEscrowed(token common.Address) (*big.Int, error) {
	return _RelayAdapter.Contract.TotalEscrowed(&_RelayAdapter.CallOpts, token)
}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_RelayAdapter *RelayAdapterCallerSession) TotalEscrowed(token common.Address) (*big.Int, error) {
	return _RelayAdapter.Contract.TotalEscrowed(&_RelayAdapter.CallOpts, token)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_RelayAdapter *RelayAdapterTransactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _RelayAdapter.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_RelayAdapter *RelayAdapterSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _RelayAdapter.Contract.ClaimFailedTransfer(&_RelayAdapter.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_RelayAdapter *RelayAdapterTransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _RelayAdapter.Contract.ClaimFailedTransfer(&_RelayAdapter.TransactOpts, token, amount)
}

// ProcessRelayExecution is a paid mutator transaction binding the contract method 0xd69dd152.
//
// Solidity: function processRelayExecution(address tokenSent, uint256 amount, bytes message) payable returns()
func (_RelayAdapter *RelayAdapterTransactor) ProcessRelayExecution(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, message []byte) (*types.Transaction, error) {
	return _RelayAdapter.contract.Transact(opts, "processRelayExecution", tokenSent, amount, message)
}

// ProcessRelayExecution is a paid mutator transaction binding the contract method 0xd69dd152.
//
// Solidity: function processRelayExecution(address tokenSent, uint256 amount, bytes message) payable returns()
func (_RelayAdapter *RelayAdapterSession) ProcessRelayExecution(tokenSent common.Address, amount *big.Int, message []byte) (*types.Transaction, error) {
	return _RelayAdapter.Contract.ProcessRelayExecution(&_RelayAdapter.TransactOpts, tokenSent, amount, message)
}

// ProcessRelayExecution is a paid mutator transaction binding the contract method 0xd69dd152.
//
// Solidity: function processRelayExecution(address tokenSent, uint256 amount, bytes message) payable returns()
func (_RelayAdapter *RelayAdapterTransactorSession) ProcessRelayExecution(tokenSent common.Address, amount *big.Int, message []byte) (*types.Transaction, error) {
	return _RelayAdapter.Contract.ProcessRelayExecution(&_RelayAdapter.TransactOpts, tokenSent, amount, message)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_RelayAdapter *RelayAdapterTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayAdapter.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_RelayAdapter *RelayAdapterSession) Receive() (*types.Transaction, error) {
	return _RelayAdapter.Contract.Receive(&_RelayAdapter.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_RelayAdapter *RelayAdapterTransactorSession) Receive() (*types.Transaction, error) {
	return _RelayAdapter.Contract.Receive(&_RelayAdapter.TransactOpts)
}

// RelayAdapterExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the RelayAdapter contract.
type RelayAdapterExecutionFailedIterator struct {
	Event *RelayAdapterExecutionFailed // Event containing the contract specifics and raw log

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
func (it *RelayAdapterExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterExecutionFailed)
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
		it.Event = new(RelayAdapterExecutionFailed)
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
func (it *RelayAdapterExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterExecutionFailed represents a ExecutionFailed event raised by the RelayAdapter contract.
type RelayAdapterExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0x0cddc7f3a22f81520638293af12599a9ad1cc7a1a0b41c4e49b85d3ed8fdafad.
//
// Solidity: event ExecutionFailed(address indexed account)
func (_RelayAdapter *RelayAdapterFilterer) FilterExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*RelayAdapterExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _RelayAdapter.contract.FilterLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterExecutionFailedIterator{contract: _RelayAdapter.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0x0cddc7f3a22f81520638293af12599a9ad1cc7a1a0b41c4e49b85d3ed8fdafad.
//
// Solidity: event ExecutionFailed(address indexed account)
func (_RelayAdapter *RelayAdapterFilterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *RelayAdapterExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _RelayAdapter.contract.WatchLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterExecutionFailed)
				if err := _RelayAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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
func (_RelayAdapter *RelayAdapterFilterer) ParseExecutionFailed(log types.Log) (*RelayAdapterExecutionFailed, error) {
	event := new(RelayAdapterExecutionFailed)
	if err := _RelayAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayAdapterFailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the RelayAdapter contract.
type RelayAdapterFailedTransferClaimedIterator struct {
	Event *RelayAdapterFailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *RelayAdapterFailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterFailedTransferClaimed)
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
		it.Event = new(RelayAdapterFailedTransferClaimed)
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
func (it *RelayAdapterFailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterFailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterFailedTransferClaimed represents a FailedTransferClaimed event raised by the RelayAdapter contract.
type RelayAdapterFailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapter *RelayAdapterFilterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*RelayAdapterFailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapter.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterFailedTransferClaimedIterator{contract: _RelayAdapter.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapter *RelayAdapterFilterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *RelayAdapterFailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapter.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterFailedTransferClaimed)
				if err := _RelayAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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
func (_RelayAdapter *RelayAdapterFilterer) ParseFailedTransferClaimed(log types.Log) (*RelayAdapterFailedTransferClaimed, error) {
	event := new(RelayAdapterFailedTransferClaimed)
	if err := _RelayAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayAdapterTransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the RelayAdapter contract.
type RelayAdapterTransferFailedIterator struct {
	Event *RelayAdapterTransferFailed // Event containing the contract specifics and raw log

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
func (it *RelayAdapterTransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterTransferFailed)
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
		it.Event = new(RelayAdapterTransferFailed)
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
func (it *RelayAdapterTransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterTransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterTransferFailed represents a TransferFailed event raised by the RelayAdapter contract.
type RelayAdapterTransferFailed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapter *RelayAdapterFilterer) FilterTransferFailed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*RelayAdapterTransferFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapter.contract.FilterLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterTransferFailedIterator{contract: _RelayAdapter.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapter *RelayAdapterFilterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *RelayAdapterTransferFailed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapter.contract.WatchLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterTransferFailed)
				if err := _RelayAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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
func (_RelayAdapter *RelayAdapterFilterer) ParseTransferFailed(log types.Log) (*RelayAdapterTransferFailed, error) {
	event := new(RelayAdapterTransferFailed)
	if err := _RelayAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayAdapterTransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the RelayAdapter contract.
type RelayAdapterTransferSucceededIterator struct {
	Event *RelayAdapterTransferSucceeded // Event containing the contract specifics and raw log

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
func (it *RelayAdapterTransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterTransferSucceeded)
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
		it.Event = new(RelayAdapterTransferSucceeded)
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
func (it *RelayAdapterTransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterTransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterTransferSucceeded represents a TransferSucceeded event raised by the RelayAdapter contract.
type RelayAdapterTransferSucceeded struct {
	Account   common.Address
	TokenSent common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount)
func (_RelayAdapter *RelayAdapterFilterer) FilterTransferSucceeded(opts *bind.FilterOpts, account []common.Address, tokenSent []common.Address) (*RelayAdapterTransferSucceededIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _RelayAdapter.contract.FilterLogs(opts, "TransferSucceeded", accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterTransferSucceededIterator{contract: _RelayAdapter.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount)
func (_RelayAdapter *RelayAdapterFilterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *RelayAdapterTransferSucceeded, account []common.Address, tokenSent []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _RelayAdapter.contract.WatchLogs(opts, "TransferSucceeded", accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterTransferSucceeded)
				if err := _RelayAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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
func (_RelayAdapter *RelayAdapterFilterer) ParseTransferSucceeded(log types.Log) (*RelayAdapterTransferSucceeded, error) {
	event := new(RelayAdapterTransferSucceeded)
	if err := _RelayAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
