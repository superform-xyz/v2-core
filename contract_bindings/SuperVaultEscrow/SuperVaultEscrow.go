// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperVaultEscrow

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

// SuperVaultEscrowMetaData contains all meta data concerning the SuperVaultEscrow contract.
var SuperVaultEscrowMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"escrowShares\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":[{\"name\":\"vault_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategy_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"initialized\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"returnShares\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"shares\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIERC20\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"strategy\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"vault\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperVaultEscrowABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperVaultEscrowMetaData.ABI instead.
var SuperVaultEscrowABI = SuperVaultEscrowMetaData.ABI

// SuperVaultEscrow is an auto generated Go binding around an Ethereum contract.
type SuperVaultEscrow struct {
	SuperVaultEscrowCaller     // Read-only binding to the contract
	SuperVaultEscrowTransactor // Write-only binding to the contract
	SuperVaultEscrowFilterer   // Log filterer for contract events
}

// SuperVaultEscrowCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperVaultEscrowCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultEscrowTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperVaultEscrowTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultEscrowFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperVaultEscrowFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultEscrowSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperVaultEscrowSession struct {
	Contract     *SuperVaultEscrow // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperVaultEscrowCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperVaultEscrowCallerSession struct {
	Contract *SuperVaultEscrowCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts           // Call options to use throughout this session
}

// SuperVaultEscrowTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperVaultEscrowTransactorSession struct {
	Contract     *SuperVaultEscrowTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts           // Transaction auth options to use throughout this session
}

// SuperVaultEscrowRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperVaultEscrowRaw struct {
	Contract *SuperVaultEscrow // Generic contract binding to access the raw methods on
}

// SuperVaultEscrowCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperVaultEscrowCallerRaw struct {
	Contract *SuperVaultEscrowCaller // Generic read-only contract binding to access the raw methods on
}

// SuperVaultEscrowTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperVaultEscrowTransactorRaw struct {
	Contract *SuperVaultEscrowTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperVaultEscrow creates a new instance of SuperVaultEscrow, bound to a specific deployed contract.
func NewSuperVaultEscrow(address common.Address, backend bind.ContractBackend) (*SuperVaultEscrow, error) {
	contract, err := bindSuperVaultEscrow(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperVaultEscrow{SuperVaultEscrowCaller: SuperVaultEscrowCaller{contract: contract}, SuperVaultEscrowTransactor: SuperVaultEscrowTransactor{contract: contract}, SuperVaultEscrowFilterer: SuperVaultEscrowFilterer{contract: contract}}, nil
}

// NewSuperVaultEscrowCaller creates a new read-only instance of SuperVaultEscrow, bound to a specific deployed contract.
func NewSuperVaultEscrowCaller(address common.Address, caller bind.ContractCaller) (*SuperVaultEscrowCaller, error) {
	contract, err := bindSuperVaultEscrow(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultEscrowCaller{contract: contract}, nil
}

// NewSuperVaultEscrowTransactor creates a new write-only instance of SuperVaultEscrow, bound to a specific deployed contract.
func NewSuperVaultEscrowTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperVaultEscrowTransactor, error) {
	contract, err := bindSuperVaultEscrow(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultEscrowTransactor{contract: contract}, nil
}

// NewSuperVaultEscrowFilterer creates a new log filterer instance of SuperVaultEscrow, bound to a specific deployed contract.
func NewSuperVaultEscrowFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperVaultEscrowFilterer, error) {
	contract, err := bindSuperVaultEscrow(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperVaultEscrowFilterer{contract: contract}, nil
}

// bindSuperVaultEscrow binds a generic wrapper to an already deployed contract.
func bindSuperVaultEscrow(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperVaultEscrowMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultEscrow *SuperVaultEscrowRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultEscrow.Contract.SuperVaultEscrowCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultEscrow *SuperVaultEscrowRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.SuperVaultEscrowTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultEscrow *SuperVaultEscrowRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.SuperVaultEscrowTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultEscrow *SuperVaultEscrowCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultEscrow.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultEscrow *SuperVaultEscrowTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultEscrow *SuperVaultEscrowTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.contract.Transact(opts, method, params...)
}

// Initialized is a free data retrieval call binding the contract method 0x158ef93e.
//
// Solidity: function initialized() view returns(bool)
func (_SuperVaultEscrow *SuperVaultEscrowCaller) Initialized(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperVaultEscrow.contract.Call(opts, &out, "initialized")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Initialized is a free data retrieval call binding the contract method 0x158ef93e.
//
// Solidity: function initialized() view returns(bool)
func (_SuperVaultEscrow *SuperVaultEscrowSession) Initialized() (bool, error) {
	return _SuperVaultEscrow.Contract.Initialized(&_SuperVaultEscrow.CallOpts)
}

// Initialized is a free data retrieval call binding the contract method 0x158ef93e.
//
// Solidity: function initialized() view returns(bool)
func (_SuperVaultEscrow *SuperVaultEscrowCallerSession) Initialized() (bool, error) {
	return _SuperVaultEscrow.Contract.Initialized(&_SuperVaultEscrow.CallOpts)
}

// Shares is a free data retrieval call binding the contract method 0x03314efa.
//
// Solidity: function shares() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowCaller) Shares(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultEscrow.contract.Call(opts, &out, "shares")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Shares is a free data retrieval call binding the contract method 0x03314efa.
//
// Solidity: function shares() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowSession) Shares() (common.Address, error) {
	return _SuperVaultEscrow.Contract.Shares(&_SuperVaultEscrow.CallOpts)
}

// Shares is a free data retrieval call binding the contract method 0x03314efa.
//
// Solidity: function shares() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowCallerSession) Shares() (common.Address, error) {
	return _SuperVaultEscrow.Contract.Shares(&_SuperVaultEscrow.CallOpts)
}

// Strategy is a free data retrieval call binding the contract method 0xa8c62e76.
//
// Solidity: function strategy() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowCaller) Strategy(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultEscrow.contract.Call(opts, &out, "strategy")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Strategy is a free data retrieval call binding the contract method 0xa8c62e76.
//
// Solidity: function strategy() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowSession) Strategy() (common.Address, error) {
	return _SuperVaultEscrow.Contract.Strategy(&_SuperVaultEscrow.CallOpts)
}

// Strategy is a free data retrieval call binding the contract method 0xa8c62e76.
//
// Solidity: function strategy() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowCallerSession) Strategy() (common.Address, error) {
	return _SuperVaultEscrow.Contract.Strategy(&_SuperVaultEscrow.CallOpts)
}

// Vault is a free data retrieval call binding the contract method 0xfbfa77cf.
//
// Solidity: function vault() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowCaller) Vault(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultEscrow.contract.Call(opts, &out, "vault")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Vault is a free data retrieval call binding the contract method 0xfbfa77cf.
//
// Solidity: function vault() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowSession) Vault() (common.Address, error) {
	return _SuperVaultEscrow.Contract.Vault(&_SuperVaultEscrow.CallOpts)
}

// Vault is a free data retrieval call binding the contract method 0xfbfa77cf.
//
// Solidity: function vault() view returns(address)
func (_SuperVaultEscrow *SuperVaultEscrowCallerSession) Vault() (common.Address, error) {
	return _SuperVaultEscrow.Contract.Vault(&_SuperVaultEscrow.CallOpts)
}

// EscrowShares is a paid mutator transaction binding the contract method 0x3aad4a4f.
//
// Solidity: function escrowShares(address from, uint256 amount) returns()
func (_SuperVaultEscrow *SuperVaultEscrowTransactor) EscrowShares(opts *bind.TransactOpts, from common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultEscrow.contract.Transact(opts, "escrowShares", from, amount)
}

// EscrowShares is a paid mutator transaction binding the contract method 0x3aad4a4f.
//
// Solidity: function escrowShares(address from, uint256 amount) returns()
func (_SuperVaultEscrow *SuperVaultEscrowSession) EscrowShares(from common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.EscrowShares(&_SuperVaultEscrow.TransactOpts, from, amount)
}

// EscrowShares is a paid mutator transaction binding the contract method 0x3aad4a4f.
//
// Solidity: function escrowShares(address from, uint256 amount) returns()
func (_SuperVaultEscrow *SuperVaultEscrowTransactorSession) EscrowShares(from common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.EscrowShares(&_SuperVaultEscrow.TransactOpts, from, amount)
}

// Initialize is a paid mutator transaction binding the contract method 0x485cc955.
//
// Solidity: function initialize(address vault_, address strategy_) returns()
func (_SuperVaultEscrow *SuperVaultEscrowTransactor) Initialize(opts *bind.TransactOpts, vault_ common.Address, strategy_ common.Address) (*types.Transaction, error) {
	return _SuperVaultEscrow.contract.Transact(opts, "initialize", vault_, strategy_)
}

// Initialize is a paid mutator transaction binding the contract method 0x485cc955.
//
// Solidity: function initialize(address vault_, address strategy_) returns()
func (_SuperVaultEscrow *SuperVaultEscrowSession) Initialize(vault_ common.Address, strategy_ common.Address) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.Initialize(&_SuperVaultEscrow.TransactOpts, vault_, strategy_)
}

// Initialize is a paid mutator transaction binding the contract method 0x485cc955.
//
// Solidity: function initialize(address vault_, address strategy_) returns()
func (_SuperVaultEscrow *SuperVaultEscrowTransactorSession) Initialize(vault_ common.Address, strategy_ common.Address) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.Initialize(&_SuperVaultEscrow.TransactOpts, vault_, strategy_)
}

// ReturnShares is a paid mutator transaction binding the contract method 0x8b198025.
//
// Solidity: function returnShares(address to, uint256 amount) returns()
func (_SuperVaultEscrow *SuperVaultEscrowTransactor) ReturnShares(opts *bind.TransactOpts, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultEscrow.contract.Transact(opts, "returnShares", to, amount)
}

// ReturnShares is a paid mutator transaction binding the contract method 0x8b198025.
//
// Solidity: function returnShares(address to, uint256 amount) returns()
func (_SuperVaultEscrow *SuperVaultEscrowSession) ReturnShares(to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.ReturnShares(&_SuperVaultEscrow.TransactOpts, to, amount)
}

// ReturnShares is a paid mutator transaction binding the contract method 0x8b198025.
//
// Solidity: function returnShares(address to, uint256 amount) returns()
func (_SuperVaultEscrow *SuperVaultEscrowTransactorSession) ReturnShares(to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultEscrow.Contract.ReturnShares(&_SuperVaultEscrow.TransactOpts, to, amount)
}
