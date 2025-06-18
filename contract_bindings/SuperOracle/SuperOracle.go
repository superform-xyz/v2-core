// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperOracle

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

// SuperOracleMetaData contains all meta data concerning the SuperOracle contract.
var SuperOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superGovernor_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"bases\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_GOVERNOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"activeProviders\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"batchSetEmergencyPrice\",\"inputs\":[{\"name\":\"tokens_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"prices_\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"emergencyPrices\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"emergencyPrice\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"executeOracleUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeProviderRemoval\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"feedMaxStaleness\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"maxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getActiveProviders\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getEmergencyPrice\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOracleAddress\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getQuote\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getQuoteFromProvider\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracleProvider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"deviation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"totalProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"availableProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isProviderSet\",\"inputs\":[{\"name\":\"provider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"isSet\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"maxDefaultStaleness\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingRemoval\",\"inputs\":[],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingUpdate\",\"inputs\":[],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"queueOracleUpdate\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"queueProviderRemoval\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setEmergencyPrice\",\"inputs\":[{\"name\":\"token_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"price_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStaleness\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStalenessBatch\",\"inputs\":[{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"newMaxStalenessList\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setMaxStaleness\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"EmergencyPriceUpdated\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"price\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeedMaxStalenessUpdated\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MaxStalenessUpdated\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateExecuted\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateQueued\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OraclesConfigured\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalExecuted\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalQueued\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AVERAGE_PROVIDER_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ORACLE_PROVIDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MAX_STALENESS_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_ADMIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_ORACLES_CONFIGURED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_UPDATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_VALID_REPORTED_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ORACLE_UNTRUSTED_DATA\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OracleUnsupportedPair\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OracleUntrustedData\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"PENDING_UPDATE_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TIMELOCK_NOT_ELAPSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED_UPDATE_AUTHORITY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_QUOTE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_PROVIDER\",\"inputs\":[]}]",
}

// SuperOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperOracleMetaData.ABI instead.
var SuperOracleABI = SuperOracleMetaData.ABI

// SuperOracle is an auto generated Go binding around an Ethereum contract.
type SuperOracle struct {
	SuperOracleCaller     // Read-only binding to the contract
	SuperOracleTransactor // Write-only binding to the contract
	SuperOracleFilterer   // Log filterer for contract events
}

// SuperOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperOracleSession struct {
	Contract     *SuperOracle      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperOracleCallerSession struct {
	Contract *SuperOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// SuperOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperOracleTransactorSession struct {
	Contract     *SuperOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// SuperOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperOracleRaw struct {
	Contract *SuperOracle // Generic contract binding to access the raw methods on
}

// SuperOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperOracleCallerRaw struct {
	Contract *SuperOracleCaller // Generic read-only contract binding to access the raw methods on
}

// SuperOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperOracleTransactorRaw struct {
	Contract *SuperOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperOracle creates a new instance of SuperOracle, bound to a specific deployed contract.
func NewSuperOracle(address common.Address, backend bind.ContractBackend) (*SuperOracle, error) {
	contract, err := bindSuperOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperOracle{SuperOracleCaller: SuperOracleCaller{contract: contract}, SuperOracleTransactor: SuperOracleTransactor{contract: contract}, SuperOracleFilterer: SuperOracleFilterer{contract: contract}}, nil
}

// NewSuperOracleCaller creates a new read-only instance of SuperOracle, bound to a specific deployed contract.
func NewSuperOracleCaller(address common.Address, caller bind.ContractCaller) (*SuperOracleCaller, error) {
	contract, err := bindSuperOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperOracleCaller{contract: contract}, nil
}

// NewSuperOracleTransactor creates a new write-only instance of SuperOracle, bound to a specific deployed contract.
func NewSuperOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperOracleTransactor, error) {
	contract, err := bindSuperOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperOracleTransactor{contract: contract}, nil
}

// NewSuperOracleFilterer creates a new log filterer instance of SuperOracle, bound to a specific deployed contract.
func NewSuperOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperOracleFilterer, error) {
	contract, err := bindSuperOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperOracleFilterer{contract: contract}, nil
}

// bindSuperOracle binds a generic wrapper to an already deployed contract.
func bindSuperOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperOracle *SuperOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperOracle.Contract.SuperOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperOracle *SuperOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracle.Contract.SuperOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperOracle *SuperOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperOracle.Contract.SuperOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperOracle *SuperOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperOracle *SuperOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperOracle *SuperOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperOracle.Contract.contract.Transact(opts, method, params...)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperOracle *SuperOracleCaller) SUPERGOVERNOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "SUPER_GOVERNOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperOracle *SuperOracleSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperOracle.Contract.SUPERGOVERNOR(&_SuperOracle.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperOracle *SuperOracleCallerSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperOracle.Contract.SUPERGOVERNOR(&_SuperOracle.CallOpts)
}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracle *SuperOracleCaller) ActiveProviders(opts *bind.CallOpts, arg0 *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "activeProviders", arg0)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracle *SuperOracleSession) ActiveProviders(arg0 *big.Int) ([32]byte, error) {
	return _SuperOracle.Contract.ActiveProviders(&_SuperOracle.CallOpts, arg0)
}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracle *SuperOracleCallerSession) ActiveProviders(arg0 *big.Int) ([32]byte, error) {
	return _SuperOracle.Contract.ActiveProviders(&_SuperOracle.CallOpts, arg0)
}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 emergencyPrice)
func (_SuperOracle *SuperOracleCaller) EmergencyPrices(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "emergencyPrices", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 emergencyPrice)
func (_SuperOracle *SuperOracleSession) EmergencyPrices(token common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.EmergencyPrices(&_SuperOracle.CallOpts, token)
}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 emergencyPrice)
func (_SuperOracle *SuperOracleCallerSession) EmergencyPrices(token common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.EmergencyPrices(&_SuperOracle.CallOpts, token)
}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracle *SuperOracleCaller) FeedMaxStaleness(opts *bind.CallOpts, feed common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "feedMaxStaleness", feed)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracle *SuperOracleSession) FeedMaxStaleness(feed common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.FeedMaxStaleness(&_SuperOracle.CallOpts, feed)
}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracle *SuperOracleCallerSession) FeedMaxStaleness(feed common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.FeedMaxStaleness(&_SuperOracle.CallOpts, feed)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracle *SuperOracleCaller) GetActiveProviders(opts *bind.CallOpts) ([][32]byte, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "getActiveProviders")

	if err != nil {
		return *new([][32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([][32]byte)).(*[][32]byte)

	return out0, err

}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracle *SuperOracleSession) GetActiveProviders() ([][32]byte, error) {
	return _SuperOracle.Contract.GetActiveProviders(&_SuperOracle.CallOpts)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracle *SuperOracleCallerSession) GetActiveProviders() ([][32]byte, error) {
	return _SuperOracle.Contract.GetActiveProviders(&_SuperOracle.CallOpts)
}

// GetEmergencyPrice is a free data retrieval call binding the contract method 0x7dde6aee.
//
// Solidity: function getEmergencyPrice(address token) view returns(uint256)
func (_SuperOracle *SuperOracleCaller) GetEmergencyPrice(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "getEmergencyPrice", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetEmergencyPrice is a free data retrieval call binding the contract method 0x7dde6aee.
//
// Solidity: function getEmergencyPrice(address token) view returns(uint256)
func (_SuperOracle *SuperOracleSession) GetEmergencyPrice(token common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.GetEmergencyPrice(&_SuperOracle.CallOpts, token)
}

// GetEmergencyPrice is a free data retrieval call binding the contract method 0x7dde6aee.
//
// Solidity: function getEmergencyPrice(address token) view returns(uint256)
func (_SuperOracle *SuperOracleCallerSession) GetEmergencyPrice(token common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.GetEmergencyPrice(&_SuperOracle.CallOpts, token)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracle *SuperOracleCaller) GetOracleAddress(opts *bind.CallOpts, base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "getOracleAddress", base, quote, provider)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracle *SuperOracleSession) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _SuperOracle.Contract.GetOracleAddress(&_SuperOracle.CallOpts, base, quote, provider)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracle *SuperOracleCallerSession) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _SuperOracle.Contract.GetOracleAddress(&_SuperOracle.CallOpts, base, quote, provider)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracle *SuperOracleCaller) GetQuote(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "getQuote", baseAmount, base, quote)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracle *SuperOracleSession) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.GetQuote(&_SuperOracle.CallOpts, baseAmount, base, quote)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracle *SuperOracleCallerSession) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperOracle.Contract.GetQuote(&_SuperOracle.CallOpts, baseAmount, base, quote)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_SuperOracle *SuperOracleCaller) GetQuoteFromProvider(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "getQuoteFromProvider", baseAmount, base, quote, oracleProvider)

	outstruct := new(struct {
		QuoteAmount        *big.Int
		Deviation          *big.Int
		TotalProviders     *big.Int
		AvailableProviders *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.QuoteAmount = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.Deviation = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.TotalProviders = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)
	outstruct.AvailableProviders = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_SuperOracle *SuperOracleSession) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _SuperOracle.Contract.GetQuoteFromProvider(&_SuperOracle.CallOpts, baseAmount, base, quote, oracleProvider)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_SuperOracle *SuperOracleCallerSession) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _SuperOracle.Contract.GetQuoteFromProvider(&_SuperOracle.CallOpts, baseAmount, base, quote, oracleProvider)
}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracle *SuperOracleCaller) IsProviderSet(opts *bind.CallOpts, provider [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "isProviderSet", provider)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracle *SuperOracleSession) IsProviderSet(provider [32]byte) (bool, error) {
	return _SuperOracle.Contract.IsProviderSet(&_SuperOracle.CallOpts, provider)
}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracle *SuperOracleCallerSession) IsProviderSet(provider [32]byte) (bool, error) {
	return _SuperOracle.Contract.IsProviderSet(&_SuperOracle.CallOpts, provider)
}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracle *SuperOracleCaller) MaxDefaultStaleness(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "maxDefaultStaleness")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracle *SuperOracleSession) MaxDefaultStaleness() (*big.Int, error) {
	return _SuperOracle.Contract.MaxDefaultStaleness(&_SuperOracle.CallOpts)
}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracle *SuperOracleCallerSession) MaxDefaultStaleness() (*big.Int, error) {
	return _SuperOracle.Contract.MaxDefaultStaleness(&_SuperOracle.CallOpts)
}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracle *SuperOracleCaller) PendingRemoval(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "pendingRemoval")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracle *SuperOracleSession) PendingRemoval() (*big.Int, error) {
	return _SuperOracle.Contract.PendingRemoval(&_SuperOracle.CallOpts)
}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracle *SuperOracleCallerSession) PendingRemoval() (*big.Int, error) {
	return _SuperOracle.Contract.PendingRemoval(&_SuperOracle.CallOpts)
}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracle *SuperOracleCaller) PendingUpdate(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracle.contract.Call(opts, &out, "pendingUpdate")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracle *SuperOracleSession) PendingUpdate() (*big.Int, error) {
	return _SuperOracle.Contract.PendingUpdate(&_SuperOracle.CallOpts)
}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracle *SuperOracleCallerSession) PendingUpdate() (*big.Int, error) {
	return _SuperOracle.Contract.PendingUpdate(&_SuperOracle.CallOpts)
}

// BatchSetEmergencyPrice is a paid mutator transaction binding the contract method 0x0a8209b7.
//
// Solidity: function batchSetEmergencyPrice(address[] tokens_, uint256[] prices_) returns()
func (_SuperOracle *SuperOracleTransactor) BatchSetEmergencyPrice(opts *bind.TransactOpts, tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "batchSetEmergencyPrice", tokens_, prices_)
}

// BatchSetEmergencyPrice is a paid mutator transaction binding the contract method 0x0a8209b7.
//
// Solidity: function batchSetEmergencyPrice(address[] tokens_, uint256[] prices_) returns()
func (_SuperOracle *SuperOracleSession) BatchSetEmergencyPrice(tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.BatchSetEmergencyPrice(&_SuperOracle.TransactOpts, tokens_, prices_)
}

// BatchSetEmergencyPrice is a paid mutator transaction binding the contract method 0x0a8209b7.
//
// Solidity: function batchSetEmergencyPrice(address[] tokens_, uint256[] prices_) returns()
func (_SuperOracle *SuperOracleTransactorSession) BatchSetEmergencyPrice(tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.BatchSetEmergencyPrice(&_SuperOracle.TransactOpts, tokens_, prices_)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracle *SuperOracleTransactor) ExecuteOracleUpdate(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "executeOracleUpdate")
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracle *SuperOracleSession) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _SuperOracle.Contract.ExecuteOracleUpdate(&_SuperOracle.TransactOpts)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracle *SuperOracleTransactorSession) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _SuperOracle.Contract.ExecuteOracleUpdate(&_SuperOracle.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracle *SuperOracleTransactor) ExecuteProviderRemoval(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "executeProviderRemoval")
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracle *SuperOracleSession) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _SuperOracle.Contract.ExecuteProviderRemoval(&_SuperOracle.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracle *SuperOracleTransactorSession) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _SuperOracle.Contract.ExecuteProviderRemoval(&_SuperOracle.TransactOpts)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracle *SuperOracleTransactor) QueueOracleUpdate(opts *bind.TransactOpts, bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "queueOracleUpdate", bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracle *SuperOracleSession) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracle.Contract.QueueOracleUpdate(&_SuperOracle.TransactOpts, bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracle *SuperOracleTransactorSession) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracle.Contract.QueueOracleUpdate(&_SuperOracle.TransactOpts, bases, quotes, providers, feeds)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracle *SuperOracleTransactor) QueueProviderRemoval(opts *bind.TransactOpts, providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "queueProviderRemoval", providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracle *SuperOracleSession) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracle.Contract.QueueProviderRemoval(&_SuperOracle.TransactOpts, providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracle *SuperOracleTransactorSession) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracle.Contract.QueueProviderRemoval(&_SuperOracle.TransactOpts, providers)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperOracle *SuperOracleTransactor) SetEmergencyPrice(opts *bind.TransactOpts, token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "setEmergencyPrice", token_, price_)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperOracle *SuperOracleSession) SetEmergencyPrice(token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetEmergencyPrice(&_SuperOracle.TransactOpts, token_, price_)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperOracle *SuperOracleTransactorSession) SetEmergencyPrice(token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetEmergencyPrice(&_SuperOracle.TransactOpts, token_, price_)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracle *SuperOracleTransactor) SetFeedMaxStaleness(opts *bind.TransactOpts, feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "setFeedMaxStaleness", feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracle *SuperOracleSession) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetFeedMaxStaleness(&_SuperOracle.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracle *SuperOracleTransactorSession) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetFeedMaxStaleness(&_SuperOracle.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracle *SuperOracleTransactor) SetFeedMaxStalenessBatch(opts *bind.TransactOpts, feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "setFeedMaxStalenessBatch", feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracle *SuperOracleSession) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetFeedMaxStalenessBatch(&_SuperOracle.TransactOpts, feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracle *SuperOracleTransactorSession) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetFeedMaxStalenessBatch(&_SuperOracle.TransactOpts, feeds, newMaxStalenessList)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracle *SuperOracleTransactor) SetMaxStaleness(opts *bind.TransactOpts, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracle.contract.Transact(opts, "setMaxStaleness", newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracle *SuperOracleSession) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetMaxStaleness(&_SuperOracle.TransactOpts, newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracle *SuperOracleTransactorSession) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracle.Contract.SetMaxStaleness(&_SuperOracle.TransactOpts, newMaxStaleness)
}

// SuperOracleEmergencyPriceUpdatedIterator is returned from FilterEmergencyPriceUpdated and is used to iterate over the raw logs and unpacked data for EmergencyPriceUpdated events raised by the SuperOracle contract.
type SuperOracleEmergencyPriceUpdatedIterator struct {
	Event *SuperOracleEmergencyPriceUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleEmergencyPriceUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleEmergencyPriceUpdated)
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
		it.Event = new(SuperOracleEmergencyPriceUpdated)
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
func (it *SuperOracleEmergencyPriceUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleEmergencyPriceUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleEmergencyPriceUpdated represents a EmergencyPriceUpdated event raised by the SuperOracle contract.
type SuperOracleEmergencyPriceUpdated struct {
	Token common.Address
	Price *big.Int
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterEmergencyPriceUpdated is a free log retrieval operation binding the contract event 0xe370960bcd07b43e7cd9ddad2e5402c8679785673033b06c09edbea916797f34.
//
// Solidity: event EmergencyPriceUpdated(address token, uint256 price)
func (_SuperOracle *SuperOracleFilterer) FilterEmergencyPriceUpdated(opts *bind.FilterOpts) (*SuperOracleEmergencyPriceUpdatedIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "EmergencyPriceUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleEmergencyPriceUpdatedIterator{contract: _SuperOracle.contract, event: "EmergencyPriceUpdated", logs: logs, sub: sub}, nil
}

// WatchEmergencyPriceUpdated is a free log subscription operation binding the contract event 0xe370960bcd07b43e7cd9ddad2e5402c8679785673033b06c09edbea916797f34.
//
// Solidity: event EmergencyPriceUpdated(address token, uint256 price)
func (_SuperOracle *SuperOracleFilterer) WatchEmergencyPriceUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleEmergencyPriceUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "EmergencyPriceUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleEmergencyPriceUpdated)
				if err := _SuperOracle.contract.UnpackLog(event, "EmergencyPriceUpdated", log); err != nil {
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

// ParseEmergencyPriceUpdated is a log parse operation binding the contract event 0xe370960bcd07b43e7cd9ddad2e5402c8679785673033b06c09edbea916797f34.
//
// Solidity: event EmergencyPriceUpdated(address token, uint256 price)
func (_SuperOracle *SuperOracleFilterer) ParseEmergencyPriceUpdated(log types.Log) (*SuperOracleEmergencyPriceUpdated, error) {
	event := new(SuperOracleEmergencyPriceUpdated)
	if err := _SuperOracle.contract.UnpackLog(event, "EmergencyPriceUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleFeedMaxStalenessUpdatedIterator is returned from FilterFeedMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for FeedMaxStalenessUpdated events raised by the SuperOracle contract.
type SuperOracleFeedMaxStalenessUpdatedIterator struct {
	Event *SuperOracleFeedMaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleFeedMaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleFeedMaxStalenessUpdated)
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
		it.Event = new(SuperOracleFeedMaxStalenessUpdated)
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
func (it *SuperOracleFeedMaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleFeedMaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleFeedMaxStalenessUpdated represents a FeedMaxStalenessUpdated event raised by the SuperOracle contract.
type SuperOracleFeedMaxStalenessUpdated struct {
	Feed            common.Address
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterFeedMaxStalenessUpdated is a free log retrieval operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_SuperOracle *SuperOracleFilterer) FilterFeedMaxStalenessUpdated(opts *bind.FilterOpts) (*SuperOracleFeedMaxStalenessUpdatedIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleFeedMaxStalenessUpdatedIterator{contract: _SuperOracle.contract, event: "FeedMaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchFeedMaxStalenessUpdated is a free log subscription operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_SuperOracle *SuperOracleFilterer) WatchFeedMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleFeedMaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleFeedMaxStalenessUpdated)
				if err := _SuperOracle.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
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

// ParseFeedMaxStalenessUpdated is a log parse operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_SuperOracle *SuperOracleFilterer) ParseFeedMaxStalenessUpdated(log types.Log) (*SuperOracleFeedMaxStalenessUpdated, error) {
	event := new(SuperOracleFeedMaxStalenessUpdated)
	if err := _SuperOracle.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleMaxStalenessUpdatedIterator is returned from FilterMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for MaxStalenessUpdated events raised by the SuperOracle contract.
type SuperOracleMaxStalenessUpdatedIterator struct {
	Event *SuperOracleMaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleMaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleMaxStalenessUpdated)
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
		it.Event = new(SuperOracleMaxStalenessUpdated)
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
func (it *SuperOracleMaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleMaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleMaxStalenessUpdated represents a MaxStalenessUpdated event raised by the SuperOracle contract.
type SuperOracleMaxStalenessUpdated struct {
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterMaxStalenessUpdated is a free log retrieval operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_SuperOracle *SuperOracleFilterer) FilterMaxStalenessUpdated(opts *bind.FilterOpts) (*SuperOracleMaxStalenessUpdatedIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleMaxStalenessUpdatedIterator{contract: _SuperOracle.contract, event: "MaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchMaxStalenessUpdated is a free log subscription operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_SuperOracle *SuperOracleFilterer) WatchMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleMaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleMaxStalenessUpdated)
				if err := _SuperOracle.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
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

// ParseMaxStalenessUpdated is a log parse operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_SuperOracle *SuperOracleFilterer) ParseMaxStalenessUpdated(log types.Log) (*SuperOracleMaxStalenessUpdated, error) {
	event := new(SuperOracleMaxStalenessUpdated)
	if err := _SuperOracle.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleOracleUpdateExecutedIterator is returned from FilterOracleUpdateExecuted and is used to iterate over the raw logs and unpacked data for OracleUpdateExecuted events raised by the SuperOracle contract.
type SuperOracleOracleUpdateExecutedIterator struct {
	Event *SuperOracleOracleUpdateExecuted // Event containing the contract specifics and raw log

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
func (it *SuperOracleOracleUpdateExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleOracleUpdateExecuted)
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
		it.Event = new(SuperOracleOracleUpdateExecuted)
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
func (it *SuperOracleOracleUpdateExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleOracleUpdateExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleOracleUpdateExecuted represents a OracleUpdateExecuted event raised by the SuperOracle contract.
type SuperOracleOracleUpdateExecuted struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOracleUpdateExecuted is a free log retrieval operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracle *SuperOracleFilterer) FilterOracleUpdateExecuted(opts *bind.FilterOpts) (*SuperOracleOracleUpdateExecutedIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperOracleOracleUpdateExecutedIterator{contract: _SuperOracle.contract, event: "OracleUpdateExecuted", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateExecuted is a free log subscription operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracle *SuperOracleFilterer) WatchOracleUpdateExecuted(opts *bind.WatchOpts, sink chan<- *SuperOracleOracleUpdateExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleOracleUpdateExecuted)
				if err := _SuperOracle.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
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

// ParseOracleUpdateExecuted is a log parse operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracle *SuperOracleFilterer) ParseOracleUpdateExecuted(log types.Log) (*SuperOracleOracleUpdateExecuted, error) {
	event := new(SuperOracleOracleUpdateExecuted)
	if err := _SuperOracle.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleOracleUpdateQueuedIterator is returned from FilterOracleUpdateQueued and is used to iterate over the raw logs and unpacked data for OracleUpdateQueued events raised by the SuperOracle contract.
type SuperOracleOracleUpdateQueuedIterator struct {
	Event *SuperOracleOracleUpdateQueued // Event containing the contract specifics and raw log

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
func (it *SuperOracleOracleUpdateQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleOracleUpdateQueued)
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
		it.Event = new(SuperOracleOracleUpdateQueued)
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
func (it *SuperOracleOracleUpdateQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleOracleUpdateQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleOracleUpdateQueued represents a OracleUpdateQueued event raised by the SuperOracle contract.
type SuperOracleOracleUpdateQueued struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Timestamp *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOracleUpdateQueued is a free log retrieval operation binding the contract event 0x47555224c714bb2542163eb1af8f45ad13e8ac6bf56fb032b81425bdcc8521fa.
//
// Solidity: event OracleUpdateQueued(address[] bases, address[] quotes, bytes32[] providers, address[] feeds, uint256 timestamp)
func (_SuperOracle *SuperOracleFilterer) FilterOracleUpdateQueued(opts *bind.FilterOpts) (*SuperOracleOracleUpdateQueuedIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return &SuperOracleOracleUpdateQueuedIterator{contract: _SuperOracle.contract, event: "OracleUpdateQueued", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateQueued is a free log subscription operation binding the contract event 0x47555224c714bb2542163eb1af8f45ad13e8ac6bf56fb032b81425bdcc8521fa.
//
// Solidity: event OracleUpdateQueued(address[] bases, address[] quotes, bytes32[] providers, address[] feeds, uint256 timestamp)
func (_SuperOracle *SuperOracleFilterer) WatchOracleUpdateQueued(opts *bind.WatchOpts, sink chan<- *SuperOracleOracleUpdateQueued) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleOracleUpdateQueued)
				if err := _SuperOracle.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
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

// ParseOracleUpdateQueued is a log parse operation binding the contract event 0x47555224c714bb2542163eb1af8f45ad13e8ac6bf56fb032b81425bdcc8521fa.
//
// Solidity: event OracleUpdateQueued(address[] bases, address[] quotes, bytes32[] providers, address[] feeds, uint256 timestamp)
func (_SuperOracle *SuperOracleFilterer) ParseOracleUpdateQueued(log types.Log) (*SuperOracleOracleUpdateQueued, error) {
	event := new(SuperOracleOracleUpdateQueued)
	if err := _SuperOracle.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleOraclesConfiguredIterator is returned from FilterOraclesConfigured and is used to iterate over the raw logs and unpacked data for OraclesConfigured events raised by the SuperOracle contract.
type SuperOracleOraclesConfiguredIterator struct {
	Event *SuperOracleOraclesConfigured // Event containing the contract specifics and raw log

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
func (it *SuperOracleOraclesConfiguredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleOraclesConfigured)
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
		it.Event = new(SuperOracleOraclesConfigured)
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
func (it *SuperOracleOraclesConfiguredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleOraclesConfiguredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleOraclesConfigured represents a OraclesConfigured event raised by the SuperOracle contract.
type SuperOracleOraclesConfigured struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOraclesConfigured is a free log retrieval operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracle *SuperOracleFilterer) FilterOraclesConfigured(opts *bind.FilterOpts) (*SuperOracleOraclesConfiguredIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return &SuperOracleOraclesConfiguredIterator{contract: _SuperOracle.contract, event: "OraclesConfigured", logs: logs, sub: sub}, nil
}

// WatchOraclesConfigured is a free log subscription operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracle *SuperOracleFilterer) WatchOraclesConfigured(opts *bind.WatchOpts, sink chan<- *SuperOracleOraclesConfigured) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleOraclesConfigured)
				if err := _SuperOracle.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
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

// ParseOraclesConfigured is a log parse operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracle *SuperOracleFilterer) ParseOraclesConfigured(log types.Log) (*SuperOracleOraclesConfigured, error) {
	event := new(SuperOracleOraclesConfigured)
	if err := _SuperOracle.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleProviderRemovalExecutedIterator is returned from FilterProviderRemovalExecuted and is used to iterate over the raw logs and unpacked data for ProviderRemovalExecuted events raised by the SuperOracle contract.
type SuperOracleProviderRemovalExecutedIterator struct {
	Event *SuperOracleProviderRemovalExecuted // Event containing the contract specifics and raw log

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
func (it *SuperOracleProviderRemovalExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleProviderRemovalExecuted)
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
		it.Event = new(SuperOracleProviderRemovalExecuted)
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
func (it *SuperOracleProviderRemovalExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleProviderRemovalExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleProviderRemovalExecuted represents a ProviderRemovalExecuted event raised by the SuperOracle contract.
type SuperOracleProviderRemovalExecuted struct {
	Providers [][32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalExecuted is a free log retrieval operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_SuperOracle *SuperOracleFilterer) FilterProviderRemovalExecuted(opts *bind.FilterOpts) (*SuperOracleProviderRemovalExecutedIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperOracleProviderRemovalExecutedIterator{contract: _SuperOracle.contract, event: "ProviderRemovalExecuted", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalExecuted is a free log subscription operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_SuperOracle *SuperOracleFilterer) WatchProviderRemovalExecuted(opts *bind.WatchOpts, sink chan<- *SuperOracleProviderRemovalExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleProviderRemovalExecuted)
				if err := _SuperOracle.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
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

// ParseProviderRemovalExecuted is a log parse operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_SuperOracle *SuperOracleFilterer) ParseProviderRemovalExecuted(log types.Log) (*SuperOracleProviderRemovalExecuted, error) {
	event := new(SuperOracleProviderRemovalExecuted)
	if err := _SuperOracle.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleProviderRemovalQueuedIterator is returned from FilterProviderRemovalQueued and is used to iterate over the raw logs and unpacked data for ProviderRemovalQueued events raised by the SuperOracle contract.
type SuperOracleProviderRemovalQueuedIterator struct {
	Event *SuperOracleProviderRemovalQueued // Event containing the contract specifics and raw log

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
func (it *SuperOracleProviderRemovalQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleProviderRemovalQueued)
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
		it.Event = new(SuperOracleProviderRemovalQueued)
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
func (it *SuperOracleProviderRemovalQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleProviderRemovalQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleProviderRemovalQueued represents a ProviderRemovalQueued event raised by the SuperOracle contract.
type SuperOracleProviderRemovalQueued struct {
	Providers [][32]byte
	Timestamp *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalQueued is a free log retrieval operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_SuperOracle *SuperOracleFilterer) FilterProviderRemovalQueued(opts *bind.FilterOpts) (*SuperOracleProviderRemovalQueuedIterator, error) {

	logs, sub, err := _SuperOracle.contract.FilterLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return &SuperOracleProviderRemovalQueuedIterator{contract: _SuperOracle.contract, event: "ProviderRemovalQueued", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalQueued is a free log subscription operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_SuperOracle *SuperOracleFilterer) WatchProviderRemovalQueued(opts *bind.WatchOpts, sink chan<- *SuperOracleProviderRemovalQueued) (event.Subscription, error) {

	logs, sub, err := _SuperOracle.contract.WatchLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleProviderRemovalQueued)
				if err := _SuperOracle.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
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

// ParseProviderRemovalQueued is a log parse operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_SuperOracle *SuperOracleFilterer) ParseProviderRemovalQueued(log types.Log) (*SuperOracleProviderRemovalQueued, error) {
	event := new(SuperOracleProviderRemovalQueued)
	if err := _SuperOracle.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
