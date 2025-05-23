// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ISuperOracle

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

// ISuperOracleMetaData contains all meta data concerning the ISuperOracle contract.
var ISuperOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"executeOracleUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeProviderRemoval\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getActiveProviders\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOracleAddress\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getQuoteFromProvider\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracleProvider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"deviation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"totalProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"availableProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"queueOracleUpdate\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"queueProviderRemoval\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStaleness\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStalenessBatch\",\"inputs\":[{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"newMaxStalenessList\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setMaxStaleness\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"FeedMaxStalenessUpdated\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MaxStalenessUpdated\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateExecuted\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateQueued\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OraclesConfigured\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalExecuted\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalQueued\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AVERAGE_PROVIDER_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ORACLE_PROVIDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MAX_STALENESS_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_ADMIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_ORACLES_CONFIGURED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_UPDATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_VALID_REPORTED_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ORACLE_UNTRUSTED_DATA\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PENDING_UPDATE_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TIMELOCK_NOT_ELAPSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_QUOTE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_PROVIDER\",\"inputs\":[]}]",
}

// ISuperOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use ISuperOracleMetaData.ABI instead.
var ISuperOracleABI = ISuperOracleMetaData.ABI

// ISuperOracle is an auto generated Go binding around an Ethereum contract.
type ISuperOracle struct {
	ISuperOracleCaller     // Read-only binding to the contract
	ISuperOracleTransactor // Write-only binding to the contract
	ISuperOracleFilterer   // Log filterer for contract events
}

// ISuperOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type ISuperOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ISuperOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ISuperOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ISuperOracleSession struct {
	Contract     *ISuperOracle     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ISuperOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ISuperOracleCallerSession struct {
	Contract *ISuperOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// ISuperOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ISuperOracleTransactorSession struct {
	Contract     *ISuperOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// ISuperOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type ISuperOracleRaw struct {
	Contract *ISuperOracle // Generic contract binding to access the raw methods on
}

// ISuperOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ISuperOracleCallerRaw struct {
	Contract *ISuperOracleCaller // Generic read-only contract binding to access the raw methods on
}

// ISuperOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ISuperOracleTransactorRaw struct {
	Contract *ISuperOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewISuperOracle creates a new instance of ISuperOracle, bound to a specific deployed contract.
func NewISuperOracle(address common.Address, backend bind.ContractBackend) (*ISuperOracle, error) {
	contract, err := bindISuperOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ISuperOracle{ISuperOracleCaller: ISuperOracleCaller{contract: contract}, ISuperOracleTransactor: ISuperOracleTransactor{contract: contract}, ISuperOracleFilterer: ISuperOracleFilterer{contract: contract}}, nil
}

// NewISuperOracleCaller creates a new read-only instance of ISuperOracle, bound to a specific deployed contract.
func NewISuperOracleCaller(address common.Address, caller bind.ContractCaller) (*ISuperOracleCaller, error) {
	contract, err := bindISuperOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperOracleCaller{contract: contract}, nil
}

// NewISuperOracleTransactor creates a new write-only instance of ISuperOracle, bound to a specific deployed contract.
func NewISuperOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*ISuperOracleTransactor, error) {
	contract, err := bindISuperOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperOracleTransactor{contract: contract}, nil
}

// NewISuperOracleFilterer creates a new log filterer instance of ISuperOracle, bound to a specific deployed contract.
func NewISuperOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*ISuperOracleFilterer, error) {
	contract, err := bindISuperOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ISuperOracleFilterer{contract: contract}, nil
}

// bindISuperOracle binds a generic wrapper to an already deployed contract.
func bindISuperOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ISuperOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperOracle *ISuperOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperOracle.Contract.ISuperOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperOracle *ISuperOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperOracle.Contract.ISuperOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperOracle *ISuperOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperOracle.Contract.ISuperOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperOracle *ISuperOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperOracle *ISuperOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperOracle *ISuperOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperOracle.Contract.contract.Transact(opts, method, params...)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_ISuperOracle *ISuperOracleCaller) GetActiveProviders(opts *bind.CallOpts) ([][32]byte, error) {
	var out []interface{}
	err := _ISuperOracle.contract.Call(opts, &out, "getActiveProviders")

	if err != nil {
		return *new([][32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([][32]byte)).(*[][32]byte)

	return out0, err

}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_ISuperOracle *ISuperOracleSession) GetActiveProviders() ([][32]byte, error) {
	return _ISuperOracle.Contract.GetActiveProviders(&_ISuperOracle.CallOpts)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_ISuperOracle *ISuperOracleCallerSession) GetActiveProviders() ([][32]byte, error) {
	return _ISuperOracle.Contract.GetActiveProviders(&_ISuperOracle.CallOpts)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_ISuperOracle *ISuperOracleCaller) GetOracleAddress(opts *bind.CallOpts, base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	var out []interface{}
	err := _ISuperOracle.contract.Call(opts, &out, "getOracleAddress", base, quote, provider)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_ISuperOracle *ISuperOracleSession) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _ISuperOracle.Contract.GetOracleAddress(&_ISuperOracle.CallOpts, base, quote, provider)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_ISuperOracle *ISuperOracleCallerSession) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _ISuperOracle.Contract.GetOracleAddress(&_ISuperOracle.CallOpts, base, quote, provider)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_ISuperOracle *ISuperOracleCaller) GetQuoteFromProvider(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	var out []interface{}
	err := _ISuperOracle.contract.Call(opts, &out, "getQuoteFromProvider", baseAmount, base, quote, oracleProvider)

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
func (_ISuperOracle *ISuperOracleSession) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _ISuperOracle.Contract.GetQuoteFromProvider(&_ISuperOracle.CallOpts, baseAmount, base, quote, oracleProvider)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_ISuperOracle *ISuperOracleCallerSession) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _ISuperOracle.Contract.GetQuoteFromProvider(&_ISuperOracle.CallOpts, baseAmount, base, quote, oracleProvider)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_ISuperOracle *ISuperOracleTransactor) ExecuteOracleUpdate(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperOracle.contract.Transact(opts, "executeOracleUpdate")
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_ISuperOracle *ISuperOracleSession) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _ISuperOracle.Contract.ExecuteOracleUpdate(&_ISuperOracle.TransactOpts)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_ISuperOracle *ISuperOracleTransactorSession) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _ISuperOracle.Contract.ExecuteOracleUpdate(&_ISuperOracle.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_ISuperOracle *ISuperOracleTransactor) ExecuteProviderRemoval(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperOracle.contract.Transact(opts, "executeProviderRemoval")
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_ISuperOracle *ISuperOracleSession) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _ISuperOracle.Contract.ExecuteProviderRemoval(&_ISuperOracle.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_ISuperOracle *ISuperOracleTransactorSession) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _ISuperOracle.Contract.ExecuteProviderRemoval(&_ISuperOracle.TransactOpts)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_ISuperOracle *ISuperOracleTransactor) QueueOracleUpdate(opts *bind.TransactOpts, bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _ISuperOracle.contract.Transact(opts, "queueOracleUpdate", bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_ISuperOracle *ISuperOracleSession) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _ISuperOracle.Contract.QueueOracleUpdate(&_ISuperOracle.TransactOpts, bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_ISuperOracle *ISuperOracleTransactorSession) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _ISuperOracle.Contract.QueueOracleUpdate(&_ISuperOracle.TransactOpts, bases, quotes, providers, feeds)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_ISuperOracle *ISuperOracleTransactor) QueueProviderRemoval(opts *bind.TransactOpts, providers [][32]byte) (*types.Transaction, error) {
	return _ISuperOracle.contract.Transact(opts, "queueProviderRemoval", providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_ISuperOracle *ISuperOracleSession) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _ISuperOracle.Contract.QueueProviderRemoval(&_ISuperOracle.TransactOpts, providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_ISuperOracle *ISuperOracleTransactorSession) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _ISuperOracle.Contract.QueueProviderRemoval(&_ISuperOracle.TransactOpts, providers)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_ISuperOracle *ISuperOracleTransactor) SetFeedMaxStaleness(opts *bind.TransactOpts, feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _ISuperOracle.contract.Transact(opts, "setFeedMaxStaleness", feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_ISuperOracle *ISuperOracleSession) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _ISuperOracle.Contract.SetFeedMaxStaleness(&_ISuperOracle.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_ISuperOracle *ISuperOracleTransactorSession) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _ISuperOracle.Contract.SetFeedMaxStaleness(&_ISuperOracle.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_ISuperOracle *ISuperOracleTransactor) SetFeedMaxStalenessBatch(opts *bind.TransactOpts, feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _ISuperOracle.contract.Transact(opts, "setFeedMaxStalenessBatch", feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_ISuperOracle *ISuperOracleSession) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _ISuperOracle.Contract.SetFeedMaxStalenessBatch(&_ISuperOracle.TransactOpts, feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_ISuperOracle *ISuperOracleTransactorSession) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _ISuperOracle.Contract.SetFeedMaxStalenessBatch(&_ISuperOracle.TransactOpts, feeds, newMaxStalenessList)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_ISuperOracle *ISuperOracleTransactor) SetMaxStaleness(opts *bind.TransactOpts, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _ISuperOracle.contract.Transact(opts, "setMaxStaleness", newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_ISuperOracle *ISuperOracleSession) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _ISuperOracle.Contract.SetMaxStaleness(&_ISuperOracle.TransactOpts, newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_ISuperOracle *ISuperOracleTransactorSession) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _ISuperOracle.Contract.SetMaxStaleness(&_ISuperOracle.TransactOpts, newMaxStaleness)
}

// ISuperOracleFeedMaxStalenessUpdatedIterator is returned from FilterFeedMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for FeedMaxStalenessUpdated events raised by the ISuperOracle contract.
type ISuperOracleFeedMaxStalenessUpdatedIterator struct {
	Event *ISuperOracleFeedMaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *ISuperOracleFeedMaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ISuperOracleFeedMaxStalenessUpdated)
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
		it.Event = new(ISuperOracleFeedMaxStalenessUpdated)
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
func (it *ISuperOracleFeedMaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ISuperOracleFeedMaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ISuperOracleFeedMaxStalenessUpdated represents a FeedMaxStalenessUpdated event raised by the ISuperOracle contract.
type ISuperOracleFeedMaxStalenessUpdated struct {
	Feed            common.Address
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterFeedMaxStalenessUpdated is a free log retrieval operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_ISuperOracle *ISuperOracleFilterer) FilterFeedMaxStalenessUpdated(opts *bind.FilterOpts) (*ISuperOracleFeedMaxStalenessUpdatedIterator, error) {

	logs, sub, err := _ISuperOracle.contract.FilterLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &ISuperOracleFeedMaxStalenessUpdatedIterator{contract: _ISuperOracle.contract, event: "FeedMaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchFeedMaxStalenessUpdated is a free log subscription operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_ISuperOracle *ISuperOracleFilterer) WatchFeedMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *ISuperOracleFeedMaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _ISuperOracle.contract.WatchLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ISuperOracleFeedMaxStalenessUpdated)
				if err := _ISuperOracle.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
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
func (_ISuperOracle *ISuperOracleFilterer) ParseFeedMaxStalenessUpdated(log types.Log) (*ISuperOracleFeedMaxStalenessUpdated, error) {
	event := new(ISuperOracleFeedMaxStalenessUpdated)
	if err := _ISuperOracle.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ISuperOracleMaxStalenessUpdatedIterator is returned from FilterMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for MaxStalenessUpdated events raised by the ISuperOracle contract.
type ISuperOracleMaxStalenessUpdatedIterator struct {
	Event *ISuperOracleMaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *ISuperOracleMaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ISuperOracleMaxStalenessUpdated)
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
		it.Event = new(ISuperOracleMaxStalenessUpdated)
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
func (it *ISuperOracleMaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ISuperOracleMaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ISuperOracleMaxStalenessUpdated represents a MaxStalenessUpdated event raised by the ISuperOracle contract.
type ISuperOracleMaxStalenessUpdated struct {
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterMaxStalenessUpdated is a free log retrieval operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_ISuperOracle *ISuperOracleFilterer) FilterMaxStalenessUpdated(opts *bind.FilterOpts) (*ISuperOracleMaxStalenessUpdatedIterator, error) {

	logs, sub, err := _ISuperOracle.contract.FilterLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &ISuperOracleMaxStalenessUpdatedIterator{contract: _ISuperOracle.contract, event: "MaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchMaxStalenessUpdated is a free log subscription operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_ISuperOracle *ISuperOracleFilterer) WatchMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *ISuperOracleMaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _ISuperOracle.contract.WatchLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ISuperOracleMaxStalenessUpdated)
				if err := _ISuperOracle.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
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
func (_ISuperOracle *ISuperOracleFilterer) ParseMaxStalenessUpdated(log types.Log) (*ISuperOracleMaxStalenessUpdated, error) {
	event := new(ISuperOracleMaxStalenessUpdated)
	if err := _ISuperOracle.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ISuperOracleOracleUpdateExecutedIterator is returned from FilterOracleUpdateExecuted and is used to iterate over the raw logs and unpacked data for OracleUpdateExecuted events raised by the ISuperOracle contract.
type ISuperOracleOracleUpdateExecutedIterator struct {
	Event *ISuperOracleOracleUpdateExecuted // Event containing the contract specifics and raw log

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
func (it *ISuperOracleOracleUpdateExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ISuperOracleOracleUpdateExecuted)
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
		it.Event = new(ISuperOracleOracleUpdateExecuted)
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
func (it *ISuperOracleOracleUpdateExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ISuperOracleOracleUpdateExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ISuperOracleOracleUpdateExecuted represents a OracleUpdateExecuted event raised by the ISuperOracle contract.
type ISuperOracleOracleUpdateExecuted struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOracleUpdateExecuted is a free log retrieval operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_ISuperOracle *ISuperOracleFilterer) FilterOracleUpdateExecuted(opts *bind.FilterOpts) (*ISuperOracleOracleUpdateExecutedIterator, error) {

	logs, sub, err := _ISuperOracle.contract.FilterLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return &ISuperOracleOracleUpdateExecutedIterator{contract: _ISuperOracle.contract, event: "OracleUpdateExecuted", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateExecuted is a free log subscription operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_ISuperOracle *ISuperOracleFilterer) WatchOracleUpdateExecuted(opts *bind.WatchOpts, sink chan<- *ISuperOracleOracleUpdateExecuted) (event.Subscription, error) {

	logs, sub, err := _ISuperOracle.contract.WatchLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ISuperOracleOracleUpdateExecuted)
				if err := _ISuperOracle.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
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
func (_ISuperOracle *ISuperOracleFilterer) ParseOracleUpdateExecuted(log types.Log) (*ISuperOracleOracleUpdateExecuted, error) {
	event := new(ISuperOracleOracleUpdateExecuted)
	if err := _ISuperOracle.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ISuperOracleOracleUpdateQueuedIterator is returned from FilterOracleUpdateQueued and is used to iterate over the raw logs and unpacked data for OracleUpdateQueued events raised by the ISuperOracle contract.
type ISuperOracleOracleUpdateQueuedIterator struct {
	Event *ISuperOracleOracleUpdateQueued // Event containing the contract specifics and raw log

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
func (it *ISuperOracleOracleUpdateQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ISuperOracleOracleUpdateQueued)
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
		it.Event = new(ISuperOracleOracleUpdateQueued)
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
func (it *ISuperOracleOracleUpdateQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ISuperOracleOracleUpdateQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ISuperOracleOracleUpdateQueued represents a OracleUpdateQueued event raised by the ISuperOracle contract.
type ISuperOracleOracleUpdateQueued struct {
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
func (_ISuperOracle *ISuperOracleFilterer) FilterOracleUpdateQueued(opts *bind.FilterOpts) (*ISuperOracleOracleUpdateQueuedIterator, error) {

	logs, sub, err := _ISuperOracle.contract.FilterLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return &ISuperOracleOracleUpdateQueuedIterator{contract: _ISuperOracle.contract, event: "OracleUpdateQueued", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateQueued is a free log subscription operation binding the contract event 0x47555224c714bb2542163eb1af8f45ad13e8ac6bf56fb032b81425bdcc8521fa.
//
// Solidity: event OracleUpdateQueued(address[] bases, address[] quotes, bytes32[] providers, address[] feeds, uint256 timestamp)
func (_ISuperOracle *ISuperOracleFilterer) WatchOracleUpdateQueued(opts *bind.WatchOpts, sink chan<- *ISuperOracleOracleUpdateQueued) (event.Subscription, error) {

	logs, sub, err := _ISuperOracle.contract.WatchLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ISuperOracleOracleUpdateQueued)
				if err := _ISuperOracle.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
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
func (_ISuperOracle *ISuperOracleFilterer) ParseOracleUpdateQueued(log types.Log) (*ISuperOracleOracleUpdateQueued, error) {
	event := new(ISuperOracleOracleUpdateQueued)
	if err := _ISuperOracle.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ISuperOracleOraclesConfiguredIterator is returned from FilterOraclesConfigured and is used to iterate over the raw logs and unpacked data for OraclesConfigured events raised by the ISuperOracle contract.
type ISuperOracleOraclesConfiguredIterator struct {
	Event *ISuperOracleOraclesConfigured // Event containing the contract specifics and raw log

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
func (it *ISuperOracleOraclesConfiguredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ISuperOracleOraclesConfigured)
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
		it.Event = new(ISuperOracleOraclesConfigured)
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
func (it *ISuperOracleOraclesConfiguredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ISuperOracleOraclesConfiguredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ISuperOracleOraclesConfigured represents a OraclesConfigured event raised by the ISuperOracle contract.
type ISuperOracleOraclesConfigured struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOraclesConfigured is a free log retrieval operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_ISuperOracle *ISuperOracleFilterer) FilterOraclesConfigured(opts *bind.FilterOpts) (*ISuperOracleOraclesConfiguredIterator, error) {

	logs, sub, err := _ISuperOracle.contract.FilterLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return &ISuperOracleOraclesConfiguredIterator{contract: _ISuperOracle.contract, event: "OraclesConfigured", logs: logs, sub: sub}, nil
}

// WatchOraclesConfigured is a free log subscription operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_ISuperOracle *ISuperOracleFilterer) WatchOraclesConfigured(opts *bind.WatchOpts, sink chan<- *ISuperOracleOraclesConfigured) (event.Subscription, error) {

	logs, sub, err := _ISuperOracle.contract.WatchLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ISuperOracleOraclesConfigured)
				if err := _ISuperOracle.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
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
func (_ISuperOracle *ISuperOracleFilterer) ParseOraclesConfigured(log types.Log) (*ISuperOracleOraclesConfigured, error) {
	event := new(ISuperOracleOraclesConfigured)
	if err := _ISuperOracle.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ISuperOracleProviderRemovalExecutedIterator is returned from FilterProviderRemovalExecuted and is used to iterate over the raw logs and unpacked data for ProviderRemovalExecuted events raised by the ISuperOracle contract.
type ISuperOracleProviderRemovalExecutedIterator struct {
	Event *ISuperOracleProviderRemovalExecuted // Event containing the contract specifics and raw log

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
func (it *ISuperOracleProviderRemovalExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ISuperOracleProviderRemovalExecuted)
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
		it.Event = new(ISuperOracleProviderRemovalExecuted)
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
func (it *ISuperOracleProviderRemovalExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ISuperOracleProviderRemovalExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ISuperOracleProviderRemovalExecuted represents a ProviderRemovalExecuted event raised by the ISuperOracle contract.
type ISuperOracleProviderRemovalExecuted struct {
	Providers [][32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalExecuted is a free log retrieval operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_ISuperOracle *ISuperOracleFilterer) FilterProviderRemovalExecuted(opts *bind.FilterOpts) (*ISuperOracleProviderRemovalExecutedIterator, error) {

	logs, sub, err := _ISuperOracle.contract.FilterLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return &ISuperOracleProviderRemovalExecutedIterator{contract: _ISuperOracle.contract, event: "ProviderRemovalExecuted", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalExecuted is a free log subscription operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_ISuperOracle *ISuperOracleFilterer) WatchProviderRemovalExecuted(opts *bind.WatchOpts, sink chan<- *ISuperOracleProviderRemovalExecuted) (event.Subscription, error) {

	logs, sub, err := _ISuperOracle.contract.WatchLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ISuperOracleProviderRemovalExecuted)
				if err := _ISuperOracle.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
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
func (_ISuperOracle *ISuperOracleFilterer) ParseProviderRemovalExecuted(log types.Log) (*ISuperOracleProviderRemovalExecuted, error) {
	event := new(ISuperOracleProviderRemovalExecuted)
	if err := _ISuperOracle.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ISuperOracleProviderRemovalQueuedIterator is returned from FilterProviderRemovalQueued and is used to iterate over the raw logs and unpacked data for ProviderRemovalQueued events raised by the ISuperOracle contract.
type ISuperOracleProviderRemovalQueuedIterator struct {
	Event *ISuperOracleProviderRemovalQueued // Event containing the contract specifics and raw log

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
func (it *ISuperOracleProviderRemovalQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ISuperOracleProviderRemovalQueued)
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
		it.Event = new(ISuperOracleProviderRemovalQueued)
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
func (it *ISuperOracleProviderRemovalQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ISuperOracleProviderRemovalQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ISuperOracleProviderRemovalQueued represents a ProviderRemovalQueued event raised by the ISuperOracle contract.
type ISuperOracleProviderRemovalQueued struct {
	Providers [][32]byte
	Timestamp *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalQueued is a free log retrieval operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_ISuperOracle *ISuperOracleFilterer) FilterProviderRemovalQueued(opts *bind.FilterOpts) (*ISuperOracleProviderRemovalQueuedIterator, error) {

	logs, sub, err := _ISuperOracle.contract.FilterLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return &ISuperOracleProviderRemovalQueuedIterator{contract: _ISuperOracle.contract, event: "ProviderRemovalQueued", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalQueued is a free log subscription operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_ISuperOracle *ISuperOracleFilterer) WatchProviderRemovalQueued(opts *bind.WatchOpts, sink chan<- *ISuperOracleProviderRemovalQueued) (event.Subscription, error) {

	logs, sub, err := _ISuperOracle.contract.WatchLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ISuperOracleProviderRemovalQueued)
				if err := _ISuperOracle.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
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
func (_ISuperOracle *ISuperOracleFilterer) ParseProviderRemovalQueued(log types.Log) (*ISuperOracleProviderRemovalQueued, error) {
	event := new(ISuperOracleProviderRemovalQueued)
	if err := _ISuperOracle.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
