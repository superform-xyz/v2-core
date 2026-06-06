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
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"lzEndpoint_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokenMessaging_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"LZ_ENDPOINT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TOKEN_MESSAGING\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractITokenMessaging\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleCompose\",\"inputs\":[{\"name\":\"_guid\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountLD\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"composeFrom\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lzCompose\",\"inputs\":[{\"name\":\"_from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_guid\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"ComposeDecodeFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ComposeMsgTooShort\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"messageLength\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TokenResolutionFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UnregisteredPool\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
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

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapter *StargateAdapterCaller) TOKENMESSAGING(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapter.contract.Call(opts, &out, "TOKEN_MESSAGING")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapter *StargateAdapterSession) TOKENMESSAGING() (common.Address, error) {
	return _StargateAdapter.Contract.TOKENMESSAGING(&_StargateAdapter.CallOpts)
}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapter *StargateAdapterCallerSession) TOKENMESSAGING() (common.Address, error) {
	return _StargateAdapter.Contract.TOKENMESSAGING(&_StargateAdapter.CallOpts)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapter *StargateAdapterCaller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapter.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapter *StargateAdapterSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _StargateAdapter.Contract.FailedTransfers(&_StargateAdapter.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapter *StargateAdapterCallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _StargateAdapter.Contract.FailedTransfers(&_StargateAdapter.CallOpts, account, token)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapter *StargateAdapterTransactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapter.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapter *StargateAdapterSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapter.Contract.ClaimFailedTransfer(&_StargateAdapter.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapter *StargateAdapterTransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapter.Contract.ClaimFailedTransfer(&_StargateAdapter.TransactOpts, token, amount)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapter *StargateAdapterTransactor) HandleCompose(opts *bind.TransactOpts, _guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapter.contract.Transact(opts, "handleCompose", _guid, _message, tokenSent, amountLD, composeFrom)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapter *StargateAdapterSession) HandleCompose(_guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapter.Contract.HandleCompose(&_StargateAdapter.TransactOpts, _guid, _message, tokenSent, amountLD, composeFrom)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapter *StargateAdapterTransactorSession) HandleCompose(_guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapter.Contract.HandleCompose(&_StargateAdapter.TransactOpts, _guid, _message, tokenSent, amountLD, composeFrom)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapter *StargateAdapterTransactor) LzCompose(opts *bind.TransactOpts, _from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapter.contract.Transact(opts, "lzCompose", _from, _guid, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapter *StargateAdapterSession) LzCompose(_from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapter.Contract.LzCompose(&_StargateAdapter.TransactOpts, _from, _guid, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapter *StargateAdapterTransactorSession) LzCompose(_from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapter.Contract.LzCompose(&_StargateAdapter.TransactOpts, _from, _guid, _message, arg3, arg4)
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

// StargateAdapterComposeDecodeFailedIterator is returned from FilterComposeDecodeFailed and is used to iterate over the raw logs and unpacked data for ComposeDecodeFailed events raised by the StargateAdapter contract.
type StargateAdapterComposeDecodeFailedIterator struct {
	Event *StargateAdapterComposeDecodeFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterComposeDecodeFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterComposeDecodeFailed)
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
		it.Event = new(StargateAdapterComposeDecodeFailed)
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
func (it *StargateAdapterComposeDecodeFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterComposeDecodeFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterComposeDecodeFailed represents a ComposeDecodeFailed event raised by the StargateAdapter contract.
type StargateAdapterComposeDecodeFailed struct {
	Guid [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterComposeDecodeFailed is a free log retrieval operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapter *StargateAdapterFilterer) FilterComposeDecodeFailed(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterComposeDecodeFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "ComposeDecodeFailed", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterComposeDecodeFailedIterator{contract: _StargateAdapter.contract, event: "ComposeDecodeFailed", logs: logs, sub: sub}, nil
}

// WatchComposeDecodeFailed is a free log subscription operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapter *StargateAdapterFilterer) WatchComposeDecodeFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterComposeDecodeFailed, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "ComposeDecodeFailed", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterComposeDecodeFailed)
				if err := _StargateAdapter.contract.UnpackLog(event, "ComposeDecodeFailed", log); err != nil {
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

// ParseComposeDecodeFailed is a log parse operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapter *StargateAdapterFilterer) ParseComposeDecodeFailed(log types.Log) (*StargateAdapterComposeDecodeFailed, error) {
	event := new(StargateAdapterComposeDecodeFailed)
	if err := _StargateAdapter.contract.UnpackLog(event, "ComposeDecodeFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterComposeMsgTooShortIterator is returned from FilterComposeMsgTooShort and is used to iterate over the raw logs and unpacked data for ComposeMsgTooShort events raised by the StargateAdapter contract.
type StargateAdapterComposeMsgTooShortIterator struct {
	Event *StargateAdapterComposeMsgTooShort // Event containing the contract specifics and raw log

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
func (it *StargateAdapterComposeMsgTooShortIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterComposeMsgTooShort)
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
		it.Event = new(StargateAdapterComposeMsgTooShort)
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
func (it *StargateAdapterComposeMsgTooShortIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterComposeMsgTooShortIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterComposeMsgTooShort represents a ComposeMsgTooShort event raised by the StargateAdapter contract.
type StargateAdapterComposeMsgTooShort struct {
	Guid          [32]byte
	MessageLength *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterComposeMsgTooShort is a free log retrieval operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapter *StargateAdapterFilterer) FilterComposeMsgTooShort(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterComposeMsgTooShortIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "ComposeMsgTooShort", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterComposeMsgTooShortIterator{contract: _StargateAdapter.contract, event: "ComposeMsgTooShort", logs: logs, sub: sub}, nil
}

// WatchComposeMsgTooShort is a free log subscription operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapter *StargateAdapterFilterer) WatchComposeMsgTooShort(opts *bind.WatchOpts, sink chan<- *StargateAdapterComposeMsgTooShort, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "ComposeMsgTooShort", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterComposeMsgTooShort)
				if err := _StargateAdapter.contract.UnpackLog(event, "ComposeMsgTooShort", log); err != nil {
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

// ParseComposeMsgTooShort is a log parse operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapter *StargateAdapterFilterer) ParseComposeMsgTooShort(log types.Log) (*StargateAdapterComposeMsgTooShort, error) {
	event := new(StargateAdapterComposeMsgTooShort)
	if err := _StargateAdapter.contract.UnpackLog(event, "ComposeMsgTooShort", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the StargateAdapter contract.
type StargateAdapterExecutionFailedIterator struct {
	Event *StargateAdapterExecutionFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterExecutionFailed)
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
		it.Event = new(StargateAdapterExecutionFailed)
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
func (it *StargateAdapterExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterExecutionFailed represents a ExecutionFailed event raised by the StargateAdapter contract.
type StargateAdapterExecutionFailed struct {
	Guid    [32]byte
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapter *StargateAdapterFilterer) FilterExecutionFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address) (*StargateAdapterExecutionFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterExecutionFailedIterator{contract: _StargateAdapter.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapter *StargateAdapterFilterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterExecutionFailed, guid [][32]byte, account []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterExecutionFailed)
				if err := _StargateAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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

// ParseExecutionFailed is a log parse operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapter *StargateAdapterFilterer) ParseExecutionFailed(log types.Log) (*StargateAdapterExecutionFailed, error) {
	event := new(StargateAdapterExecutionFailed)
	if err := _StargateAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterFailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the StargateAdapter contract.
type StargateAdapterFailedTransferClaimedIterator struct {
	Event *StargateAdapterFailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterFailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterFailedTransferClaimed)
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
		it.Event = new(StargateAdapterFailedTransferClaimed)
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
func (it *StargateAdapterFailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterFailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterFailedTransferClaimed represents a FailedTransferClaimed event raised by the StargateAdapter contract.
type StargateAdapterFailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*StargateAdapterFailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterFailedTransferClaimedIterator{contract: _StargateAdapter.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *StargateAdapterFailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterFailedTransferClaimed)
				if err := _StargateAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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
func (_StargateAdapter *StargateAdapterFilterer) ParseFailedTransferClaimed(log types.Log) (*StargateAdapterFailedTransferClaimed, error) {
	event := new(StargateAdapterFailedTransferClaimed)
	if err := _StargateAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTokenResolutionFailedIterator is returned from FilterTokenResolutionFailed and is used to iterate over the raw logs and unpacked data for TokenResolutionFailed events raised by the StargateAdapter contract.
type StargateAdapterTokenResolutionFailedIterator struct {
	Event *StargateAdapterTokenResolutionFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterTokenResolutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTokenResolutionFailed)
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
		it.Event = new(StargateAdapterTokenResolutionFailed)
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
func (it *StargateAdapterTokenResolutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTokenResolutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTokenResolutionFailed represents a TokenResolutionFailed event raised by the StargateAdapter contract.
type StargateAdapterTokenResolutionFailed struct {
	Guid [32]byte
	From common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterTokenResolutionFailed is a free log retrieval operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapter *StargateAdapterFilterer) FilterTokenResolutionFailed(opts *bind.FilterOpts, guid [][32]byte, from []common.Address) (*StargateAdapterTokenResolutionFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "TokenResolutionFailed", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTokenResolutionFailedIterator{contract: _StargateAdapter.contract, event: "TokenResolutionFailed", logs: logs, sub: sub}, nil
}

// WatchTokenResolutionFailed is a free log subscription operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapter *StargateAdapterFilterer) WatchTokenResolutionFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterTokenResolutionFailed, guid [][32]byte, from []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "TokenResolutionFailed", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTokenResolutionFailed)
				if err := _StargateAdapter.contract.UnpackLog(event, "TokenResolutionFailed", log); err != nil {
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

// ParseTokenResolutionFailed is a log parse operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapter *StargateAdapterFilterer) ParseTokenResolutionFailed(log types.Log) (*StargateAdapterTokenResolutionFailed, error) {
	event := new(StargateAdapterTokenResolutionFailed)
	if err := _StargateAdapter.contract.UnpackLog(event, "TokenResolutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the StargateAdapter contract.
type StargateAdapterTransferFailedIterator struct {
	Event *StargateAdapterTransferFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterTransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTransferFailed)
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
		it.Event = new(StargateAdapterTransferFailed)
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
func (it *StargateAdapterTransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTransferFailed represents a TransferFailed event raised by the StargateAdapter contract.
type StargateAdapterTransferFailed struct {
	Guid    [32]byte
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) FilterTransferFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, token []common.Address) (*StargateAdapterTransferFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTransferFailedIterator{contract: _StargateAdapter.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterTransferFailed, guid [][32]byte, account []common.Address, token []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTransferFailed)
				if err := _StargateAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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

// ParseTransferFailed is a log parse operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) ParseTransferFailed(log types.Log) (*StargateAdapterTransferFailed, error) {
	event := new(StargateAdapterTransferFailed)
	if err := _StargateAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the StargateAdapter contract.
type StargateAdapterTransferSucceededIterator struct {
	Event *StargateAdapterTransferSucceeded // Event containing the contract specifics and raw log

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
func (it *StargateAdapterTransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTransferSucceeded)
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
		it.Event = new(StargateAdapterTransferSucceeded)
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
func (it *StargateAdapterTransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTransferSucceeded represents a TransferSucceeded event raised by the StargateAdapter contract.
type StargateAdapterTransferSucceeded struct {
	Guid      [32]byte
	Account   common.Address
	TokenSent common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) FilterTransferSucceeded(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, tokenSent []common.Address) (*StargateAdapterTransferSucceededIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTransferSucceededIterator{contract: _StargateAdapter.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *StargateAdapterTransferSucceeded, guid [][32]byte, account []common.Address, tokenSent []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTransferSucceeded)
				if err := _StargateAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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

// ParseTransferSucceeded is a log parse operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapter *StargateAdapterFilterer) ParseTransferSucceeded(log types.Log) (*StargateAdapterTransferSucceeded, error) {
	event := new(StargateAdapterTransferSucceeded)
	if err := _StargateAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterUnregisteredPoolIterator is returned from FilterUnregisteredPool and is used to iterate over the raw logs and unpacked data for UnregisteredPool events raised by the StargateAdapter contract.
type StargateAdapterUnregisteredPoolIterator struct {
	Event *StargateAdapterUnregisteredPool // Event containing the contract specifics and raw log

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
func (it *StargateAdapterUnregisteredPoolIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterUnregisteredPool)
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
		it.Event = new(StargateAdapterUnregisteredPool)
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
func (it *StargateAdapterUnregisteredPoolIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterUnregisteredPoolIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterUnregisteredPool represents a UnregisteredPool event raised by the StargateAdapter contract.
type StargateAdapterUnregisteredPool struct {
	Guid [32]byte
	From common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterUnregisteredPool is a free log retrieval operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapter *StargateAdapterFilterer) FilterUnregisteredPool(opts *bind.FilterOpts, guid [][32]byte, from []common.Address) (*StargateAdapterUnregisteredPoolIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapter.contract.FilterLogs(opts, "UnregisteredPool", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterUnregisteredPoolIterator{contract: _StargateAdapter.contract, event: "UnregisteredPool", logs: logs, sub: sub}, nil
}

// WatchUnregisteredPool is a free log subscription operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapter *StargateAdapterFilterer) WatchUnregisteredPool(opts *bind.WatchOpts, sink chan<- *StargateAdapterUnregisteredPool, guid [][32]byte, from []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapter.contract.WatchLogs(opts, "UnregisteredPool", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterUnregisteredPool)
				if err := _StargateAdapter.contract.UnpackLog(event, "UnregisteredPool", log); err != nil {
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

// ParseUnregisteredPool is a log parse operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapter *StargateAdapterFilterer) ParseUnregisteredPool(log types.Log) (*StargateAdapterUnregisteredPool, error) {
	event := new(StargateAdapterUnregisteredPool)
	if err := _StargateAdapter.contract.UnpackLog(event, "UnregisteredPool", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
