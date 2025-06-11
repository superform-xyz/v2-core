// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperBank

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

// IHookExecutionDataHookExecutionData is an auto generated low-level Go binding around an user-defined struct.
type IHookExecutionDataHookExecutionData struct {
	Hooks        []common.Address
	Data         [][]byte
	MerkleProofs [][][32]byte
}

// SuperBankMetaData contains all meta data concerning the SuperBank contract.
var SuperBankMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superGovernor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"SUPER_GOVERNOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperGovernor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"distribute\",\"inputs\":[{\"name\":\"upAmount_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeHooks\",\"inputs\":[{\"name\":\"executionData\",\"type\":\"tuple\",\"internalType\":\"structIHookExecutionData.HookExecutionData\",\"components\":[{\"name\":\"hooks\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"data\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"merkleProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"}]}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"HooksExecuted\",\"inputs\":[{\"name\":\"hooks\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"data\",\"type\":\"bytes[]\",\"indexed\":false,\"internalType\":\"bytes[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RevenueDistributed\",\"inputs\":[{\"name\":\"upToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"supToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"treasury\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"supAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"treasuryAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"HOOK_EXECUTION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BANK_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_HOOK\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MERKLE_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_UP_AMOUNT_TO_DISTRIBUTE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_LENGTH_ARRAY\",\"inputs\":[]}]",
}

// SuperBankABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperBankMetaData.ABI instead.
var SuperBankABI = SuperBankMetaData.ABI

// SuperBank is an auto generated Go binding around an Ethereum contract.
type SuperBank struct {
	SuperBankCaller     // Read-only binding to the contract
	SuperBankTransactor // Write-only binding to the contract
	SuperBankFilterer   // Log filterer for contract events
}

// SuperBankCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperBankCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBankTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperBankTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBankFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperBankFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBankSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperBankSession struct {
	Contract     *SuperBank        // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperBankCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperBankCallerSession struct {
	Contract *SuperBankCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts    // Call options to use throughout this session
}

// SuperBankTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperBankTransactorSession struct {
	Contract     *SuperBankTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// SuperBankRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperBankRaw struct {
	Contract *SuperBank // Generic contract binding to access the raw methods on
}

// SuperBankCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperBankCallerRaw struct {
	Contract *SuperBankCaller // Generic read-only contract binding to access the raw methods on
}

// SuperBankTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperBankTransactorRaw struct {
	Contract *SuperBankTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperBank creates a new instance of SuperBank, bound to a specific deployed contract.
func NewSuperBank(address common.Address, backend bind.ContractBackend) (*SuperBank, error) {
	contract, err := bindSuperBank(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperBank{SuperBankCaller: SuperBankCaller{contract: contract}, SuperBankTransactor: SuperBankTransactor{contract: contract}, SuperBankFilterer: SuperBankFilterer{contract: contract}}, nil
}

// NewSuperBankCaller creates a new read-only instance of SuperBank, bound to a specific deployed contract.
func NewSuperBankCaller(address common.Address, caller bind.ContractCaller) (*SuperBankCaller, error) {
	contract, err := bindSuperBank(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperBankCaller{contract: contract}, nil
}

// NewSuperBankTransactor creates a new write-only instance of SuperBank, bound to a specific deployed contract.
func NewSuperBankTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperBankTransactor, error) {
	contract, err := bindSuperBank(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperBankTransactor{contract: contract}, nil
}

// NewSuperBankFilterer creates a new log filterer instance of SuperBank, bound to a specific deployed contract.
func NewSuperBankFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperBankFilterer, error) {
	contract, err := bindSuperBank(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperBankFilterer{contract: contract}, nil
}

// bindSuperBank binds a generic wrapper to an already deployed contract.
func bindSuperBank(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperBankMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperBank *SuperBankRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperBank.Contract.SuperBankCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperBank *SuperBankRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperBank.Contract.SuperBankTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperBank *SuperBankRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperBank.Contract.SuperBankTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperBank *SuperBankCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperBank.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperBank *SuperBankTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperBank.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperBank *SuperBankTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperBank.Contract.contract.Transact(opts, method, params...)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperBank *SuperBankCaller) SUPERGOVERNOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperBank.contract.Call(opts, &out, "SUPER_GOVERNOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperBank *SuperBankSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperBank.Contract.SUPERGOVERNOR(&_SuperBank.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperBank *SuperBankCallerSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperBank.Contract.SUPERGOVERNOR(&_SuperBank.CallOpts)
}

// Distribute is a paid mutator transaction binding the contract method 0x91c05b0b.
//
// Solidity: function distribute(uint256 upAmount_) returns()
func (_SuperBank *SuperBankTransactor) Distribute(opts *bind.TransactOpts, upAmount_ *big.Int) (*types.Transaction, error) {
	return _SuperBank.contract.Transact(opts, "distribute", upAmount_)
}

// Distribute is a paid mutator transaction binding the contract method 0x91c05b0b.
//
// Solidity: function distribute(uint256 upAmount_) returns()
func (_SuperBank *SuperBankSession) Distribute(upAmount_ *big.Int) (*types.Transaction, error) {
	return _SuperBank.Contract.Distribute(&_SuperBank.TransactOpts, upAmount_)
}

// Distribute is a paid mutator transaction binding the contract method 0x91c05b0b.
//
// Solidity: function distribute(uint256 upAmount_) returns()
func (_SuperBank *SuperBankTransactorSession) Distribute(upAmount_ *big.Int) (*types.Transaction, error) {
	return _SuperBank.Contract.Distribute(&_SuperBank.TransactOpts, upAmount_)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x199f4433.
//
// Solidity: function executeHooks((address[],bytes[],bytes32[][]) executionData) payable returns()
func (_SuperBank *SuperBankTransactor) ExecuteHooks(opts *bind.TransactOpts, executionData IHookExecutionDataHookExecutionData) (*types.Transaction, error) {
	return _SuperBank.contract.Transact(opts, "executeHooks", executionData)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x199f4433.
//
// Solidity: function executeHooks((address[],bytes[],bytes32[][]) executionData) payable returns()
func (_SuperBank *SuperBankSession) ExecuteHooks(executionData IHookExecutionDataHookExecutionData) (*types.Transaction, error) {
	return _SuperBank.Contract.ExecuteHooks(&_SuperBank.TransactOpts, executionData)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x199f4433.
//
// Solidity: function executeHooks((address[],bytes[],bytes32[][]) executionData) payable returns()
func (_SuperBank *SuperBankTransactorSession) ExecuteHooks(executionData IHookExecutionDataHookExecutionData) (*types.Transaction, error) {
	return _SuperBank.Contract.ExecuteHooks(&_SuperBank.TransactOpts, executionData)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperBank *SuperBankTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperBank.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperBank *SuperBankSession) Receive() (*types.Transaction, error) {
	return _SuperBank.Contract.Receive(&_SuperBank.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperBank *SuperBankTransactorSession) Receive() (*types.Transaction, error) {
	return _SuperBank.Contract.Receive(&_SuperBank.TransactOpts)
}

// SuperBankHooksExecutedIterator is returned from FilterHooksExecuted and is used to iterate over the raw logs and unpacked data for HooksExecuted events raised by the SuperBank contract.
type SuperBankHooksExecutedIterator struct {
	Event *SuperBankHooksExecuted // Event containing the contract specifics and raw log

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
func (it *SuperBankHooksExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperBankHooksExecuted)
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
		it.Event = new(SuperBankHooksExecuted)
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
func (it *SuperBankHooksExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperBankHooksExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperBankHooksExecuted represents a HooksExecuted event raised by the SuperBank contract.
type SuperBankHooksExecuted struct {
	Hooks []common.Address
	Data  [][]byte
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterHooksExecuted is a free log retrieval operation binding the contract event 0xb51260367a120f22d0e7728a82ecb61dbd859a7aa66d2dd356a735d3f0174b42.
//
// Solidity: event HooksExecuted(address[] hooks, bytes[] data)
func (_SuperBank *SuperBankFilterer) FilterHooksExecuted(opts *bind.FilterOpts) (*SuperBankHooksExecutedIterator, error) {

	logs, sub, err := _SuperBank.contract.FilterLogs(opts, "HooksExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperBankHooksExecutedIterator{contract: _SuperBank.contract, event: "HooksExecuted", logs: logs, sub: sub}, nil
}

// WatchHooksExecuted is a free log subscription operation binding the contract event 0xb51260367a120f22d0e7728a82ecb61dbd859a7aa66d2dd356a735d3f0174b42.
//
// Solidity: event HooksExecuted(address[] hooks, bytes[] data)
func (_SuperBank *SuperBankFilterer) WatchHooksExecuted(opts *bind.WatchOpts, sink chan<- *SuperBankHooksExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperBank.contract.WatchLogs(opts, "HooksExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperBankHooksExecuted)
				if err := _SuperBank.contract.UnpackLog(event, "HooksExecuted", log); err != nil {
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

// ParseHooksExecuted is a log parse operation binding the contract event 0xb51260367a120f22d0e7728a82ecb61dbd859a7aa66d2dd356a735d3f0174b42.
//
// Solidity: event HooksExecuted(address[] hooks, bytes[] data)
func (_SuperBank *SuperBankFilterer) ParseHooksExecuted(log types.Log) (*SuperBankHooksExecuted, error) {
	event := new(SuperBankHooksExecuted)
	if err := _SuperBank.contract.UnpackLog(event, "HooksExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperBankRevenueDistributedIterator is returned from FilterRevenueDistributed and is used to iterate over the raw logs and unpacked data for RevenueDistributed events raised by the SuperBank contract.
type SuperBankRevenueDistributedIterator struct {
	Event *SuperBankRevenueDistributed // Event containing the contract specifics and raw log

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
func (it *SuperBankRevenueDistributedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperBankRevenueDistributed)
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
		it.Event = new(SuperBankRevenueDistributed)
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
func (it *SuperBankRevenueDistributedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperBankRevenueDistributedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperBankRevenueDistributed represents a RevenueDistributed event raised by the SuperBank contract.
type SuperBankRevenueDistributed struct {
	UpToken        common.Address
	SupToken       common.Address
	Treasury       common.Address
	SupAmount      *big.Int
	TreasuryAmount *big.Int
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterRevenueDistributed is a free log retrieval operation binding the contract event 0xee5bc9a05820722887a4100a84ffe71dcbee663d7ac3328b7462b575d43763d7.
//
// Solidity: event RevenueDistributed(address indexed upToken, address indexed supToken, address indexed treasury, uint256 supAmount, uint256 treasuryAmount)
func (_SuperBank *SuperBankFilterer) FilterRevenueDistributed(opts *bind.FilterOpts, upToken []common.Address, supToken []common.Address, treasury []common.Address) (*SuperBankRevenueDistributedIterator, error) {

	var upTokenRule []interface{}
	for _, upTokenItem := range upToken {
		upTokenRule = append(upTokenRule, upTokenItem)
	}
	var supTokenRule []interface{}
	for _, supTokenItem := range supToken {
		supTokenRule = append(supTokenRule, supTokenItem)
	}
	var treasuryRule []interface{}
	for _, treasuryItem := range treasury {
		treasuryRule = append(treasuryRule, treasuryItem)
	}

	logs, sub, err := _SuperBank.contract.FilterLogs(opts, "RevenueDistributed", upTokenRule, supTokenRule, treasuryRule)
	if err != nil {
		return nil, err
	}
	return &SuperBankRevenueDistributedIterator{contract: _SuperBank.contract, event: "RevenueDistributed", logs: logs, sub: sub}, nil
}

// WatchRevenueDistributed is a free log subscription operation binding the contract event 0xee5bc9a05820722887a4100a84ffe71dcbee663d7ac3328b7462b575d43763d7.
//
// Solidity: event RevenueDistributed(address indexed upToken, address indexed supToken, address indexed treasury, uint256 supAmount, uint256 treasuryAmount)
func (_SuperBank *SuperBankFilterer) WatchRevenueDistributed(opts *bind.WatchOpts, sink chan<- *SuperBankRevenueDistributed, upToken []common.Address, supToken []common.Address, treasury []common.Address) (event.Subscription, error) {

	var upTokenRule []interface{}
	for _, upTokenItem := range upToken {
		upTokenRule = append(upTokenRule, upTokenItem)
	}
	var supTokenRule []interface{}
	for _, supTokenItem := range supToken {
		supTokenRule = append(supTokenRule, supTokenItem)
	}
	var treasuryRule []interface{}
	for _, treasuryItem := range treasury {
		treasuryRule = append(treasuryRule, treasuryItem)
	}

	logs, sub, err := _SuperBank.contract.WatchLogs(opts, "RevenueDistributed", upTokenRule, supTokenRule, treasuryRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperBankRevenueDistributed)
				if err := _SuperBank.contract.UnpackLog(event, "RevenueDistributed", log); err != nil {
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

// ParseRevenueDistributed is a log parse operation binding the contract event 0xee5bc9a05820722887a4100a84ffe71dcbee663d7ac3328b7462b575d43763d7.
//
// Solidity: event RevenueDistributed(address indexed upToken, address indexed supToken, address indexed treasury, uint256 supAmount, uint256 treasuryAmount)
func (_SuperBank *SuperBankFilterer) ParseRevenueDistributed(log types.Log) (*SuperBankRevenueDistributed, error) {
	event := new(SuperBankRevenueDistributed)
	if err := _SuperBank.contract.UnpackLog(event, "RevenueDistributed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
