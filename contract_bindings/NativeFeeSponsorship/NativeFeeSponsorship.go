// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package NativeFeeSponsorship

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

// NativeFeeSponsorshipMetaData contains all meta data concerning the NativeFeeSponsorship contract.
var NativeFeeSponsorshipMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"depositForAccount\",\"inputs\":[{\"name\":\"sponsor\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"sponsoredAmount\",\"inputs\":[{\"name\":\"sponsor\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"withdrawSponsorDeposit\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"addresspayable\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawSponsoredNative\",\"inputs\":[{\"name\":\"sponsor\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"NativeDeposited\",\"inputs\":[{\"name\":\"sponsor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"NativeWithdrawnByAccount\",\"inputs\":[{\"name\":\"sponsor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"NativeWithdrawnBySponsor\",\"inputs\":[{\"name\":\"sponsor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_SPONSORED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED_DEPOSITOR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// NativeFeeSponsorshipABI is the input ABI used to generate the binding from.
// Deprecated: Use NativeFeeSponsorshipMetaData.ABI instead.
var NativeFeeSponsorshipABI = NativeFeeSponsorshipMetaData.ABI

// NativeFeeSponsorship is an auto generated Go binding around an Ethereum contract.
type NativeFeeSponsorship struct {
	NativeFeeSponsorshipCaller     // Read-only binding to the contract
	NativeFeeSponsorshipTransactor // Write-only binding to the contract
	NativeFeeSponsorshipFilterer   // Log filterer for contract events
}

// NativeFeeSponsorshipCaller is an auto generated read-only Go binding around an Ethereum contract.
type NativeFeeSponsorshipCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// NativeFeeSponsorshipTransactor is an auto generated write-only Go binding around an Ethereum contract.
type NativeFeeSponsorshipTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// NativeFeeSponsorshipFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type NativeFeeSponsorshipFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// NativeFeeSponsorshipSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type NativeFeeSponsorshipSession struct {
	Contract     *NativeFeeSponsorship // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// NativeFeeSponsorshipCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type NativeFeeSponsorshipCallerSession struct {
	Contract *NativeFeeSponsorshipCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// NativeFeeSponsorshipTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type NativeFeeSponsorshipTransactorSession struct {
	Contract     *NativeFeeSponsorshipTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// NativeFeeSponsorshipRaw is an auto generated low-level Go binding around an Ethereum contract.
type NativeFeeSponsorshipRaw struct {
	Contract *NativeFeeSponsorship // Generic contract binding to access the raw methods on
}

// NativeFeeSponsorshipCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type NativeFeeSponsorshipCallerRaw struct {
	Contract *NativeFeeSponsorshipCaller // Generic read-only contract binding to access the raw methods on
}

// NativeFeeSponsorshipTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type NativeFeeSponsorshipTransactorRaw struct {
	Contract *NativeFeeSponsorshipTransactor // Generic write-only contract binding to access the raw methods on
}

// NewNativeFeeSponsorship creates a new instance of NativeFeeSponsorship, bound to a specific deployed contract.
func NewNativeFeeSponsorship(address common.Address, backend bind.ContractBackend) (*NativeFeeSponsorship, error) {
	contract, err := bindNativeFeeSponsorship(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &NativeFeeSponsorship{NativeFeeSponsorshipCaller: NativeFeeSponsorshipCaller{contract: contract}, NativeFeeSponsorshipTransactor: NativeFeeSponsorshipTransactor{contract: contract}, NativeFeeSponsorshipFilterer: NativeFeeSponsorshipFilterer{contract: contract}}, nil
}

// NewNativeFeeSponsorshipCaller creates a new read-only instance of NativeFeeSponsorship, bound to a specific deployed contract.
func NewNativeFeeSponsorshipCaller(address common.Address, caller bind.ContractCaller) (*NativeFeeSponsorshipCaller, error) {
	contract, err := bindNativeFeeSponsorship(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &NativeFeeSponsorshipCaller{contract: contract}, nil
}

// NewNativeFeeSponsorshipTransactor creates a new write-only instance of NativeFeeSponsorship, bound to a specific deployed contract.
func NewNativeFeeSponsorshipTransactor(address common.Address, transactor bind.ContractTransactor) (*NativeFeeSponsorshipTransactor, error) {
	contract, err := bindNativeFeeSponsorship(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &NativeFeeSponsorshipTransactor{contract: contract}, nil
}

// NewNativeFeeSponsorshipFilterer creates a new log filterer instance of NativeFeeSponsorship, bound to a specific deployed contract.
func NewNativeFeeSponsorshipFilterer(address common.Address, filterer bind.ContractFilterer) (*NativeFeeSponsorshipFilterer, error) {
	contract, err := bindNativeFeeSponsorship(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &NativeFeeSponsorshipFilterer{contract: contract}, nil
}

// bindNativeFeeSponsorship binds a generic wrapper to an already deployed contract.
func bindNativeFeeSponsorship(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := NativeFeeSponsorshipMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_NativeFeeSponsorship *NativeFeeSponsorshipRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _NativeFeeSponsorship.Contract.NativeFeeSponsorshipCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_NativeFeeSponsorship *NativeFeeSponsorshipRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.NativeFeeSponsorshipTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_NativeFeeSponsorship *NativeFeeSponsorshipRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.NativeFeeSponsorshipTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_NativeFeeSponsorship *NativeFeeSponsorshipCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _NativeFeeSponsorship.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.contract.Transact(opts, method, params...)
}

// SponsoredAmount is a free data retrieval call binding the contract method 0x47c5f99e.
//
// Solidity: function sponsoredAmount(address sponsor, address account) view returns(uint256)
func (_NativeFeeSponsorship *NativeFeeSponsorshipCaller) SponsoredAmount(opts *bind.CallOpts, sponsor common.Address, account common.Address) (*big.Int, error) {
	var out []interface{}
	err := _NativeFeeSponsorship.contract.Call(opts, &out, "sponsoredAmount", sponsor, account)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SponsoredAmount is a free data retrieval call binding the contract method 0x47c5f99e.
//
// Solidity: function sponsoredAmount(address sponsor, address account) view returns(uint256)
func (_NativeFeeSponsorship *NativeFeeSponsorshipSession) SponsoredAmount(sponsor common.Address, account common.Address) (*big.Int, error) {
	return _NativeFeeSponsorship.Contract.SponsoredAmount(&_NativeFeeSponsorship.CallOpts, sponsor, account)
}

// SponsoredAmount is a free data retrieval call binding the contract method 0x47c5f99e.
//
// Solidity: function sponsoredAmount(address sponsor, address account) view returns(uint256)
func (_NativeFeeSponsorship *NativeFeeSponsorshipCallerSession) SponsoredAmount(sponsor common.Address, account common.Address) (*big.Int, error) {
	return _NativeFeeSponsorship.Contract.SponsoredAmount(&_NativeFeeSponsorship.CallOpts, sponsor, account)
}

// DepositForAccount is a paid mutator transaction binding the contract method 0x6019defe.
//
// Solidity: function depositForAccount(address sponsor, address account) payable returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactor) DepositForAccount(opts *bind.TransactOpts, sponsor common.Address, account common.Address) (*types.Transaction, error) {
	return _NativeFeeSponsorship.contract.Transact(opts, "depositForAccount", sponsor, account)
}

// DepositForAccount is a paid mutator transaction binding the contract method 0x6019defe.
//
// Solidity: function depositForAccount(address sponsor, address account) payable returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipSession) DepositForAccount(sponsor common.Address, account common.Address) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.DepositForAccount(&_NativeFeeSponsorship.TransactOpts, sponsor, account)
}

// DepositForAccount is a paid mutator transaction binding the contract method 0x6019defe.
//
// Solidity: function depositForAccount(address sponsor, address account) payable returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactorSession) DepositForAccount(sponsor common.Address, account common.Address) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.DepositForAccount(&_NativeFeeSponsorship.TransactOpts, sponsor, account)
}

// WithdrawSponsorDeposit is a paid mutator transaction binding the contract method 0x19e5d95c.
//
// Solidity: function withdrawSponsorDeposit(address account, address to, uint256 amount) returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactor) WithdrawSponsorDeposit(opts *bind.TransactOpts, account common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _NativeFeeSponsorship.contract.Transact(opts, "withdrawSponsorDeposit", account, to, amount)
}

// WithdrawSponsorDeposit is a paid mutator transaction binding the contract method 0x19e5d95c.
//
// Solidity: function withdrawSponsorDeposit(address account, address to, uint256 amount) returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipSession) WithdrawSponsorDeposit(account common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.WithdrawSponsorDeposit(&_NativeFeeSponsorship.TransactOpts, account, to, amount)
}

// WithdrawSponsorDeposit is a paid mutator transaction binding the contract method 0x19e5d95c.
//
// Solidity: function withdrawSponsorDeposit(address account, address to, uint256 amount) returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactorSession) WithdrawSponsorDeposit(account common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.WithdrawSponsorDeposit(&_NativeFeeSponsorship.TransactOpts, account, to, amount)
}

// WithdrawSponsoredNative is a paid mutator transaction binding the contract method 0x31fdf857.
//
// Solidity: function withdrawSponsoredNative(address sponsor, uint256 amount) returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactor) WithdrawSponsoredNative(opts *bind.TransactOpts, sponsor common.Address, amount *big.Int) (*types.Transaction, error) {
	return _NativeFeeSponsorship.contract.Transact(opts, "withdrawSponsoredNative", sponsor, amount)
}

// WithdrawSponsoredNative is a paid mutator transaction binding the contract method 0x31fdf857.
//
// Solidity: function withdrawSponsoredNative(address sponsor, uint256 amount) returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipSession) WithdrawSponsoredNative(sponsor common.Address, amount *big.Int) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.WithdrawSponsoredNative(&_NativeFeeSponsorship.TransactOpts, sponsor, amount)
}

// WithdrawSponsoredNative is a paid mutator transaction binding the contract method 0x31fdf857.
//
// Solidity: function withdrawSponsoredNative(address sponsor, uint256 amount) returns()
func (_NativeFeeSponsorship *NativeFeeSponsorshipTransactorSession) WithdrawSponsoredNative(sponsor common.Address, amount *big.Int) (*types.Transaction, error) {
	return _NativeFeeSponsorship.Contract.WithdrawSponsoredNative(&_NativeFeeSponsorship.TransactOpts, sponsor, amount)
}

// NativeFeeSponsorshipNativeDepositedIterator is returned from FilterNativeDeposited and is used to iterate over the raw logs and unpacked data for NativeDeposited events raised by the NativeFeeSponsorship contract.
type NativeFeeSponsorshipNativeDepositedIterator struct {
	Event *NativeFeeSponsorshipNativeDeposited // Event containing the contract specifics and raw log

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
func (it *NativeFeeSponsorshipNativeDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(NativeFeeSponsorshipNativeDeposited)
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
		it.Event = new(NativeFeeSponsorshipNativeDeposited)
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
func (it *NativeFeeSponsorshipNativeDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *NativeFeeSponsorshipNativeDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// NativeFeeSponsorshipNativeDeposited represents a NativeDeposited event raised by the NativeFeeSponsorship contract.
type NativeFeeSponsorshipNativeDeposited struct {
	Sponsor common.Address
	Account common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterNativeDeposited is a free log retrieval operation binding the contract event 0xc7ec43e3ee021a9905da943ad23f91eb47980caf461d532b12e34b230f976ab2.
//
// Solidity: event NativeDeposited(address indexed sponsor, address indexed account, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) FilterNativeDeposited(opts *bind.FilterOpts, sponsor []common.Address, account []common.Address) (*NativeFeeSponsorshipNativeDepositedIterator, error) {

	var sponsorRule []interface{}
	for _, sponsorItem := range sponsor {
		sponsorRule = append(sponsorRule, sponsorItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _NativeFeeSponsorship.contract.FilterLogs(opts, "NativeDeposited", sponsorRule, accountRule)
	if err != nil {
		return nil, err
	}
	return &NativeFeeSponsorshipNativeDepositedIterator{contract: _NativeFeeSponsorship.contract, event: "NativeDeposited", logs: logs, sub: sub}, nil
}

// WatchNativeDeposited is a free log subscription operation binding the contract event 0xc7ec43e3ee021a9905da943ad23f91eb47980caf461d532b12e34b230f976ab2.
//
// Solidity: event NativeDeposited(address indexed sponsor, address indexed account, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) WatchNativeDeposited(opts *bind.WatchOpts, sink chan<- *NativeFeeSponsorshipNativeDeposited, sponsor []common.Address, account []common.Address) (event.Subscription, error) {

	var sponsorRule []interface{}
	for _, sponsorItem := range sponsor {
		sponsorRule = append(sponsorRule, sponsorItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _NativeFeeSponsorship.contract.WatchLogs(opts, "NativeDeposited", sponsorRule, accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(NativeFeeSponsorshipNativeDeposited)
				if err := _NativeFeeSponsorship.contract.UnpackLog(event, "NativeDeposited", log); err != nil {
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

// ParseNativeDeposited is a log parse operation binding the contract event 0xc7ec43e3ee021a9905da943ad23f91eb47980caf461d532b12e34b230f976ab2.
//
// Solidity: event NativeDeposited(address indexed sponsor, address indexed account, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) ParseNativeDeposited(log types.Log) (*NativeFeeSponsorshipNativeDeposited, error) {
	event := new(NativeFeeSponsorshipNativeDeposited)
	if err := _NativeFeeSponsorship.contract.UnpackLog(event, "NativeDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// NativeFeeSponsorshipNativeWithdrawnByAccountIterator is returned from FilterNativeWithdrawnByAccount and is used to iterate over the raw logs and unpacked data for NativeWithdrawnByAccount events raised by the NativeFeeSponsorship contract.
type NativeFeeSponsorshipNativeWithdrawnByAccountIterator struct {
	Event *NativeFeeSponsorshipNativeWithdrawnByAccount // Event containing the contract specifics and raw log

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
func (it *NativeFeeSponsorshipNativeWithdrawnByAccountIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(NativeFeeSponsorshipNativeWithdrawnByAccount)
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
		it.Event = new(NativeFeeSponsorshipNativeWithdrawnByAccount)
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
func (it *NativeFeeSponsorshipNativeWithdrawnByAccountIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *NativeFeeSponsorshipNativeWithdrawnByAccountIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// NativeFeeSponsorshipNativeWithdrawnByAccount represents a NativeWithdrawnByAccount event raised by the NativeFeeSponsorship contract.
type NativeFeeSponsorshipNativeWithdrawnByAccount struct {
	Sponsor common.Address
	Account common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterNativeWithdrawnByAccount is a free log retrieval operation binding the contract event 0x1319aca049b04084dfd5fc8b7977ec8d440c549683d78d84e1f33618f9e07da7.
//
// Solidity: event NativeWithdrawnByAccount(address indexed sponsor, address indexed account, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) FilterNativeWithdrawnByAccount(opts *bind.FilterOpts, sponsor []common.Address, account []common.Address) (*NativeFeeSponsorshipNativeWithdrawnByAccountIterator, error) {

	var sponsorRule []interface{}
	for _, sponsorItem := range sponsor {
		sponsorRule = append(sponsorRule, sponsorItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _NativeFeeSponsorship.contract.FilterLogs(opts, "NativeWithdrawnByAccount", sponsorRule, accountRule)
	if err != nil {
		return nil, err
	}
	return &NativeFeeSponsorshipNativeWithdrawnByAccountIterator{contract: _NativeFeeSponsorship.contract, event: "NativeWithdrawnByAccount", logs: logs, sub: sub}, nil
}

// WatchNativeWithdrawnByAccount is a free log subscription operation binding the contract event 0x1319aca049b04084dfd5fc8b7977ec8d440c549683d78d84e1f33618f9e07da7.
//
// Solidity: event NativeWithdrawnByAccount(address indexed sponsor, address indexed account, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) WatchNativeWithdrawnByAccount(opts *bind.WatchOpts, sink chan<- *NativeFeeSponsorshipNativeWithdrawnByAccount, sponsor []common.Address, account []common.Address) (event.Subscription, error) {

	var sponsorRule []interface{}
	for _, sponsorItem := range sponsor {
		sponsorRule = append(sponsorRule, sponsorItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _NativeFeeSponsorship.contract.WatchLogs(opts, "NativeWithdrawnByAccount", sponsorRule, accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(NativeFeeSponsorshipNativeWithdrawnByAccount)
				if err := _NativeFeeSponsorship.contract.UnpackLog(event, "NativeWithdrawnByAccount", log); err != nil {
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

// ParseNativeWithdrawnByAccount is a log parse operation binding the contract event 0x1319aca049b04084dfd5fc8b7977ec8d440c549683d78d84e1f33618f9e07da7.
//
// Solidity: event NativeWithdrawnByAccount(address indexed sponsor, address indexed account, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) ParseNativeWithdrawnByAccount(log types.Log) (*NativeFeeSponsorshipNativeWithdrawnByAccount, error) {
	event := new(NativeFeeSponsorshipNativeWithdrawnByAccount)
	if err := _NativeFeeSponsorship.contract.UnpackLog(event, "NativeWithdrawnByAccount", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// NativeFeeSponsorshipNativeWithdrawnBySponsorIterator is returned from FilterNativeWithdrawnBySponsor and is used to iterate over the raw logs and unpacked data for NativeWithdrawnBySponsor events raised by the NativeFeeSponsorship contract.
type NativeFeeSponsorshipNativeWithdrawnBySponsorIterator struct {
	Event *NativeFeeSponsorshipNativeWithdrawnBySponsor // Event containing the contract specifics and raw log

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
func (it *NativeFeeSponsorshipNativeWithdrawnBySponsorIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(NativeFeeSponsorshipNativeWithdrawnBySponsor)
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
		it.Event = new(NativeFeeSponsorshipNativeWithdrawnBySponsor)
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
func (it *NativeFeeSponsorshipNativeWithdrawnBySponsorIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *NativeFeeSponsorshipNativeWithdrawnBySponsorIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// NativeFeeSponsorshipNativeWithdrawnBySponsor represents a NativeWithdrawnBySponsor event raised by the NativeFeeSponsorship contract.
type NativeFeeSponsorshipNativeWithdrawnBySponsor struct {
	Sponsor common.Address
	Account common.Address
	To      common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterNativeWithdrawnBySponsor is a free log retrieval operation binding the contract event 0x69db1f0433eeeea1a5afca4c7b22f2a0163307cf3622fac1573812f4cadc5ac5.
//
// Solidity: event NativeWithdrawnBySponsor(address indexed sponsor, address indexed account, address indexed to, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) FilterNativeWithdrawnBySponsor(opts *bind.FilterOpts, sponsor []common.Address, account []common.Address, to []common.Address) (*NativeFeeSponsorshipNativeWithdrawnBySponsorIterator, error) {

	var sponsorRule []interface{}
	for _, sponsorItem := range sponsor {
		sponsorRule = append(sponsorRule, sponsorItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _NativeFeeSponsorship.contract.FilterLogs(opts, "NativeWithdrawnBySponsor", sponsorRule, accountRule, toRule)
	if err != nil {
		return nil, err
	}
	return &NativeFeeSponsorshipNativeWithdrawnBySponsorIterator{contract: _NativeFeeSponsorship.contract, event: "NativeWithdrawnBySponsor", logs: logs, sub: sub}, nil
}

// WatchNativeWithdrawnBySponsor is a free log subscription operation binding the contract event 0x69db1f0433eeeea1a5afca4c7b22f2a0163307cf3622fac1573812f4cadc5ac5.
//
// Solidity: event NativeWithdrawnBySponsor(address indexed sponsor, address indexed account, address indexed to, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) WatchNativeWithdrawnBySponsor(opts *bind.WatchOpts, sink chan<- *NativeFeeSponsorshipNativeWithdrawnBySponsor, sponsor []common.Address, account []common.Address, to []common.Address) (event.Subscription, error) {

	var sponsorRule []interface{}
	for _, sponsorItem := range sponsor {
		sponsorRule = append(sponsorRule, sponsorItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _NativeFeeSponsorship.contract.WatchLogs(opts, "NativeWithdrawnBySponsor", sponsorRule, accountRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(NativeFeeSponsorshipNativeWithdrawnBySponsor)
				if err := _NativeFeeSponsorship.contract.UnpackLog(event, "NativeWithdrawnBySponsor", log); err != nil {
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

// ParseNativeWithdrawnBySponsor is a log parse operation binding the contract event 0x69db1f0433eeeea1a5afca4c7b22f2a0163307cf3622fac1573812f4cadc5ac5.
//
// Solidity: event NativeWithdrawnBySponsor(address indexed sponsor, address indexed account, address indexed to, uint256 amount)
func (_NativeFeeSponsorship *NativeFeeSponsorshipFilterer) ParseNativeWithdrawnBySponsor(log types.Log) (*NativeFeeSponsorshipNativeWithdrawnBySponsor, error) {
	event := new(NativeFeeSponsorshipNativeWithdrawnBySponsor)
	if err := _NativeFeeSponsorship.contract.UnpackLog(event, "NativeWithdrawnBySponsor", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
