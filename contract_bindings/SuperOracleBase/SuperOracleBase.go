// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperOracleBase

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

// SuperOracleBaseMetaData contains all meta data concerning the SuperOracleBase contract.
var SuperOracleBaseMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"SUPER_GOVERNOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"activeProviders\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"batchSetEmergencyPrice\",\"inputs\":[{\"name\":\"tokens_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"prices_\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"emergencyPrices\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"emergencyPrice\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"executeOracleUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeProviderRemoval\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"feedMaxStaleness\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"maxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getActiveProviders\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getEmergencyPrice\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOracleAddress\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getQuote\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getQuoteFromProvider\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracleProvider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"deviation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"totalProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"availableProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isProviderSet\",\"inputs\":[{\"name\":\"provider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"isSet\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"maxDefaultStaleness\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingRemoval\",\"inputs\":[],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingUpdate\",\"inputs\":[],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"queueOracleUpdate\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"queueProviderRemoval\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setEmergencyPrice\",\"inputs\":[{\"name\":\"token_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"price_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStaleness\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStalenessBatch\",\"inputs\":[{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"newMaxStalenessList\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setMaxStaleness\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"EmergencyPriceUpdated\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"price\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeedMaxStalenessUpdated\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MaxStalenessUpdated\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateExecuted\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateQueued\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OraclesConfigured\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalExecuted\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalQueued\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AVERAGE_PROVIDER_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ORACLE_PROVIDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MAX_STALENESS_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_ADMIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_ORACLES_CONFIGURED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_UPDATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_VALID_REPORTED_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ORACLE_UNTRUSTED_DATA\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OracleUnsupportedPair\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OracleUntrustedData\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"PENDING_UPDATE_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TIMELOCK_NOT_ELAPSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED_UPDATE_AUTHORITY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_QUOTE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_PROVIDER\",\"inputs\":[]}]",
}

// SuperOracleBaseABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperOracleBaseMetaData.ABI instead.
var SuperOracleBaseABI = SuperOracleBaseMetaData.ABI

// SuperOracleBase is an auto generated Go binding around an Ethereum contract.
type SuperOracleBase struct {
	SuperOracleBaseCaller     // Read-only binding to the contract
	SuperOracleBaseTransactor // Write-only binding to the contract
	SuperOracleBaseFilterer   // Log filterer for contract events
}

// SuperOracleBaseCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperOracleBaseCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleBaseTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperOracleBaseTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleBaseFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperOracleBaseFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleBaseSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperOracleBaseSession struct {
	Contract     *SuperOracleBase  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperOracleBaseCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperOracleBaseCallerSession struct {
	Contract *SuperOracleBaseCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// SuperOracleBaseTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperOracleBaseTransactorSession struct {
	Contract     *SuperOracleBaseTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// SuperOracleBaseRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperOracleBaseRaw struct {
	Contract *SuperOracleBase // Generic contract binding to access the raw methods on
}

// SuperOracleBaseCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperOracleBaseCallerRaw struct {
	Contract *SuperOracleBaseCaller // Generic read-only contract binding to access the raw methods on
}

// SuperOracleBaseTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperOracleBaseTransactorRaw struct {
	Contract *SuperOracleBaseTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperOracleBase creates a new instance of SuperOracleBase, bound to a specific deployed contract.
func NewSuperOracleBase(address common.Address, backend bind.ContractBackend) (*SuperOracleBase, error) {
	contract, err := bindSuperOracleBase(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperOracleBase{SuperOracleBaseCaller: SuperOracleBaseCaller{contract: contract}, SuperOracleBaseTransactor: SuperOracleBaseTransactor{contract: contract}, SuperOracleBaseFilterer: SuperOracleBaseFilterer{contract: contract}}, nil
}

// NewSuperOracleBaseCaller creates a new read-only instance of SuperOracleBase, bound to a specific deployed contract.
func NewSuperOracleBaseCaller(address common.Address, caller bind.ContractCaller) (*SuperOracleBaseCaller, error) {
	contract, err := bindSuperOracleBase(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseCaller{contract: contract}, nil
}

// NewSuperOracleBaseTransactor creates a new write-only instance of SuperOracleBase, bound to a specific deployed contract.
func NewSuperOracleBaseTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperOracleBaseTransactor, error) {
	contract, err := bindSuperOracleBase(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseTransactor{contract: contract}, nil
}

// NewSuperOracleBaseFilterer creates a new log filterer instance of SuperOracleBase, bound to a specific deployed contract.
func NewSuperOracleBaseFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperOracleBaseFilterer, error) {
	contract, err := bindSuperOracleBase(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseFilterer{contract: contract}, nil
}

// bindSuperOracleBase binds a generic wrapper to an already deployed contract.
func bindSuperOracleBase(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperOracleBaseMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperOracleBase *SuperOracleBaseRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperOracleBase.Contract.SuperOracleBaseCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperOracleBase *SuperOracleBaseRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SuperOracleBaseTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperOracleBase *SuperOracleBaseRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SuperOracleBaseTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperOracleBase *SuperOracleBaseCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperOracleBase.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperOracleBase *SuperOracleBaseTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperOracleBase *SuperOracleBaseTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.contract.Transact(opts, method, params...)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperOracleBase *SuperOracleBaseCaller) SUPERGOVERNOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "SUPER_GOVERNOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperOracleBase *SuperOracleBaseSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperOracleBase.Contract.SUPERGOVERNOR(&_SuperOracleBase.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperOracleBase *SuperOracleBaseCallerSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperOracleBase.Contract.SUPERGOVERNOR(&_SuperOracleBase.CallOpts)
}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracleBase *SuperOracleBaseCaller) ActiveProviders(opts *bind.CallOpts, arg0 *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "activeProviders", arg0)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracleBase *SuperOracleBaseSession) ActiveProviders(arg0 *big.Int) ([32]byte, error) {
	return _SuperOracleBase.Contract.ActiveProviders(&_SuperOracleBase.CallOpts, arg0)
}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracleBase *SuperOracleBaseCallerSession) ActiveProviders(arg0 *big.Int) ([32]byte, error) {
	return _SuperOracleBase.Contract.ActiveProviders(&_SuperOracleBase.CallOpts, arg0)
}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 emergencyPrice)
func (_SuperOracleBase *SuperOracleBaseCaller) EmergencyPrices(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "emergencyPrices", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 emergencyPrice)
func (_SuperOracleBase *SuperOracleBaseSession) EmergencyPrices(token common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.EmergencyPrices(&_SuperOracleBase.CallOpts, token)
}

// EmergencyPrices is a free data retrieval call binding the contract method 0x1a97300d.
//
// Solidity: function emergencyPrices(address token) view returns(uint256 emergencyPrice)
func (_SuperOracleBase *SuperOracleBaseCallerSession) EmergencyPrices(token common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.EmergencyPrices(&_SuperOracleBase.CallOpts, token)
}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracleBase *SuperOracleBaseCaller) FeedMaxStaleness(opts *bind.CallOpts, feed common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "feedMaxStaleness", feed)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracleBase *SuperOracleBaseSession) FeedMaxStaleness(feed common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.FeedMaxStaleness(&_SuperOracleBase.CallOpts, feed)
}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracleBase *SuperOracleBaseCallerSession) FeedMaxStaleness(feed common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.FeedMaxStaleness(&_SuperOracleBase.CallOpts, feed)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracleBase *SuperOracleBaseCaller) GetActiveProviders(opts *bind.CallOpts) ([][32]byte, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "getActiveProviders")

	if err != nil {
		return *new([][32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([][32]byte)).(*[][32]byte)

	return out0, err

}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracleBase *SuperOracleBaseSession) GetActiveProviders() ([][32]byte, error) {
	return _SuperOracleBase.Contract.GetActiveProviders(&_SuperOracleBase.CallOpts)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracleBase *SuperOracleBaseCallerSession) GetActiveProviders() ([][32]byte, error) {
	return _SuperOracleBase.Contract.GetActiveProviders(&_SuperOracleBase.CallOpts)
}

// GetEmergencyPrice is a free data retrieval call binding the contract method 0x7dde6aee.
//
// Solidity: function getEmergencyPrice(address token) view returns(uint256)
func (_SuperOracleBase *SuperOracleBaseCaller) GetEmergencyPrice(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "getEmergencyPrice", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetEmergencyPrice is a free data retrieval call binding the contract method 0x7dde6aee.
//
// Solidity: function getEmergencyPrice(address token) view returns(uint256)
func (_SuperOracleBase *SuperOracleBaseSession) GetEmergencyPrice(token common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.GetEmergencyPrice(&_SuperOracleBase.CallOpts, token)
}

// GetEmergencyPrice is a free data retrieval call binding the contract method 0x7dde6aee.
//
// Solidity: function getEmergencyPrice(address token) view returns(uint256)
func (_SuperOracleBase *SuperOracleBaseCallerSession) GetEmergencyPrice(token common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.GetEmergencyPrice(&_SuperOracleBase.CallOpts, token)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracleBase *SuperOracleBaseCaller) GetOracleAddress(opts *bind.CallOpts, base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "getOracleAddress", base, quote, provider)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracleBase *SuperOracleBaseSession) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _SuperOracleBase.Contract.GetOracleAddress(&_SuperOracleBase.CallOpts, base, quote, provider)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracleBase *SuperOracleBaseCallerSession) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _SuperOracleBase.Contract.GetOracleAddress(&_SuperOracleBase.CallOpts, base, quote, provider)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracleBase *SuperOracleBaseCaller) GetQuote(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "getQuote", baseAmount, base, quote)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracleBase *SuperOracleBaseSession) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.GetQuote(&_SuperOracleBase.CallOpts, baseAmount, base, quote)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracleBase *SuperOracleBaseCallerSession) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperOracleBase.Contract.GetQuote(&_SuperOracleBase.CallOpts, baseAmount, base, quote)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_SuperOracleBase *SuperOracleBaseCaller) GetQuoteFromProvider(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "getQuoteFromProvider", baseAmount, base, quote, oracleProvider)

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
func (_SuperOracleBase *SuperOracleBaseSession) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _SuperOracleBase.Contract.GetQuoteFromProvider(&_SuperOracleBase.CallOpts, baseAmount, base, quote, oracleProvider)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_SuperOracleBase *SuperOracleBaseCallerSession) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _SuperOracleBase.Contract.GetQuoteFromProvider(&_SuperOracleBase.CallOpts, baseAmount, base, quote, oracleProvider)
}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracleBase *SuperOracleBaseCaller) IsProviderSet(opts *bind.CallOpts, provider [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "isProviderSet", provider)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracleBase *SuperOracleBaseSession) IsProviderSet(provider [32]byte) (bool, error) {
	return _SuperOracleBase.Contract.IsProviderSet(&_SuperOracleBase.CallOpts, provider)
}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracleBase *SuperOracleBaseCallerSession) IsProviderSet(provider [32]byte) (bool, error) {
	return _SuperOracleBase.Contract.IsProviderSet(&_SuperOracleBase.CallOpts, provider)
}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracleBase *SuperOracleBaseCaller) MaxDefaultStaleness(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "maxDefaultStaleness")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracleBase *SuperOracleBaseSession) MaxDefaultStaleness() (*big.Int, error) {
	return _SuperOracleBase.Contract.MaxDefaultStaleness(&_SuperOracleBase.CallOpts)
}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracleBase *SuperOracleBaseCallerSession) MaxDefaultStaleness() (*big.Int, error) {
	return _SuperOracleBase.Contract.MaxDefaultStaleness(&_SuperOracleBase.CallOpts)
}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseCaller) PendingRemoval(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "pendingRemoval")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseSession) PendingRemoval() (*big.Int, error) {
	return _SuperOracleBase.Contract.PendingRemoval(&_SuperOracleBase.CallOpts)
}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseCallerSession) PendingRemoval() (*big.Int, error) {
	return _SuperOracleBase.Contract.PendingRemoval(&_SuperOracleBase.CallOpts)
}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseCaller) PendingUpdate(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleBase.contract.Call(opts, &out, "pendingUpdate")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseSession) PendingUpdate() (*big.Int, error) {
	return _SuperOracleBase.Contract.PendingUpdate(&_SuperOracleBase.CallOpts)
}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseCallerSession) PendingUpdate() (*big.Int, error) {
	return _SuperOracleBase.Contract.PendingUpdate(&_SuperOracleBase.CallOpts)
}

// BatchSetEmergencyPrice is a paid mutator transaction binding the contract method 0x0a8209b7.
//
// Solidity: function batchSetEmergencyPrice(address[] tokens_, uint256[] prices_) returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) BatchSetEmergencyPrice(opts *bind.TransactOpts, tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "batchSetEmergencyPrice", tokens_, prices_)
}

// BatchSetEmergencyPrice is a paid mutator transaction binding the contract method 0x0a8209b7.
//
// Solidity: function batchSetEmergencyPrice(address[] tokens_, uint256[] prices_) returns()
func (_SuperOracleBase *SuperOracleBaseSession) BatchSetEmergencyPrice(tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.BatchSetEmergencyPrice(&_SuperOracleBase.TransactOpts, tokens_, prices_)
}

// BatchSetEmergencyPrice is a paid mutator transaction binding the contract method 0x0a8209b7.
//
// Solidity: function batchSetEmergencyPrice(address[] tokens_, uint256[] prices_) returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) BatchSetEmergencyPrice(tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.BatchSetEmergencyPrice(&_SuperOracleBase.TransactOpts, tokens_, prices_)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) ExecuteOracleUpdate(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "executeOracleUpdate")
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracleBase *SuperOracleBaseSession) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _SuperOracleBase.Contract.ExecuteOracleUpdate(&_SuperOracleBase.TransactOpts)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _SuperOracleBase.Contract.ExecuteOracleUpdate(&_SuperOracleBase.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) ExecuteProviderRemoval(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "executeProviderRemoval")
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracleBase *SuperOracleBaseSession) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _SuperOracleBase.Contract.ExecuteProviderRemoval(&_SuperOracleBase.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _SuperOracleBase.Contract.ExecuteProviderRemoval(&_SuperOracleBase.TransactOpts)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) QueueOracleUpdate(opts *bind.TransactOpts, bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "queueOracleUpdate", bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracleBase *SuperOracleBaseSession) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.QueueOracleUpdate(&_SuperOracleBase.TransactOpts, bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.QueueOracleUpdate(&_SuperOracleBase.TransactOpts, bases, quotes, providers, feeds)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) QueueProviderRemoval(opts *bind.TransactOpts, providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "queueProviderRemoval", providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracleBase *SuperOracleBaseSession) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.QueueProviderRemoval(&_SuperOracleBase.TransactOpts, providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.QueueProviderRemoval(&_SuperOracleBase.TransactOpts, providers)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) SetEmergencyPrice(opts *bind.TransactOpts, token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "setEmergencyPrice", token_, price_)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperOracleBase *SuperOracleBaseSession) SetEmergencyPrice(token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetEmergencyPrice(&_SuperOracleBase.TransactOpts, token_, price_)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) SetEmergencyPrice(token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetEmergencyPrice(&_SuperOracleBase.TransactOpts, token_, price_)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) SetFeedMaxStaleness(opts *bind.TransactOpts, feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "setFeedMaxStaleness", feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracleBase *SuperOracleBaseSession) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetFeedMaxStaleness(&_SuperOracleBase.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetFeedMaxStaleness(&_SuperOracleBase.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) SetFeedMaxStalenessBatch(opts *bind.TransactOpts, feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "setFeedMaxStalenessBatch", feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracleBase *SuperOracleBaseSession) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetFeedMaxStalenessBatch(&_SuperOracleBase.TransactOpts, feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetFeedMaxStalenessBatch(&_SuperOracleBase.TransactOpts, feeds, newMaxStalenessList)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracleBase *SuperOracleBaseTransactor) SetMaxStaleness(opts *bind.TransactOpts, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.contract.Transact(opts, "setMaxStaleness", newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracleBase *SuperOracleBaseSession) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetMaxStaleness(&_SuperOracleBase.TransactOpts, newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracleBase *SuperOracleBaseTransactorSession) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleBase.Contract.SetMaxStaleness(&_SuperOracleBase.TransactOpts, newMaxStaleness)
}

// SuperOracleBaseEmergencyPriceUpdatedIterator is returned from FilterEmergencyPriceUpdated and is used to iterate over the raw logs and unpacked data for EmergencyPriceUpdated events raised by the SuperOracleBase contract.
type SuperOracleBaseEmergencyPriceUpdatedIterator struct {
	Event *SuperOracleBaseEmergencyPriceUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseEmergencyPriceUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseEmergencyPriceUpdated)
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
		it.Event = new(SuperOracleBaseEmergencyPriceUpdated)
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
func (it *SuperOracleBaseEmergencyPriceUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseEmergencyPriceUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseEmergencyPriceUpdated represents a EmergencyPriceUpdated event raised by the SuperOracleBase contract.
type SuperOracleBaseEmergencyPriceUpdated struct {
	Token common.Address
	Price *big.Int
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterEmergencyPriceUpdated is a free log retrieval operation binding the contract event 0xe370960bcd07b43e7cd9ddad2e5402c8679785673033b06c09edbea916797f34.
//
// Solidity: event EmergencyPriceUpdated(address token, uint256 price)
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterEmergencyPriceUpdated(opts *bind.FilterOpts) (*SuperOracleBaseEmergencyPriceUpdatedIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "EmergencyPriceUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseEmergencyPriceUpdatedIterator{contract: _SuperOracleBase.contract, event: "EmergencyPriceUpdated", logs: logs, sub: sub}, nil
}

// WatchEmergencyPriceUpdated is a free log subscription operation binding the contract event 0xe370960bcd07b43e7cd9ddad2e5402c8679785673033b06c09edbea916797f34.
//
// Solidity: event EmergencyPriceUpdated(address token, uint256 price)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchEmergencyPriceUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseEmergencyPriceUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "EmergencyPriceUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseEmergencyPriceUpdated)
				if err := _SuperOracleBase.contract.UnpackLog(event, "EmergencyPriceUpdated", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseEmergencyPriceUpdated(log types.Log) (*SuperOracleBaseEmergencyPriceUpdated, error) {
	event := new(SuperOracleBaseEmergencyPriceUpdated)
	if err := _SuperOracleBase.contract.UnpackLog(event, "EmergencyPriceUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleBaseFeedMaxStalenessUpdatedIterator is returned from FilterFeedMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for FeedMaxStalenessUpdated events raised by the SuperOracleBase contract.
type SuperOracleBaseFeedMaxStalenessUpdatedIterator struct {
	Event *SuperOracleBaseFeedMaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseFeedMaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseFeedMaxStalenessUpdated)
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
		it.Event = new(SuperOracleBaseFeedMaxStalenessUpdated)
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
func (it *SuperOracleBaseFeedMaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseFeedMaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseFeedMaxStalenessUpdated represents a FeedMaxStalenessUpdated event raised by the SuperOracleBase contract.
type SuperOracleBaseFeedMaxStalenessUpdated struct {
	Feed            common.Address
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterFeedMaxStalenessUpdated is a free log retrieval operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterFeedMaxStalenessUpdated(opts *bind.FilterOpts) (*SuperOracleBaseFeedMaxStalenessUpdatedIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseFeedMaxStalenessUpdatedIterator{contract: _SuperOracleBase.contract, event: "FeedMaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchFeedMaxStalenessUpdated is a free log subscription operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchFeedMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseFeedMaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseFeedMaxStalenessUpdated)
				if err := _SuperOracleBase.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseFeedMaxStalenessUpdated(log types.Log) (*SuperOracleBaseFeedMaxStalenessUpdated, error) {
	event := new(SuperOracleBaseFeedMaxStalenessUpdated)
	if err := _SuperOracleBase.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleBaseMaxStalenessUpdatedIterator is returned from FilterMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for MaxStalenessUpdated events raised by the SuperOracleBase contract.
type SuperOracleBaseMaxStalenessUpdatedIterator struct {
	Event *SuperOracleBaseMaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseMaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseMaxStalenessUpdated)
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
		it.Event = new(SuperOracleBaseMaxStalenessUpdated)
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
func (it *SuperOracleBaseMaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseMaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseMaxStalenessUpdated represents a MaxStalenessUpdated event raised by the SuperOracleBase contract.
type SuperOracleBaseMaxStalenessUpdated struct {
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterMaxStalenessUpdated is a free log retrieval operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterMaxStalenessUpdated(opts *bind.FilterOpts) (*SuperOracleBaseMaxStalenessUpdatedIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseMaxStalenessUpdatedIterator{contract: _SuperOracleBase.contract, event: "MaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchMaxStalenessUpdated is a free log subscription operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseMaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseMaxStalenessUpdated)
				if err := _SuperOracleBase.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseMaxStalenessUpdated(log types.Log) (*SuperOracleBaseMaxStalenessUpdated, error) {
	event := new(SuperOracleBaseMaxStalenessUpdated)
	if err := _SuperOracleBase.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleBaseOracleUpdateExecutedIterator is returned from FilterOracleUpdateExecuted and is used to iterate over the raw logs and unpacked data for OracleUpdateExecuted events raised by the SuperOracleBase contract.
type SuperOracleBaseOracleUpdateExecutedIterator struct {
	Event *SuperOracleBaseOracleUpdateExecuted // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseOracleUpdateExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseOracleUpdateExecuted)
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
		it.Event = new(SuperOracleBaseOracleUpdateExecuted)
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
func (it *SuperOracleBaseOracleUpdateExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseOracleUpdateExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseOracleUpdateExecuted represents a OracleUpdateExecuted event raised by the SuperOracleBase contract.
type SuperOracleBaseOracleUpdateExecuted struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOracleUpdateExecuted is a free log retrieval operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterOracleUpdateExecuted(opts *bind.FilterOpts) (*SuperOracleBaseOracleUpdateExecutedIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseOracleUpdateExecutedIterator{contract: _SuperOracleBase.contract, event: "OracleUpdateExecuted", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateExecuted is a free log subscription operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchOracleUpdateExecuted(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseOracleUpdateExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseOracleUpdateExecuted)
				if err := _SuperOracleBase.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseOracleUpdateExecuted(log types.Log) (*SuperOracleBaseOracleUpdateExecuted, error) {
	event := new(SuperOracleBaseOracleUpdateExecuted)
	if err := _SuperOracleBase.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleBaseOracleUpdateQueuedIterator is returned from FilterOracleUpdateQueued and is used to iterate over the raw logs and unpacked data for OracleUpdateQueued events raised by the SuperOracleBase contract.
type SuperOracleBaseOracleUpdateQueuedIterator struct {
	Event *SuperOracleBaseOracleUpdateQueued // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseOracleUpdateQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseOracleUpdateQueued)
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
		it.Event = new(SuperOracleBaseOracleUpdateQueued)
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
func (it *SuperOracleBaseOracleUpdateQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseOracleUpdateQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseOracleUpdateQueued represents a OracleUpdateQueued event raised by the SuperOracleBase contract.
type SuperOracleBaseOracleUpdateQueued struct {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterOracleUpdateQueued(opts *bind.FilterOpts) (*SuperOracleBaseOracleUpdateQueuedIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseOracleUpdateQueuedIterator{contract: _SuperOracleBase.contract, event: "OracleUpdateQueued", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateQueued is a free log subscription operation binding the contract event 0x47555224c714bb2542163eb1af8f45ad13e8ac6bf56fb032b81425bdcc8521fa.
//
// Solidity: event OracleUpdateQueued(address[] bases, address[] quotes, bytes32[] providers, address[] feeds, uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchOracleUpdateQueued(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseOracleUpdateQueued) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseOracleUpdateQueued)
				if err := _SuperOracleBase.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseOracleUpdateQueued(log types.Log) (*SuperOracleBaseOracleUpdateQueued, error) {
	event := new(SuperOracleBaseOracleUpdateQueued)
	if err := _SuperOracleBase.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleBaseOraclesConfiguredIterator is returned from FilterOraclesConfigured and is used to iterate over the raw logs and unpacked data for OraclesConfigured events raised by the SuperOracleBase contract.
type SuperOracleBaseOraclesConfiguredIterator struct {
	Event *SuperOracleBaseOraclesConfigured // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseOraclesConfiguredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseOraclesConfigured)
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
		it.Event = new(SuperOracleBaseOraclesConfigured)
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
func (it *SuperOracleBaseOraclesConfiguredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseOraclesConfiguredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseOraclesConfigured represents a OraclesConfigured event raised by the SuperOracleBase contract.
type SuperOracleBaseOraclesConfigured struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOraclesConfigured is a free log retrieval operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterOraclesConfigured(opts *bind.FilterOpts) (*SuperOracleBaseOraclesConfiguredIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseOraclesConfiguredIterator{contract: _SuperOracleBase.contract, event: "OraclesConfigured", logs: logs, sub: sub}, nil
}

// WatchOraclesConfigured is a free log subscription operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchOraclesConfigured(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseOraclesConfigured) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseOraclesConfigured)
				if err := _SuperOracleBase.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseOraclesConfigured(log types.Log) (*SuperOracleBaseOraclesConfigured, error) {
	event := new(SuperOracleBaseOraclesConfigured)
	if err := _SuperOracleBase.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleBaseProviderRemovalExecutedIterator is returned from FilterProviderRemovalExecuted and is used to iterate over the raw logs and unpacked data for ProviderRemovalExecuted events raised by the SuperOracleBase contract.
type SuperOracleBaseProviderRemovalExecutedIterator struct {
	Event *SuperOracleBaseProviderRemovalExecuted // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseProviderRemovalExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseProviderRemovalExecuted)
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
		it.Event = new(SuperOracleBaseProviderRemovalExecuted)
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
func (it *SuperOracleBaseProviderRemovalExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseProviderRemovalExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseProviderRemovalExecuted represents a ProviderRemovalExecuted event raised by the SuperOracleBase contract.
type SuperOracleBaseProviderRemovalExecuted struct {
	Providers [][32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalExecuted is a free log retrieval operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterProviderRemovalExecuted(opts *bind.FilterOpts) (*SuperOracleBaseProviderRemovalExecutedIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseProviderRemovalExecutedIterator{contract: _SuperOracleBase.contract, event: "ProviderRemovalExecuted", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalExecuted is a free log subscription operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchProviderRemovalExecuted(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseProviderRemovalExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseProviderRemovalExecuted)
				if err := _SuperOracleBase.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseProviderRemovalExecuted(log types.Log) (*SuperOracleBaseProviderRemovalExecuted, error) {
	event := new(SuperOracleBaseProviderRemovalExecuted)
	if err := _SuperOracleBase.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleBaseProviderRemovalQueuedIterator is returned from FilterProviderRemovalQueued and is used to iterate over the raw logs and unpacked data for ProviderRemovalQueued events raised by the SuperOracleBase contract.
type SuperOracleBaseProviderRemovalQueuedIterator struct {
	Event *SuperOracleBaseProviderRemovalQueued // Event containing the contract specifics and raw log

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
func (it *SuperOracleBaseProviderRemovalQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleBaseProviderRemovalQueued)
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
		it.Event = new(SuperOracleBaseProviderRemovalQueued)
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
func (it *SuperOracleBaseProviderRemovalQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleBaseProviderRemovalQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleBaseProviderRemovalQueued represents a ProviderRemovalQueued event raised by the SuperOracleBase contract.
type SuperOracleBaseProviderRemovalQueued struct {
	Providers [][32]byte
	Timestamp *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalQueued is a free log retrieval operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseFilterer) FilterProviderRemovalQueued(opts *bind.FilterOpts) (*SuperOracleBaseProviderRemovalQueuedIterator, error) {

	logs, sub, err := _SuperOracleBase.contract.FilterLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return &SuperOracleBaseProviderRemovalQueuedIterator{contract: _SuperOracleBase.contract, event: "ProviderRemovalQueued", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalQueued is a free log subscription operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_SuperOracleBase *SuperOracleBaseFilterer) WatchProviderRemovalQueued(opts *bind.WatchOpts, sink chan<- *SuperOracleBaseProviderRemovalQueued) (event.Subscription, error) {

	logs, sub, err := _SuperOracleBase.contract.WatchLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleBaseProviderRemovalQueued)
				if err := _SuperOracleBase.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
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
func (_SuperOracleBase *SuperOracleBaseFilterer) ParseProviderRemovalQueued(log types.Log) (*SuperOracleBaseProviderRemovalQueued, error) {
	event := new(SuperOracleBaseProviderRemovalQueued)
	if err := _SuperOracleBase.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
