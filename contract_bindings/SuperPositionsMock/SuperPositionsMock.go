// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperPositionsMock

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

// SuperPositionsMockMetaData contains all meta data concerning the SuperPositionsMock contract.
var SuperPositionsMockMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"decimals_\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"allowance\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"approve\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"balanceOf\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mint\",\"inputs\":[{\"name\":\"to_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"symbol\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"totalSupply\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transfer\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferFrom\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"Approval\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Transfer\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ERC20InsufficientAllowance\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"allowance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ERC20InsufficientBalance\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidApprover\",\"inputs\":[{\"name\":\"approver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidReceiver\",\"inputs\":[{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidSender\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC20InvalidSpender\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// SuperPositionsMockABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperPositionsMockMetaData.ABI instead.
var SuperPositionsMockABI = SuperPositionsMockMetaData.ABI

// SuperPositionsMock is an auto generated Go binding around an Ethereum contract.
type SuperPositionsMock struct {
	SuperPositionsMockCaller     // Read-only binding to the contract
	SuperPositionsMockTransactor // Write-only binding to the contract
	SuperPositionsMockFilterer   // Log filterer for contract events
}

// SuperPositionsMockCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperPositionsMockCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperPositionsMockTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperPositionsMockTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperPositionsMockFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperPositionsMockFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperPositionsMockSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperPositionsMockSession struct {
	Contract     *SuperPositionsMock // Generic contract binding to set the session for
	CallOpts     bind.CallOpts       // Call options to use throughout this session
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// SuperPositionsMockCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperPositionsMockCallerSession struct {
	Contract *SuperPositionsMockCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts             // Call options to use throughout this session
}

// SuperPositionsMockTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperPositionsMockTransactorSession struct {
	Contract     *SuperPositionsMockTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// SuperPositionsMockRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperPositionsMockRaw struct {
	Contract *SuperPositionsMock // Generic contract binding to access the raw methods on
}

// SuperPositionsMockCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperPositionsMockCallerRaw struct {
	Contract *SuperPositionsMockCaller // Generic read-only contract binding to access the raw methods on
}

// SuperPositionsMockTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperPositionsMockTransactorRaw struct {
	Contract *SuperPositionsMockTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperPositionsMock creates a new instance of SuperPositionsMock, bound to a specific deployed contract.
func NewSuperPositionsMock(address common.Address, backend bind.ContractBackend) (*SuperPositionsMock, error) {
	contract, err := bindSuperPositionsMock(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperPositionsMock{SuperPositionsMockCaller: SuperPositionsMockCaller{contract: contract}, SuperPositionsMockTransactor: SuperPositionsMockTransactor{contract: contract}, SuperPositionsMockFilterer: SuperPositionsMockFilterer{contract: contract}}, nil
}

// NewSuperPositionsMockCaller creates a new read-only instance of SuperPositionsMock, bound to a specific deployed contract.
func NewSuperPositionsMockCaller(address common.Address, caller bind.ContractCaller) (*SuperPositionsMockCaller, error) {
	contract, err := bindSuperPositionsMock(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperPositionsMockCaller{contract: contract}, nil
}

// NewSuperPositionsMockTransactor creates a new write-only instance of SuperPositionsMock, bound to a specific deployed contract.
func NewSuperPositionsMockTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperPositionsMockTransactor, error) {
	contract, err := bindSuperPositionsMock(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperPositionsMockTransactor{contract: contract}, nil
}

// NewSuperPositionsMockFilterer creates a new log filterer instance of SuperPositionsMock, bound to a specific deployed contract.
func NewSuperPositionsMockFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperPositionsMockFilterer, error) {
	contract, err := bindSuperPositionsMock(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperPositionsMockFilterer{contract: contract}, nil
}

// bindSuperPositionsMock binds a generic wrapper to an already deployed contract.
func bindSuperPositionsMock(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperPositionsMockMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperPositionsMock *SuperPositionsMockRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperPositionsMock.Contract.SuperPositionsMockCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperPositionsMock *SuperPositionsMockRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.SuperPositionsMockTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperPositionsMock *SuperPositionsMockRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.SuperPositionsMockTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperPositionsMock *SuperPositionsMockCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperPositionsMock.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperPositionsMock *SuperPositionsMockTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperPositionsMock *SuperPositionsMockTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.contract.Transact(opts, method, params...)
}

// Allowance is a free data retrieval call binding the contract method 0xdd62ed3e.
//
// Solidity: function allowance(address owner, address spender) view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockCaller) Allowance(opts *bind.CallOpts, owner common.Address, spender common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperPositionsMock.contract.Call(opts, &out, "allowance", owner, spender)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Allowance is a free data retrieval call binding the contract method 0xdd62ed3e.
//
// Solidity: function allowance(address owner, address spender) view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockSession) Allowance(owner common.Address, spender common.Address) (*big.Int, error) {
	return _SuperPositionsMock.Contract.Allowance(&_SuperPositionsMock.CallOpts, owner, spender)
}

// Allowance is a free data retrieval call binding the contract method 0xdd62ed3e.
//
// Solidity: function allowance(address owner, address spender) view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockCallerSession) Allowance(owner common.Address, spender common.Address) (*big.Int, error) {
	return _SuperPositionsMock.Contract.Allowance(&_SuperPositionsMock.CallOpts, owner, spender)
}

// BalanceOf is a free data retrieval call binding the contract method 0x70a08231.
//
// Solidity: function balanceOf(address account) view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockCaller) BalanceOf(opts *bind.CallOpts, account common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperPositionsMock.contract.Call(opts, &out, "balanceOf", account)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BalanceOf is a free data retrieval call binding the contract method 0x70a08231.
//
// Solidity: function balanceOf(address account) view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockSession) BalanceOf(account common.Address) (*big.Int, error) {
	return _SuperPositionsMock.Contract.BalanceOf(&_SuperPositionsMock.CallOpts, account)
}

// BalanceOf is a free data retrieval call binding the contract method 0x70a08231.
//
// Solidity: function balanceOf(address account) view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockCallerSession) BalanceOf(account common.Address) (*big.Int, error) {
	return _SuperPositionsMock.Contract.BalanceOf(&_SuperPositionsMock.CallOpts, account)
}

// Decimals is a free data retrieval call binding the contract method 0x313ce567.
//
// Solidity: function decimals() view returns(uint8)
func (_SuperPositionsMock *SuperPositionsMockCaller) Decimals(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _SuperPositionsMock.contract.Call(opts, &out, "decimals")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0x313ce567.
//
// Solidity: function decimals() view returns(uint8)
func (_SuperPositionsMock *SuperPositionsMockSession) Decimals() (uint8, error) {
	return _SuperPositionsMock.Contract.Decimals(&_SuperPositionsMock.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0x313ce567.
//
// Solidity: function decimals() view returns(uint8)
func (_SuperPositionsMock *SuperPositionsMockCallerSession) Decimals() (uint8, error) {
	return _SuperPositionsMock.Contract.Decimals(&_SuperPositionsMock.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperPositionsMock *SuperPositionsMockCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperPositionsMock.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperPositionsMock *SuperPositionsMockSession) Name() (string, error) {
	return _SuperPositionsMock.Contract.Name(&_SuperPositionsMock.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperPositionsMock *SuperPositionsMockCallerSession) Name() (string, error) {
	return _SuperPositionsMock.Contract.Name(&_SuperPositionsMock.CallOpts)
}

// Symbol is a free data retrieval call binding the contract method 0x95d89b41.
//
// Solidity: function symbol() view returns(string)
func (_SuperPositionsMock *SuperPositionsMockCaller) Symbol(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperPositionsMock.contract.Call(opts, &out, "symbol")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Symbol is a free data retrieval call binding the contract method 0x95d89b41.
//
// Solidity: function symbol() view returns(string)
func (_SuperPositionsMock *SuperPositionsMockSession) Symbol() (string, error) {
	return _SuperPositionsMock.Contract.Symbol(&_SuperPositionsMock.CallOpts)
}

// Symbol is a free data retrieval call binding the contract method 0x95d89b41.
//
// Solidity: function symbol() view returns(string)
func (_SuperPositionsMock *SuperPositionsMockCallerSession) Symbol() (string, error) {
	return _SuperPositionsMock.Contract.Symbol(&_SuperPositionsMock.CallOpts)
}

// TotalSupply is a free data retrieval call binding the contract method 0x18160ddd.
//
// Solidity: function totalSupply() view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockCaller) TotalSupply(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperPositionsMock.contract.Call(opts, &out, "totalSupply")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TotalSupply is a free data retrieval call binding the contract method 0x18160ddd.
//
// Solidity: function totalSupply() view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockSession) TotalSupply() (*big.Int, error) {
	return _SuperPositionsMock.Contract.TotalSupply(&_SuperPositionsMock.CallOpts)
}

// TotalSupply is a free data retrieval call binding the contract method 0x18160ddd.
//
// Solidity: function totalSupply() view returns(uint256)
func (_SuperPositionsMock *SuperPositionsMockCallerSession) TotalSupply() (*big.Int, error) {
	return _SuperPositionsMock.Contract.TotalSupply(&_SuperPositionsMock.CallOpts)
}

// Approve is a paid mutator transaction binding the contract method 0x095ea7b3.
//
// Solidity: function approve(address spender, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockTransactor) Approve(opts *bind.TransactOpts, spender common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.contract.Transact(opts, "approve", spender, value)
}

// Approve is a paid mutator transaction binding the contract method 0x095ea7b3.
//
// Solidity: function approve(address spender, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockSession) Approve(spender common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.Approve(&_SuperPositionsMock.TransactOpts, spender, value)
}

// Approve is a paid mutator transaction binding the contract method 0x095ea7b3.
//
// Solidity: function approve(address spender, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockTransactorSession) Approve(spender common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.Approve(&_SuperPositionsMock.TransactOpts, spender, value)
}

// Mint is a paid mutator transaction binding the contract method 0x40c10f19.
//
// Solidity: function mint(address to_, uint256 amount_) returns()
func (_SuperPositionsMock *SuperPositionsMockTransactor) Mint(opts *bind.TransactOpts, to_ common.Address, amount_ *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.contract.Transact(opts, "mint", to_, amount_)
}

// Mint is a paid mutator transaction binding the contract method 0x40c10f19.
//
// Solidity: function mint(address to_, uint256 amount_) returns()
func (_SuperPositionsMock *SuperPositionsMockSession) Mint(to_ common.Address, amount_ *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.Mint(&_SuperPositionsMock.TransactOpts, to_, amount_)
}

// Mint is a paid mutator transaction binding the contract method 0x40c10f19.
//
// Solidity: function mint(address to_, uint256 amount_) returns()
func (_SuperPositionsMock *SuperPositionsMockTransactorSession) Mint(to_ common.Address, amount_ *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.Mint(&_SuperPositionsMock.TransactOpts, to_, amount_)
}

// Transfer is a paid mutator transaction binding the contract method 0xa9059cbb.
//
// Solidity: function transfer(address to, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockTransactor) Transfer(opts *bind.TransactOpts, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.contract.Transact(opts, "transfer", to, value)
}

// Transfer is a paid mutator transaction binding the contract method 0xa9059cbb.
//
// Solidity: function transfer(address to, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockSession) Transfer(to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.Transfer(&_SuperPositionsMock.TransactOpts, to, value)
}

// Transfer is a paid mutator transaction binding the contract method 0xa9059cbb.
//
// Solidity: function transfer(address to, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockTransactorSession) Transfer(to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.Transfer(&_SuperPositionsMock.TransactOpts, to, value)
}

// TransferFrom is a paid mutator transaction binding the contract method 0x23b872dd.
//
// Solidity: function transferFrom(address from, address to, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockTransactor) TransferFrom(opts *bind.TransactOpts, from common.Address, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.contract.Transact(opts, "transferFrom", from, to, value)
}

// TransferFrom is a paid mutator transaction binding the contract method 0x23b872dd.
//
// Solidity: function transferFrom(address from, address to, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockSession) TransferFrom(from common.Address, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.TransferFrom(&_SuperPositionsMock.TransactOpts, from, to, value)
}

// TransferFrom is a paid mutator transaction binding the contract method 0x23b872dd.
//
// Solidity: function transferFrom(address from, address to, uint256 value) returns(bool)
func (_SuperPositionsMock *SuperPositionsMockTransactorSession) TransferFrom(from common.Address, to common.Address, value *big.Int) (*types.Transaction, error) {
	return _SuperPositionsMock.Contract.TransferFrom(&_SuperPositionsMock.TransactOpts, from, to, value)
}

// SuperPositionsMockApprovalIterator is returned from FilterApproval and is used to iterate over the raw logs and unpacked data for Approval events raised by the SuperPositionsMock contract.
type SuperPositionsMockApprovalIterator struct {
	Event *SuperPositionsMockApproval // Event containing the contract specifics and raw log

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
func (it *SuperPositionsMockApprovalIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperPositionsMockApproval)
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
		it.Event = new(SuperPositionsMockApproval)
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
func (it *SuperPositionsMockApprovalIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperPositionsMockApprovalIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperPositionsMockApproval represents a Approval event raised by the SuperPositionsMock contract.
type SuperPositionsMockApproval struct {
	Owner   common.Address
	Spender common.Address
	Value   *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterApproval is a free log retrieval operation binding the contract event 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 value)
func (_SuperPositionsMock *SuperPositionsMockFilterer) FilterApproval(opts *bind.FilterOpts, owner []common.Address, spender []common.Address) (*SuperPositionsMockApprovalIterator, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var spenderRule []interface{}
	for _, spenderItem := range spender {
		spenderRule = append(spenderRule, spenderItem)
	}

	logs, sub, err := _SuperPositionsMock.contract.FilterLogs(opts, "Approval", ownerRule, spenderRule)
	if err != nil {
		return nil, err
	}
	return &SuperPositionsMockApprovalIterator{contract: _SuperPositionsMock.contract, event: "Approval", logs: logs, sub: sub}, nil
}

// WatchApproval is a free log subscription operation binding the contract event 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 value)
func (_SuperPositionsMock *SuperPositionsMockFilterer) WatchApproval(opts *bind.WatchOpts, sink chan<- *SuperPositionsMockApproval, owner []common.Address, spender []common.Address) (event.Subscription, error) {

	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}
	var spenderRule []interface{}
	for _, spenderItem := range spender {
		spenderRule = append(spenderRule, spenderItem)
	}

	logs, sub, err := _SuperPositionsMock.contract.WatchLogs(opts, "Approval", ownerRule, spenderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperPositionsMockApproval)
				if err := _SuperPositionsMock.contract.UnpackLog(event, "Approval", log); err != nil {
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

// ParseApproval is a log parse operation binding the contract event 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925.
//
// Solidity: event Approval(address indexed owner, address indexed spender, uint256 value)
func (_SuperPositionsMock *SuperPositionsMockFilterer) ParseApproval(log types.Log) (*SuperPositionsMockApproval, error) {
	event := new(SuperPositionsMockApproval)
	if err := _SuperPositionsMock.contract.UnpackLog(event, "Approval", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperPositionsMockTransferIterator is returned from FilterTransfer and is used to iterate over the raw logs and unpacked data for Transfer events raised by the SuperPositionsMock contract.
type SuperPositionsMockTransferIterator struct {
	Event *SuperPositionsMockTransfer // Event containing the contract specifics and raw log

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
func (it *SuperPositionsMockTransferIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperPositionsMockTransfer)
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
		it.Event = new(SuperPositionsMockTransfer)
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
func (it *SuperPositionsMockTransferIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperPositionsMockTransferIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperPositionsMockTransfer represents a Transfer event raised by the SuperPositionsMock contract.
type SuperPositionsMockTransfer struct {
	From  common.Address
	To    common.Address
	Value *big.Int
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterTransfer is a free log retrieval operation binding the contract event 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef.
//
// Solidity: event Transfer(address indexed from, address indexed to, uint256 value)
func (_SuperPositionsMock *SuperPositionsMockFilterer) FilterTransfer(opts *bind.FilterOpts, from []common.Address, to []common.Address) (*SuperPositionsMockTransferIterator, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperPositionsMock.contract.FilterLogs(opts, "Transfer", fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &SuperPositionsMockTransferIterator{contract: _SuperPositionsMock.contract, event: "Transfer", logs: logs, sub: sub}, nil
}

// WatchTransfer is a free log subscription operation binding the contract event 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef.
//
// Solidity: event Transfer(address indexed from, address indexed to, uint256 value)
func (_SuperPositionsMock *SuperPositionsMockFilterer) WatchTransfer(opts *bind.WatchOpts, sink chan<- *SuperPositionsMockTransfer, from []common.Address, to []common.Address) (event.Subscription, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperPositionsMock.contract.WatchLogs(opts, "Transfer", fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperPositionsMockTransfer)
				if err := _SuperPositionsMock.contract.UnpackLog(event, "Transfer", log); err != nil {
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

// ParseTransfer is a log parse operation binding the contract event 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef.
//
// Solidity: event Transfer(address indexed from, address indexed to, uint256 value)
func (_SuperPositionsMock *SuperPositionsMockFilterer) ParseTransfer(log types.Log) (*SuperPositionsMockTransfer, error) {
	event := new(SuperPositionsMockTransfer)
	if err := _SuperPositionsMock.contract.UnpackLog(event, "Transfer", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
