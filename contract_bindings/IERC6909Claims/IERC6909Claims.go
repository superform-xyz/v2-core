// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package IERC6909Claims

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

// IERC6909ClaimsMetaData contains all meta data concerning the IERC6909Claims contract.
var IERC6909ClaimsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"allowance\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"approve\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"balanceOf\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isOperator\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"approved\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"setOperator\",\"inputs\":[{\"name\":\"operator\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"approved\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transfer\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferFrom\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"Approval\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OperatorSet\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"operator\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"approved\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Transfer\",\"inputs\":[{\"name\":\"caller\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false}]",
}

// IERC6909ClaimsABI is the input ABI used to generate the binding from.
// Deprecated: Use IERC6909ClaimsMetaData.ABI instead.
var IERC6909ClaimsABI = IERC6909ClaimsMetaData.ABI

// IERC6909Claims is an auto generated Go binding around an Ethereum contract.
type IERC6909Claims struct {
	IERC6909ClaimsCaller     // Read-only binding to the contract
	IERC6909ClaimsTransactor // Write-only binding to the contract
	IERC6909ClaimsFilterer   // Log filterer for contract events
}

// IERC6909ClaimsCaller is an auto generated read-only Go binding around an Ethereum contract.
type IERC6909ClaimsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IERC6909ClaimsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IERC6909ClaimsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IERC6909ClaimsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IERC6909ClaimsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IERC6909ClaimsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IERC6909ClaimsSession struct {
	Contract     *IERC6909Claims   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// IERC6909ClaimsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IERC6909ClaimsCallerSession struct {
	Contract *IERC6909ClaimsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// IERC6909ClaimsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IERC6909ClaimsTransactorSession struct {
	Contract     *IERC6909ClaimsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// IERC6909ClaimsRaw is an auto generated low-level Go binding around an Ethereum contract.
type IERC6909ClaimsRaw struct {
	Contract *IERC6909Claims // Generic contract binding to access the raw methods on
}

// IERC6909ClaimsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IERC6909ClaimsCallerRaw struct {
	Contract *IERC6909ClaimsCaller // Generic read-only contract binding to access the raw methods on
}

// IERC6909ClaimsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IERC6909ClaimsTransactorRaw struct {
	Contract *IERC6909ClaimsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIERC6909Claims creates a new instance of IERC6909Claims, bound to a specific deployed contract.
func NewIERC6909Claims(address common.Address, backend bind.ContractBackend) (*IERC6909Claims, error) {
	contract, err := bindIERC6909Claims(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IERC6909Claims{IERC6909ClaimsCaller: IERC6909ClaimsCaller{contract: contract}, IERC6909ClaimsTransactor: IERC6909ClaimsTransactor{contract: contract}, IERC6909ClaimsFilterer: IERC6909ClaimsFilterer{contract: contract}}, nil
}

// NewIERC6909ClaimsCaller creates a new read-only instance of IERC6909Claims, bound to a specific deployed contract.
func NewIERC6909ClaimsCaller(address common.Address, caller bind.ContractCaller) (*IERC6909ClaimsCaller, error) {
	contract, err := bindIERC6909Claims(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IERC6909ClaimsCaller{contract: contract}, nil
}

// NewIERC6909ClaimsTransactor creates a new write-only instance of IERC6909Claims, bound to a specific deployed contract.
func NewIERC6909ClaimsTransactor(address common.Address, transactor bind.ContractTransactor) (*IERC6909ClaimsTransactor, error) {
	contract, err := bindIERC6909Claims(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IERC6909ClaimsTransactor{contract: contract}, nil
}

// NewIERC6909ClaimsFilterer creates a new log filterer instance of IERC6909Claims, bound to a specific deployed contract.
func NewIERC6909ClaimsFilterer(address common.Address, filterer bind.ContractFilterer) (*IERC6909ClaimsFilterer, error) {
	contract, err := bindIERC6909Claims(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IERC6909ClaimsFilterer{contract: contract}, nil
}

// bindIERC6909Claims binds a generic wrapper to an already deployed contract.
func bindIERC6909Claims(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := IERC6909ClaimsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IERC6909Claims *IERC6909ClaimsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IERC6909Claims.Contract.IERC6909ClaimsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IERC6909Claims *IERC6909ClaimsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.IERC6909ClaimsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IERC6909Claims *IERC6909ClaimsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.IERC6909ClaimsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IERC6909Claims *IERC6909ClaimsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IERC6909Claims.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IERC6909Claims *IERC6909ClaimsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IERC6909Claims *IERC6909ClaimsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.contract.Transact(opts, method, params...)
}

// Allowance is a free data retrieval call binding the contract method 0x598af9e7.
//
// Solidity: function allowance(address owner, address spender, uint256 id) view returns(uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsCaller) Allowance(opts *bind.CallOpts, owner common.Address, spender common.Address, id *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _IERC6909Claims.contract.Call(opts, &out, "allowance", owner, spender, id)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Allowance is a free data retrieval call binding the contract method 0x598af9e7.
//
// Solidity: function allowance(address owner, address spender, uint256 id) view returns(uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsSession) Allowance(owner common.Address, spender common.Address, id *big.Int) (*big.Int, error) {
	return _IERC6909Claims.Contract.Allowance(&_IERC6909Claims.CallOpts, owner, spender, id)
}

// Allowance is a free data retrieval call binding the contract method 0x598af9e7.
//
// Solidity: function allowance(address owner, address spender, uint256 id) view returns(uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsCallerSession) Allowance(owner common.Address, spender common.Address, id *big.Int) (*big.Int, error) {
	return _IERC6909Claims.Contract.Allowance(&_IERC6909Claims.CallOpts, owner, spender, id)
}

// BalanceOf is a free data retrieval call binding the contract method 0x00fdd58e.
//
// Solidity: function balanceOf(address owner, uint256 id) view returns(uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsCaller) BalanceOf(opts *bind.CallOpts, owner common.Address, id *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _IERC6909Claims.contract.Call(opts, &out, "balanceOf", owner, id)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BalanceOf is a free data retrieval call binding the contract method 0x00fdd58e.
//
// Solidity: function balanceOf(address owner, uint256 id) view returns(uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsSession) BalanceOf(owner common.Address, id *big.Int) (*big.Int, error) {
	return _IERC6909Claims.Contract.BalanceOf(&_IERC6909Claims.CallOpts, owner, id)
}

// BalanceOf is a free data retrieval call binding the contract method 0x00fdd58e.
//
// Solidity: function balanceOf(address owner, uint256 id) view returns(uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsCallerSession) BalanceOf(owner common.Address, id *big.Int) (*big.Int, error) {
	return _IERC6909Claims.Contract.BalanceOf(&_IERC6909Claims.CallOpts, owner, id)
}

// IsOperator is a free data retrieval call binding the contract method 0xb6363cf2.
//
// Solidity: function isOperator(address owner, address spender) view returns(bool approved)
func (_IERC6909Claims *IERC6909ClaimsCaller) IsOperator(opts *bind.CallOpts, owner common.Address, spender common.Address) (bool, error) {
	var out []interface{}
	err := _IERC6909Claims.contract.Call(opts, &out, "isOperator", owner, spender)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOperator is a free data retrieval call binding the contract method 0xb6363cf2.
//
// Solidity: function isOperator(address owner, address spender) view returns(bool approved)
func (_IERC6909Claims *IERC6909ClaimsSession) IsOperator(owner common.Address, spender common.Address) (bool, error) {
	return _IERC6909Claims.Contract.IsOperator(&_IERC6909Claims.CallOpts, owner, spender)
}

// IsOperator is a free data retrieval call binding the contract method 0xb6363cf2.
//
// Solidity: function isOperator(address owner, address spender) view returns(bool approved)
func (_IERC6909Claims *IERC6909ClaimsCallerSession) IsOperator(owner common.Address, spender common.Address) (bool, error) {
	return _IERC6909Claims.Contract.IsOperator(&_IERC6909Claims.CallOpts, owner, spender)
}

// Approve is a paid mutator transaction binding the contract method 0x426a8493.
//
// Solidity: function approve(address spender, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactor) Approve(opts *bind.TransactOpts, spender common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.contract.Transact(opts, "approve", spender, id, amount)
}

// Approve is a paid mutator transaction binding the contract method 0x426a8493.
//
// Solidity: function approve(address spender, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsSession) Approve(spender common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.Approve(&_IERC6909Claims.TransactOpts, spender, id, amount)
}

// Approve is a paid mutator transaction binding the contract method 0x426a8493.
//
// Solidity: function approve(address spender, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactorSession) Approve(spender common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.Approve(&_IERC6909Claims.TransactOpts, spender, id, amount)
}

// SetOperator is a paid mutator transaction binding the contract method 0x558a7297.
//
// Solidity: function setOperator(address operator, bool approved) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactor) SetOperator(opts *bind.TransactOpts, operator common.Address, approved bool) (*types.Transaction, error) {
	return _IERC6909Claims.contract.Transact(opts, "setOperator", operator, approved)
}

// SetOperator is a paid mutator transaction binding the contract method 0x558a7297.
//
// Solidity: function setOperator(address operator, bool approved) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsSession) SetOperator(operator common.Address, approved bool) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.SetOperator(&_IERC6909Claims.TransactOpts, operator, approved)
}

// SetOperator is a paid mutator transaction binding the contract method 0x558a7297.
//
// Solidity: function setOperator(address operator, bool approved) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactorSession) SetOperator(operator common.Address, approved bool) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.SetOperator(&_IERC6909Claims.TransactOpts, operator, approved)
}

// Transfer is a paid mutator transaction binding the contract method 0x095bcdb6.
//
// Solidity: function transfer(address receiver, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactor) Transfer(opts *bind.TransactOpts, receiver common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.contract.Transact(opts, "transfer", receiver, id, amount)
}

// Transfer is a paid mutator transaction binding the contract method 0x095bcdb6.
//
// Solidity: function transfer(address receiver, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsSession) Transfer(receiver common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.Transfer(&_IERC6909Claims.TransactOpts, receiver, id, amount)
}

// Transfer is a paid mutator transaction binding the contract method 0x095bcdb6.
//
// Solidity: function transfer(address receiver, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactorSession) Transfer(receiver common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.Transfer(&_IERC6909Claims.TransactOpts, receiver, id, amount)
}

// TransferFrom is a paid mutator transaction binding the contract method 0xfe99049a.
//
// Solidity: function transferFrom(address sender, address receiver, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactor) TransferFrom(opts *bind.TransactOpts, sender common.Address, receiver common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.contract.Transact(opts, "transferFrom", sender, receiver, id, amount)
}

// TransferFrom is a paid mutator transaction binding the contract method 0xfe99049a.
//
// Solidity: function transferFrom(address sender, address receiver, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsSession) TransferFrom(sender common.Address, receiver common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.TransferFrom(&_IERC6909Claims.TransactOpts, sender, receiver, id, amount)
}

// TransferFrom is a paid mutator transaction binding the contract method 0xfe99049a.
//
// Solidity: function transferFrom(address sender, address receiver, uint256 id, uint256 amount) returns(bool)
func (_IERC6909Claims *IERC6909ClaimsTransactorSession) TransferFrom(sender common.Address, receiver common.Address, id *big.Int, amount *big.Int) (*types.Transaction, error) {
	return _IERC6909Claims.Contract.TransferFrom(&_IERC6909Claims.TransactOpts, sender, receiver, id, amount)
}

// IERC6909ClaimsApprovalIterator is returned from FilterApproval and is used to iterate over the raw logs and unpacked data for Approval events raised by the IERC6909Claims contract.
type IERC6909ClaimsApprovalIterator struct {
	Event *IERC6909ClaimsApproval // Event containing the contract specifics and raw log

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
func (it *IERC6909ClaimsApprovalIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IERC6909ClaimsApproval)
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
		it.Event = new(IERC6909ClaimsApproval)
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
func (it *IERC6909ClaimsApprovalIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IERC6909ClaimsApprovalIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IERC6909ClaimsApproval represents a Approval event raised by the IERC6909Claims contract.
type IERC6909ClaimsApproval struct {
	Owner   common.Address
	Spender common.Address
	Id      *big.Int
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterApproval is a free log retrieval operation binding the contract event 0xb3fd5071835887567a0671151121894ddccc2842f1d10bedad13e0d17cace9a7.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsFilterer) FilterApproval(opts *bind.FilterOpts, owner []common.Address, spender []common.Address, id []*big.Int) (*IERC6909ClaimsApprovalIterator, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var spenderRule []interface{}
	for _, spenderItem := range spender {
		spenderRule = append(spenderRule, spenderItem)
	}
	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _IERC6909Claims.contract.FilterLogs(opts, "Approval", ownerRule, spenderRule, idRule)
	if err != nil {
		return nil, err
	}
	return &IERC6909ClaimsApprovalIterator{contract: _IERC6909Claims.contract, event: "Approval", logs: logs, sub: sub}, nil
}

// WatchApproval is a free log subscription operation binding the contract event 0xb3fd5071835887567a0671151121894ddccc2842f1d10bedad13e0d17cace9a7.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsFilterer) WatchApproval(opts *bind.WatchOpts, sink chan<- *IERC6909ClaimsApproval, owner []common.Address, spender []common.Address, id []*big.Int) (event.Subscription, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var spenderRule []interface{}
	for _, spenderItem := range spender {
		spenderRule = append(spenderRule, spenderItem)
	}
	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _IERC6909Claims.contract.WatchLogs(opts, "Approval", ownerRule, spenderRule, idRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IERC6909ClaimsApproval)
				if err := _IERC6909Claims.contract.UnpackLog(event, "Approval", log); err != nil {
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

// ParseApproval is a log parse operation binding the contract event 0xb3fd5071835887567a0671151121894ddccc2842f1d10bedad13e0d17cace9a7.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsFilterer) ParseApproval(log types.Log) (*IERC6909ClaimsApproval, error) {
	event := new(IERC6909ClaimsApproval)
	if err := _IERC6909Claims.contract.UnpackLog(event, "Approval", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// IERC6909ClaimsOperatorSetIterator is returned from FilterOperatorSet and is used to iterate over the raw logs and unpacked data for OperatorSet events raised by the IERC6909Claims contract.
type IERC6909ClaimsOperatorSetIterator struct {
	Event *IERC6909ClaimsOperatorSet // Event containing the contract specifics and raw log

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
func (it *IERC6909ClaimsOperatorSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IERC6909ClaimsOperatorSet)
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
		it.Event = new(IERC6909ClaimsOperatorSet)
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
func (it *IERC6909ClaimsOperatorSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IERC6909ClaimsOperatorSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IERC6909ClaimsOperatorSet represents a OperatorSet event raised by the IERC6909Claims contract.
type IERC6909ClaimsOperatorSet struct {
	Owner    common.Address
	Operator common.Address
	Approved bool
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterOperatorSet is a free log retrieval operation binding the contract event 0xceb576d9f15e4e200fdb5096d64d5dfd667e16def20c1eefd14256d8e3faa267.
//
// Solidity: event OperatorSet(address indexed owner, address indexed operator, bool approved)
func (_IERC6909Claims *IERC6909ClaimsFilterer) FilterOperatorSet(opts *bind.FilterOpts, owner []common.Address, operator []common.Address) (*IERC6909ClaimsOperatorSetIterator, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _IERC6909Claims.contract.FilterLogs(opts, "OperatorSet", ownerRule, operatorRule)
	if err != nil {
		return nil, err
	}
	return &IERC6909ClaimsOperatorSetIterator{contract: _IERC6909Claims.contract, event: "OperatorSet", logs: logs, sub: sub}, nil
}

// WatchOperatorSet is a free log subscription operation binding the contract event 0xceb576d9f15e4e200fdb5096d64d5dfd667e16def20c1eefd14256d8e3faa267.
//
// Solidity: event OperatorSet(address indexed owner, address indexed operator, bool approved)
func (_IERC6909Claims *IERC6909ClaimsFilterer) WatchOperatorSet(opts *bind.WatchOpts, sink chan<- *IERC6909ClaimsOperatorSet, owner []common.Address, operator []common.Address) (event.Subscription, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _IERC6909Claims.contract.WatchLogs(opts, "OperatorSet", ownerRule, operatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IERC6909ClaimsOperatorSet)
				if err := _IERC6909Claims.contract.UnpackLog(event, "OperatorSet", log); err != nil {
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

// ParseOperatorSet is a log parse operation binding the contract event 0xceb576d9f15e4e200fdb5096d64d5dfd667e16def20c1eefd14256d8e3faa267.
//
// Solidity: event OperatorSet(address indexed owner, address indexed operator, bool approved)
func (_IERC6909Claims *IERC6909ClaimsFilterer) ParseOperatorSet(log types.Log) (*IERC6909ClaimsOperatorSet, error) {
	event := new(IERC6909ClaimsOperatorSet)
	if err := _IERC6909Claims.contract.UnpackLog(event, "OperatorSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// IERC6909ClaimsTransferIterator is returned from FilterTransfer and is used to iterate over the raw logs and unpacked data for Transfer events raised by the IERC6909Claims contract.
type IERC6909ClaimsTransferIterator struct {
	Event *IERC6909ClaimsTransfer // Event containing the contract specifics and raw log

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
func (it *IERC6909ClaimsTransferIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IERC6909ClaimsTransfer)
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
		it.Event = new(IERC6909ClaimsTransfer)
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
func (it *IERC6909ClaimsTransferIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IERC6909ClaimsTransferIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IERC6909ClaimsTransfer represents a Transfer event raised by the IERC6909Claims contract.
type IERC6909ClaimsTransfer struct {
	Caller common.Address
	From   common.Address
	To     common.Address
	Id     *big.Int
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterTransfer is a free log retrieval operation binding the contract event 0x1b3d7edb2e9c0b0e7c525b20aaaef0f5940d2ed71663c7d39266ecafac728859.
//
// Solidity: event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsFilterer) FilterTransfer(opts *bind.FilterOpts, from []common.Address, to []common.Address, id []*big.Int) (*IERC6909ClaimsTransferIterator, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}
	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _IERC6909Claims.contract.FilterLogs(opts, "Transfer", fromRule, toRule, idRule)
	if err != nil {
		return nil, err
	}
	return &IERC6909ClaimsTransferIterator{contract: _IERC6909Claims.contract, event: "Transfer", logs: logs, sub: sub}, nil
}

// WatchTransfer is a free log subscription operation binding the contract event 0x1b3d7edb2e9c0b0e7c525b20aaaef0f5940d2ed71663c7d39266ecafac728859.
//
// Solidity: event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsFilterer) WatchTransfer(opts *bind.WatchOpts, sink chan<- *IERC6909ClaimsTransfer, from []common.Address, to []common.Address, id []*big.Int) (event.Subscription, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}
	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _IERC6909Claims.contract.WatchLogs(opts, "Transfer", fromRule, toRule, idRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IERC6909ClaimsTransfer)
				if err := _IERC6909Claims.contract.UnpackLog(event, "Transfer", log); err != nil {
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

// ParseTransfer is a log parse operation binding the contract event 0x1b3d7edb2e9c0b0e7c525b20aaaef0f5940d2ed71663c7d39266ecafac728859.
//
// Solidity: event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount)
func (_IERC6909Claims *IERC6909ClaimsFilterer) ParseTransfer(log types.Log) (*IERC6909ClaimsTransfer, error) {
	event := new(IERC6909ClaimsTransfer)
	if err := _IERC6909Claims.contract.UnpackLog(event, "Transfer", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
