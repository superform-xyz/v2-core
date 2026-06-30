// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package IStargateAdapterClaim

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

// IStargateAdapterClaimMetaData contains all meta data concerning the IStargateAdapterClaim contract.
var IStargateAdapterClaimMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"}]",
}

// IStargateAdapterClaimABI is the input ABI used to generate the binding from.
// Deprecated: Use IStargateAdapterClaimMetaData.ABI instead.
var IStargateAdapterClaimABI = IStargateAdapterClaimMetaData.ABI

// IStargateAdapterClaim is an auto generated Go binding around an Ethereum contract.
type IStargateAdapterClaim struct {
	IStargateAdapterClaimCaller     // Read-only binding to the contract
	IStargateAdapterClaimTransactor // Write-only binding to the contract
	IStargateAdapterClaimFilterer   // Log filterer for contract events
}

// IStargateAdapterClaimCaller is an auto generated read-only Go binding around an Ethereum contract.
type IStargateAdapterClaimCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IStargateAdapterClaimTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IStargateAdapterClaimTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IStargateAdapterClaimFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IStargateAdapterClaimFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IStargateAdapterClaimSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IStargateAdapterClaimSession struct {
	Contract     *IStargateAdapterClaim // Generic contract binding to set the session for
	CallOpts     bind.CallOpts          // Call options to use throughout this session
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// IStargateAdapterClaimCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IStargateAdapterClaimCallerSession struct {
	Contract *IStargateAdapterClaimCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                // Call options to use throughout this session
}

// IStargateAdapterClaimTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IStargateAdapterClaimTransactorSession struct {
	Contract     *IStargateAdapterClaimTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                // Transaction auth options to use throughout this session
}

// IStargateAdapterClaimRaw is an auto generated low-level Go binding around an Ethereum contract.
type IStargateAdapterClaimRaw struct {
	Contract *IStargateAdapterClaim // Generic contract binding to access the raw methods on
}

// IStargateAdapterClaimCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IStargateAdapterClaimCallerRaw struct {
	Contract *IStargateAdapterClaimCaller // Generic read-only contract binding to access the raw methods on
}

// IStargateAdapterClaimTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IStargateAdapterClaimTransactorRaw struct {
	Contract *IStargateAdapterClaimTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIStargateAdapterClaim creates a new instance of IStargateAdapterClaim, bound to a specific deployed contract.
func NewIStargateAdapterClaim(address common.Address, backend bind.ContractBackend) (*IStargateAdapterClaim, error) {
	contract, err := bindIStargateAdapterClaim(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IStargateAdapterClaim{IStargateAdapterClaimCaller: IStargateAdapterClaimCaller{contract: contract}, IStargateAdapterClaimTransactor: IStargateAdapterClaimTransactor{contract: contract}, IStargateAdapterClaimFilterer: IStargateAdapterClaimFilterer{contract: contract}}, nil
}

// NewIStargateAdapterClaimCaller creates a new read-only instance of IStargateAdapterClaim, bound to a specific deployed contract.
func NewIStargateAdapterClaimCaller(address common.Address, caller bind.ContractCaller) (*IStargateAdapterClaimCaller, error) {
	contract, err := bindIStargateAdapterClaim(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IStargateAdapterClaimCaller{contract: contract}, nil
}

// NewIStargateAdapterClaimTransactor creates a new write-only instance of IStargateAdapterClaim, bound to a specific deployed contract.
func NewIStargateAdapterClaimTransactor(address common.Address, transactor bind.ContractTransactor) (*IStargateAdapterClaimTransactor, error) {
	contract, err := bindIStargateAdapterClaim(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IStargateAdapterClaimTransactor{contract: contract}, nil
}

// NewIStargateAdapterClaimFilterer creates a new log filterer instance of IStargateAdapterClaim, bound to a specific deployed contract.
func NewIStargateAdapterClaimFilterer(address common.Address, filterer bind.ContractFilterer) (*IStargateAdapterClaimFilterer, error) {
	contract, err := bindIStargateAdapterClaim(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IStargateAdapterClaimFilterer{contract: contract}, nil
}

// bindIStargateAdapterClaim binds a generic wrapper to an already deployed contract.
func bindIStargateAdapterClaim(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := IStargateAdapterClaimMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IStargateAdapterClaim *IStargateAdapterClaimRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IStargateAdapterClaim.Contract.IStargateAdapterClaimCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IStargateAdapterClaim *IStargateAdapterClaimRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IStargateAdapterClaim.Contract.IStargateAdapterClaimTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IStargateAdapterClaim *IStargateAdapterClaimRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IStargateAdapterClaim.Contract.IStargateAdapterClaimTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IStargateAdapterClaim *IStargateAdapterClaimCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IStargateAdapterClaim.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IStargateAdapterClaim *IStargateAdapterClaimTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IStargateAdapterClaim.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IStargateAdapterClaim *IStargateAdapterClaimTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IStargateAdapterClaim.Contract.contract.Transact(opts, method, params...)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_IStargateAdapterClaim *IStargateAdapterClaimTransactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _IStargateAdapterClaim.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_IStargateAdapterClaim *IStargateAdapterClaimSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _IStargateAdapterClaim.Contract.ClaimFailedTransfer(&_IStargateAdapterClaim.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_IStargateAdapterClaim *IStargateAdapterClaimTransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _IStargateAdapterClaim.Contract.ClaimFailedTransfer(&_IStargateAdapterClaim.TransactOpts, token, amount)
}
