// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package contracts

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

// SuperBridgeMetaData contains all meta data concerning the SuperBridge contract.
var SuperBridgeMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_relayer\",\"type\":\"address\"}],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"destinationChainId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"destinationContract\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"Msg\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"relayer\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"release\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"dstChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"send\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
	Bin: "0x608060405234801561000f575f80fd5b50604051610850380380610850833981810160405281019061003191906100d4565b805f806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550506100ff565b5f80fd5b5f73ffffffffffffffffffffffffffffffffffffffff82169050919050565b5f6100a38261007a565b9050919050565b6100b381610099565b81146100bd575f80fd5b50565b5f815190506100ce816100aa565b92915050565b5f602082840312156100e9576100e8610076565b5b5f6100f6848285016100c0565b91505092915050565b6107448061010c5f395ff3fe608060405234801561000f575f80fd5b506004361061003f575f3560e01c8063150b375f146100435780638406c0791461005f578063af411b1d1461007d575b5f80fd5b61005d60048036038101906100589190610424565b610099565b005b6100676100ed565b604051610074919061049f565b60405180910390f35b610097600480360381019061009291906104b8565b610110565b005b8173ffffffffffffffffffffffffffffffffffffffff16837f48e957ce415904e13d24866d8154cae4d6effcae2b4676dab6c58ec19258c262836040516100e09190610572565b60405180910390a3505050565b5f8054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b5f8054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161461019d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161019490610612565b60405180910390fd5b5f8273ffffffffffffffffffffffffffffffffffffffff16826040516101c3919061066a565b5f604051808303815f865af19150503d805f81146101fc576040519150601f19603f3d011682016040523d82523d5f602084013e610201565b606091505b5050905080610245576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161023c906106f0565b60405180910390fd5b505050565b5f604051905090565b5f80fd5b5f80fd5b5f819050919050565b61026d8161025b565b8114610277575f80fd5b50565b5f8135905061028881610264565b92915050565b5f73ffffffffffffffffffffffffffffffffffffffff82169050919050565b5f6102b78261028e565b9050919050565b6102c7816102ad565b81146102d1575f80fd5b50565b5f813590506102e2816102be565b92915050565b5f80fd5b5f80fd5b5f601f19601f8301169050919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b610336826102f0565b810181811067ffffffffffffffff8211171561035557610354610300565b5b80604052505050565b5f61036761024a565b9050610373828261032d565b919050565b5f67ffffffffffffffff82111561039257610391610300565b5b61039b826102f0565b9050602081019050919050565b828183375f83830152505050565b5f6103c86103c384610378565b61035e565b9050828152602081018484840111156103e4576103e36102ec565b5b6103ef8482856103a8565b509392505050565b5f82601f83011261040b5761040a6102e8565b5b813561041b8482602086016103b6565b91505092915050565b5f805f6060848603121561043b5761043a610253565b5b5f6104488682870161027a565b9350506020610459868287016102d4565b925050604084013567ffffffffffffffff81111561047a57610479610257565b5b610486868287016103f7565b9150509250925092565b610499816102ad565b82525050565b5f6020820190506104b25f830184610490565b92915050565b5f80604083850312156104ce576104cd610253565b5b5f6104db858286016102d4565b925050602083013567ffffffffffffffff8111156104fc576104fb610257565b5b610508858286016103f7565b9150509250929050565b5f81519050919050565b5f82825260208201905092915050565b8281835e5f83830152505050565b5f61054482610512565b61054e818561051c565b935061055e81856020860161052c565b610567816102f0565b840191505092915050565b5f6020820190508181035f83015261058a818461053a565b905092915050565b5f82825260208201905092915050565b7f4f6e6c792072656c617965722063616e2063616c6c20746869732066756e63745f8201527f696f6e0000000000000000000000000000000000000000000000000000000000602082015250565b5f6105fc602383610592565b9150610607826105a2565b604082019050919050565b5f6020820190508181035f830152610629816105f0565b9050919050565b5f81905092915050565b5f61064482610512565b61064e8185610630565b935061065e81856020860161052c565b80840191505092915050565b5f610675828461063a565b915081905092915050565b7f43616c6c20746f2064657374696e6174696f6e20636f6e7472616374206661695f8201527f6c65640000000000000000000000000000000000000000000000000000000000602082015250565b5f6106da602383610592565b91506106e582610680565b604082019050919050565b5f6020820190508181035f830152610707816106ce565b905091905056fea2646970667358221220a57860f448b0db2d2705feb59cbc396820a2f887ecb15b1a6d8a6c9046e5246564736f6c63430008190033",
}

// SuperBridgeABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperBridgeMetaData.ABI instead.
var SuperBridgeABI = SuperBridgeMetaData.ABI

// SuperBridgeBin is the compiled bytecode used for deploying new contracts.
// Deprecated: Use SuperBridgeMetaData.Bin instead.
var SuperBridgeBin = SuperBridgeMetaData.Bin

// DeploySuperBridge deploys a new Ethereum contract, binding an instance of SuperBridge to it.
func DeploySuperBridge(auth *bind.TransactOpts, backend bind.ContractBackend, _relayer common.Address) (common.Address, *types.Transaction, *SuperBridge, error) {
	parsed, err := SuperBridgeMetaData.GetAbi()
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	if parsed == nil {
		return common.Address{}, nil, nil, errors.New("GetABI returned nil")
	}

	address, tx, contract, err := bind.DeployContract(auth, *parsed, common.FromHex(SuperBridgeBin), backend, _relayer)
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	return address, tx, &SuperBridge{SuperBridgeCaller: SuperBridgeCaller{contract: contract}, SuperBridgeTransactor: SuperBridgeTransactor{contract: contract}, SuperBridgeFilterer: SuperBridgeFilterer{contract: contract}}, nil
}

// SuperBridge is an auto generated Go binding around an Ethereum contract.
type SuperBridge struct {
	SuperBridgeCaller     // Read-only binding to the contract
	SuperBridgeTransactor // Write-only binding to the contract
	SuperBridgeFilterer   // Log filterer for contract events
}

// SuperBridgeCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperBridgeCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBridgeTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperBridgeTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBridgeFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperBridgeFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBridgeSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperBridgeSession struct {
	Contract     *SuperBridge      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperBridgeCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperBridgeCallerSession struct {
	Contract *SuperBridgeCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// SuperBridgeTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperBridgeTransactorSession struct {
	Contract     *SuperBridgeTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// SuperBridgeRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperBridgeRaw struct {
	Contract *SuperBridge // Generic contract binding to access the raw methods on
}

// SuperBridgeCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperBridgeCallerRaw struct {
	Contract *SuperBridgeCaller // Generic read-only contract binding to access the raw methods on
}

// SuperBridgeTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperBridgeTransactorRaw struct {
	Contract *SuperBridgeTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperBridge creates a new instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridge(address common.Address, backend bind.ContractBackend) (*SuperBridge, error) {
	contract, err := bindSuperBridge(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperBridge{SuperBridgeCaller: SuperBridgeCaller{contract: contract}, SuperBridgeTransactor: SuperBridgeTransactor{contract: contract}, SuperBridgeFilterer: SuperBridgeFilterer{contract: contract}}, nil
}

// NewSuperBridgeCaller creates a new read-only instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridgeCaller(address common.Address, caller bind.ContractCaller) (*SuperBridgeCaller, error) {
	contract, err := bindSuperBridge(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeCaller{contract: contract}, nil
}

// NewSuperBridgeTransactor creates a new write-only instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridgeTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperBridgeTransactor, error) {
	contract, err := bindSuperBridge(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeTransactor{contract: contract}, nil
}

// NewSuperBridgeFilterer creates a new log filterer instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridgeFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperBridgeFilterer, error) {
	contract, err := bindSuperBridge(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeFilterer{contract: contract}, nil
}

// bindSuperBridge binds a generic wrapper to an already deployed contract.
func bindSuperBridge(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperBridgeMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperBridge *SuperBridgeRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperBridge.Contract.SuperBridgeCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperBridge *SuperBridgeRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperBridge.Contract.SuperBridgeTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperBridge *SuperBridgeRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperBridge.Contract.SuperBridgeTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperBridge *SuperBridgeCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperBridge.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperBridge *SuperBridgeTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperBridge.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperBridge *SuperBridgeTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperBridge.Contract.contract.Transact(opts, method, params...)
}

// Relayer is a free data retrieval call binding the contract method 0x8406c079.
//
// Solidity: function relayer() view returns(address)
func (_SuperBridge *SuperBridgeCaller) Relayer(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperBridge.contract.Call(opts, &out, "relayer")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Relayer is a free data retrieval call binding the contract method 0x8406c079.
//
// Solidity: function relayer() view returns(address)
func (_SuperBridge *SuperBridgeSession) Relayer() (common.Address, error) {
	return _SuperBridge.Contract.Relayer(&_SuperBridge.CallOpts)
}

// Relayer is a free data retrieval call binding the contract method 0x8406c079.
//
// Solidity: function relayer() view returns(address)
func (_SuperBridge *SuperBridgeCallerSession) Relayer() (common.Address, error) {
	return _SuperBridge.Contract.Relayer(&_SuperBridge.CallOpts)
}

// Release is a paid mutator transaction binding the contract method 0xaf411b1d.
//
// Solidity: function release(address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactor) Release(opts *bind.TransactOpts, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.contract.Transact(opts, "release", addr, data)
}

// Release is a paid mutator transaction binding the contract method 0xaf411b1d.
//
// Solidity: function release(address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeSession) Release(addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Release(&_SuperBridge.TransactOpts, addr, data)
}

// Release is a paid mutator transaction binding the contract method 0xaf411b1d.
//
// Solidity: function release(address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactorSession) Release(addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Release(&_SuperBridge.TransactOpts, addr, data)
}

// Send is a paid mutator transaction binding the contract method 0x150b375f.
//
// Solidity: function send(uint256 dstChainId, address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactor) Send(opts *bind.TransactOpts, dstChainId *big.Int, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.contract.Transact(opts, "send", dstChainId, addr, data)
}

// Send is a paid mutator transaction binding the contract method 0x150b375f.
//
// Solidity: function send(uint256 dstChainId, address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeSession) Send(dstChainId *big.Int, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Send(&_SuperBridge.TransactOpts, dstChainId, addr, data)
}

// Send is a paid mutator transaction binding the contract method 0x150b375f.
//
// Solidity: function send(uint256 dstChainId, address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactorSession) Send(dstChainId *big.Int, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Send(&_SuperBridge.TransactOpts, dstChainId, addr, data)
}

// SuperBridgeMsgIterator is returned from FilterMsg and is used to iterate over the raw logs and unpacked data for Msg events raised by the SuperBridge contract.
type SuperBridgeMsgIterator struct {
	Event *SuperBridgeMsg // Event containing the contract specifics and raw log

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
func (it *SuperBridgeMsgIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperBridgeMsg)
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
		it.Event = new(SuperBridgeMsg)
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
func (it *SuperBridgeMsgIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperBridgeMsgIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperBridgeMsg represents a Msg event raised by the SuperBridge contract.
type SuperBridgeMsg struct {
	DestinationChainId  *big.Int
	DestinationContract common.Address
	Data                []byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterMsg is a free log retrieval operation binding the contract event 0x48e957ce415904e13d24866d8154cae4d6effcae2b4676dab6c58ec19258c262.
//
// Solidity: event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) FilterMsg(opts *bind.FilterOpts, destinationChainId []*big.Int, destinationContract []common.Address) (*SuperBridgeMsgIterator, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _SuperBridge.contract.FilterLogs(opts, "Msg", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeMsgIterator{contract: _SuperBridge.contract, event: "Msg", logs: logs, sub: sub}, nil
}

// WatchMsg is a free log subscription operation binding the contract event 0x48e957ce415904e13d24866d8154cae4d6effcae2b4676dab6c58ec19258c262.
//
// Solidity: event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) WatchMsg(opts *bind.WatchOpts, sink chan<- *SuperBridgeMsg, destinationChainId []*big.Int, destinationContract []common.Address) (event.Subscription, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _SuperBridge.contract.WatchLogs(opts, "Msg", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperBridgeMsg)
				if err := _SuperBridge.contract.UnpackLog(event, "Msg", log); err != nil {
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

// ParseMsg is a log parse operation binding the contract event 0x48e957ce415904e13d24866d8154cae4d6effcae2b4676dab6c58ec19258c262.
//
// Solidity: event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) ParseMsg(log types.Log) (*SuperBridgeMsg, error) {
	event := new(SuperBridgeMsg)
	if err := _SuperBridge.contract.UnpackLog(event, "Msg", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
