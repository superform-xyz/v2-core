// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperOracleL2

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

// SuperOracleL2MetaData contains all meta data concerning the SuperOracleL2 contract.
var SuperOracleL2MetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"owner_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"bases\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"activeProviders\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"executeOracleUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeProviderRemoval\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"feedMaxStaleness\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"maxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getActiveProviders\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOracleAddress\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getQuote\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getQuoteFromProvider\",\"inputs\":[{\"name\":\"baseAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracleProvider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"quoteAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"deviation\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"totalProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"availableProviders\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"gracePeriods\",\"inputs\":[{\"name\":\"uptimeOracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"gracePeriod\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isProviderSet\",\"inputs\":[{\"name\":\"provider\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"isSet\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"maxDefaultStaleness\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingRemoval\",\"inputs\":[],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingUpdate\",\"inputs\":[],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"queueOracleUpdate\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"queueProviderRemoval\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStaleness\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setFeedMaxStalenessBatch\",\"inputs\":[{\"name\":\"feeds\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"newMaxStalenessList\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setMaxStaleness\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setUptimeFeed\",\"inputs\":[{\"name\":\"dataOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"uptimeOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"gracePeriod\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"uptimeFeeds\",\"inputs\":[{\"name\":\"dataOracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"uptimeOracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"FeedMaxStalenessUpdated\",\"inputs\":[{\"name\":\"feed\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"GracePeriodSet\",\"inputs\":[{\"name\":\"uptimeOracle\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"gracePeriod\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MaxStalenessUpdated\",\"inputs\":[{\"name\":\"newMaxStaleness\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateExecuted\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OracleUpdateQueued\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OraclesConfigured\",\"inputs\":[{\"name\":\"bases\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"quotes\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"feeds\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalExecuted\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProviderRemovalQueued\",\"inputs\":[{\"name\":\"providers\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UptimeFeedSet\",\"inputs\":[{\"name\":\"dataOracle\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"uptimeOracle\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AVERAGE_PROVIDER_NOT_ALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"GRACE_PERIOD_NOT_OVER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ORACLE_PROVIDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MAX_STALENESS_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_ADMIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_ORACLES_CONFIGURED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_UPDATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_UPTIME_FEED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_VALID_REPORTED_PRICES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ORACLE_UNTRUSTED_DATA\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OracleUnsupportedPair\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OracleUntrustedData\",\"inputs\":[{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableInvalidOwner\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"PENDING_UPDATE_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SEQUENCER_DOWN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TIMELOCK_NOT_ELAPSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_QUOTE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_PROVIDER\",\"inputs\":[]}]",
}

// SuperOracleL2ABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperOracleL2MetaData.ABI instead.
var SuperOracleL2ABI = SuperOracleL2MetaData.ABI

// SuperOracleL2 is an auto generated Go binding around an Ethereum contract.
type SuperOracleL2 struct {
	SuperOracleL2Caller     // Read-only binding to the contract
	SuperOracleL2Transactor // Write-only binding to the contract
	SuperOracleL2Filterer   // Log filterer for contract events
}

// SuperOracleL2Caller is an auto generated read-only Go binding around an Ethereum contract.
type SuperOracleL2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleL2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperOracleL2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleL2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperOracleL2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperOracleL2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperOracleL2Session struct {
	Contract     *SuperOracleL2    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperOracleL2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperOracleL2CallerSession struct {
	Contract *SuperOracleL2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// SuperOracleL2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperOracleL2TransactorSession struct {
	Contract     *SuperOracleL2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SuperOracleL2Raw is an auto generated low-level Go binding around an Ethereum contract.
type SuperOracleL2Raw struct {
	Contract *SuperOracleL2 // Generic contract binding to access the raw methods on
}

// SuperOracleL2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperOracleL2CallerRaw struct {
	Contract *SuperOracleL2Caller // Generic read-only contract binding to access the raw methods on
}

// SuperOracleL2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperOracleL2TransactorRaw struct {
	Contract *SuperOracleL2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperOracleL2 creates a new instance of SuperOracleL2, bound to a specific deployed contract.
func NewSuperOracleL2(address common.Address, backend bind.ContractBackend) (*SuperOracleL2, error) {
	contract, err := bindSuperOracleL2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2{SuperOracleL2Caller: SuperOracleL2Caller{contract: contract}, SuperOracleL2Transactor: SuperOracleL2Transactor{contract: contract}, SuperOracleL2Filterer: SuperOracleL2Filterer{contract: contract}}, nil
}

// NewSuperOracleL2Caller creates a new read-only instance of SuperOracleL2, bound to a specific deployed contract.
func NewSuperOracleL2Caller(address common.Address, caller bind.ContractCaller) (*SuperOracleL2Caller, error) {
	contract, err := bindSuperOracleL2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2Caller{contract: contract}, nil
}

// NewSuperOracleL2Transactor creates a new write-only instance of SuperOracleL2, bound to a specific deployed contract.
func NewSuperOracleL2Transactor(address common.Address, transactor bind.ContractTransactor) (*SuperOracleL2Transactor, error) {
	contract, err := bindSuperOracleL2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2Transactor{contract: contract}, nil
}

// NewSuperOracleL2Filterer creates a new log filterer instance of SuperOracleL2, bound to a specific deployed contract.
func NewSuperOracleL2Filterer(address common.Address, filterer bind.ContractFilterer) (*SuperOracleL2Filterer, error) {
	contract, err := bindSuperOracleL2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2Filterer{contract: contract}, nil
}

// bindSuperOracleL2 binds a generic wrapper to an already deployed contract.
func bindSuperOracleL2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperOracleL2MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperOracleL2 *SuperOracleL2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperOracleL2.Contract.SuperOracleL2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperOracleL2 *SuperOracleL2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SuperOracleL2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperOracleL2 *SuperOracleL2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SuperOracleL2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperOracleL2 *SuperOracleL2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperOracleL2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperOracleL2 *SuperOracleL2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperOracleL2 *SuperOracleL2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.contract.Transact(opts, method, params...)
}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracleL2 *SuperOracleL2Caller) ActiveProviders(opts *bind.CallOpts, arg0 *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "activeProviders", arg0)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracleL2 *SuperOracleL2Session) ActiveProviders(arg0 *big.Int) ([32]byte, error) {
	return _SuperOracleL2.Contract.ActiveProviders(&_SuperOracleL2.CallOpts, arg0)
}

// ActiveProviders is a free data retrieval call binding the contract method 0x5da471d1.
//
// Solidity: function activeProviders(uint256 ) view returns(bytes32)
func (_SuperOracleL2 *SuperOracleL2CallerSession) ActiveProviders(arg0 *big.Int) ([32]byte, error) {
	return _SuperOracleL2.Contract.ActiveProviders(&_SuperOracleL2.CallOpts, arg0)
}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracleL2 *SuperOracleL2Caller) FeedMaxStaleness(opts *bind.CallOpts, feed common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "feedMaxStaleness", feed)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracleL2 *SuperOracleL2Session) FeedMaxStaleness(feed common.Address) (*big.Int, error) {
	return _SuperOracleL2.Contract.FeedMaxStaleness(&_SuperOracleL2.CallOpts, feed)
}

// FeedMaxStaleness is a free data retrieval call binding the contract method 0x9aa560d8.
//
// Solidity: function feedMaxStaleness(address feed) view returns(uint256 maxStaleness)
func (_SuperOracleL2 *SuperOracleL2CallerSession) FeedMaxStaleness(feed common.Address) (*big.Int, error) {
	return _SuperOracleL2.Contract.FeedMaxStaleness(&_SuperOracleL2.CallOpts, feed)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracleL2 *SuperOracleL2Caller) GetActiveProviders(opts *bind.CallOpts) ([][32]byte, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "getActiveProviders")

	if err != nil {
		return *new([][32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([][32]byte)).(*[][32]byte)

	return out0, err

}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracleL2 *SuperOracleL2Session) GetActiveProviders() ([][32]byte, error) {
	return _SuperOracleL2.Contract.GetActiveProviders(&_SuperOracleL2.CallOpts)
}

// GetActiveProviders is a free data retrieval call binding the contract method 0xfb0e9ec1.
//
// Solidity: function getActiveProviders() view returns(bytes32[])
func (_SuperOracleL2 *SuperOracleL2CallerSession) GetActiveProviders() ([][32]byte, error) {
	return _SuperOracleL2.Contract.GetActiveProviders(&_SuperOracleL2.CallOpts)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracleL2 *SuperOracleL2Caller) GetOracleAddress(opts *bind.CallOpts, base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "getOracleAddress", base, quote, provider)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracleL2 *SuperOracleL2Session) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _SuperOracleL2.Contract.GetOracleAddress(&_SuperOracleL2.CallOpts, base, quote, provider)
}

// GetOracleAddress is a free data retrieval call binding the contract method 0x5008a70d.
//
// Solidity: function getOracleAddress(address base, address quote, bytes32 provider) view returns(address oracle)
func (_SuperOracleL2 *SuperOracleL2CallerSession) GetOracleAddress(base common.Address, quote common.Address, provider [32]byte) (common.Address, error) {
	return _SuperOracleL2.Contract.GetOracleAddress(&_SuperOracleL2.CallOpts, base, quote, provider)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracleL2 *SuperOracleL2Caller) GetQuote(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "getQuote", baseAmount, base, quote)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracleL2 *SuperOracleL2Session) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperOracleL2.Contract.GetQuote(&_SuperOracleL2.CallOpts, baseAmount, base, quote)
}

// GetQuote is a free data retrieval call binding the contract method 0xae68676c.
//
// Solidity: function getQuote(uint256 baseAmount, address base, address quote) view returns(uint256 quoteAmount)
func (_SuperOracleL2 *SuperOracleL2CallerSession) GetQuote(baseAmount *big.Int, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperOracleL2.Contract.GetQuote(&_SuperOracleL2.CallOpts, baseAmount, base, quote)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_SuperOracleL2 *SuperOracleL2Caller) GetQuoteFromProvider(opts *bind.CallOpts, baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "getQuoteFromProvider", baseAmount, base, quote, oracleProvider)

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
func (_SuperOracleL2 *SuperOracleL2Session) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _SuperOracleL2.Contract.GetQuoteFromProvider(&_SuperOracleL2.CallOpts, baseAmount, base, quote, oracleProvider)
}

// GetQuoteFromProvider is a free data retrieval call binding the contract method 0xeacc8037.
//
// Solidity: function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider) view returns(uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
func (_SuperOracleL2 *SuperOracleL2CallerSession) GetQuoteFromProvider(baseAmount *big.Int, base common.Address, quote common.Address, oracleProvider [32]byte) (struct {
	QuoteAmount        *big.Int
	Deviation          *big.Int
	TotalProviders     *big.Int
	AvailableProviders *big.Int
}, error) {
	return _SuperOracleL2.Contract.GetQuoteFromProvider(&_SuperOracleL2.CallOpts, baseAmount, base, quote, oracleProvider)
}

// GracePeriods is a free data retrieval call binding the contract method 0x17ced45d.
//
// Solidity: function gracePeriods(address uptimeOracle) view returns(uint256 gracePeriod)
func (_SuperOracleL2 *SuperOracleL2Caller) GracePeriods(opts *bind.CallOpts, uptimeOracle common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "gracePeriods", uptimeOracle)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GracePeriods is a free data retrieval call binding the contract method 0x17ced45d.
//
// Solidity: function gracePeriods(address uptimeOracle) view returns(uint256 gracePeriod)
func (_SuperOracleL2 *SuperOracleL2Session) GracePeriods(uptimeOracle common.Address) (*big.Int, error) {
	return _SuperOracleL2.Contract.GracePeriods(&_SuperOracleL2.CallOpts, uptimeOracle)
}

// GracePeriods is a free data retrieval call binding the contract method 0x17ced45d.
//
// Solidity: function gracePeriods(address uptimeOracle) view returns(uint256 gracePeriod)
func (_SuperOracleL2 *SuperOracleL2CallerSession) GracePeriods(uptimeOracle common.Address) (*big.Int, error) {
	return _SuperOracleL2.Contract.GracePeriods(&_SuperOracleL2.CallOpts, uptimeOracle)
}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracleL2 *SuperOracleL2Caller) IsProviderSet(opts *bind.CallOpts, provider [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "isProviderSet", provider)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracleL2 *SuperOracleL2Session) IsProviderSet(provider [32]byte) (bool, error) {
	return _SuperOracleL2.Contract.IsProviderSet(&_SuperOracleL2.CallOpts, provider)
}

// IsProviderSet is a free data retrieval call binding the contract method 0x0fb993be.
//
// Solidity: function isProviderSet(bytes32 provider) view returns(bool isSet)
func (_SuperOracleL2 *SuperOracleL2CallerSession) IsProviderSet(provider [32]byte) (bool, error) {
	return _SuperOracleL2.Contract.IsProviderSet(&_SuperOracleL2.CallOpts, provider)
}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracleL2 *SuperOracleL2Caller) MaxDefaultStaleness(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "maxDefaultStaleness")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracleL2 *SuperOracleL2Session) MaxDefaultStaleness() (*big.Int, error) {
	return _SuperOracleL2.Contract.MaxDefaultStaleness(&_SuperOracleL2.CallOpts)
}

// MaxDefaultStaleness is a free data retrieval call binding the contract method 0x6e6d2a3a.
//
// Solidity: function maxDefaultStaleness() view returns(uint256)
func (_SuperOracleL2 *SuperOracleL2CallerSession) MaxDefaultStaleness() (*big.Int, error) {
	return _SuperOracleL2.Contract.MaxDefaultStaleness(&_SuperOracleL2.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperOracleL2 *SuperOracleL2Caller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperOracleL2 *SuperOracleL2Session) Owner() (common.Address, error) {
	return _SuperOracleL2.Contract.Owner(&_SuperOracleL2.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperOracleL2 *SuperOracleL2CallerSession) Owner() (common.Address, error) {
	return _SuperOracleL2.Contract.Owner(&_SuperOracleL2.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperOracleL2 *SuperOracleL2Caller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperOracleL2 *SuperOracleL2Session) PendingOwner() (common.Address, error) {
	return _SuperOracleL2.Contract.PendingOwner(&_SuperOracleL2.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperOracleL2 *SuperOracleL2CallerSession) PendingOwner() (common.Address, error) {
	return _SuperOracleL2.Contract.PendingOwner(&_SuperOracleL2.CallOpts)
}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2Caller) PendingRemoval(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "pendingRemoval")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2Session) PendingRemoval() (*big.Int, error) {
	return _SuperOracleL2.Contract.PendingRemoval(&_SuperOracleL2.CallOpts)
}

// PendingRemoval is a free data retrieval call binding the contract method 0x2ea72b52.
//
// Solidity: function pendingRemoval() view returns(uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2CallerSession) PendingRemoval() (*big.Int, error) {
	return _SuperOracleL2.Contract.PendingRemoval(&_SuperOracleL2.CallOpts)
}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2Caller) PendingUpdate(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "pendingUpdate")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2Session) PendingUpdate() (*big.Int, error) {
	return _SuperOracleL2.Contract.PendingUpdate(&_SuperOracleL2.CallOpts)
}

// PendingUpdate is a free data retrieval call binding the contract method 0x00a4dcac.
//
// Solidity: function pendingUpdate() view returns(uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2CallerSession) PendingUpdate() (*big.Int, error) {
	return _SuperOracleL2.Contract.PendingUpdate(&_SuperOracleL2.CallOpts)
}

// UptimeFeeds is a free data retrieval call binding the contract method 0xe1fcd219.
//
// Solidity: function uptimeFeeds(address dataOracle) view returns(address uptimeOracle)
func (_SuperOracleL2 *SuperOracleL2Caller) UptimeFeeds(opts *bind.CallOpts, dataOracle common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperOracleL2.contract.Call(opts, &out, "uptimeFeeds", dataOracle)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// UptimeFeeds is a free data retrieval call binding the contract method 0xe1fcd219.
//
// Solidity: function uptimeFeeds(address dataOracle) view returns(address uptimeOracle)
func (_SuperOracleL2 *SuperOracleL2Session) UptimeFeeds(dataOracle common.Address) (common.Address, error) {
	return _SuperOracleL2.Contract.UptimeFeeds(&_SuperOracleL2.CallOpts, dataOracle)
}

// UptimeFeeds is a free data retrieval call binding the contract method 0xe1fcd219.
//
// Solidity: function uptimeFeeds(address dataOracle) view returns(address uptimeOracle)
func (_SuperOracleL2 *SuperOracleL2CallerSession) UptimeFeeds(dataOracle common.Address) (common.Address, error) {
	return _SuperOracleL2.Contract.UptimeFeeds(&_SuperOracleL2.CallOpts, dataOracle)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperOracleL2 *SuperOracleL2Session) AcceptOwnership() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.AcceptOwnership(&_SuperOracleL2.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.AcceptOwnership(&_SuperOracleL2.TransactOpts)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) ExecuteOracleUpdate(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "executeOracleUpdate")
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracleL2 *SuperOracleL2Session) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.ExecuteOracleUpdate(&_SuperOracleL2.TransactOpts)
}

// ExecuteOracleUpdate is a paid mutator transaction binding the contract method 0x45e62881.
//
// Solidity: function executeOracleUpdate() returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) ExecuteOracleUpdate() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.ExecuteOracleUpdate(&_SuperOracleL2.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) ExecuteProviderRemoval(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "executeProviderRemoval")
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracleL2 *SuperOracleL2Session) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.ExecuteProviderRemoval(&_SuperOracleL2.TransactOpts)
}

// ExecuteProviderRemoval is a paid mutator transaction binding the contract method 0x41cad0bf.
//
// Solidity: function executeProviderRemoval() returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) ExecuteProviderRemoval() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.ExecuteProviderRemoval(&_SuperOracleL2.TransactOpts)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) QueueOracleUpdate(opts *bind.TransactOpts, bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "queueOracleUpdate", bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracleL2 *SuperOracleL2Session) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.QueueOracleUpdate(&_SuperOracleL2.TransactOpts, bases, quotes, providers, feeds)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases, address[] quotes, bytes32[] providers, address[] feeds) returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) QueueOracleUpdate(bases []common.Address, quotes []common.Address, providers [][32]byte, feeds []common.Address) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.QueueOracleUpdate(&_SuperOracleL2.TransactOpts, bases, quotes, providers, feeds)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) QueueProviderRemoval(opts *bind.TransactOpts, providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "queueProviderRemoval", providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracleL2 *SuperOracleL2Session) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.QueueProviderRemoval(&_SuperOracleL2.TransactOpts, providers)
}

// QueueProviderRemoval is a paid mutator transaction binding the contract method 0x2e8d764a.
//
// Solidity: function queueProviderRemoval(bytes32[] providers) returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) QueueProviderRemoval(providers [][32]byte) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.QueueProviderRemoval(&_SuperOracleL2.TransactOpts, providers)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperOracleL2 *SuperOracleL2Session) RenounceOwnership() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.RenounceOwnership(&_SuperOracleL2.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SuperOracleL2.Contract.RenounceOwnership(&_SuperOracleL2.TransactOpts)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) SetFeedMaxStaleness(opts *bind.TransactOpts, feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "setFeedMaxStaleness", feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracleL2 *SuperOracleL2Session) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetFeedMaxStaleness(&_SuperOracleL2.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStaleness is a paid mutator transaction binding the contract method 0x65c61e09.
//
// Solidity: function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) SetFeedMaxStaleness(feed common.Address, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetFeedMaxStaleness(&_SuperOracleL2.TransactOpts, feed, newMaxStaleness)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) SetFeedMaxStalenessBatch(opts *bind.TransactOpts, feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "setFeedMaxStalenessBatch", feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracleL2 *SuperOracleL2Session) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetFeedMaxStalenessBatch(&_SuperOracleL2.TransactOpts, feeds, newMaxStalenessList)
}

// SetFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0xf7aad939.
//
// Solidity: function setFeedMaxStalenessBatch(address[] feeds, uint256[] newMaxStalenessList) returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) SetFeedMaxStalenessBatch(feeds []common.Address, newMaxStalenessList []*big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetFeedMaxStalenessBatch(&_SuperOracleL2.TransactOpts, feeds, newMaxStalenessList)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) SetMaxStaleness(opts *bind.TransactOpts, newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "setMaxStaleness", newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracleL2 *SuperOracleL2Session) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetMaxStaleness(&_SuperOracleL2.TransactOpts, newMaxStaleness)
}

// SetMaxStaleness is a paid mutator transaction binding the contract method 0x100bc9e1.
//
// Solidity: function setMaxStaleness(uint256 newMaxStaleness) returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) SetMaxStaleness(newMaxStaleness *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetMaxStaleness(&_SuperOracleL2.TransactOpts, newMaxStaleness)
}

// SetUptimeFeed is a paid mutator transaction binding the contract method 0xae721df9.
//
// Solidity: function setUptimeFeed(address dataOracle, address uptimeOracle, uint256 gracePeriod) returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) SetUptimeFeed(opts *bind.TransactOpts, dataOracle common.Address, uptimeOracle common.Address, gracePeriod *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "setUptimeFeed", dataOracle, uptimeOracle, gracePeriod)
}

// SetUptimeFeed is a paid mutator transaction binding the contract method 0xae721df9.
//
// Solidity: function setUptimeFeed(address dataOracle, address uptimeOracle, uint256 gracePeriod) returns()
func (_SuperOracleL2 *SuperOracleL2Session) SetUptimeFeed(dataOracle common.Address, uptimeOracle common.Address, gracePeriod *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetUptimeFeed(&_SuperOracleL2.TransactOpts, dataOracle, uptimeOracle, gracePeriod)
}

// SetUptimeFeed is a paid mutator transaction binding the contract method 0xae721df9.
//
// Solidity: function setUptimeFeed(address dataOracle, address uptimeOracle, uint256 gracePeriod) returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) SetUptimeFeed(dataOracle common.Address, uptimeOracle common.Address, gracePeriod *big.Int) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.SetUptimeFeed(&_SuperOracleL2.TransactOpts, dataOracle, uptimeOracle, gracePeriod)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperOracleL2 *SuperOracleL2Transactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SuperOracleL2.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperOracleL2 *SuperOracleL2Session) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.TransferOwnership(&_SuperOracleL2.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperOracleL2 *SuperOracleL2TransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperOracleL2.Contract.TransferOwnership(&_SuperOracleL2.TransactOpts, newOwner)
}

// SuperOracleL2FeedMaxStalenessUpdatedIterator is returned from FilterFeedMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for FeedMaxStalenessUpdated events raised by the SuperOracleL2 contract.
type SuperOracleL2FeedMaxStalenessUpdatedIterator struct {
	Event *SuperOracleL2FeedMaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2FeedMaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2FeedMaxStalenessUpdated)
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
		it.Event = new(SuperOracleL2FeedMaxStalenessUpdated)
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
func (it *SuperOracleL2FeedMaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2FeedMaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2FeedMaxStalenessUpdated represents a FeedMaxStalenessUpdated event raised by the SuperOracleL2 contract.
type SuperOracleL2FeedMaxStalenessUpdated struct {
	Feed            common.Address
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterFeedMaxStalenessUpdated is a free log retrieval operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterFeedMaxStalenessUpdated(opts *bind.FilterOpts) (*SuperOracleL2FeedMaxStalenessUpdatedIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2FeedMaxStalenessUpdatedIterator{contract: _SuperOracleL2.contract, event: "FeedMaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchFeedMaxStalenessUpdated is a free log subscription operation binding the contract event 0xc488cc477b0271fd4a6f5e8202b465f869944960cd7f10f1fb3f0547ff0e6ca1.
//
// Solidity: event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchFeedMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleL2FeedMaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "FeedMaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2FeedMaxStalenessUpdated)
				if err := _SuperOracleL2.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseFeedMaxStalenessUpdated(log types.Log) (*SuperOracleL2FeedMaxStalenessUpdated, error) {
	event := new(SuperOracleL2FeedMaxStalenessUpdated)
	if err := _SuperOracleL2.contract.UnpackLog(event, "FeedMaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2GracePeriodSetIterator is returned from FilterGracePeriodSet and is used to iterate over the raw logs and unpacked data for GracePeriodSet events raised by the SuperOracleL2 contract.
type SuperOracleL2GracePeriodSetIterator struct {
	Event *SuperOracleL2GracePeriodSet // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2GracePeriodSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2GracePeriodSet)
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
		it.Event = new(SuperOracleL2GracePeriodSet)
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
func (it *SuperOracleL2GracePeriodSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2GracePeriodSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2GracePeriodSet represents a GracePeriodSet event raised by the SuperOracleL2 contract.
type SuperOracleL2GracePeriodSet struct {
	UptimeOracle common.Address
	GracePeriod  *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterGracePeriodSet is a free log retrieval operation binding the contract event 0x5e49a0f74ce60fb80493b458c23b3d1bf1f01c47dac774d48ed470ab3a615e26.
//
// Solidity: event GracePeriodSet(address uptimeOracle, uint256 gracePeriod)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterGracePeriodSet(opts *bind.FilterOpts) (*SuperOracleL2GracePeriodSetIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "GracePeriodSet")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2GracePeriodSetIterator{contract: _SuperOracleL2.contract, event: "GracePeriodSet", logs: logs, sub: sub}, nil
}

// WatchGracePeriodSet is a free log subscription operation binding the contract event 0x5e49a0f74ce60fb80493b458c23b3d1bf1f01c47dac774d48ed470ab3a615e26.
//
// Solidity: event GracePeriodSet(address uptimeOracle, uint256 gracePeriod)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchGracePeriodSet(opts *bind.WatchOpts, sink chan<- *SuperOracleL2GracePeriodSet) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "GracePeriodSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2GracePeriodSet)
				if err := _SuperOracleL2.contract.UnpackLog(event, "GracePeriodSet", log); err != nil {
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

// ParseGracePeriodSet is a log parse operation binding the contract event 0x5e49a0f74ce60fb80493b458c23b3d1bf1f01c47dac774d48ed470ab3a615e26.
//
// Solidity: event GracePeriodSet(address uptimeOracle, uint256 gracePeriod)
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseGracePeriodSet(log types.Log) (*SuperOracleL2GracePeriodSet, error) {
	event := new(SuperOracleL2GracePeriodSet)
	if err := _SuperOracleL2.contract.UnpackLog(event, "GracePeriodSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2MaxStalenessUpdatedIterator is returned from FilterMaxStalenessUpdated and is used to iterate over the raw logs and unpacked data for MaxStalenessUpdated events raised by the SuperOracleL2 contract.
type SuperOracleL2MaxStalenessUpdatedIterator struct {
	Event *SuperOracleL2MaxStalenessUpdated // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2MaxStalenessUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2MaxStalenessUpdated)
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
		it.Event = new(SuperOracleL2MaxStalenessUpdated)
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
func (it *SuperOracleL2MaxStalenessUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2MaxStalenessUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2MaxStalenessUpdated represents a MaxStalenessUpdated event raised by the SuperOracleL2 contract.
type SuperOracleL2MaxStalenessUpdated struct {
	NewMaxStaleness *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterMaxStalenessUpdated is a free log retrieval operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterMaxStalenessUpdated(opts *bind.FilterOpts) (*SuperOracleL2MaxStalenessUpdatedIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2MaxStalenessUpdatedIterator{contract: _SuperOracleL2.contract, event: "MaxStalenessUpdated", logs: logs, sub: sub}, nil
}

// WatchMaxStalenessUpdated is a free log subscription operation binding the contract event 0x64a4703c7c168827058126cbd2e71d8d0f026afa821e7dff1480173dffdd3895.
//
// Solidity: event MaxStalenessUpdated(uint256 newMaxStaleness)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchMaxStalenessUpdated(opts *bind.WatchOpts, sink chan<- *SuperOracleL2MaxStalenessUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "MaxStalenessUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2MaxStalenessUpdated)
				if err := _SuperOracleL2.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseMaxStalenessUpdated(log types.Log) (*SuperOracleL2MaxStalenessUpdated, error) {
	event := new(SuperOracleL2MaxStalenessUpdated)
	if err := _SuperOracleL2.contract.UnpackLog(event, "MaxStalenessUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2OracleUpdateExecutedIterator is returned from FilterOracleUpdateExecuted and is used to iterate over the raw logs and unpacked data for OracleUpdateExecuted events raised by the SuperOracleL2 contract.
type SuperOracleL2OracleUpdateExecutedIterator struct {
	Event *SuperOracleL2OracleUpdateExecuted // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2OracleUpdateExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2OracleUpdateExecuted)
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
		it.Event = new(SuperOracleL2OracleUpdateExecuted)
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
func (it *SuperOracleL2OracleUpdateExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2OracleUpdateExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2OracleUpdateExecuted represents a OracleUpdateExecuted event raised by the SuperOracleL2 contract.
type SuperOracleL2OracleUpdateExecuted struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOracleUpdateExecuted is a free log retrieval operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterOracleUpdateExecuted(opts *bind.FilterOpts) (*SuperOracleL2OracleUpdateExecutedIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2OracleUpdateExecutedIterator{contract: _SuperOracleL2.contract, event: "OracleUpdateExecuted", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateExecuted is a free log subscription operation binding the contract event 0x7018ca71229e8b48ed03793464df6e3ddcff12361c7b33750590c5406a6ad985.
//
// Solidity: event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchOracleUpdateExecuted(opts *bind.WatchOpts, sink chan<- *SuperOracleL2OracleUpdateExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "OracleUpdateExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2OracleUpdateExecuted)
				if err := _SuperOracleL2.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseOracleUpdateExecuted(log types.Log) (*SuperOracleL2OracleUpdateExecuted, error) {
	event := new(SuperOracleL2OracleUpdateExecuted)
	if err := _SuperOracleL2.contract.UnpackLog(event, "OracleUpdateExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2OracleUpdateQueuedIterator is returned from FilterOracleUpdateQueued and is used to iterate over the raw logs and unpacked data for OracleUpdateQueued events raised by the SuperOracleL2 contract.
type SuperOracleL2OracleUpdateQueuedIterator struct {
	Event *SuperOracleL2OracleUpdateQueued // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2OracleUpdateQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2OracleUpdateQueued)
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
		it.Event = new(SuperOracleL2OracleUpdateQueued)
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
func (it *SuperOracleL2OracleUpdateQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2OracleUpdateQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2OracleUpdateQueued represents a OracleUpdateQueued event raised by the SuperOracleL2 contract.
type SuperOracleL2OracleUpdateQueued struct {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterOracleUpdateQueued(opts *bind.FilterOpts) (*SuperOracleL2OracleUpdateQueuedIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2OracleUpdateQueuedIterator{contract: _SuperOracleL2.contract, event: "OracleUpdateQueued", logs: logs, sub: sub}, nil
}

// WatchOracleUpdateQueued is a free log subscription operation binding the contract event 0x47555224c714bb2542163eb1af8f45ad13e8ac6bf56fb032b81425bdcc8521fa.
//
// Solidity: event OracleUpdateQueued(address[] bases, address[] quotes, bytes32[] providers, address[] feeds, uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchOracleUpdateQueued(opts *bind.WatchOpts, sink chan<- *SuperOracleL2OracleUpdateQueued) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "OracleUpdateQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2OracleUpdateQueued)
				if err := _SuperOracleL2.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseOracleUpdateQueued(log types.Log) (*SuperOracleL2OracleUpdateQueued, error) {
	event := new(SuperOracleL2OracleUpdateQueued)
	if err := _SuperOracleL2.contract.UnpackLog(event, "OracleUpdateQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2OraclesConfiguredIterator is returned from FilterOraclesConfigured and is used to iterate over the raw logs and unpacked data for OraclesConfigured events raised by the SuperOracleL2 contract.
type SuperOracleL2OraclesConfiguredIterator struct {
	Event *SuperOracleL2OraclesConfigured // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2OraclesConfiguredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2OraclesConfigured)
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
		it.Event = new(SuperOracleL2OraclesConfigured)
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
func (it *SuperOracleL2OraclesConfiguredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2OraclesConfiguredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2OraclesConfigured represents a OraclesConfigured event raised by the SuperOracleL2 contract.
type SuperOracleL2OraclesConfigured struct {
	Bases     []common.Address
	Quotes    []common.Address
	Providers [][32]byte
	Feeds     []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterOraclesConfigured is a free log retrieval operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterOraclesConfigured(opts *bind.FilterOpts) (*SuperOracleL2OraclesConfiguredIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2OraclesConfiguredIterator{contract: _SuperOracleL2.contract, event: "OraclesConfigured", logs: logs, sub: sub}, nil
}

// WatchOraclesConfigured is a free log subscription operation binding the contract event 0xed2484453fc307287f25c68d3914fc64fc127811025cf269f315192ddc02f843.
//
// Solidity: event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchOraclesConfigured(opts *bind.WatchOpts, sink chan<- *SuperOracleL2OraclesConfigured) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "OraclesConfigured")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2OraclesConfigured)
				if err := _SuperOracleL2.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseOraclesConfigured(log types.Log) (*SuperOracleL2OraclesConfigured, error) {
	event := new(SuperOracleL2OraclesConfigured)
	if err := _SuperOracleL2.contract.UnpackLog(event, "OraclesConfigured", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2OwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the SuperOracleL2 contract.
type SuperOracleL2OwnershipTransferStartedIterator struct {
	Event *SuperOracleL2OwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2OwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2OwnershipTransferStarted)
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
		it.Event = new(SuperOracleL2OwnershipTransferStarted)
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
func (it *SuperOracleL2OwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2OwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2OwnershipTransferStarted represents a OwnershipTransferStarted event raised by the SuperOracleL2 contract.
type SuperOracleL2OwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SuperOracleL2OwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2OwnershipTransferStartedIterator{contract: _SuperOracleL2.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *SuperOracleL2OwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2OwnershipTransferStarted)
				if err := _SuperOracleL2.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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

// ParseOwnershipTransferStarted is a log parse operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseOwnershipTransferStarted(log types.Log) (*SuperOracleL2OwnershipTransferStarted, error) {
	event := new(SuperOracleL2OwnershipTransferStarted)
	if err := _SuperOracleL2.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2OwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SuperOracleL2 contract.
type SuperOracleL2OwnershipTransferredIterator struct {
	Event *SuperOracleL2OwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2OwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2OwnershipTransferred)
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
		it.Event = new(SuperOracleL2OwnershipTransferred)
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
func (it *SuperOracleL2OwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2OwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2OwnershipTransferred represents a OwnershipTransferred event raised by the SuperOracleL2 contract.
type SuperOracleL2OwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SuperOracleL2OwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2OwnershipTransferredIterator{contract: _SuperOracleL2.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SuperOracleL2OwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2OwnershipTransferred)
				if err := _SuperOracleL2.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseOwnershipTransferred(log types.Log) (*SuperOracleL2OwnershipTransferred, error) {
	event := new(SuperOracleL2OwnershipTransferred)
	if err := _SuperOracleL2.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2ProviderRemovalExecutedIterator is returned from FilterProviderRemovalExecuted and is used to iterate over the raw logs and unpacked data for ProviderRemovalExecuted events raised by the SuperOracleL2 contract.
type SuperOracleL2ProviderRemovalExecutedIterator struct {
	Event *SuperOracleL2ProviderRemovalExecuted // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2ProviderRemovalExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2ProviderRemovalExecuted)
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
		it.Event = new(SuperOracleL2ProviderRemovalExecuted)
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
func (it *SuperOracleL2ProviderRemovalExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2ProviderRemovalExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2ProviderRemovalExecuted represents a ProviderRemovalExecuted event raised by the SuperOracleL2 contract.
type SuperOracleL2ProviderRemovalExecuted struct {
	Providers [][32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalExecuted is a free log retrieval operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterProviderRemovalExecuted(opts *bind.FilterOpts) (*SuperOracleL2ProviderRemovalExecutedIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2ProviderRemovalExecutedIterator{contract: _SuperOracleL2.contract, event: "ProviderRemovalExecuted", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalExecuted is a free log subscription operation binding the contract event 0x1fdb9ae8825c51e20c5c162353ceb1508048b09918c9713c099bafa43a8a6349.
//
// Solidity: event ProviderRemovalExecuted(bytes32[] providers)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchProviderRemovalExecuted(opts *bind.WatchOpts, sink chan<- *SuperOracleL2ProviderRemovalExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "ProviderRemovalExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2ProviderRemovalExecuted)
				if err := _SuperOracleL2.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseProviderRemovalExecuted(log types.Log) (*SuperOracleL2ProviderRemovalExecuted, error) {
	event := new(SuperOracleL2ProviderRemovalExecuted)
	if err := _SuperOracleL2.contract.UnpackLog(event, "ProviderRemovalExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2ProviderRemovalQueuedIterator is returned from FilterProviderRemovalQueued and is used to iterate over the raw logs and unpacked data for ProviderRemovalQueued events raised by the SuperOracleL2 contract.
type SuperOracleL2ProviderRemovalQueuedIterator struct {
	Event *SuperOracleL2ProviderRemovalQueued // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2ProviderRemovalQueuedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2ProviderRemovalQueued)
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
		it.Event = new(SuperOracleL2ProviderRemovalQueued)
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
func (it *SuperOracleL2ProviderRemovalQueuedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2ProviderRemovalQueuedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2ProviderRemovalQueued represents a ProviderRemovalQueued event raised by the SuperOracleL2 contract.
type SuperOracleL2ProviderRemovalQueued struct {
	Providers [][32]byte
	Timestamp *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterProviderRemovalQueued is a free log retrieval operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterProviderRemovalQueued(opts *bind.FilterOpts) (*SuperOracleL2ProviderRemovalQueuedIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2ProviderRemovalQueuedIterator{contract: _SuperOracleL2.contract, event: "ProviderRemovalQueued", logs: logs, sub: sub}, nil
}

// WatchProviderRemovalQueued is a free log subscription operation binding the contract event 0x294673882d73ea0b20d4688c114adc15d18f2ed5254d56cb5d7646e1960b232f.
//
// Solidity: event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchProviderRemovalQueued(opts *bind.WatchOpts, sink chan<- *SuperOracleL2ProviderRemovalQueued) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "ProviderRemovalQueued")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2ProviderRemovalQueued)
				if err := _SuperOracleL2.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
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
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseProviderRemovalQueued(log types.Log) (*SuperOracleL2ProviderRemovalQueued, error) {
	event := new(SuperOracleL2ProviderRemovalQueued)
	if err := _SuperOracleL2.contract.UnpackLog(event, "ProviderRemovalQueued", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperOracleL2UptimeFeedSetIterator is returned from FilterUptimeFeedSet and is used to iterate over the raw logs and unpacked data for UptimeFeedSet events raised by the SuperOracleL2 contract.
type SuperOracleL2UptimeFeedSetIterator struct {
	Event *SuperOracleL2UptimeFeedSet // Event containing the contract specifics and raw log

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
func (it *SuperOracleL2UptimeFeedSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperOracleL2UptimeFeedSet)
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
		it.Event = new(SuperOracleL2UptimeFeedSet)
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
func (it *SuperOracleL2UptimeFeedSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperOracleL2UptimeFeedSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperOracleL2UptimeFeedSet represents a UptimeFeedSet event raised by the SuperOracleL2 contract.
type SuperOracleL2UptimeFeedSet struct {
	DataOracle   common.Address
	UptimeOracle common.Address
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterUptimeFeedSet is a free log retrieval operation binding the contract event 0x0fe0439a9dbea7a284c9a008d922e254a155f584b9ad529825e6dd6d42417551.
//
// Solidity: event UptimeFeedSet(address dataOracle, address uptimeOracle)
func (_SuperOracleL2 *SuperOracleL2Filterer) FilterUptimeFeedSet(opts *bind.FilterOpts) (*SuperOracleL2UptimeFeedSetIterator, error) {

	logs, sub, err := _SuperOracleL2.contract.FilterLogs(opts, "UptimeFeedSet")
	if err != nil {
		return nil, err
	}
	return &SuperOracleL2UptimeFeedSetIterator{contract: _SuperOracleL2.contract, event: "UptimeFeedSet", logs: logs, sub: sub}, nil
}

// WatchUptimeFeedSet is a free log subscription operation binding the contract event 0x0fe0439a9dbea7a284c9a008d922e254a155f584b9ad529825e6dd6d42417551.
//
// Solidity: event UptimeFeedSet(address dataOracle, address uptimeOracle)
func (_SuperOracleL2 *SuperOracleL2Filterer) WatchUptimeFeedSet(opts *bind.WatchOpts, sink chan<- *SuperOracleL2UptimeFeedSet) (event.Subscription, error) {

	logs, sub, err := _SuperOracleL2.contract.WatchLogs(opts, "UptimeFeedSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperOracleL2UptimeFeedSet)
				if err := _SuperOracleL2.contract.UnpackLog(event, "UptimeFeedSet", log); err != nil {
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

// ParseUptimeFeedSet is a log parse operation binding the contract event 0x0fe0439a9dbea7a284c9a008d922e254a155f584b9ad529825e6dd6d42417551.
//
// Solidity: event UptimeFeedSet(address dataOracle, address uptimeOracle)
func (_SuperOracleL2 *SuperOracleL2Filterer) ParseUptimeFeedSet(log types.Log) (*SuperOracleL2UptimeFeedSet, error) {
	event := new(SuperOracleL2UptimeFeedSet)
	if err := _SuperOracleL2.contract.UnpackLog(event, "UptimeFeedSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
