// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperLedgerConfiguration

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

// ISuperLedgerConfigurationYieldSourceOracleConfig is an auto generated low-level Go binding around an user-defined struct.
type ISuperLedgerConfigurationYieldSourceOracleConfig struct {
	YieldSourceOracle common.Address
	FeePercent        *big.Int
	FeeRecipient      common.Address
	Manager           common.Address
	Ledger            common.Address
}

// ISuperLedgerConfigurationYieldSourceOracleConfigArgs is an auto generated low-level Go binding around an user-defined struct.
type ISuperLedgerConfigurationYieldSourceOracleConfigArgs struct {
	YieldSourceOracleId [4]byte
	YieldSourceOracle   common.Address
	FeePercent          *big.Int
	FeeRecipient        common.Address
	Ledger              common.Address
}

// SuperLedgerConfigurationMetaData contains all meta data concerning the SuperLedgerConfiguration contract.
var SuperLedgerConfigurationMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_deployer\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptManagerRole\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptYieldSourceOracleConfigProposal\",\"inputs\":[{\"name\":\"yieldSourceOracleIds\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"cancelYieldSourceOracleConfigProposal\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getYieldSourceOracleConfig\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structISuperLedgerConfiguration.YieldSourceOracleConfig\",\"components\":[{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"manager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYieldSourceOracleConfigs\",\"inputs\":[{\"name\":\"yieldSourceOracleIds\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}],\"outputs\":[{\"name\":\"configs\",\"type\":\"tuple[]\",\"internalType\":\"structISuperLedgerConfiguration.YieldSourceOracleConfig[]\",\"components\":[{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"manager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeYieldSourceOracleConfig\",\"inputs\":[{\"name\":\"configs\",\"type\":\"tuple[]\",\"internalType\":\"structISuperLedgerConfiguration.YieldSourceOracleConfigArgs[]\",\"components\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setYieldSourceOracles\",\"inputs\":[{\"name\":\"configs\",\"type\":\"tuple[]\",\"internalType\":\"structISuperLedgerConfiguration.YieldSourceOracleConfigArgs[]\",\"components\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferManagerRole\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"newManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"ManagerRoleTransferAccepted\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"indexed\":true,\"internalType\":\"bytes4\"},{\"name\":\"newManager\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ManagerRoleTransferStarted\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"indexed\":true,\"internalType\":\"bytes4\"},{\"name\":\"currentManager\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newManager\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceOracleConfigAccepted\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"indexed\":true,\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"manager\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceOracleConfigProposalCancelled\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"indexed\":true,\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"manager\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceOracleConfigProposalSet\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"indexed\":true,\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"manager\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceOracleConfigSet\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"indexed\":true,\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"feePercent\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"feeRecipient\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"manager\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"ledger\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CANNOT_ACCEPT_YET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CHANGE_ALREADY_PROPOSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CONFIG_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CONFIG_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE_PERCENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_MATCHED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_DEPLOYER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_PENDING_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_PROPOSAL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ID_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_LENGTH\",\"inputs\":[]}]",
}

// SuperLedgerConfigurationABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperLedgerConfigurationMetaData.ABI instead.
var SuperLedgerConfigurationABI = SuperLedgerConfigurationMetaData.ABI

// SuperLedgerConfiguration is an auto generated Go binding around an Ethereum contract.
type SuperLedgerConfiguration struct {
	SuperLedgerConfigurationCaller     // Read-only binding to the contract
	SuperLedgerConfigurationTransactor // Write-only binding to the contract
	SuperLedgerConfigurationFilterer   // Log filterer for contract events
}

// SuperLedgerConfigurationCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperLedgerConfigurationCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperLedgerConfigurationTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperLedgerConfigurationTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperLedgerConfigurationFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperLedgerConfigurationFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperLedgerConfigurationSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperLedgerConfigurationSession struct {
	Contract     *SuperLedgerConfiguration // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// SuperLedgerConfigurationCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperLedgerConfigurationCallerSession struct {
	Contract *SuperLedgerConfigurationCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// SuperLedgerConfigurationTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperLedgerConfigurationTransactorSession struct {
	Contract     *SuperLedgerConfigurationTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// SuperLedgerConfigurationRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperLedgerConfigurationRaw struct {
	Contract *SuperLedgerConfiguration // Generic contract binding to access the raw methods on
}

// SuperLedgerConfigurationCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperLedgerConfigurationCallerRaw struct {
	Contract *SuperLedgerConfigurationCaller // Generic read-only contract binding to access the raw methods on
}

// SuperLedgerConfigurationTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperLedgerConfigurationTransactorRaw struct {
	Contract *SuperLedgerConfigurationTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperLedgerConfiguration creates a new instance of SuperLedgerConfiguration, bound to a specific deployed contract.
func NewSuperLedgerConfiguration(address common.Address, backend bind.ContractBackend) (*SuperLedgerConfiguration, error) {
	contract, err := bindSuperLedgerConfiguration(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfiguration{SuperLedgerConfigurationCaller: SuperLedgerConfigurationCaller{contract: contract}, SuperLedgerConfigurationTransactor: SuperLedgerConfigurationTransactor{contract: contract}, SuperLedgerConfigurationFilterer: SuperLedgerConfigurationFilterer{contract: contract}}, nil
}

// NewSuperLedgerConfigurationCaller creates a new read-only instance of SuperLedgerConfiguration, bound to a specific deployed contract.
func NewSuperLedgerConfigurationCaller(address common.Address, caller bind.ContractCaller) (*SuperLedgerConfigurationCaller, error) {
	contract, err := bindSuperLedgerConfiguration(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationCaller{contract: contract}, nil
}

// NewSuperLedgerConfigurationTransactor creates a new write-only instance of SuperLedgerConfiguration, bound to a specific deployed contract.
func NewSuperLedgerConfigurationTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperLedgerConfigurationTransactor, error) {
	contract, err := bindSuperLedgerConfiguration(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationTransactor{contract: contract}, nil
}

// NewSuperLedgerConfigurationFilterer creates a new log filterer instance of SuperLedgerConfiguration, bound to a specific deployed contract.
func NewSuperLedgerConfigurationFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperLedgerConfigurationFilterer, error) {
	contract, err := bindSuperLedgerConfiguration(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationFilterer{contract: contract}, nil
}

// bindSuperLedgerConfiguration binds a generic wrapper to an already deployed contract.
func bindSuperLedgerConfiguration(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperLedgerConfigurationMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperLedgerConfiguration *SuperLedgerConfigurationRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperLedgerConfiguration.Contract.SuperLedgerConfigurationCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperLedgerConfiguration *SuperLedgerConfigurationRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.SuperLedgerConfigurationTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperLedgerConfiguration *SuperLedgerConfigurationRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.SuperLedgerConfigurationTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperLedgerConfiguration *SuperLedgerConfigurationCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperLedgerConfiguration.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.contract.Transact(opts, method, params...)
}

// GetYieldSourceOracleConfig is a free data retrieval call binding the contract method 0xf8bc154b.
//
// Solidity: function getYieldSourceOracleConfig(bytes4 yieldSourceOracleId) view returns((address,uint256,address,address,address))
func (_SuperLedgerConfiguration *SuperLedgerConfigurationCaller) GetYieldSourceOracleConfig(opts *bind.CallOpts, yieldSourceOracleId [4]byte) (ISuperLedgerConfigurationYieldSourceOracleConfig, error) {
	var out []interface{}
	err := _SuperLedgerConfiguration.contract.Call(opts, &out, "getYieldSourceOracleConfig", yieldSourceOracleId)

	if err != nil {
		return *new(ISuperLedgerConfigurationYieldSourceOracleConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(ISuperLedgerConfigurationYieldSourceOracleConfig)).(*ISuperLedgerConfigurationYieldSourceOracleConfig)

	return out0, err

}

// GetYieldSourceOracleConfig is a free data retrieval call binding the contract method 0xf8bc154b.
//
// Solidity: function getYieldSourceOracleConfig(bytes4 yieldSourceOracleId) view returns((address,uint256,address,address,address))
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) GetYieldSourceOracleConfig(yieldSourceOracleId [4]byte) (ISuperLedgerConfigurationYieldSourceOracleConfig, error) {
	return _SuperLedgerConfiguration.Contract.GetYieldSourceOracleConfig(&_SuperLedgerConfiguration.CallOpts, yieldSourceOracleId)
}

// GetYieldSourceOracleConfig is a free data retrieval call binding the contract method 0xf8bc154b.
//
// Solidity: function getYieldSourceOracleConfig(bytes4 yieldSourceOracleId) view returns((address,uint256,address,address,address))
func (_SuperLedgerConfiguration *SuperLedgerConfigurationCallerSession) GetYieldSourceOracleConfig(yieldSourceOracleId [4]byte) (ISuperLedgerConfigurationYieldSourceOracleConfig, error) {
	return _SuperLedgerConfiguration.Contract.GetYieldSourceOracleConfig(&_SuperLedgerConfiguration.CallOpts, yieldSourceOracleId)
}

// GetYieldSourceOracleConfigs is a free data retrieval call binding the contract method 0xa53fba1a.
//
// Solidity: function getYieldSourceOracleConfigs(bytes4[] yieldSourceOracleIds) view returns((address,uint256,address,address,address)[] configs)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationCaller) GetYieldSourceOracleConfigs(opts *bind.CallOpts, yieldSourceOracleIds [][4]byte) ([]ISuperLedgerConfigurationYieldSourceOracleConfig, error) {
	var out []interface{}
	err := _SuperLedgerConfiguration.contract.Call(opts, &out, "getYieldSourceOracleConfigs", yieldSourceOracleIds)

	if err != nil {
		return *new([]ISuperLedgerConfigurationYieldSourceOracleConfig), err
	}

	out0 := *abi.ConvertType(out[0], new([]ISuperLedgerConfigurationYieldSourceOracleConfig)).(*[]ISuperLedgerConfigurationYieldSourceOracleConfig)

	return out0, err

}

// GetYieldSourceOracleConfigs is a free data retrieval call binding the contract method 0xa53fba1a.
//
// Solidity: function getYieldSourceOracleConfigs(bytes4[] yieldSourceOracleIds) view returns((address,uint256,address,address,address)[] configs)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) GetYieldSourceOracleConfigs(yieldSourceOracleIds [][4]byte) ([]ISuperLedgerConfigurationYieldSourceOracleConfig, error) {
	return _SuperLedgerConfiguration.Contract.GetYieldSourceOracleConfigs(&_SuperLedgerConfiguration.CallOpts, yieldSourceOracleIds)
}

// GetYieldSourceOracleConfigs is a free data retrieval call binding the contract method 0xa53fba1a.
//
// Solidity: function getYieldSourceOracleConfigs(bytes4[] yieldSourceOracleIds) view returns((address,uint256,address,address,address)[] configs)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationCallerSession) GetYieldSourceOracleConfigs(yieldSourceOracleIds [][4]byte) ([]ISuperLedgerConfigurationYieldSourceOracleConfig, error) {
	return _SuperLedgerConfiguration.Contract.GetYieldSourceOracleConfigs(&_SuperLedgerConfiguration.CallOpts, yieldSourceOracleIds)
}

// AcceptManagerRole is a paid mutator transaction binding the contract method 0xef841cc2.
//
// Solidity: function acceptManagerRole(bytes4 yieldSourceOracleId) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactor) AcceptManagerRole(opts *bind.TransactOpts, yieldSourceOracleId [4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.contract.Transact(opts, "acceptManagerRole", yieldSourceOracleId)
}

// AcceptManagerRole is a paid mutator transaction binding the contract method 0xef841cc2.
//
// Solidity: function acceptManagerRole(bytes4 yieldSourceOracleId) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) AcceptManagerRole(yieldSourceOracleId [4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.AcceptManagerRole(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleId)
}

// AcceptManagerRole is a paid mutator transaction binding the contract method 0xef841cc2.
//
// Solidity: function acceptManagerRole(bytes4 yieldSourceOracleId) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorSession) AcceptManagerRole(yieldSourceOracleId [4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.AcceptManagerRole(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleId)
}

// AcceptYieldSourceOracleConfigProposal is a paid mutator transaction binding the contract method 0x03a63c75.
//
// Solidity: function acceptYieldSourceOracleConfigProposal(bytes4[] yieldSourceOracleIds) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactor) AcceptYieldSourceOracleConfigProposal(opts *bind.TransactOpts, yieldSourceOracleIds [][4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.contract.Transact(opts, "acceptYieldSourceOracleConfigProposal", yieldSourceOracleIds)
}

// AcceptYieldSourceOracleConfigProposal is a paid mutator transaction binding the contract method 0x03a63c75.
//
// Solidity: function acceptYieldSourceOracleConfigProposal(bytes4[] yieldSourceOracleIds) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) AcceptYieldSourceOracleConfigProposal(yieldSourceOracleIds [][4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.AcceptYieldSourceOracleConfigProposal(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleIds)
}

// AcceptYieldSourceOracleConfigProposal is a paid mutator transaction binding the contract method 0x03a63c75.
//
// Solidity: function acceptYieldSourceOracleConfigProposal(bytes4[] yieldSourceOracleIds) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorSession) AcceptYieldSourceOracleConfigProposal(yieldSourceOracleIds [][4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.AcceptYieldSourceOracleConfigProposal(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleIds)
}

// CancelYieldSourceOracleConfigProposal is a paid mutator transaction binding the contract method 0x0ec29842.
//
// Solidity: function cancelYieldSourceOracleConfigProposal(bytes4 yieldSourceOracleId) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactor) CancelYieldSourceOracleConfigProposal(opts *bind.TransactOpts, yieldSourceOracleId [4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.contract.Transact(opts, "cancelYieldSourceOracleConfigProposal", yieldSourceOracleId)
}

// CancelYieldSourceOracleConfigProposal is a paid mutator transaction binding the contract method 0x0ec29842.
//
// Solidity: function cancelYieldSourceOracleConfigProposal(bytes4 yieldSourceOracleId) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) CancelYieldSourceOracleConfigProposal(yieldSourceOracleId [4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.CancelYieldSourceOracleConfigProposal(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleId)
}

// CancelYieldSourceOracleConfigProposal is a paid mutator transaction binding the contract method 0x0ec29842.
//
// Solidity: function cancelYieldSourceOracleConfigProposal(bytes4 yieldSourceOracleId) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorSession) CancelYieldSourceOracleConfigProposal(yieldSourceOracleId [4]byte) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.CancelYieldSourceOracleConfigProposal(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleId)
}

// ProposeYieldSourceOracleConfig is a paid mutator transaction binding the contract method 0x3685d4be.
//
// Solidity: function proposeYieldSourceOracleConfig((bytes4,address,uint256,address,address)[] configs) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactor) ProposeYieldSourceOracleConfig(opts *bind.TransactOpts, configs []ISuperLedgerConfigurationYieldSourceOracleConfigArgs) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.contract.Transact(opts, "proposeYieldSourceOracleConfig", configs)
}

// ProposeYieldSourceOracleConfig is a paid mutator transaction binding the contract method 0x3685d4be.
//
// Solidity: function proposeYieldSourceOracleConfig((bytes4,address,uint256,address,address)[] configs) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) ProposeYieldSourceOracleConfig(configs []ISuperLedgerConfigurationYieldSourceOracleConfigArgs) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.ProposeYieldSourceOracleConfig(&_SuperLedgerConfiguration.TransactOpts, configs)
}

// ProposeYieldSourceOracleConfig is a paid mutator transaction binding the contract method 0x3685d4be.
//
// Solidity: function proposeYieldSourceOracleConfig((bytes4,address,uint256,address,address)[] configs) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorSession) ProposeYieldSourceOracleConfig(configs []ISuperLedgerConfigurationYieldSourceOracleConfigArgs) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.ProposeYieldSourceOracleConfig(&_SuperLedgerConfiguration.TransactOpts, configs)
}

// SetYieldSourceOracles is a paid mutator transaction binding the contract method 0x79fc641e.
//
// Solidity: function setYieldSourceOracles((bytes4,address,uint256,address,address)[] configs) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactor) SetYieldSourceOracles(opts *bind.TransactOpts, configs []ISuperLedgerConfigurationYieldSourceOracleConfigArgs) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.contract.Transact(opts, "setYieldSourceOracles", configs)
}

// SetYieldSourceOracles is a paid mutator transaction binding the contract method 0x79fc641e.
//
// Solidity: function setYieldSourceOracles((bytes4,address,uint256,address,address)[] configs) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) SetYieldSourceOracles(configs []ISuperLedgerConfigurationYieldSourceOracleConfigArgs) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.SetYieldSourceOracles(&_SuperLedgerConfiguration.TransactOpts, configs)
}

// SetYieldSourceOracles is a paid mutator transaction binding the contract method 0x79fc641e.
//
// Solidity: function setYieldSourceOracles((bytes4,address,uint256,address,address)[] configs) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorSession) SetYieldSourceOracles(configs []ISuperLedgerConfigurationYieldSourceOracleConfigArgs) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.SetYieldSourceOracles(&_SuperLedgerConfiguration.TransactOpts, configs)
}

// TransferManagerRole is a paid mutator transaction binding the contract method 0x0e9a3a76.
//
// Solidity: function transferManagerRole(bytes4 yieldSourceOracleId, address newManager) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactor) TransferManagerRole(opts *bind.TransactOpts, yieldSourceOracleId [4]byte, newManager common.Address) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.contract.Transact(opts, "transferManagerRole", yieldSourceOracleId, newManager)
}

// TransferManagerRole is a paid mutator transaction binding the contract method 0x0e9a3a76.
//
// Solidity: function transferManagerRole(bytes4 yieldSourceOracleId, address newManager) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationSession) TransferManagerRole(yieldSourceOracleId [4]byte, newManager common.Address) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.TransferManagerRole(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleId, newManager)
}

// TransferManagerRole is a paid mutator transaction binding the contract method 0x0e9a3a76.
//
// Solidity: function transferManagerRole(bytes4 yieldSourceOracleId, address newManager) returns()
func (_SuperLedgerConfiguration *SuperLedgerConfigurationTransactorSession) TransferManagerRole(yieldSourceOracleId [4]byte, newManager common.Address) (*types.Transaction, error) {
	return _SuperLedgerConfiguration.Contract.TransferManagerRole(&_SuperLedgerConfiguration.TransactOpts, yieldSourceOracleId, newManager)
}

// SuperLedgerConfigurationManagerRoleTransferAcceptedIterator is returned from FilterManagerRoleTransferAccepted and is used to iterate over the raw logs and unpacked data for ManagerRoleTransferAccepted events raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationManagerRoleTransferAcceptedIterator struct {
	Event *SuperLedgerConfigurationManagerRoleTransferAccepted // Event containing the contract specifics and raw log

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
func (it *SuperLedgerConfigurationManagerRoleTransferAcceptedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerConfigurationManagerRoleTransferAccepted)
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
		it.Event = new(SuperLedgerConfigurationManagerRoleTransferAccepted)
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
func (it *SuperLedgerConfigurationManagerRoleTransferAcceptedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerConfigurationManagerRoleTransferAcceptedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerConfigurationManagerRoleTransferAccepted represents a ManagerRoleTransferAccepted event raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationManagerRoleTransferAccepted struct {
	YieldSourceOracleId [4]byte
	NewManager          common.Address
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterManagerRoleTransferAccepted is a free log retrieval operation binding the contract event 0x61c5f5d804ff8c242cac3cdb71c97f45ef46d5bac0e47b2ce23684710e2f1770.
//
// Solidity: event ManagerRoleTransferAccepted(bytes4 indexed yieldSourceOracleId, address indexed newManager)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) FilterManagerRoleTransferAccepted(opts *bind.FilterOpts, yieldSourceOracleId [][4]byte, newManager []common.Address) (*SuperLedgerConfigurationManagerRoleTransferAcceptedIterator, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var newManagerRule []interface{}
	for _, newManagerItem := range newManager {
		newManagerRule = append(newManagerRule, newManagerItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.FilterLogs(opts, "ManagerRoleTransferAccepted", yieldSourceOracleIdRule, newManagerRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationManagerRoleTransferAcceptedIterator{contract: _SuperLedgerConfiguration.contract, event: "ManagerRoleTransferAccepted", logs: logs, sub: sub}, nil
}

// WatchManagerRoleTransferAccepted is a free log subscription operation binding the contract event 0x61c5f5d804ff8c242cac3cdb71c97f45ef46d5bac0e47b2ce23684710e2f1770.
//
// Solidity: event ManagerRoleTransferAccepted(bytes4 indexed yieldSourceOracleId, address indexed newManager)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) WatchManagerRoleTransferAccepted(opts *bind.WatchOpts, sink chan<- *SuperLedgerConfigurationManagerRoleTransferAccepted, yieldSourceOracleId [][4]byte, newManager []common.Address) (event.Subscription, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var newManagerRule []interface{}
	for _, newManagerItem := range newManager {
		newManagerRule = append(newManagerRule, newManagerItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.WatchLogs(opts, "ManagerRoleTransferAccepted", yieldSourceOracleIdRule, newManagerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerConfigurationManagerRoleTransferAccepted)
				if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "ManagerRoleTransferAccepted", log); err != nil {
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

// ParseManagerRoleTransferAccepted is a log parse operation binding the contract event 0x61c5f5d804ff8c242cac3cdb71c97f45ef46d5bac0e47b2ce23684710e2f1770.
//
// Solidity: event ManagerRoleTransferAccepted(bytes4 indexed yieldSourceOracleId, address indexed newManager)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) ParseManagerRoleTransferAccepted(log types.Log) (*SuperLedgerConfigurationManagerRoleTransferAccepted, error) {
	event := new(SuperLedgerConfigurationManagerRoleTransferAccepted)
	if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "ManagerRoleTransferAccepted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperLedgerConfigurationManagerRoleTransferStartedIterator is returned from FilterManagerRoleTransferStarted and is used to iterate over the raw logs and unpacked data for ManagerRoleTransferStarted events raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationManagerRoleTransferStartedIterator struct {
	Event *SuperLedgerConfigurationManagerRoleTransferStarted // Event containing the contract specifics and raw log

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
func (it *SuperLedgerConfigurationManagerRoleTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerConfigurationManagerRoleTransferStarted)
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
		it.Event = new(SuperLedgerConfigurationManagerRoleTransferStarted)
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
func (it *SuperLedgerConfigurationManagerRoleTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerConfigurationManagerRoleTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerConfigurationManagerRoleTransferStarted represents a ManagerRoleTransferStarted event raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationManagerRoleTransferStarted struct {
	YieldSourceOracleId [4]byte
	CurrentManager      common.Address
	NewManager          common.Address
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterManagerRoleTransferStarted is a free log retrieval operation binding the contract event 0x60540b5ce4133c8361bacbc33d47bfba0613b441b7dbdd89454b538d0e7ee049.
//
// Solidity: event ManagerRoleTransferStarted(bytes4 indexed yieldSourceOracleId, address indexed currentManager, address indexed newManager)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) FilterManagerRoleTransferStarted(opts *bind.FilterOpts, yieldSourceOracleId [][4]byte, currentManager []common.Address, newManager []common.Address) (*SuperLedgerConfigurationManagerRoleTransferStartedIterator, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var currentManagerRule []interface{}
	for _, currentManagerItem := range currentManager {
		currentManagerRule = append(currentManagerRule, currentManagerItem)
	}
	var newManagerRule []interface{}
	for _, newManagerItem := range newManager {
		newManagerRule = append(newManagerRule, newManagerItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.FilterLogs(opts, "ManagerRoleTransferStarted", yieldSourceOracleIdRule, currentManagerRule, newManagerRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationManagerRoleTransferStartedIterator{contract: _SuperLedgerConfiguration.contract, event: "ManagerRoleTransferStarted", logs: logs, sub: sub}, nil
}

// WatchManagerRoleTransferStarted is a free log subscription operation binding the contract event 0x60540b5ce4133c8361bacbc33d47bfba0613b441b7dbdd89454b538d0e7ee049.
//
// Solidity: event ManagerRoleTransferStarted(bytes4 indexed yieldSourceOracleId, address indexed currentManager, address indexed newManager)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) WatchManagerRoleTransferStarted(opts *bind.WatchOpts, sink chan<- *SuperLedgerConfigurationManagerRoleTransferStarted, yieldSourceOracleId [][4]byte, currentManager []common.Address, newManager []common.Address) (event.Subscription, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var currentManagerRule []interface{}
	for _, currentManagerItem := range currentManager {
		currentManagerRule = append(currentManagerRule, currentManagerItem)
	}
	var newManagerRule []interface{}
	for _, newManagerItem := range newManager {
		newManagerRule = append(newManagerRule, newManagerItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.WatchLogs(opts, "ManagerRoleTransferStarted", yieldSourceOracleIdRule, currentManagerRule, newManagerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerConfigurationManagerRoleTransferStarted)
				if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "ManagerRoleTransferStarted", log); err != nil {
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

// ParseManagerRoleTransferStarted is a log parse operation binding the contract event 0x60540b5ce4133c8361bacbc33d47bfba0613b441b7dbdd89454b538d0e7ee049.
//
// Solidity: event ManagerRoleTransferStarted(bytes4 indexed yieldSourceOracleId, address indexed currentManager, address indexed newManager)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) ParseManagerRoleTransferStarted(log types.Log) (*SuperLedgerConfigurationManagerRoleTransferStarted, error) {
	event := new(SuperLedgerConfigurationManagerRoleTransferStarted)
	if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "ManagerRoleTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigAcceptedIterator is returned from FilterYieldSourceOracleConfigAccepted and is used to iterate over the raw logs and unpacked data for YieldSourceOracleConfigAccepted events raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigAcceptedIterator struct {
	Event *SuperLedgerConfigurationYieldSourceOracleConfigAccepted // Event containing the contract specifics and raw log

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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigAcceptedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigAccepted)
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
		it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigAccepted)
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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigAcceptedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerConfigurationYieldSourceOracleConfigAcceptedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigAccepted represents a YieldSourceOracleConfigAccepted event raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigAccepted struct {
	YieldSourceOracleId [4]byte
	YieldSourceOracle   common.Address
	FeePercent          *big.Int
	FeeRecipient        common.Address
	Manager             common.Address
	Ledger              common.Address
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceOracleConfigAccepted is a free log retrieval operation binding the contract event 0x814831b00a6934451a16960666868ead8dc884f244a041c3aa9866aa8ab9bf61.
//
// Solidity: event YieldSourceOracleConfigAccepted(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) FilterYieldSourceOracleConfigAccepted(opts *bind.FilterOpts, yieldSourceOracleId [][4]byte, yieldSourceOracle []common.Address) (*SuperLedgerConfigurationYieldSourceOracleConfigAcceptedIterator, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.FilterLogs(opts, "YieldSourceOracleConfigAccepted", yieldSourceOracleIdRule, yieldSourceOracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationYieldSourceOracleConfigAcceptedIterator{contract: _SuperLedgerConfiguration.contract, event: "YieldSourceOracleConfigAccepted", logs: logs, sub: sub}, nil
}

// WatchYieldSourceOracleConfigAccepted is a free log subscription operation binding the contract event 0x814831b00a6934451a16960666868ead8dc884f244a041c3aa9866aa8ab9bf61.
//
// Solidity: event YieldSourceOracleConfigAccepted(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) WatchYieldSourceOracleConfigAccepted(opts *bind.WatchOpts, sink chan<- *SuperLedgerConfigurationYieldSourceOracleConfigAccepted, yieldSourceOracleId [][4]byte, yieldSourceOracle []common.Address) (event.Subscription, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.WatchLogs(opts, "YieldSourceOracleConfigAccepted", yieldSourceOracleIdRule, yieldSourceOracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerConfigurationYieldSourceOracleConfigAccepted)
				if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigAccepted", log); err != nil {
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

// ParseYieldSourceOracleConfigAccepted is a log parse operation binding the contract event 0x814831b00a6934451a16960666868ead8dc884f244a041c3aa9866aa8ab9bf61.
//
// Solidity: event YieldSourceOracleConfigAccepted(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) ParseYieldSourceOracleConfigAccepted(log types.Log) (*SuperLedgerConfigurationYieldSourceOracleConfigAccepted, error) {
	event := new(SuperLedgerConfigurationYieldSourceOracleConfigAccepted)
	if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigAccepted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelledIterator is returned from FilterYieldSourceOracleConfigProposalCancelled and is used to iterate over the raw logs and unpacked data for YieldSourceOracleConfigProposalCancelled events raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelledIterator struct {
	Event *SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled // Event containing the contract specifics and raw log

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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled)
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
		it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled)
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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled represents a YieldSourceOracleConfigProposalCancelled event raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled struct {
	YieldSourceOracleId [4]byte
	YieldSourceOracle   common.Address
	FeePercent          *big.Int
	FeeRecipient        common.Address
	Manager             common.Address
	Ledger              common.Address
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceOracleConfigProposalCancelled is a free log retrieval operation binding the contract event 0x68839b26267a4e2923397c3c18eea298983035a126631feb8efc72e5e082f581.
//
// Solidity: event YieldSourceOracleConfigProposalCancelled(bytes4 indexed yieldSourceOracleId, address yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) FilterYieldSourceOracleConfigProposalCancelled(opts *bind.FilterOpts, yieldSourceOracleId [][4]byte) (*SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelledIterator, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.FilterLogs(opts, "YieldSourceOracleConfigProposalCancelled", yieldSourceOracleIdRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelledIterator{contract: _SuperLedgerConfiguration.contract, event: "YieldSourceOracleConfigProposalCancelled", logs: logs, sub: sub}, nil
}

// WatchYieldSourceOracleConfigProposalCancelled is a free log subscription operation binding the contract event 0x68839b26267a4e2923397c3c18eea298983035a126631feb8efc72e5e082f581.
//
// Solidity: event YieldSourceOracleConfigProposalCancelled(bytes4 indexed yieldSourceOracleId, address yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) WatchYieldSourceOracleConfigProposalCancelled(opts *bind.WatchOpts, sink chan<- *SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled, yieldSourceOracleId [][4]byte) (event.Subscription, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.WatchLogs(opts, "YieldSourceOracleConfigProposalCancelled", yieldSourceOracleIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled)
				if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigProposalCancelled", log); err != nil {
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

// ParseYieldSourceOracleConfigProposalCancelled is a log parse operation binding the contract event 0x68839b26267a4e2923397c3c18eea298983035a126631feb8efc72e5e082f581.
//
// Solidity: event YieldSourceOracleConfigProposalCancelled(bytes4 indexed yieldSourceOracleId, address yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) ParseYieldSourceOracleConfigProposalCancelled(log types.Log) (*SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled, error) {
	event := new(SuperLedgerConfigurationYieldSourceOracleConfigProposalCancelled)
	if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigProposalCancelled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigProposalSetIterator is returned from FilterYieldSourceOracleConfigProposalSet and is used to iterate over the raw logs and unpacked data for YieldSourceOracleConfigProposalSet events raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigProposalSetIterator struct {
	Event *SuperLedgerConfigurationYieldSourceOracleConfigProposalSet // Event containing the contract specifics and raw log

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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigProposalSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigProposalSet)
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
		it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigProposalSet)
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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigProposalSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerConfigurationYieldSourceOracleConfigProposalSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigProposalSet represents a YieldSourceOracleConfigProposalSet event raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigProposalSet struct {
	YieldSourceOracleId [4]byte
	YieldSourceOracle   common.Address
	FeePercent          *big.Int
	FeeRecipient        common.Address
	Manager             common.Address
	Ledger              common.Address
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceOracleConfigProposalSet is a free log retrieval operation binding the contract event 0x15b13915ede6636ce8731f76ba01024780f382a88587dbb649e002b447f5ea10.
//
// Solidity: event YieldSourceOracleConfigProposalSet(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) FilterYieldSourceOracleConfigProposalSet(opts *bind.FilterOpts, yieldSourceOracleId [][4]byte, yieldSourceOracle []common.Address) (*SuperLedgerConfigurationYieldSourceOracleConfigProposalSetIterator, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.FilterLogs(opts, "YieldSourceOracleConfigProposalSet", yieldSourceOracleIdRule, yieldSourceOracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationYieldSourceOracleConfigProposalSetIterator{contract: _SuperLedgerConfiguration.contract, event: "YieldSourceOracleConfigProposalSet", logs: logs, sub: sub}, nil
}

// WatchYieldSourceOracleConfigProposalSet is a free log subscription operation binding the contract event 0x15b13915ede6636ce8731f76ba01024780f382a88587dbb649e002b447f5ea10.
//
// Solidity: event YieldSourceOracleConfigProposalSet(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) WatchYieldSourceOracleConfigProposalSet(opts *bind.WatchOpts, sink chan<- *SuperLedgerConfigurationYieldSourceOracleConfigProposalSet, yieldSourceOracleId [][4]byte, yieldSourceOracle []common.Address) (event.Subscription, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.WatchLogs(opts, "YieldSourceOracleConfigProposalSet", yieldSourceOracleIdRule, yieldSourceOracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerConfigurationYieldSourceOracleConfigProposalSet)
				if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigProposalSet", log); err != nil {
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

// ParseYieldSourceOracleConfigProposalSet is a log parse operation binding the contract event 0x15b13915ede6636ce8731f76ba01024780f382a88587dbb649e002b447f5ea10.
//
// Solidity: event YieldSourceOracleConfigProposalSet(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) ParseYieldSourceOracleConfigProposalSet(log types.Log) (*SuperLedgerConfigurationYieldSourceOracleConfigProposalSet, error) {
	event := new(SuperLedgerConfigurationYieldSourceOracleConfigProposalSet)
	if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigProposalSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigSetIterator is returned from FilterYieldSourceOracleConfigSet and is used to iterate over the raw logs and unpacked data for YieldSourceOracleConfigSet events raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigSetIterator struct {
	Event *SuperLedgerConfigurationYieldSourceOracleConfigSet // Event containing the contract specifics and raw log

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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigSet)
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
		it.Event = new(SuperLedgerConfigurationYieldSourceOracleConfigSet)
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
func (it *SuperLedgerConfigurationYieldSourceOracleConfigSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperLedgerConfigurationYieldSourceOracleConfigSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperLedgerConfigurationYieldSourceOracleConfigSet represents a YieldSourceOracleConfigSet event raised by the SuperLedgerConfiguration contract.
type SuperLedgerConfigurationYieldSourceOracleConfigSet struct {
	YieldSourceOracleId [4]byte
	YieldSourceOracle   common.Address
	FeePercent          *big.Int
	FeeRecipient        common.Address
	Manager             common.Address
	Ledger              common.Address
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceOracleConfigSet is a free log retrieval operation binding the contract event 0x325563e67bd0f9ddf8076fe8c531e47576230cd340e7ea24ea7fed745606131a.
//
// Solidity: event YieldSourceOracleConfigSet(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) FilterYieldSourceOracleConfigSet(opts *bind.FilterOpts, yieldSourceOracleId [][4]byte, yieldSourceOracle []common.Address) (*SuperLedgerConfigurationYieldSourceOracleConfigSetIterator, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.FilterLogs(opts, "YieldSourceOracleConfigSet", yieldSourceOracleIdRule, yieldSourceOracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperLedgerConfigurationYieldSourceOracleConfigSetIterator{contract: _SuperLedgerConfiguration.contract, event: "YieldSourceOracleConfigSet", logs: logs, sub: sub}, nil
}

// WatchYieldSourceOracleConfigSet is a free log subscription operation binding the contract event 0x325563e67bd0f9ddf8076fe8c531e47576230cd340e7ea24ea7fed745606131a.
//
// Solidity: event YieldSourceOracleConfigSet(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) WatchYieldSourceOracleConfigSet(opts *bind.WatchOpts, sink chan<- *SuperLedgerConfigurationYieldSourceOracleConfigSet, yieldSourceOracleId [][4]byte, yieldSourceOracle []common.Address) (event.Subscription, error) {

	var yieldSourceOracleIdRule []interface{}
	for _, yieldSourceOracleIdItem := range yieldSourceOracleId {
		yieldSourceOracleIdRule = append(yieldSourceOracleIdRule, yieldSourceOracleIdItem)
	}
	var yieldSourceOracleRule []interface{}
	for _, yieldSourceOracleItem := range yieldSourceOracle {
		yieldSourceOracleRule = append(yieldSourceOracleRule, yieldSourceOracleItem)
	}

	logs, sub, err := _SuperLedgerConfiguration.contract.WatchLogs(opts, "YieldSourceOracleConfigSet", yieldSourceOracleIdRule, yieldSourceOracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperLedgerConfigurationYieldSourceOracleConfigSet)
				if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigSet", log); err != nil {
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

// ParseYieldSourceOracleConfigSet is a log parse operation binding the contract event 0x325563e67bd0f9ddf8076fe8c531e47576230cd340e7ea24ea7fed745606131a.
//
// Solidity: event YieldSourceOracleConfigSet(bytes4 indexed yieldSourceOracleId, address indexed yieldSourceOracle, uint256 feePercent, address feeRecipient, address manager, address ledger)
func (_SuperLedgerConfiguration *SuperLedgerConfigurationFilterer) ParseYieldSourceOracleConfigSet(log types.Log) (*SuperLedgerConfigurationYieldSourceOracleConfigSet, error) {
	event := new(SuperLedgerConfigurationYieldSourceOracleConfigSet)
	if err := _SuperLedgerConfiguration.contract.UnpackLog(event, "YieldSourceOracleConfigSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
