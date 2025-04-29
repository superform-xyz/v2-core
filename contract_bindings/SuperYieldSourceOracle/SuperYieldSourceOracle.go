// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperYieldSourceOracle

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

// SuperYieldSourceOracleMetaData contains all meta data concerning the SuperYieldSourceOracle contract.
var SuperYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superOracle_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultipleQuote\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"baseAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quoteAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShareQuote\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareQuote\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pricePerShareQuote\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultipleQuote\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"},{\"name\":\"baseAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quoteAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"userTvlsQuote\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"},{\"name\":\"totalTvlsQuote\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesQuote\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvlQuote\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultipleQuote\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"baseAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quoteAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvlsQuote\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLQuote\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvlQuote\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superOracle\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIOracle\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// SuperYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperYieldSourceOracleMetaData.ABI instead.
var SuperYieldSourceOracleABI = SuperYieldSourceOracleMetaData.ABI

// SuperYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type SuperYieldSourceOracle struct {
	SuperYieldSourceOracleCaller     // Read-only binding to the contract
	SuperYieldSourceOracleTransactor // Write-only binding to the contract
	SuperYieldSourceOracleFilterer   // Log filterer for contract events
}

// SuperYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperYieldSourceOracleSession struct {
	Contract     *SuperYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts           // Call options to use throughout this session
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// SuperYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperYieldSourceOracleCallerSession struct {
	Contract *SuperYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                 // Call options to use throughout this session
}

// SuperYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperYieldSourceOracleTransactorSession struct {
	Contract     *SuperYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                 // Transaction auth options to use throughout this session
}

// SuperYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperYieldSourceOracleRaw struct {
	Contract *SuperYieldSourceOracle // Generic contract binding to access the raw methods on
}

// SuperYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperYieldSourceOracleCallerRaw struct {
	Contract *SuperYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// SuperYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperYieldSourceOracleTransactorRaw struct {
	Contract *SuperYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperYieldSourceOracle creates a new instance of SuperYieldSourceOracle, bound to a specific deployed contract.
func NewSuperYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*SuperYieldSourceOracle, error) {
	contract, err := bindSuperYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperYieldSourceOracle{SuperYieldSourceOracleCaller: SuperYieldSourceOracleCaller{contract: contract}, SuperYieldSourceOracleTransactor: SuperYieldSourceOracleTransactor{contract: contract}, SuperYieldSourceOracleFilterer: SuperYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewSuperYieldSourceOracleCaller creates a new read-only instance of SuperYieldSourceOracle, bound to a specific deployed contract.
func NewSuperYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*SuperYieldSourceOracleCaller, error) {
	contract, err := bindSuperYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperYieldSourceOracleCaller{contract: contract}, nil
}

// NewSuperYieldSourceOracleTransactor creates a new write-only instance of SuperYieldSourceOracle, bound to a specific deployed contract.
func NewSuperYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperYieldSourceOracleTransactor, error) {
	contract, err := bindSuperYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperYieldSourceOracleTransactor{contract: contract}, nil
}

// NewSuperYieldSourceOracleFilterer creates a new log filterer instance of SuperYieldSourceOracle, bound to a specific deployed contract.
func NewSuperYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperYieldSourceOracleFilterer, error) {
	contract, err := bindSuperYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperYieldSourceOracleFilterer{contract: contract}, nil
}

// bindSuperYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindSuperYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperYieldSourceOracle *SuperYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperYieldSourceOracle.Contract.SuperYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperYieldSourceOracle *SuperYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperYieldSourceOracle.Contract.SuperYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperYieldSourceOracle *SuperYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperYieldSourceOracle.Contract.SuperYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperYieldSourceOracle *SuperYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperYieldSourceOracle *SuperYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// GetPricePerShareMultipleQuote is a free data retrieval call binding the contract method 0x379a09cb.
//
// Solidity: function getPricePerShareMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[] pricesPerShareQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCaller) GetPricePerShareMultipleQuote(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SuperYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultipleQuote", yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultipleQuote is a free data retrieval call binding the contract method 0x379a09cb.
//
// Solidity: function getPricePerShareMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[] pricesPerShareQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleSession) GetPricePerShareMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) ([]*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetPricePerShareMultipleQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses)
}

// GetPricePerShareMultipleQuote is a free data retrieval call binding the contract method 0x379a09cb.
//
// Solidity: function getPricePerShareMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[] pricesPerShareQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerSession) GetPricePerShareMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) ([]*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetPricePerShareMultipleQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses)
}

// GetPricePerShareQuote is a free data retrieval call binding the contract method 0x8bc857d4.
//
// Solidity: function getPricePerShareQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote) view returns(uint256 pricePerShareQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCaller) GetPricePerShareQuote(opts *bind.CallOpts, yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareQuote", yieldSourceAddress, yieldSourceOracle, base, quote)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShareQuote is a free data retrieval call binding the contract method 0x8bc857d4.
//
// Solidity: function getPricePerShareQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote) view returns(uint256 pricePerShareQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleSession) GetPricePerShareQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetPricePerShareQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote)
}

// GetPricePerShareQuote is a free data retrieval call binding the contract method 0x8bc857d4.
//
// Solidity: function getPricePerShareQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote) view returns(uint256 pricePerShareQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerSession) GetPricePerShareQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetPricePerShareQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote)
}

// GetTVLByOwnerOfSharesMultipleQuote is a free data retrieval call binding the contract method 0xa0c90db0.
//
// Solidity: function getTVLByOwnerOfSharesMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[][] ownersOfShares, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[][] userTvlsQuote, uint256[] totalTvlsQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultipleQuote(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares [][]common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) (struct {
	UserTvlsQuote  [][]*big.Int
	TotalTvlsQuote []*big.Int
}, error) {
	var out []interface{}
	err := _SuperYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultipleQuote", yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAddresses, quoteAddresses)

	outstruct := new(struct {
		UserTvlsQuote  [][]*big.Int
		TotalTvlsQuote []*big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.UserTvlsQuote = *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)
	outstruct.TotalTvlsQuote = *abi.ConvertType(out[1], new([]*big.Int)).(*[]*big.Int)

	return *outstruct, err

}

// GetTVLByOwnerOfSharesMultipleQuote is a free data retrieval call binding the contract method 0xa0c90db0.
//
// Solidity: function getTVLByOwnerOfSharesMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[][] ownersOfShares, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[][] userTvlsQuote, uint256[] totalTvlsQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleSession) GetTVLByOwnerOfSharesMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares [][]common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) (struct {
	UserTvlsQuote  [][]*big.Int
	TotalTvlsQuote []*big.Int
}, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultipleQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAddresses, quoteAddresses)
}

// GetTVLByOwnerOfSharesMultipleQuote is a free data retrieval call binding the contract method 0xa0c90db0.
//
// Solidity: function getTVLByOwnerOfSharesMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[][] ownersOfShares, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[][] userTvlsQuote, uint256[] totalTvlsQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares [][]common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) (struct {
	UserTvlsQuote  [][]*big.Int
	TotalTvlsQuote []*big.Int
}, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultipleQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAddresses, quoteAddresses)
}

// GetTVLByOwnerOfSharesQuote is a free data retrieval call binding the contract method 0xd98417d6.
//
// Solidity: function getTVLByOwnerOfSharesQuote(address yieldSourceAddress, address yieldSourceOracle, address ownerOfShares, address base, address quote) view returns(uint256 tvlQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCaller) GetTVLByOwnerOfSharesQuote(opts *bind.CallOpts, yieldSourceAddress common.Address, yieldSourceOracle common.Address, ownerOfShares common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesQuote", yieldSourceAddress, yieldSourceOracle, ownerOfShares, base, quote)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesQuote is a free data retrieval call binding the contract method 0xd98417d6.
//
// Solidity: function getTVLByOwnerOfSharesQuote(address yieldSourceAddress, address yieldSourceOracle, address ownerOfShares, address base, address quote) view returns(uint256 tvlQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleSession) GetTVLByOwnerOfSharesQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, ownerOfShares common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, ownerOfShares, base, quote)
}

// GetTVLByOwnerOfSharesQuote is a free data retrieval call binding the contract method 0xd98417d6.
//
// Solidity: function getTVLByOwnerOfSharesQuote(address yieldSourceAddress, address yieldSourceOracle, address ownerOfShares, address base, address quote) view returns(uint256 tvlQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, ownerOfShares common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, ownerOfShares, base, quote)
}

// GetTVLMultipleQuote is a free data retrieval call binding the contract method 0x57ae0545.
//
// Solidity: function getTVLMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[] tvlsQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCaller) GetTVLMultipleQuote(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SuperYieldSourceOracle.contract.Call(opts, &out, "getTVLMultipleQuote", yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultipleQuote is a free data retrieval call binding the contract method 0x57ae0545.
//
// Solidity: function getTVLMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[] tvlsQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleSession) GetTVLMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) ([]*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLMultipleQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses)
}

// GetTVLMultipleQuote is a free data retrieval call binding the contract method 0x57ae0545.
//
// Solidity: function getTVLMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses) view returns(uint256[] tvlsQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerSession) GetTVLMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address) ([]*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLMultipleQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses)
}

// GetTVLQuote is a free data retrieval call binding the contract method 0xfe1c4994.
//
// Solidity: function getTVLQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote) view returns(uint256 tvlQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCaller) GetTVLQuote(opts *bind.CallOpts, yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperYieldSourceOracle.contract.Call(opts, &out, "getTVLQuote", yieldSourceAddress, yieldSourceOracle, base, quote)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLQuote is a free data retrieval call binding the contract method 0xfe1c4994.
//
// Solidity: function getTVLQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote) view returns(uint256 tvlQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleSession) GetTVLQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote)
}

// GetTVLQuote is a free data retrieval call binding the contract method 0xfe1c4994.
//
// Solidity: function getTVLQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote) view returns(uint256 tvlQuote)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerSession) GetTVLQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address) (*big.Int, error) {
	return _SuperYieldSourceOracle.Contract.GetTVLQuote(&_SuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote)
}

// SuperOracle is a free data retrieval call binding the contract method 0x3fbfddce.
//
// Solidity: function superOracle() view returns(address)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCaller) SuperOracle(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperYieldSourceOracle.contract.Call(opts, &out, "superOracle")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperOracle is a free data retrieval call binding the contract method 0x3fbfddce.
//
// Solidity: function superOracle() view returns(address)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleSession) SuperOracle() (common.Address, error) {
	return _SuperYieldSourceOracle.Contract.SuperOracle(&_SuperYieldSourceOracle.CallOpts)
}

// SuperOracle is a free data retrieval call binding the contract method 0x3fbfddce.
//
// Solidity: function superOracle() view returns(address)
func (_SuperYieldSourceOracle *SuperYieldSourceOracleCallerSession) SuperOracle() (common.Address, error) {
	return _SuperYieldSourceOracle.Contract.SuperOracle(&_SuperYieldSourceOracle.CallOpts)
}
