// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ECDSAPPSOracle

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

// IECDSAPPSOracleBatchUpdatePPSArgs is an auto generated low-level Go binding around an user-defined struct.
type IECDSAPPSOracleBatchUpdatePPSArgs struct {
	Strategies      []common.Address
	ProofsArray     [][][]byte
	Ppss            []*big.Int
	PpsStdevs       []*big.Int
	ValidatorSets   []*big.Int
	TotalValidators []*big.Int
	Timestamps      []*big.Int
}

// IECDSAPPSOracleUpdatePPSArgs is an auto generated low-level Go binding around an user-defined struct.
type IECDSAPPSOracleUpdatePPSArgs struct {
	Strategy        common.Address
	Proofs          [][]byte
	Pps             *big.Int
	PpsStdev        *big.Int
	ValidatorSet    *big.Int
	TotalValidators *big.Int
	Timestamp       *big.Int
}

// ECDSAPPSOracleMetaData contains all meta data concerning the ECDSAPPSOracle contract.
var ECDSAPPSOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superGovernor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_GOVERNOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperGovernor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"batchUpdatePPS\",\"inputs\":[{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structIECDSAPPSOracle.BatchUpdatePPSArgs\",\"components\":[{\"name\":\"strategies\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"proofsArray\",\"type\":\"bytes[][]\",\"internalType\":\"bytes[][]\"},{\"name\":\"ppss\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"ppsStdevs\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"validatorSets\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"totalValidators\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"timestamps\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"updatePPS\",\"inputs\":[{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structIECDSAPPSOracle.UpdatePPSArgs\",\"components\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proofs\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"pps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ppsStdev\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"validatorSet\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"totalValidators\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"PPSValidated\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"pps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"ppsStdev\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"validatorSet\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"totalValidators\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureLength\",\"inputs\":[{\"name\":\"length\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureS\",\"inputs\":[{\"name\":\"s\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"HIGH_PPS_DEVIATION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HIGH_PPS_DISPERSION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_VALIDATOR_PARTICIPATION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_TIMESTAMP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_VALIDATOR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_ACTIVE_PPS_ORACLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PPS_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"QUORUM_NOT_MET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGY_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VALIDATOR_COUNT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_LENGTH_ARRAY\",\"inputs\":[]}]",
}

// ECDSAPPSOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use ECDSAPPSOracleMetaData.ABI instead.
var ECDSAPPSOracleABI = ECDSAPPSOracleMetaData.ABI

// ECDSAPPSOracle is an auto generated Go binding around an Ethereum contract.
type ECDSAPPSOracle struct {
	ECDSAPPSOracleCaller     // Read-only binding to the contract
	ECDSAPPSOracleTransactor // Write-only binding to the contract
	ECDSAPPSOracleFilterer   // Log filterer for contract events
}

// ECDSAPPSOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type ECDSAPPSOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ECDSAPPSOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ECDSAPPSOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ECDSAPPSOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ECDSAPPSOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ECDSAPPSOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ECDSAPPSOracleSession struct {
	Contract     *ECDSAPPSOracle   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ECDSAPPSOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ECDSAPPSOracleCallerSession struct {
	Contract *ECDSAPPSOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// ECDSAPPSOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ECDSAPPSOracleTransactorSession struct {
	Contract     *ECDSAPPSOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// ECDSAPPSOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type ECDSAPPSOracleRaw struct {
	Contract *ECDSAPPSOracle // Generic contract binding to access the raw methods on
}

// ECDSAPPSOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ECDSAPPSOracleCallerRaw struct {
	Contract *ECDSAPPSOracleCaller // Generic read-only contract binding to access the raw methods on
}

// ECDSAPPSOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ECDSAPPSOracleTransactorRaw struct {
	Contract *ECDSAPPSOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewECDSAPPSOracle creates a new instance of ECDSAPPSOracle, bound to a specific deployed contract.
func NewECDSAPPSOracle(address common.Address, backend bind.ContractBackend) (*ECDSAPPSOracle, error) {
	contract, err := bindECDSAPPSOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ECDSAPPSOracle{ECDSAPPSOracleCaller: ECDSAPPSOracleCaller{contract: contract}, ECDSAPPSOracleTransactor: ECDSAPPSOracleTransactor{contract: contract}, ECDSAPPSOracleFilterer: ECDSAPPSOracleFilterer{contract: contract}}, nil
}

// NewECDSAPPSOracleCaller creates a new read-only instance of ECDSAPPSOracle, bound to a specific deployed contract.
func NewECDSAPPSOracleCaller(address common.Address, caller bind.ContractCaller) (*ECDSAPPSOracleCaller, error) {
	contract, err := bindECDSAPPSOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ECDSAPPSOracleCaller{contract: contract}, nil
}

// NewECDSAPPSOracleTransactor creates a new write-only instance of ECDSAPPSOracle, bound to a specific deployed contract.
func NewECDSAPPSOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*ECDSAPPSOracleTransactor, error) {
	contract, err := bindECDSAPPSOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ECDSAPPSOracleTransactor{contract: contract}, nil
}

// NewECDSAPPSOracleFilterer creates a new log filterer instance of ECDSAPPSOracle, bound to a specific deployed contract.
func NewECDSAPPSOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*ECDSAPPSOracleFilterer, error) {
	contract, err := bindECDSAPPSOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ECDSAPPSOracleFilterer{contract: contract}, nil
}

// bindECDSAPPSOracle binds a generic wrapper to an already deployed contract.
func bindECDSAPPSOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ECDSAPPSOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ECDSAPPSOracle *ECDSAPPSOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ECDSAPPSOracle.Contract.ECDSAPPSOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ECDSAPPSOracle *ECDSAPPSOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.ECDSAPPSOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ECDSAPPSOracle *ECDSAPPSOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.ECDSAPPSOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ECDSAPPSOracle *ECDSAPPSOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ECDSAPPSOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ECDSAPPSOracle *ECDSAPPSOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ECDSAPPSOracle *ECDSAPPSOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.contract.Transact(opts, method, params...)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_ECDSAPPSOracle *ECDSAPPSOracleCaller) SUPERGOVERNOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ECDSAPPSOracle.contract.Call(opts, &out, "SUPER_GOVERNOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_ECDSAPPSOracle *ECDSAPPSOracleSession) SUPERGOVERNOR() (common.Address, error) {
	return _ECDSAPPSOracle.Contract.SUPERGOVERNOR(&_ECDSAPPSOracle.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_ECDSAPPSOracle *ECDSAPPSOracleCallerSession) SUPERGOVERNOR() (common.Address, error) {
	return _ECDSAPPSOracle.Contract.SUPERGOVERNOR(&_ECDSAPPSOracle.CallOpts)
}

// BatchUpdatePPS is a paid mutator transaction binding the contract method 0xa1867527.
//
// Solidity: function batchUpdatePPS((address[],bytes[][],uint256[],uint256[],uint256[],uint256[],uint256[]) args) returns()
func (_ECDSAPPSOracle *ECDSAPPSOracleTransactor) BatchUpdatePPS(opts *bind.TransactOpts, args IECDSAPPSOracleBatchUpdatePPSArgs) (*types.Transaction, error) {
	return _ECDSAPPSOracle.contract.Transact(opts, "batchUpdatePPS", args)
}

// BatchUpdatePPS is a paid mutator transaction binding the contract method 0xa1867527.
//
// Solidity: function batchUpdatePPS((address[],bytes[][],uint256[],uint256[],uint256[],uint256[],uint256[]) args) returns()
func (_ECDSAPPSOracle *ECDSAPPSOracleSession) BatchUpdatePPS(args IECDSAPPSOracleBatchUpdatePPSArgs) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.BatchUpdatePPS(&_ECDSAPPSOracle.TransactOpts, args)
}

// BatchUpdatePPS is a paid mutator transaction binding the contract method 0xa1867527.
//
// Solidity: function batchUpdatePPS((address[],bytes[][],uint256[],uint256[],uint256[],uint256[],uint256[]) args) returns()
func (_ECDSAPPSOracle *ECDSAPPSOracleTransactorSession) BatchUpdatePPS(args IECDSAPPSOracleBatchUpdatePPSArgs) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.BatchUpdatePPS(&_ECDSAPPSOracle.TransactOpts, args)
}

// UpdatePPS is a paid mutator transaction binding the contract method 0x2382d9c3.
//
// Solidity: function updatePPS((address,bytes[],uint256,uint256,uint256,uint256,uint256) args) returns()
func (_ECDSAPPSOracle *ECDSAPPSOracleTransactor) UpdatePPS(opts *bind.TransactOpts, args IECDSAPPSOracleUpdatePPSArgs) (*types.Transaction, error) {
	return _ECDSAPPSOracle.contract.Transact(opts, "updatePPS", args)
}

// UpdatePPS is a paid mutator transaction binding the contract method 0x2382d9c3.
//
// Solidity: function updatePPS((address,bytes[],uint256,uint256,uint256,uint256,uint256) args) returns()
func (_ECDSAPPSOracle *ECDSAPPSOracleSession) UpdatePPS(args IECDSAPPSOracleUpdatePPSArgs) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.UpdatePPS(&_ECDSAPPSOracle.TransactOpts, args)
}

// UpdatePPS is a paid mutator transaction binding the contract method 0x2382d9c3.
//
// Solidity: function updatePPS((address,bytes[],uint256,uint256,uint256,uint256,uint256) args) returns()
func (_ECDSAPPSOracle *ECDSAPPSOracleTransactorSession) UpdatePPS(args IECDSAPPSOracleUpdatePPSArgs) (*types.Transaction, error) {
	return _ECDSAPPSOracle.Contract.UpdatePPS(&_ECDSAPPSOracle.TransactOpts, args)
}

// ECDSAPPSOraclePPSValidatedIterator is returned from FilterPPSValidated and is used to iterate over the raw logs and unpacked data for PPSValidated events raised by the ECDSAPPSOracle contract.
type ECDSAPPSOraclePPSValidatedIterator struct {
	Event *ECDSAPPSOraclePPSValidated // Event containing the contract specifics and raw log

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
func (it *ECDSAPPSOraclePPSValidatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ECDSAPPSOraclePPSValidated)
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
		it.Event = new(ECDSAPPSOraclePPSValidated)
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
func (it *ECDSAPPSOraclePPSValidatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ECDSAPPSOraclePPSValidatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ECDSAPPSOraclePPSValidated represents a PPSValidated event raised by the ECDSAPPSOracle contract.
type ECDSAPPSOraclePPSValidated struct {
	Strategy        common.Address
	Pps             *big.Int
	PpsStdev        *big.Int
	ValidatorSet    *big.Int
	TotalValidators *big.Int
	Timestamp       *big.Int
	Sender          common.Address
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterPPSValidated is a free log retrieval operation binding the contract event 0xfbdd9422833aff4d04333f008c0d33063458b4050c51fbd4f1eeb2cea915e954.
//
// Solidity: event PPSValidated(address indexed strategy, uint256 pps, uint256 ppsStdev, uint256 validatorSet, uint256 totalValidators, uint256 timestamp, address indexed sender)
func (_ECDSAPPSOracle *ECDSAPPSOracleFilterer) FilterPPSValidated(opts *bind.FilterOpts, strategy []common.Address, sender []common.Address) (*ECDSAPPSOraclePPSValidatedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _ECDSAPPSOracle.contract.FilterLogs(opts, "PPSValidated", strategyRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &ECDSAPPSOraclePPSValidatedIterator{contract: _ECDSAPPSOracle.contract, event: "PPSValidated", logs: logs, sub: sub}, nil
}

// WatchPPSValidated is a free log subscription operation binding the contract event 0xfbdd9422833aff4d04333f008c0d33063458b4050c51fbd4f1eeb2cea915e954.
//
// Solidity: event PPSValidated(address indexed strategy, uint256 pps, uint256 ppsStdev, uint256 validatorSet, uint256 totalValidators, uint256 timestamp, address indexed sender)
func (_ECDSAPPSOracle *ECDSAPPSOracleFilterer) WatchPPSValidated(opts *bind.WatchOpts, sink chan<- *ECDSAPPSOraclePPSValidated, strategy []common.Address, sender []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _ECDSAPPSOracle.contract.WatchLogs(opts, "PPSValidated", strategyRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ECDSAPPSOraclePPSValidated)
				if err := _ECDSAPPSOracle.contract.UnpackLog(event, "PPSValidated", log); err != nil {
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

// ParsePPSValidated is a log parse operation binding the contract event 0xfbdd9422833aff4d04333f008c0d33063458b4050c51fbd4f1eeb2cea915e954.
//
// Solidity: event PPSValidated(address indexed strategy, uint256 pps, uint256 ppsStdev, uint256 validatorSet, uint256 totalValidators, uint256 timestamp, address indexed sender)
func (_ECDSAPPSOracle *ECDSAPPSOracleFilterer) ParsePPSValidated(log types.Log) (*ECDSAPPSOraclePPSValidated, error) {
	event := new(ECDSAPPSOraclePPSValidated)
	if err := _ECDSAPPSOracle.contract.UnpackLog(event, "PPSValidated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
