// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperLedger

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

// SuperLedgerMetaData contains all meta data concerning the SuperLedger contract.
var SuperLedgerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"ledgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"allowedExecutors_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"allowedExecutors\",\"inputs\":[{\"name\":\"executor\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isAllowed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"calculateCostBasisView\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSource\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"costBasis\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"shares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"previewFees\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountAssets\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"feeAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superLedgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractSuperLedgerConfiguration\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"updateAccounting\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSource\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"isInflow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"amountSharesOrAssets\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"feeAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"usersAccumulatorCostBasis\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSource\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"costBasis\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"usersAccumulatorShares\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSource\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"shares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"AccountingInflow\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"yieldSource\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"pps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AccountingOutflow\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"yieldSource\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"feeAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UsedSharesCapped\",\"inputs\":[{\"name\":\"originalVal\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"cappedVal\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"FEE_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE_PERCENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_LEDGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PRICE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ID_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_LENGTH\",\"inputs\":[]}]",
}

// SuperLedgerABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperLedgerMetaData.ABI instead.
var SuperLedgerABI = SuperLedgerMetaData.ABI

// SuperLedger is an auto generated Go binding around an Ethereum contract.
type SuperLedger struct {
	SuperLedgerCaller     // Read-only binding to the contract
	SuperLedgerTransactor // Write-only binding to the contract
	SuperLedgerFilterer   // Log filterer for contract events
}

// SuperLedgerCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperLedgerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperLedgerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperLedgerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperLedgerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperLedgerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperLedgerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperLedgerSession struct {
	Contract     *SuperLedger      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperLedgerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperLedgerCallerSession struct {
	Contract *SuperLedgerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// SuperLedgerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperLedgerTransactorSession struct {
	Contract     *SuperLedgerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// SuperLedgerRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperLedgerRaw struct {
	Contract *SuperLedger // Generic contract binding to access the raw methods on
}

// SuperLedgerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperLedgerCallerRaw struct {
	Contract *SuperLedgerCaller // Generic read-only contract binding to access the raw methods on
}

// SuperLedgerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperLedgerTransactorRaw struct {
	Contract *SuperLedgerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperLedger creates a new instance of SuperLedger, bound to a specific deployed contract.
func NewSuperLedger(address common.Address, backend bind.ContractBackend) (*SuperLedger, error) {
	contract, err := bindSuperLedger(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperLedger{SuperLedgerCaller: SuperLedgerCaller{contract: contract}, SuperLedgerTransactor: SuperLedgerTransactor{contract: contract}, SuperLedgerFilterer: SuperLedgerFilterer{contract: contract}}, nil
}

// NewSuperLedgerCaller creates a new read-only instance of SuperLedger, bound to a specific deployed contract.
func NewSuperLedgerCaller(address common.Address, caller bind.ContractCaller) (*SuperLedgerCaller, error) {
	contract, err := bindSuperLedger(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerCaller{contract: contract}, nil
}

// NewSuperLedgerTransactor creates a new write-only instance of SuperLedger, bound to a specific deployed contract.
func NewSuperLedgerTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperLedgerTransactor, error) {
	contract, err := bindSuperLedger(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerTransactor{contract: contract}, nil
}

// NewSuperLedgerFilterer creates a new log filterer instance of SuperLedger, bound to a specific deployed contract.
func NewSuperLedgerFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperLedgerFilterer, error) {
	contract, err := bindSuperLedger(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerFilterer{contract: contract}, nil
}

// bindSuperLedger binds a generic wrapper to an already deployed contract.
func bindSuperLedger(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperLedgerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperLedger *SuperLedgerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperLedger.Contract.SuperLedgerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperLedger *SuperLedgerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperLedger.Contract.SuperLedgerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperLedger *SuperLedgerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperLedger.Contract.SuperLedgerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperLedger *SuperLedgerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperLedger.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperLedger *SuperLedgerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperLedger.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperLedger *SuperLedgerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperLedger.Contract.contract.Transact(opts, method, params...)
}

// AllowedExecutors is a free data retrieval call binding the contract method 0x37cb6736.
//
// Solidity: function allowedExecutors(address executor) view returns(bool isAllowed)
func (_SuperLedger *SuperLedgerCaller) AllowedExecutors(opts *bind.CallOpts, executor common.Address) (bool, error) {
	var out []interface{}
	err := _SuperLedger.contract.Call(opts, &out, "allowedExecutors", executor)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// AllowedExecutors is a free data retrieval call binding the contract method 0x37cb6736.
//
// Solidity: function allowedExecutors(address executor) view returns(bool isAllowed)
func (_SuperLedger *SuperLedgerSession) AllowedExecutors(executor common.Address) (bool, error) {
	return _SuperLedger.Contract.AllowedExecutors(&_SuperLedger.CallOpts, executor)
}

// AllowedExecutors is a free data retrieval call binding the contract method 0x37cb6736.
//
// Solidity: function allowedExecutors(address executor) view returns(bool isAllowed)
func (_SuperLedger *SuperLedgerCallerSession) AllowedExecutors(executor common.Address) (bool, error) {
	return _SuperLedger.Contract.AllowedExecutors(&_SuperLedger.CallOpts, executor)
}

// CalculateCostBasisView is a free data retrieval call binding the contract method 0xe4367cd3.
//
// Solidity: function calculateCostBasisView(address user, address yieldSource, uint256 usedShares) view returns(uint256 costBasis, uint256 shares)
func (_SuperLedger *SuperLedgerCaller) CalculateCostBasisView(opts *bind.CallOpts, user common.Address, yieldSource common.Address, usedShares *big.Int) (struct {
	CostBasis *big.Int
	Shares    *big.Int
}, error) {
	var out []interface{}
	err := _SuperLedger.contract.Call(opts, &out, "calculateCostBasisView", user, yieldSource, usedShares)

	outstruct := new(struct {
		CostBasis *big.Int
		Shares    *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.CostBasis = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.Shares = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// CalculateCostBasisView is a free data retrieval call binding the contract method 0xe4367cd3.
//
// Solidity: function calculateCostBasisView(address user, address yieldSource, uint256 usedShares) view returns(uint256 costBasis, uint256 shares)
func (_SuperLedger *SuperLedgerSession) CalculateCostBasisView(user common.Address, yieldSource common.Address, usedShares *big.Int) (struct {
	CostBasis *big.Int
	Shares    *big.Int
}, error) {
	return _SuperLedger.Contract.CalculateCostBasisView(&_SuperLedger.CallOpts, user, yieldSource, usedShares)
}

// CalculateCostBasisView is a free data retrieval call binding the contract method 0xe4367cd3.
//
// Solidity: function calculateCostBasisView(address user, address yieldSource, uint256 usedShares) view returns(uint256 costBasis, uint256 shares)
func (_SuperLedger *SuperLedgerCallerSession) CalculateCostBasisView(user common.Address, yieldSource common.Address, usedShares *big.Int) (struct {
	CostBasis *big.Int
	Shares    *big.Int
}, error) {
	return _SuperLedger.Contract.CalculateCostBasisView(&_SuperLedger.CallOpts, user, yieldSource, usedShares)
}

// PreviewFees is a free data retrieval call binding the contract method 0x49b1df7b.
//
// Solidity: function previewFees(address user, address yieldSourceAddress, uint256 amountAssets, uint256 usedShares, uint256 feePercent) view returns(uint256 feeAmount)
func (_SuperLedger *SuperLedgerCaller) PreviewFees(opts *bind.CallOpts, user common.Address, yieldSourceAddress common.Address, amountAssets *big.Int, usedShares *big.Int, feePercent *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SuperLedger.contract.Call(opts, &out, "previewFees", user, yieldSourceAddress, amountAssets, usedShares, feePercent)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PreviewFees is a free data retrieval call binding the contract method 0x49b1df7b.
//
// Solidity: function previewFees(address user, address yieldSourceAddress, uint256 amountAssets, uint256 usedShares, uint256 feePercent) view returns(uint256 feeAmount)
func (_SuperLedger *SuperLedgerSession) PreviewFees(user common.Address, yieldSourceAddress common.Address, amountAssets *big.Int, usedShares *big.Int, feePercent *big.Int) (*big.Int, error) {
	return _SuperLedger.Contract.PreviewFees(&_SuperLedger.CallOpts, user, yieldSourceAddress, amountAssets, usedShares, feePercent)
}

// PreviewFees is a free data retrieval call binding the contract method 0x49b1df7b.
//
// Solidity: function previewFees(address user, address yieldSourceAddress, uint256 amountAssets, uint256 usedShares, uint256 feePercent) view returns(uint256 feeAmount)
func (_SuperLedger *SuperLedgerCallerSession) PreviewFees(user common.Address, yieldSourceAddress common.Address, amountAssets *big.Int, usedShares *big.Int, feePercent *big.Int) (*big.Int, error) {
	return _SuperLedger.Contract.PreviewFees(&_SuperLedger.CallOpts, user, yieldSourceAddress, amountAssets, usedShares, feePercent)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_SuperLedger *SuperLedgerCaller) SuperLedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperLedger.contract.Call(opts, &out, "superLedgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_SuperLedger *SuperLedgerSession) SuperLedgerConfiguration() (common.Address, error) {
	return _SuperLedger.Contract.SuperLedgerConfiguration(&_SuperLedger.CallOpts)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_SuperLedger *SuperLedgerCallerSession) SuperLedgerConfiguration() (common.Address, error) {
	return _SuperLedger.Contract.SuperLedgerConfiguration(&_SuperLedger.CallOpts)
}

// UsersAccumulatorCostBasis is a free data retrieval call binding the contract method 0xe70833d3.
//
// Solidity: function usersAccumulatorCostBasis(address user, address yieldSource) view returns(uint256 costBasis)
func (_SuperLedger *SuperLedgerCaller) UsersAccumulatorCostBasis(opts *bind.CallOpts, user common.Address, yieldSource common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperLedger.contract.Call(opts, &out, "usersAccumulatorCostBasis", user, yieldSource)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// UsersAccumulatorCostBasis is a free data retrieval call binding the contract method 0xe70833d3.
//
// Solidity: function usersAccumulatorCostBasis(address user, address yieldSource) view returns(uint256 costBasis)
func (_SuperLedger *SuperLedgerSession) UsersAccumulatorCostBasis(user common.Address, yieldSource common.Address) (*big.Int, error) {
	return _SuperLedger.Contract.UsersAccumulatorCostBasis(&_SuperLedger.CallOpts, user, yieldSource)
}

// UsersAccumulatorCostBasis is a free data retrieval call binding the contract method 0xe70833d3.
//
// Solidity: function usersAccumulatorCostBasis(address user, address yieldSource) view returns(uint256 costBasis)
func (_SuperLedger *SuperLedgerCallerSession) UsersAccumulatorCostBasis(user common.Address, yieldSource common.Address) (*big.Int, error) {
	return _SuperLedger.Contract.UsersAccumulatorCostBasis(&_SuperLedger.CallOpts, user, yieldSource)
}

// UsersAccumulatorShares is a free data retrieval call binding the contract method 0x2c119fca.
//
// Solidity: function usersAccumulatorShares(address user, address yieldSource) view returns(uint256 shares)
func (_SuperLedger *SuperLedgerCaller) UsersAccumulatorShares(opts *bind.CallOpts, user common.Address, yieldSource common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperLedger.contract.Call(opts, &out, "usersAccumulatorShares", user, yieldSource)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// UsersAccumulatorShares is a free data retrieval call binding the contract method 0x2c119fca.
//
// Solidity: function usersAccumulatorShares(address user, address yieldSource) view returns(uint256 shares)
func (_SuperLedger *SuperLedgerSession) UsersAccumulatorShares(user common.Address, yieldSource common.Address) (*big.Int, error) {
	return _SuperLedger.Contract.UsersAccumulatorShares(&_SuperLedger.CallOpts, user, yieldSource)
}

// UsersAccumulatorShares is a free data retrieval call binding the contract method 0x2c119fca.
//
// Solidity: function usersAccumulatorShares(address user, address yieldSource) view returns(uint256 shares)
func (_SuperLedger *SuperLedgerCallerSession) UsersAccumulatorShares(user common.Address, yieldSource common.Address) (*big.Int, error) {
	return _SuperLedger.Contract.UsersAccumulatorShares(&_SuperLedger.CallOpts, user, yieldSource)
}

// UpdateAccounting is a paid mutator transaction binding the contract method 0x603feb71.
//
// Solidity: function updateAccounting(address user, address yieldSource, bytes4 yieldSourceOracleId, bool isInflow, uint256 amountSharesOrAssets, uint256 usedShares) returns(uint256 feeAmount)
func (_SuperLedger *SuperLedgerTransactor) UpdateAccounting(opts *bind.TransactOpts, user common.Address, yieldSource common.Address, yieldSourceOracleId [4]byte, isInflow bool, amountSharesOrAssets *big.Int, usedShares *big.Int) (*types.Transaction, error) {
	return _SuperLedger.contract.Transact(opts, "updateAccounting", user, yieldSource, yieldSourceOracleId, isInflow, amountSharesOrAssets, usedShares)
}

// UpdateAccounting is a paid mutator transaction binding the contract method 0x603feb71.
//
// Solidity: function updateAccounting(address user, address yieldSource, bytes4 yieldSourceOracleId, bool isInflow, uint256 amountSharesOrAssets, uint256 usedShares) returns(uint256 feeAmount)
func (_SuperLedger *SuperLedgerSession) UpdateAccounting(user common.Address, yieldSource common.Address, yieldSourceOracleId [4]byte, isInflow bool, amountSharesOrAssets *big.Int, usedShares *big.Int) (*types.Transaction, error) {
	return _SuperLedger.Contract.UpdateAccounting(&_SuperLedger.TransactOpts, user, yieldSource, yieldSourceOracleId, isInflow, amountSharesOrAssets, usedShares)
}

// UpdateAccounting is a paid mutator transaction binding the contract method 0x603feb71.
//
// Solidity: function updateAccounting(address user, address yieldSource, bytes4 yieldSourceOracleId, bool isInflow, uint256 amountSharesOrAssets, uint256 usedShares) returns(uint256 feeAmount)
func (_SuperLedger *SuperLedgerTransactorSession) UpdateAccounting(user common.Address, yieldSource common.Address, yieldSourceOracleId [4]byte, isInflow bool, amountSharesOrAssets *big.Int, usedShares *big.Int) (*types.Transaction, error) {
	return _SuperLedger.Contract.UpdateAccounting(&_SuperLedger.TransactOpts, user, yieldSource, yieldSourceOracleId, isInflow, amountSharesOrAssets, usedShares)
}

// SuperLedgerAccountingInflowIterator is returned from FilterAccountingInflow and is used to iterate over the raw logs and unpacked data for AccountingInflow events raised by the SuperLedger contract.
type SuperLedgerAccountingInflowIterator struct {
	Event *SuperLedgerAccountingInflow // Event containing the contract specifics and raw log

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
func (it *SuperLedgerAccountingInflowIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerAccountingInflow)
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
		it.Event = new(SuperLedgerAccountingInflow)
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
func (it *SuperLedgerAccountingInflowIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerAccountingInflowIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerAccountingInflow represents a AccountingInflow event raised by the SuperLedger contract.
type SuperLedgerAccountingInflow struct {
	User              common.Address
	YieldSourceOracle common.Address
	YieldSource       common.Address
	Amount            *big.Int
	Pps               *big.Int
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterAccountingInflow is a free log retrieval operation binding the contract event 0x0739bc8e7ea8aa32e4aed717e94d5448d6c652c3d2c346961880a6878b9a2247.
//
// Solidity: event AccountingInflow(address indexed user, address indexed yieldSourceOracle, address indexed yieldSource, uint256 amount, uint256 pps)
func (_SuperLedger *SuperLedgerFilterer) FilterAccountingInflow(opts *bind.FilterOpts, user []common.Address, yieldSourceOracle []common.Address, yieldSource []common.Address) (*SuperLedgerAccountingInflowIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}
	var yieldSourceRule []interface{}
	for _, yieldSourceItem := range yieldSource {
		yieldSourceRule = append(yieldSourceRule, yieldSourceItem)
	}

	logs, sub, err := _SuperLedger.contract.FilterLogs(opts, "AccountingInflow", userRule, yieldSourceOracleRule, yieldSourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerAccountingInflowIterator{contract: _SuperLedger.contract, event: "AccountingInflow", logs: logs, sub: sub}, nil
}

// WatchAccountingInflow is a free log subscription operation binding the contract event 0x0739bc8e7ea8aa32e4aed717e94d5448d6c652c3d2c346961880a6878b9a2247.
//
// Solidity: event AccountingInflow(address indexed user, address indexed yieldSourceOracle, address indexed yieldSource, uint256 amount, uint256 pps)
func (_SuperLedger *SuperLedgerFilterer) WatchAccountingInflow(opts *bind.WatchOpts, sink chan<- *SuperLedgerAccountingInflow, user []common.Address, yieldSourceOracle []common.Address, yieldSource []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}
	var yieldSourceRule []interface{}
	for _, yieldSourceItem := range yieldSource {
		yieldSourceRule = append(yieldSourceRule, yieldSourceItem)
	}

	logs, sub, err := _SuperLedger.contract.WatchLogs(opts, "AccountingInflow", userRule, yieldSourceOracleRule, yieldSourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerAccountingInflow)
				if err := _SuperLedger.contract.UnpackLog(event, "AccountingInflow", log); err != nil {
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

// ParseAccountingInflow is a log parse operation binding the contract event 0x0739bc8e7ea8aa32e4aed717e94d5448d6c652c3d2c346961880a6878b9a2247.
//
// Solidity: event AccountingInflow(address indexed user, address indexed yieldSourceOracle, address indexed yieldSource, uint256 amount, uint256 pps)
func (_SuperLedger *SuperLedgerFilterer) ParseAccountingInflow(log types.Log) (*SuperLedgerAccountingInflow, error) {
	event := new(SuperLedgerAccountingInflow)
	if err := _SuperLedger.contract.UnpackLog(event, "AccountingInflow", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperLedgerAccountingOutflowIterator is returned from FilterAccountingOutflow and is used to iterate over the raw logs and unpacked data for AccountingOutflow events raised by the SuperLedger contract.
type SuperLedgerAccountingOutflowIterator struct {
	Event *SuperLedgerAccountingOutflow // Event containing the contract specifics and raw log

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
func (it *SuperLedgerAccountingOutflowIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerAccountingOutflow)
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
		it.Event = new(SuperLedgerAccountingOutflow)
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
func (it *SuperLedgerAccountingOutflowIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerAccountingOutflowIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerAccountingOutflow represents a AccountingOutflow event raised by the SuperLedger contract.
type SuperLedgerAccountingOutflow struct {
	User              common.Address
	YieldSourceOracle common.Address
	YieldSource       common.Address
	Amount            *big.Int
	FeeAmount         *big.Int
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterAccountingOutflow is a free log retrieval operation binding the contract event 0xc1eb34142f486694077c8fe62a1e5ea0af28fa50ecb14190c84a7f60ffbb05fd.
//
// Solidity: event AccountingOutflow(address indexed user, address indexed yieldSourceOracle, address indexed yieldSource, uint256 amount, uint256 feeAmount)
func (_SuperLedger *SuperLedgerFilterer) FilterAccountingOutflow(opts *bind.FilterOpts, user []common.Address, yieldSourceOracle []common.Address, yieldSource []common.Address) (*SuperLedgerAccountingOutflowIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}
	var yieldSourceRule []interface{}
	for _, yieldSourceItem := range yieldSource {
		yieldSourceRule = append(yieldSourceRule, yieldSourceItem)
	}

	logs, sub, err := _SuperLedger.contract.FilterLogs(opts, "AccountingOutflow", userRule, yieldSourceOracleRule, yieldSourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerAccountingOutflowIterator{contract: _SuperLedger.contract, event: "AccountingOutflow", logs: logs, sub: sub}, nil
}

// WatchAccountingOutflow is a free log subscription operation binding the contract event 0xc1eb34142f486694077c8fe62a1e5ea0af28fa50ecb14190c84a7f60ffbb05fd.
//
// Solidity: event AccountingOutflow(address indexed user, address indexed yieldSourceOracle, address indexed yieldSource, uint256 amount, uint256 feeAmount)
func (_SuperLedger *SuperLedgerFilterer) WatchAccountingOutflow(opts *bind.WatchOpts, sink chan<- *SuperLedgerAccountingOutflow, user []common.Address, yieldSourceOracle []common.Address, yieldSource []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}
	var yieldSourceRule []interface{}
	for _, yieldSourceItem := range yieldSource {
		yieldSourceRule = append(yieldSourceRule, yieldSourceItem)
	}

	logs, sub, err := _SuperLedger.contract.WatchLogs(opts, "AccountingOutflow", userRule, yieldSourceOracleRule, yieldSourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerAccountingOutflow)
				if err := _SuperLedger.contract.UnpackLog(event, "AccountingOutflow", log); err != nil {
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

// ParseAccountingOutflow is a log parse operation binding the contract event 0xc1eb34142f486694077c8fe62a1e5ea0af28fa50ecb14190c84a7f60ffbb05fd.
//
// Solidity: event AccountingOutflow(address indexed user, address indexed yieldSourceOracle, address indexed yieldSource, uint256 amount, uint256 feeAmount)
func (_SuperLedger *SuperLedgerFilterer) ParseAccountingOutflow(log types.Log) (*SuperLedgerAccountingOutflow, error) {
	event := new(SuperLedgerAccountingOutflow)
	if err := _SuperLedger.contract.UnpackLog(event, "AccountingOutflow", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperLedgerUsedSharesCappedIterator is returned from FilterUsedSharesCapped and is used to iterate over the raw logs and unpacked data for UsedSharesCapped events raised by the SuperLedger contract.
type SuperLedgerUsedSharesCappedIterator struct {
	Event *SuperLedgerUsedSharesCapped // Event containing the contract specifics and raw log

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
func (it *SuperLedgerUsedSharesCappedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerUsedSharesCapped)
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
		it.Event = new(SuperLedgerUsedSharesCapped)
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
func (it *SuperLedgerUsedSharesCappedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerUsedSharesCappedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerUsedSharesCapped represents a UsedSharesCapped event raised by the SuperLedger contract.
type SuperLedgerUsedSharesCapped struct {
	OriginalVal *big.Int
	CappedVal   *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterUsedSharesCapped is a free log retrieval operation binding the contract event 0xcbf6e1ecca8662a52fbda88e401671949eb8ef33066b8afbc19ecca7f127b22d.
//
// Solidity: event UsedSharesCapped(uint256 originalVal, uint256 cappedVal)
func (_SuperLedger *SuperLedgerFilterer) FilterUsedSharesCapped(opts *bind.FilterOpts) (*SuperLedgerUsedSharesCappedIterator, error) {

	logs, sub, err := _SuperLedger.contract.FilterLogs(opts, "UsedSharesCapped")
	if err != nil {
		return nil, err
	}
	return &SuperLedgerUsedSharesCappedIterator{contract: _SuperLedger.contract, event: "UsedSharesCapped", logs: logs, sub: sub}, nil
}

// WatchUsedSharesCapped is a free log subscription operation binding the contract event 0xcbf6e1ecca8662a52fbda88e401671949eb8ef33066b8afbc19ecca7f127b22d.
//
// Solidity: event UsedSharesCapped(uint256 originalVal, uint256 cappedVal)
func (_SuperLedger *SuperLedgerFilterer) WatchUsedSharesCapped(opts *bind.WatchOpts, sink chan<- *SuperLedgerUsedSharesCapped) (event.Subscription, error) {

	logs, sub, err := _SuperLedger.contract.WatchLogs(opts, "UsedSharesCapped")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerUsedSharesCapped)
				if err := _SuperLedger.contract.UnpackLog(event, "UsedSharesCapped", log); err != nil {
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

// ParseUsedSharesCapped is a log parse operation binding the contract event 0xcbf6e1ecca8662a52fbda88e401671949eb8ef33066b8afbc19ecca7f127b22d.
//
// Solidity: event UsedSharesCapped(uint256 originalVal, uint256 cappedVal)
func (_SuperLedger *SuperLedgerFilterer) ParseUsedSharesCapped(log types.Log) (*SuperLedgerUsedSharesCapped, error) {
	event := new(SuperLedgerUsedSharesCapped)
	if err := _SuperLedger.contract.UnpackLog(event, "UsedSharesCapped", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
