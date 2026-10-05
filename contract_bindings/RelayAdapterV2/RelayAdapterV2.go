// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package RelayAdapterV2

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

// RelayAdapterV2MetaData contains all meta data concerning the RelayAdapterV2 contract.
var RelayAdapterV2MetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"processRelayExecution\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"totalEscrowed\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SpendableBalanceRetained\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_CREATED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EXECUTOR_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FUNDS_RECEIVED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_GAS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SIGNATURE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MSG_VALUE_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_DST_PROOF_FOR_CHAIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SENDER_CREATOR_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TOKEN_NOT_IN_SIGNED_INTENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VALIDATOR_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// RelayAdapterV2ABI is the input ABI used to generate the binding from.
// Deprecated: Use RelayAdapterV2MetaData.ABI instead.
var RelayAdapterV2ABI = RelayAdapterV2MetaData.ABI

// RelayAdapterV2 is an auto generated Go binding around an Ethereum contract.
type RelayAdapterV2 struct {
	RelayAdapterV2Caller     // Read-only binding to the contract
	RelayAdapterV2Transactor // Write-only binding to the contract
	RelayAdapterV2Filterer   // Log filterer for contract events
}

// RelayAdapterV2Caller is an auto generated read-only Go binding around an Ethereum contract.
type RelayAdapterV2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayAdapterV2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type RelayAdapterV2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayAdapterV2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RelayAdapterV2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayAdapterV2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type RelayAdapterV2Session struct {
	Contract     *RelayAdapterV2   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// RelayAdapterV2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type RelayAdapterV2CallerSession struct {
	Contract *RelayAdapterV2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// RelayAdapterV2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type RelayAdapterV2TransactorSession struct {
	Contract     *RelayAdapterV2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// RelayAdapterV2Raw is an auto generated low-level Go binding around an Ethereum contract.
type RelayAdapterV2Raw struct {
	Contract *RelayAdapterV2 // Generic contract binding to access the raw methods on
}

// RelayAdapterV2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RelayAdapterV2CallerRaw struct {
	Contract *RelayAdapterV2Caller // Generic read-only contract binding to access the raw methods on
}

// RelayAdapterV2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RelayAdapterV2TransactorRaw struct {
	Contract *RelayAdapterV2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewRelayAdapterV2 creates a new instance of RelayAdapterV2, bound to a specific deployed contract.
func NewRelayAdapterV2(address common.Address, backend bind.ContractBackend) (*RelayAdapterV2, error) {
	contract, err := bindRelayAdapterV2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2{RelayAdapterV2Caller: RelayAdapterV2Caller{contract: contract}, RelayAdapterV2Transactor: RelayAdapterV2Transactor{contract: contract}, RelayAdapterV2Filterer: RelayAdapterV2Filterer{contract: contract}}, nil
}

// NewRelayAdapterV2Caller creates a new read-only instance of RelayAdapterV2, bound to a specific deployed contract.
func NewRelayAdapterV2Caller(address common.Address, caller bind.ContractCaller) (*RelayAdapterV2Caller, error) {
	contract, err := bindRelayAdapterV2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2Caller{contract: contract}, nil
}

// NewRelayAdapterV2Transactor creates a new write-only instance of RelayAdapterV2, bound to a specific deployed contract.
func NewRelayAdapterV2Transactor(address common.Address, transactor bind.ContractTransactor) (*RelayAdapterV2Transactor, error) {
	contract, err := bindRelayAdapterV2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2Transactor{contract: contract}, nil
}

// NewRelayAdapterV2Filterer creates a new log filterer instance of RelayAdapterV2, bound to a specific deployed contract.
func NewRelayAdapterV2Filterer(address common.Address, filterer bind.ContractFilterer) (*RelayAdapterV2Filterer, error) {
	contract, err := bindRelayAdapterV2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2Filterer{contract: contract}, nil
}

// bindRelayAdapterV2 binds a generic wrapper to an already deployed contract.
func bindRelayAdapterV2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := RelayAdapterV2MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RelayAdapterV2 *RelayAdapterV2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RelayAdapterV2.Contract.RelayAdapterV2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RelayAdapterV2 *RelayAdapterV2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.RelayAdapterV2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RelayAdapterV2 *RelayAdapterV2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.RelayAdapterV2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RelayAdapterV2 *RelayAdapterV2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RelayAdapterV2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RelayAdapterV2 *RelayAdapterV2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RelayAdapterV2 *RelayAdapterV2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.contract.Transact(opts, method, params...)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_RelayAdapterV2 *RelayAdapterV2Caller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RelayAdapterV2.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_RelayAdapterV2 *RelayAdapterV2Session) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _RelayAdapterV2.Contract.SUPERDESTINATIONEXECUTOR(&_RelayAdapterV2.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_RelayAdapterV2 *RelayAdapterV2CallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _RelayAdapterV2.Contract.SUPERDESTINATIONEXECUTOR(&_RelayAdapterV2.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_RelayAdapterV2 *RelayAdapterV2Caller) SUPERDESTINATIONVALIDATOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RelayAdapterV2.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_RelayAdapterV2 *RelayAdapterV2Session) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _RelayAdapterV2.Contract.SUPERDESTINATIONVALIDATOR(&_RelayAdapterV2.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_RelayAdapterV2 *RelayAdapterV2CallerSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _RelayAdapterV2.Contract.SUPERDESTINATIONVALIDATOR(&_RelayAdapterV2.CallOpts)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Caller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _RelayAdapterV2.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Session) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _RelayAdapterV2.Contract.FailedTransfers(&_RelayAdapterV2.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2CallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _RelayAdapterV2.Contract.FailedTransfers(&_RelayAdapterV2.CallOpts, account, token)
}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Caller) TotalEscrowed(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _RelayAdapterV2.contract.Call(opts, &out, "totalEscrowed", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Session) TotalEscrowed(token common.Address) (*big.Int, error) {
	return _RelayAdapterV2.Contract.TotalEscrowed(&_RelayAdapterV2.CallOpts, token)
}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2CallerSession) TotalEscrowed(token common.Address) (*big.Int, error) {
	return _RelayAdapterV2.Contract.TotalEscrowed(&_RelayAdapterV2.CallOpts, token)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_RelayAdapterV2 *RelayAdapterV2Transactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _RelayAdapterV2.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_RelayAdapterV2 *RelayAdapterV2Session) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.ClaimFailedTransfer(&_RelayAdapterV2.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_RelayAdapterV2 *RelayAdapterV2TransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.ClaimFailedTransfer(&_RelayAdapterV2.TransactOpts, token, amount)
}

// ProcessRelayExecution is a paid mutator transaction binding the contract method 0xd69dd152.
//
// Solidity: function processRelayExecution(address tokenSent, uint256 amount, bytes message) payable returns()
func (_RelayAdapterV2 *RelayAdapterV2Transactor) ProcessRelayExecution(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, message []byte) (*types.Transaction, error) {
	return _RelayAdapterV2.contract.Transact(opts, "processRelayExecution", tokenSent, amount, message)
}

// ProcessRelayExecution is a paid mutator transaction binding the contract method 0xd69dd152.
//
// Solidity: function processRelayExecution(address tokenSent, uint256 amount, bytes message) payable returns()
func (_RelayAdapterV2 *RelayAdapterV2Session) ProcessRelayExecution(tokenSent common.Address, amount *big.Int, message []byte) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.ProcessRelayExecution(&_RelayAdapterV2.TransactOpts, tokenSent, amount, message)
}

// ProcessRelayExecution is a paid mutator transaction binding the contract method 0xd69dd152.
//
// Solidity: function processRelayExecution(address tokenSent, uint256 amount, bytes message) payable returns()
func (_RelayAdapterV2 *RelayAdapterV2TransactorSession) ProcessRelayExecution(tokenSent common.Address, amount *big.Int, message []byte) (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.ProcessRelayExecution(&_RelayAdapterV2.TransactOpts, tokenSent, amount, message)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_RelayAdapterV2 *RelayAdapterV2Transactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayAdapterV2.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_RelayAdapterV2 *RelayAdapterV2Session) Receive() (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.Receive(&_RelayAdapterV2.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_RelayAdapterV2 *RelayAdapterV2TransactorSession) Receive() (*types.Transaction, error) {
	return _RelayAdapterV2.Contract.Receive(&_RelayAdapterV2.TransactOpts)
}

// RelayAdapterV2ExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the RelayAdapterV2 contract.
type RelayAdapterV2ExecutionFailedIterator struct {
	Event *RelayAdapterV2ExecutionFailed // Event containing the contract specifics and raw log

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
func (it *RelayAdapterV2ExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterV2ExecutionFailed)
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
		it.Event = new(RelayAdapterV2ExecutionFailed)
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
func (it *RelayAdapterV2ExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterV2ExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterV2ExecutionFailed represents a ExecutionFailed event raised by the RelayAdapterV2 contract.
type RelayAdapterV2ExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0x0cddc7f3a22f81520638293af12599a9ad1cc7a1a0b41c4e49b85d3ed8fdafad.
//
// Solidity: event ExecutionFailed(address indexed account)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) FilterExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*RelayAdapterV2ExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.FilterLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2ExecutionFailedIterator{contract: _RelayAdapterV2.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0x0cddc7f3a22f81520638293af12599a9ad1cc7a1a0b41c4e49b85d3ed8fdafad.
//
// Solidity: event ExecutionFailed(address indexed account)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *RelayAdapterV2ExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.WatchLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterV2ExecutionFailed)
				if err := _RelayAdapterV2.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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
func (_RelayAdapterV2 *RelayAdapterV2Filterer) ParseExecutionFailed(log types.Log) (*RelayAdapterV2ExecutionFailed, error) {
	event := new(RelayAdapterV2ExecutionFailed)
	if err := _RelayAdapterV2.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayAdapterV2FailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the RelayAdapterV2 contract.
type RelayAdapterV2FailedTransferClaimedIterator struct {
	Event *RelayAdapterV2FailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *RelayAdapterV2FailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterV2FailedTransferClaimed)
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
		it.Event = new(RelayAdapterV2FailedTransferClaimed)
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
func (it *RelayAdapterV2FailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterV2FailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterV2FailedTransferClaimed represents a FailedTransferClaimed event raised by the RelayAdapterV2 contract.
type RelayAdapterV2FailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*RelayAdapterV2FailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2FailedTransferClaimedIterator{contract: _RelayAdapterV2.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *RelayAdapterV2FailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterV2FailedTransferClaimed)
				if err := _RelayAdapterV2.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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
func (_RelayAdapterV2 *RelayAdapterV2Filterer) ParseFailedTransferClaimed(log types.Log) (*RelayAdapterV2FailedTransferClaimed, error) {
	event := new(RelayAdapterV2FailedTransferClaimed)
	if err := _RelayAdapterV2.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayAdapterV2SpendableBalanceRetainedIterator is returned from FilterSpendableBalanceRetained and is used to iterate over the raw logs and unpacked data for SpendableBalanceRetained events raised by the RelayAdapterV2 contract.
type RelayAdapterV2SpendableBalanceRetainedIterator struct {
	Event *RelayAdapterV2SpendableBalanceRetained // Event containing the contract specifics and raw log

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
func (it *RelayAdapterV2SpendableBalanceRetainedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterV2SpendableBalanceRetained)
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
		it.Event = new(RelayAdapterV2SpendableBalanceRetained)
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
func (it *RelayAdapterV2SpendableBalanceRetainedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterV2SpendableBalanceRetainedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterV2SpendableBalanceRetained represents a SpendableBalanceRetained event raised by the RelayAdapterV2 contract.
type RelayAdapterV2SpendableBalanceRetained struct {
	Token  common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterSpendableBalanceRetained is a free log retrieval operation binding the contract event 0x4a057963c9b5ad8ba509dba46b0b85db815aab189091ec16183271ee7170bf29.
//
// Solidity: event SpendableBalanceRetained(address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) FilterSpendableBalanceRetained(opts *bind.FilterOpts, token []common.Address) (*RelayAdapterV2SpendableBalanceRetainedIterator, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.FilterLogs(opts, "SpendableBalanceRetained", tokenRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2SpendableBalanceRetainedIterator{contract: _RelayAdapterV2.contract, event: "SpendableBalanceRetained", logs: logs, sub: sub}, nil
}

// WatchSpendableBalanceRetained is a free log subscription operation binding the contract event 0x4a057963c9b5ad8ba509dba46b0b85db815aab189091ec16183271ee7170bf29.
//
// Solidity: event SpendableBalanceRetained(address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) WatchSpendableBalanceRetained(opts *bind.WatchOpts, sink chan<- *RelayAdapterV2SpendableBalanceRetained, token []common.Address) (event.Subscription, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.WatchLogs(opts, "SpendableBalanceRetained", tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterV2SpendableBalanceRetained)
				if err := _RelayAdapterV2.contract.UnpackLog(event, "SpendableBalanceRetained", log); err != nil {
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

// ParseSpendableBalanceRetained is a log parse operation binding the contract event 0x4a057963c9b5ad8ba509dba46b0b85db815aab189091ec16183271ee7170bf29.
//
// Solidity: event SpendableBalanceRetained(address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) ParseSpendableBalanceRetained(log types.Log) (*RelayAdapterV2SpendableBalanceRetained, error) {
	event := new(RelayAdapterV2SpendableBalanceRetained)
	if err := _RelayAdapterV2.contract.UnpackLog(event, "SpendableBalanceRetained", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayAdapterV2TransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the RelayAdapterV2 contract.
type RelayAdapterV2TransferFailedIterator struct {
	Event *RelayAdapterV2TransferFailed // Event containing the contract specifics and raw log

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
func (it *RelayAdapterV2TransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterV2TransferFailed)
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
		it.Event = new(RelayAdapterV2TransferFailed)
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
func (it *RelayAdapterV2TransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterV2TransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterV2TransferFailed represents a TransferFailed event raised by the RelayAdapterV2 contract.
type RelayAdapterV2TransferFailed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) FilterTransferFailed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*RelayAdapterV2TransferFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.FilterLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2TransferFailedIterator{contract: _RelayAdapterV2.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *RelayAdapterV2TransferFailed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.WatchLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterV2TransferFailed)
				if err := _RelayAdapterV2.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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
func (_RelayAdapterV2 *RelayAdapterV2Filterer) ParseTransferFailed(log types.Log) (*RelayAdapterV2TransferFailed, error) {
	event := new(RelayAdapterV2TransferFailed)
	if err := _RelayAdapterV2.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayAdapterV2TransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the RelayAdapterV2 contract.
type RelayAdapterV2TransferSucceededIterator struct {
	Event *RelayAdapterV2TransferSucceeded // Event containing the contract specifics and raw log

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
func (it *RelayAdapterV2TransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayAdapterV2TransferSucceeded)
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
		it.Event = new(RelayAdapterV2TransferSucceeded)
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
func (it *RelayAdapterV2TransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayAdapterV2TransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayAdapterV2TransferSucceeded represents a TransferSucceeded event raised by the RelayAdapterV2 contract.
type RelayAdapterV2TransferSucceeded struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) FilterTransferSucceeded(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*RelayAdapterV2TransferSucceededIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.FilterLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &RelayAdapterV2TransferSucceededIterator{contract: _RelayAdapterV2.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *RelayAdapterV2TransferSucceeded, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _RelayAdapterV2.contract.WatchLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayAdapterV2TransferSucceeded)
				if err := _RelayAdapterV2.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_RelayAdapterV2 *RelayAdapterV2Filterer) ParseTransferSucceeded(log types.Log) (*RelayAdapterV2TransferSucceeded, error) {
	event := new(RelayAdapterV2TransferSucceeded)
	if err := _RelayAdapterV2.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
