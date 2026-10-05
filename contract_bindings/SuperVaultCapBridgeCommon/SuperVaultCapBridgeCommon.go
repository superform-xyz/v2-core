// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperVaultCapBridgeCommon

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

// SuperVaultCapBridgeCommonMetaData contains all meta data concerning the SuperVaultCapBridgeCommon contract.
var SuperVaultCapBridgeCommonMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"ACTION_IDLE_HOLD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACTION_VAULT_DEPOSIT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MIN_SOURCE_DELIVERY_BPS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_GOVERNOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperGovernorAddressBook\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"DELIVERY_BELOW_RESERVATION_FLOOR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_ACCOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_ACTION_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_AMOUNT_NOT_BOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_ASSET_NOT_PINNED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_TOKEN_NOT_BOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_VAULT_ASSET_NOT_BOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INPUT_TOKEN_NOT_HUB_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TRANSPORT_ADAPTER_NOT_APPROVED\",\"inputs\":[]}]",
}

// SuperVaultCapBridgeCommonABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperVaultCapBridgeCommonMetaData.ABI instead.
var SuperVaultCapBridgeCommonABI = SuperVaultCapBridgeCommonMetaData.ABI

// SuperVaultCapBridgeCommon is an auto generated Go binding around an Ethereum contract.
type SuperVaultCapBridgeCommon struct {
	SuperVaultCapBridgeCommonCaller     // Read-only binding to the contract
	SuperVaultCapBridgeCommonTransactor // Write-only binding to the contract
	SuperVaultCapBridgeCommonFilterer   // Log filterer for contract events
}

// SuperVaultCapBridgeCommonCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperVaultCapBridgeCommonCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultCapBridgeCommonTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperVaultCapBridgeCommonTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultCapBridgeCommonFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperVaultCapBridgeCommonFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultCapBridgeCommonSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperVaultCapBridgeCommonSession struct {
	Contract     *SuperVaultCapBridgeCommon // Generic contract binding to set the session for
	CallOpts     bind.CallOpts              // Call options to use throughout this session
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// SuperVaultCapBridgeCommonCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperVaultCapBridgeCommonCallerSession struct {
	Contract *SuperVaultCapBridgeCommonCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                    // Call options to use throughout this session
}

// SuperVaultCapBridgeCommonTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperVaultCapBridgeCommonTransactorSession struct {
	Contract     *SuperVaultCapBridgeCommonTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// SuperVaultCapBridgeCommonRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperVaultCapBridgeCommonRaw struct {
	Contract *SuperVaultCapBridgeCommon // Generic contract binding to access the raw methods on
}

// SuperVaultCapBridgeCommonCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperVaultCapBridgeCommonCallerRaw struct {
	Contract *SuperVaultCapBridgeCommonCaller // Generic read-only contract binding to access the raw methods on
}

// SuperVaultCapBridgeCommonTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperVaultCapBridgeCommonTransactorRaw struct {
	Contract *SuperVaultCapBridgeCommonTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperVaultCapBridgeCommon creates a new instance of SuperVaultCapBridgeCommon, bound to a specific deployed contract.
func NewSuperVaultCapBridgeCommon(address common.Address, backend bind.ContractBackend) (*SuperVaultCapBridgeCommon, error) {
	contract, err := bindSuperVaultCapBridgeCommon(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperVaultCapBridgeCommon{SuperVaultCapBridgeCommonCaller: SuperVaultCapBridgeCommonCaller{contract: contract}, SuperVaultCapBridgeCommonTransactor: SuperVaultCapBridgeCommonTransactor{contract: contract}, SuperVaultCapBridgeCommonFilterer: SuperVaultCapBridgeCommonFilterer{contract: contract}}, nil
}

// NewSuperVaultCapBridgeCommonCaller creates a new read-only instance of SuperVaultCapBridgeCommon, bound to a specific deployed contract.
func NewSuperVaultCapBridgeCommonCaller(address common.Address, caller bind.ContractCaller) (*SuperVaultCapBridgeCommonCaller, error) {
	contract, err := bindSuperVaultCapBridgeCommon(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultCapBridgeCommonCaller{contract: contract}, nil
}

// NewSuperVaultCapBridgeCommonTransactor creates a new write-only instance of SuperVaultCapBridgeCommon, bound to a specific deployed contract.
func NewSuperVaultCapBridgeCommonTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperVaultCapBridgeCommonTransactor, error) {
	contract, err := bindSuperVaultCapBridgeCommon(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultCapBridgeCommonTransactor{contract: contract}, nil
}

// NewSuperVaultCapBridgeCommonFilterer creates a new log filterer instance of SuperVaultCapBridgeCommon, bound to a specific deployed contract.
func NewSuperVaultCapBridgeCommonFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperVaultCapBridgeCommonFilterer, error) {
	contract, err := bindSuperVaultCapBridgeCommon(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperVaultCapBridgeCommonFilterer{contract: contract}, nil
}

// bindSuperVaultCapBridgeCommon binds a generic wrapper to an already deployed contract.
func bindSuperVaultCapBridgeCommon(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperVaultCapBridgeCommonMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultCapBridgeCommon.Contract.SuperVaultCapBridgeCommonCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultCapBridgeCommon.Contract.SuperVaultCapBridgeCommonTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultCapBridgeCommon.Contract.SuperVaultCapBridgeCommonTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultCapBridgeCommon.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultCapBridgeCommon.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultCapBridgeCommon.Contract.contract.Transact(opts, method, params...)
}

// ACTIONIDLEHOLD is a free data retrieval call binding the contract method 0xd3267c16.
//
// Solidity: function ACTION_IDLE_HOLD() view returns(uint8)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCaller) ACTIONIDLEHOLD(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _SuperVaultCapBridgeCommon.contract.Call(opts, &out, "ACTION_IDLE_HOLD")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// ACTIONIDLEHOLD is a free data retrieval call binding the contract method 0xd3267c16.
//
// Solidity: function ACTION_IDLE_HOLD() view returns(uint8)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonSession) ACTIONIDLEHOLD() (uint8, error) {
	return _SuperVaultCapBridgeCommon.Contract.ACTIONIDLEHOLD(&_SuperVaultCapBridgeCommon.CallOpts)
}

// ACTIONIDLEHOLD is a free data retrieval call binding the contract method 0xd3267c16.
//
// Solidity: function ACTION_IDLE_HOLD() view returns(uint8)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCallerSession) ACTIONIDLEHOLD() (uint8, error) {
	return _SuperVaultCapBridgeCommon.Contract.ACTIONIDLEHOLD(&_SuperVaultCapBridgeCommon.CallOpts)
}

// ACTIONVAULTDEPOSIT is a free data retrieval call binding the contract method 0x3c9cd4e4.
//
// Solidity: function ACTION_VAULT_DEPOSIT() view returns(uint8)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCaller) ACTIONVAULTDEPOSIT(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _SuperVaultCapBridgeCommon.contract.Call(opts, &out, "ACTION_VAULT_DEPOSIT")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// ACTIONVAULTDEPOSIT is a free data retrieval call binding the contract method 0x3c9cd4e4.
//
// Solidity: function ACTION_VAULT_DEPOSIT() view returns(uint8)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonSession) ACTIONVAULTDEPOSIT() (uint8, error) {
	return _SuperVaultCapBridgeCommon.Contract.ACTIONVAULTDEPOSIT(&_SuperVaultCapBridgeCommon.CallOpts)
}

// ACTIONVAULTDEPOSIT is a free data retrieval call binding the contract method 0x3c9cd4e4.
//
// Solidity: function ACTION_VAULT_DEPOSIT() view returns(uint8)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCallerSession) ACTIONVAULTDEPOSIT() (uint8, error) {
	return _SuperVaultCapBridgeCommon.Contract.ACTIONVAULTDEPOSIT(&_SuperVaultCapBridgeCommon.CallOpts)
}

// MINSOURCEDELIVERYBPS is a free data retrieval call binding the contract method 0xaa260338.
//
// Solidity: function MIN_SOURCE_DELIVERY_BPS() view returns(uint256)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCaller) MINSOURCEDELIVERYBPS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultCapBridgeCommon.contract.Call(opts, &out, "MIN_SOURCE_DELIVERY_BPS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MINSOURCEDELIVERYBPS is a free data retrieval call binding the contract method 0xaa260338.
//
// Solidity: function MIN_SOURCE_DELIVERY_BPS() view returns(uint256)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonSession) MINSOURCEDELIVERYBPS() (*big.Int, error) {
	return _SuperVaultCapBridgeCommon.Contract.MINSOURCEDELIVERYBPS(&_SuperVaultCapBridgeCommon.CallOpts)
}

// MINSOURCEDELIVERYBPS is a free data retrieval call binding the contract method 0xaa260338.
//
// Solidity: function MIN_SOURCE_DELIVERY_BPS() view returns(uint256)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCallerSession) MINSOURCEDELIVERYBPS() (*big.Int, error) {
	return _SuperVaultCapBridgeCommon.Contract.MINSOURCEDELIVERYBPS(&_SuperVaultCapBridgeCommon.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCaller) SUPERGOVERNOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultCapBridgeCommon.contract.Call(opts, &out, "SUPER_GOVERNOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperVaultCapBridgeCommon.Contract.SUPERGOVERNOR(&_SuperVaultCapBridgeCommon.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperVaultCapBridgeCommon *SuperVaultCapBridgeCommonCallerSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperVaultCapBridgeCommon.Contract.SUPERGOVERNOR(&_SuperVaultCapBridgeCommon.CallOpts)
}
