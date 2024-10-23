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

// FooMetaData contains all meta data concerning the Foo contract.
var FooMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"value\",\"type\":\"uint256\"}],\"name\":\"id\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"pure\",\"type\":\"function\"}]",
	Bin: "0x6080604052348015600e575f80fd5b5061010f8061001c5f395ff3fe6080604052348015600e575f80fd5b50600436106026575f3560e01c80637d3c40c814602a575b5f80fd5b60406004803603810190603c9190608f565b6054565b604051604b919060c2565b60405180910390f35b5f819050919050565b5f80fd5b5f819050919050565b6071816061565b8114607a575f80fd5b50565b5f81359050608981606a565b92915050565b5f6020828403121560a15760a0605d565b5b5f60ac84828501607d565b91505092915050565b60bc816061565b82525050565b5f60208201905060d35f83018460b5565b9291505056fea26469706673582212202840b47ba2914b74dcfd18251b9b4722dd6950e15a950a381045fdc6c2f1476c64736f6c63430008190033",
}

// FooABI is the input ABI used to generate the binding from.
// Deprecated: Use FooMetaData.ABI instead.
var FooABI = FooMetaData.ABI

// FooBin is the compiled bytecode used for deploying new contracts.
// Deprecated: Use FooMetaData.Bin instead.
var FooBin = FooMetaData.Bin

// DeployFoo deploys a new Ethereum contract, binding an instance of Foo to it.
func DeployFoo(auth *bind.TransactOpts, backend bind.ContractBackend) (common.Address, *types.Transaction, *Foo, error) {
	parsed, err := FooMetaData.GetAbi()
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	if parsed == nil {
		return common.Address{}, nil, nil, errors.New("GetABI returned nil")
	}

	address, tx, contract, err := bind.DeployContract(auth, *parsed, common.FromHex(FooBin), backend)
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	return address, tx, &Foo{FooCaller: FooCaller{contract: contract}, FooTransactor: FooTransactor{contract: contract}, FooFilterer: FooFilterer{contract: contract}}, nil
}

// Foo is an auto generated Go binding around an Ethereum contract.
type Foo struct {
	FooCaller     // Read-only binding to the contract
	FooTransactor // Write-only binding to the contract
	FooFilterer   // Log filterer for contract events
}

// FooCaller is an auto generated read-only Go binding around an Ethereum contract.
type FooCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// FooTransactor is an auto generated write-only Go binding around an Ethereum contract.
type FooTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// FooFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type FooFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// FooSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type FooSession struct {
	Contract     *Foo              // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// FooCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type FooCallerSession struct {
	Contract *FooCaller    // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts // Call options to use throughout this session
}

// FooTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type FooTransactorSession struct {
	Contract     *FooTransactor    // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// FooRaw is an auto generated low-level Go binding around an Ethereum contract.
type FooRaw struct {
	Contract *Foo // Generic contract binding to access the raw methods on
}

// FooCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type FooCallerRaw struct {
	Contract *FooCaller // Generic read-only contract binding to access the raw methods on
}

// FooTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type FooTransactorRaw struct {
	Contract *FooTransactor // Generic write-only contract binding to access the raw methods on
}

// NewFoo creates a new instance of Foo, bound to a specific deployed contract.
func NewFoo(address common.Address, backend bind.ContractBackend) (*Foo, error) {
	contract, err := bindFoo(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Foo{FooCaller: FooCaller{contract: contract}, FooTransactor: FooTransactor{contract: contract}, FooFilterer: FooFilterer{contract: contract}}, nil
}

// NewFooCaller creates a new read-only instance of Foo, bound to a specific deployed contract.
func NewFooCaller(address common.Address, caller bind.ContractCaller) (*FooCaller, error) {
	contract, err := bindFoo(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &FooCaller{contract: contract}, nil
}

// NewFooTransactor creates a new write-only instance of Foo, bound to a specific deployed contract.
func NewFooTransactor(address common.Address, transactor bind.ContractTransactor) (*FooTransactor, error) {
	contract, err := bindFoo(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &FooTransactor{contract: contract}, nil
}

// NewFooFilterer creates a new log filterer instance of Foo, bound to a specific deployed contract.
func NewFooFilterer(address common.Address, filterer bind.ContractFilterer) (*FooFilterer, error) {
	contract, err := bindFoo(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &FooFilterer{contract: contract}, nil
}

// bindFoo binds a generic wrapper to an already deployed contract.
func bindFoo(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := FooMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Foo *FooRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Foo.Contract.FooCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Foo *FooRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Foo.Contract.FooTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Foo *FooRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Foo.Contract.FooTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Foo *FooCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Foo.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Foo *FooTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Foo.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Foo *FooTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Foo.Contract.contract.Transact(opts, method, params...)
}

// Id is a free data retrieval call binding the contract method 0x7d3c40c8.
//
// Solidity: function id(uint256 value) pure returns(uint256)
func (_Foo *FooCaller) Id(opts *bind.CallOpts, value *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _Foo.contract.Call(opts, &out, "id", value)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Id is a free data retrieval call binding the contract method 0x7d3c40c8.
//
// Solidity: function id(uint256 value) pure returns(uint256)
func (_Foo *FooSession) Id(value *big.Int) (*big.Int, error) {
	return _Foo.Contract.Id(&_Foo.CallOpts, value)
}

// Id is a free data retrieval call binding the contract method 0x7d3c40c8.
//
// Solidity: function id(uint256 value) pure returns(uint256)
func (_Foo *FooCallerSession) Id(value *big.Int) (*big.Int, error) {
	return _Foo.Contract.Id(&_Foo.CallOpts, value)
}
