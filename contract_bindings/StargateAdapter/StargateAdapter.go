// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package StargateAdapter

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

// StargateAdapterMetaData contains all meta data concerning the StargateAdapter contract.
var StargateAdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"lzEndpoint_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"LZ_ENDPOINT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lzCompose\",\"inputs\":[{\"name\":\"_from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"ComposeExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"COMPOSE_MSG_TOO_SHORT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// StargateAdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use StargateAdapterMetaData.ABI instead.
var StargateAdapterABI = StargateAdapterMetaData.ABI

// StargateAdapter is an auto generated Go binding around an Ethereum contract.
type StargateAdapter struct {
	StargateAdapterCaller     // Read-only binding to the contract
	StargateAdapterTransactor // Write-only binding to the contract
	StargateAdapterFilterer   // Log filterer for contract events
}

// StargateAdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type StargateAdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type StargateAdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type StargateAdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type StargateAdapterSession struct {
	Contract     *StargateAdapter  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// StargateAdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type StargateAdapterCallerSession struct {
	Contract *StargateAdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// StargateAdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type StargateAdapterTransactorSession struct {
	Contract     *StargateAdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// StargateAdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type StargateAdapterRaw struct {
	Contract *StargateAdapter // Generic contract binding to access the raw methods on
}

// StargateAdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type StargateAdapterCallerRaw struct {
	Contract *StargateAdapterCaller // Generic read-only contract binding to access the raw methods on
}

// StargateAdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type StargateAdapterTransactorRaw struct {
	Contract *StargateAdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewStargateAdapter creates a new instance of StargateAdapter, bound to a specific deployed contract.
func NewStargateAdapter(address common.Address, backend bind.ContractBackend) (*StargateAdapter, error) {
	contract, err := bindStargateAdapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &StargateAdapter{StargateAdapterCaller: StargateAdapterCaller{contract: contract}, StargateAdapterTransactor: StargateAdapterTransactor{contract: contract}, StargateAdapterFilterer: StargateAdapterFilterer{contract: contract}}, nil
}

// NewStargateAdapterCaller creates a new read-only instance of StargateAdapter, bound to a specific deployed contract.
func NewStargateAdapterCaller(address common.Address, caller bind.ContractCaller) (*StargateAdapterCaller, error) {
	contract, err := bindStargateAdapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterCaller{contract: contract}, nil
}

// NewStargateAdapterTransactor creates a new write-only instance of StargateAdapter, bound to a specific deployed contract.
func NewStargateAdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*StargateAdapterTransactor, error) {
	contract, err := bindStargateAdapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTransactor{contract: contract}, nil
}

// NewStargateAdapterFilterer creates a new log filterer instance of StargateAdapter, bound to a specific deployed contract.
func NewStargateAdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*StargateAdapterFilterer, error) {
	contract, err := bindStargateAdapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterFilterer{contract: contract}, nil
}

// bindStargateAdapter binds a generic wrapper to an already deployed contract.
func bindStargateAdapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := StargateAdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapter *StargateAdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapter.Contract.StargateAdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapter *StargateAdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapter.Contract.StargateAdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapter *StargateAdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapter.Contract.StargateAdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapter *StargateAdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapter *StargateAdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapter *StargateAdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapter.Contract.contract.Transact(opts, method, params...)
}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapter *StargateAdapterCaller) LZENDPOINT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapter.contract.Call(opts, &out, "LZ_ENDPOINT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapter *StargateAdapterSession) LZENDPOINT() (common.Address, error) {
	return _StargateAdapter.Contract.LZENDPOINT(&_StargateAdapter.CallOpts)
}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapter *StargateAdapterCallerSession) LZENDPOINT() (common.Address, error) {
	return _StargateAdapter.Contract.LZENDPOINT(&_StargateAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapter *StargateAdapterCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapter.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapter *StargateAdapterSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _StargateAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_StargateAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapter *StargateAdapterCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _StargateAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_StargateAdapter.CallOpts)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 , bytes _message, address , bytes ) payable returns()
func (_StargateAdapter *StargateAdapterTransactor) LzCompose(opts *bind.TransactOpts, _from common.Address, arg1 [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapter.contract.Transact(opts, "lzCompose", _from, arg1, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 , bytes _message, address , bytes ) payable returns()
func (_StargateAdapter *StargateAdapterSession) LzCompose(_from common.Address, arg1 [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapter.Contract.LzCompose(&_StargateAdapter.TransactOpts, _from, arg1, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 , bytes _message, address , bytes ) payable returns()
func (_StargateAdapter *StargateAdapterTransactorSession) LzCompose(_from common.Address, arg1 [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapter.Contract.LzCompose(&_StargateAdapter.TransactOpts, _from, arg1, _message, arg3, arg4)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapter *StargateAdapterTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapter.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapter *StargateAdapterSession) Receive() (*types.Transaction, error) {
	return _StargateAdapter.Contract.Receive(&_StargateAdapter.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapter *StargateAdapterTransactorSession) Receive() (*types.Transaction, error) {
	return _StargateAdapter.Contract.Receive(&_StargateAdapter.TransactOpts)
}

// StargateAdapterComposeExecutedIterator is returned from FilterComposeExecuted and is used to iterate over the raw logs and unpacked data for ComposeExecuted events raised by the StargateAdapter contract.
type StargateAdapterComposeExecutedIterator struct {
	Event *StargateAdapterComposeExecuted // Event containing the contract specifics and raw log

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
func (it *StargateAdapterComposeExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterComposeExecuted)
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
		it.Event = new(StargateAdapterComposeExecuted)
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
func (it *StargateAdapterComposeExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterComposeExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterComposeExecuted represents a ComposeExecuted event raised by the StargateAdapter contract.
type StargateAdapterComposeExecuted struct {
	Account   common.Address
	TokenSent common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterComposeExecuted is a free log retrieval operation binding the contract event 0x33fc84c61dbf37560c160a927f1a487057cf2c60cf84f5b2d939b780cf1c2d3f.
//
// Solidity: event ComposeExecuted(address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) FilterComposeExecuted(opts *bind.FilterOpts, account []common.Address, tokenSent []common.Address) (*StargateAdapterComposeExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "ComposeExecuted", accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterComposeExecutedIterator{contract: _StargateAdapter.contract, event: "ComposeExecuted", logs: logs, sub: sub}, nil
}

// WatchComposeExecuted is a free log subscription operation binding the contract event 0x33fc84c61dbf37560c160a927f1a487057cf2c60cf84f5b2d939b780cf1c2d3f.
//
// Solidity: event ComposeExecuted(address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) WatchComposeExecuted(opts *bind.WatchOpts, sink chan<- *StargateAdapterComposeExecuted, account []common.Address, tokenSent []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "ComposeExecuted", accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterComposeExecuted)
				if err := _StargateAdapter.contract.UnpackLog(event, "ComposeExecuted", log); err != nil {
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

// ParseComposeExecuted is a log parse operation binding the contract event 0x33fc84c61dbf37560c160a927f1a487057cf2c60cf84f5b2d939b780cf1c2d3f.
//
// Solidity: event ComposeExecuted(address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) ParseComposeExecuted(log types.Log) (*StargateAdapterComposeExecuted, error) {
	event := new(StargateAdapterComposeExecuted)
	if err := _StargateAdapter.contract.UnpackLog(event, "ComposeExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
