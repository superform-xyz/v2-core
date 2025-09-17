// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperDeployer

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

// SuperDeployerMetaData contains all meta data concerning the SuperDeployer contract.
var SuperDeployerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"deploy\",\"inputs\":[{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"creationCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"deployed\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"getDeployed\",\"inputs\":[{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isDeployed\",\"inputs\":[{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"ContractDeployed\",\"inputs\":[{\"name\":\"deployed\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"deployer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false}]",
}

// SuperDeployerABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperDeployerMetaData.ABI instead.
var SuperDeployerABI = SuperDeployerMetaData.ABI

// SuperDeployer is an auto generated Go binding around an Ethereum contract.
type SuperDeployer struct {
	SuperDeployerCaller     // Read-only binding to the contract
	SuperDeployerTransactor // Write-only binding to the contract
	SuperDeployerFilterer   // Log filterer for contract events
}

// SuperDeployerCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperDeployerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDeployerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperDeployerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDeployerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperDeployerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDeployerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperDeployerSession struct {
	Contract     *SuperDeployer    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperDeployerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperDeployerCallerSession struct {
	Contract *SuperDeployerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// SuperDeployerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperDeployerTransactorSession struct {
	Contract     *SuperDeployerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SuperDeployerRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperDeployerRaw struct {
	Contract *SuperDeployer // Generic contract binding to access the raw methods on
}

// SuperDeployerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperDeployerCallerRaw struct {
	Contract *SuperDeployerCaller // Generic read-only contract binding to access the raw methods on
}

// SuperDeployerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperDeployerTransactorRaw struct {
	Contract *SuperDeployerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperDeployer creates a new instance of SuperDeployer, bound to a specific deployed contract.
func NewSuperDeployer(address common.Address, backend bind.ContractBackend) (*SuperDeployer, error) {
	contract, err := bindSuperDeployer(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperDeployer{SuperDeployerCaller: SuperDeployerCaller{contract: contract}, SuperDeployerTransactor: SuperDeployerTransactor{contract: contract}, SuperDeployerFilterer: SuperDeployerFilterer{contract: contract}}, nil
}

// NewSuperDeployerCaller creates a new read-only instance of SuperDeployer, bound to a specific deployed contract.
func NewSuperDeployerCaller(address common.Address, caller bind.ContractCaller) (*SuperDeployerCaller, error) {
	contract, err := bindSuperDeployer(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDeployerCaller{contract: contract}, nil
}

// NewSuperDeployerTransactor creates a new write-only instance of SuperDeployer, bound to a specific deployed contract.
func NewSuperDeployerTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperDeployerTransactor, error) {
	contract, err := bindSuperDeployer(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDeployerTransactor{contract: contract}, nil
}

// NewSuperDeployerFilterer creates a new log filterer instance of SuperDeployer, bound to a specific deployed contract.
func NewSuperDeployerFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperDeployerFilterer, error) {
	contract, err := bindSuperDeployer(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperDeployerFilterer{contract: contract}, nil
}

// bindSuperDeployer binds a generic wrapper to an already deployed contract.
func bindSuperDeployer(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperDeployerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDeployer *SuperDeployerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDeployer.Contract.SuperDeployerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDeployer *SuperDeployerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDeployer.Contract.SuperDeployerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDeployer *SuperDeployerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDeployer.Contract.SuperDeployerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDeployer *SuperDeployerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDeployer.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDeployer *SuperDeployerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDeployer.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDeployer *SuperDeployerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDeployer.Contract.contract.Transact(opts, method, params...)
}

// GetDeployed is a free data retrieval call binding the contract method 0xdf20e252.
//
// Solidity: function getDeployed(bytes32 salt) view returns(address)
func (_SuperDeployer *SuperDeployerCaller) GetDeployed(opts *bind.CallOpts, salt [32]byte) (common.Address, error) {
	var out []interface{}
	err := _SuperDeployer.contract.Call(opts, &out, "getDeployed", salt)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetDeployed is a free data retrieval call binding the contract method 0xdf20e252.
//
// Solidity: function getDeployed(bytes32 salt) view returns(address)
func (_SuperDeployer *SuperDeployerSession) GetDeployed(salt [32]byte) (common.Address, error) {
	return _SuperDeployer.Contract.GetDeployed(&_SuperDeployer.CallOpts, salt)
}

// GetDeployed is a free data retrieval call binding the contract method 0xdf20e252.
//
// Solidity: function getDeployed(bytes32 salt) view returns(address)
func (_SuperDeployer *SuperDeployerCallerSession) GetDeployed(salt [32]byte) (common.Address, error) {
	return _SuperDeployer.Contract.GetDeployed(&_SuperDeployer.CallOpts, salt)
}

// IsDeployed is a free data retrieval call binding the contract method 0x74c0ff4f.
//
// Solidity: function isDeployed(bytes32 salt) view returns(bool)
func (_SuperDeployer *SuperDeployerCaller) IsDeployed(opts *bind.CallOpts, salt [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperDeployer.contract.Call(opts, &out, "isDeployed", salt)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsDeployed is a free data retrieval call binding the contract method 0x74c0ff4f.
//
// Solidity: function isDeployed(bytes32 salt) view returns(bool)
func (_SuperDeployer *SuperDeployerSession) IsDeployed(salt [32]byte) (bool, error) {
	return _SuperDeployer.Contract.IsDeployed(&_SuperDeployer.CallOpts, salt)
}

// IsDeployed is a free data retrieval call binding the contract method 0x74c0ff4f.
//
// Solidity: function isDeployed(bytes32 salt) view returns(bool)
func (_SuperDeployer *SuperDeployerCallerSession) IsDeployed(salt [32]byte) (bool, error) {
	return _SuperDeployer.Contract.IsDeployed(&_SuperDeployer.CallOpts, salt)
}

// Deploy is a paid mutator transaction binding the contract method 0xcdcb760a.
//
// Solidity: function deploy(bytes32 salt, bytes creationCode) payable returns(address deployed)
func (_SuperDeployer *SuperDeployerTransactor) Deploy(opts *bind.TransactOpts, salt [32]byte, creationCode []byte) (*types.Transaction, error) {
	return _SuperDeployer.contract.Transact(opts, "deploy", salt, creationCode)
}

// Deploy is a paid mutator transaction binding the contract method 0xcdcb760a.
//
// Solidity: function deploy(bytes32 salt, bytes creationCode) payable returns(address deployed)
func (_SuperDeployer *SuperDeployerSession) Deploy(salt [32]byte, creationCode []byte) (*types.Transaction, error) {
	return _SuperDeployer.Contract.Deploy(&_SuperDeployer.TransactOpts, salt, creationCode)
}

// Deploy is a paid mutator transaction binding the contract method 0xcdcb760a.
//
// Solidity: function deploy(bytes32 salt, bytes creationCode) payable returns(address deployed)
func (_SuperDeployer *SuperDeployerTransactorSession) Deploy(salt [32]byte, creationCode []byte) (*types.Transaction, error) {
	return _SuperDeployer.Contract.Deploy(&_SuperDeployer.TransactOpts, salt, creationCode)
}

// SuperDeployerContractDeployedIterator is returned from FilterContractDeployed and is used to iterate over the raw logs and unpacked data for ContractDeployed events raised by the SuperDeployer contract.
type SuperDeployerContractDeployedIterator struct {
	Event *SuperDeployerContractDeployed // Event containing the contract specifics and raw log

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
func (it *SuperDeployerContractDeployedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDeployerContractDeployed)
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
		it.Event = new(SuperDeployerContractDeployed)
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
func (it *SuperDeployerContractDeployedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDeployerContractDeployedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDeployerContractDeployed represents a ContractDeployed event raised by the SuperDeployer contract.
type SuperDeployerContractDeployed struct {
	Deployed common.Address
	Salt     [32]byte
	Deployer common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterContractDeployed is a free log retrieval operation binding the contract event 0x290afdae231a3fc0bbae8b1af63698b0a1d79b21ad17df0342dfb952fe74f8e5.
//
// Solidity: event ContractDeployed(address indexed deployed, bytes32 indexed salt, address indexed deployer)
func (_SuperDeployer *SuperDeployerFilterer) FilterContractDeployed(opts *bind.FilterOpts, deployed []common.Address, salt [][32]byte, deployer []common.Address) (*SuperDeployerContractDeployedIterator, error) {

	var deployedRule []interface{}
	for _, deployedItem := range deployed {
		deployedRule = append(deployedRule, deployedItem)
	}
	var saltRule []interface{}
	for _, saltItem := range salt {
		saltRule = append(saltRule, saltItem)
	}
	var deployerRule []interface{}
	for _, deployerItem := range deployer {
		deployerRule = append(deployerRule, deployerItem)
	}

	logs, sub, err := _SuperDeployer.contract.FilterLogs(opts, "ContractDeployed", deployedRule, saltRule, deployerRule)
	if err != nil {
		return nil, err
	}
	return &SuperDeployerContractDeployedIterator{contract: _SuperDeployer.contract, event: "ContractDeployed", logs: logs, sub: sub}, nil
}

// WatchContractDeployed is a free log subscription operation binding the contract event 0x290afdae231a3fc0bbae8b1af63698b0a1d79b21ad17df0342dfb952fe74f8e5.
//
// Solidity: event ContractDeployed(address indexed deployed, bytes32 indexed salt, address indexed deployer)
func (_SuperDeployer *SuperDeployerFilterer) WatchContractDeployed(opts *bind.WatchOpts, sink chan<- *SuperDeployerContractDeployed, deployed []common.Address, salt [][32]byte, deployer []common.Address) (event.Subscription, error) {

	var deployedRule []interface{}
	for _, deployedItem := range deployed {
		deployedRule = append(deployedRule, deployedItem)
	}
	var saltRule []interface{}
	for _, saltItem := range salt {
		saltRule = append(saltRule, saltItem)
	}
	var deployerRule []interface{}
	for _, deployerItem := range deployer {
		deployerRule = append(deployerRule, deployerItem)
	}

	logs, sub, err := _SuperDeployer.contract.WatchLogs(opts, "ContractDeployed", deployedRule, saltRule, deployerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDeployerContractDeployed)
				if err := _SuperDeployer.contract.UnpackLog(event, "ContractDeployed", log); err != nil {
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

// ParseContractDeployed is a log parse operation binding the contract event 0x290afdae231a3fc0bbae8b1af63698b0a1d79b21ad17df0342dfb952fe74f8e5.
//
// Solidity: event ContractDeployed(address indexed deployed, bytes32 indexed salt, address indexed deployer)
func (_SuperDeployer *SuperDeployerFilterer) ParseContractDeployed(log types.Log) (*SuperDeployerContractDeployed, error) {
	event := new(SuperDeployerContractDeployed)
	if err := _SuperDeployer.contract.UnpackLog(event, "ContractDeployed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
