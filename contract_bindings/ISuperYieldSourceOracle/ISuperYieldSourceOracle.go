// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ISuperYieldSourceOracle

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

// ISuperYieldSourceOracleMetaData contains all meta data concerning the ISuperYieldSourceOracle contract.
var ISuperYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"baseAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultipleQuote\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"baseAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quoteAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"oracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShareQuote\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareQuote\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pricePerShareQuote\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"baseAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultipleQuote\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"},{\"name\":\"baseAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quoteAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"oracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"userTvlsQuote\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"},{\"name\":\"totalTvlsQuote\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesQuote\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvlQuote\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"baseAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultipleQuote\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"yieldSourceOracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"baseAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quoteAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"oracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvlsQuote\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLQuote\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"yieldSourceOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"base\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"quote\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvlQuote\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// ISuperYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use ISuperYieldSourceOracleMetaData.ABI instead.
var ISuperYieldSourceOracleABI = ISuperYieldSourceOracleMetaData.ABI

// ISuperYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type ISuperYieldSourceOracle struct {
	ISuperYieldSourceOracleCaller     // Read-only binding to the contract
	ISuperYieldSourceOracleTransactor // Write-only binding to the contract
	ISuperYieldSourceOracleFilterer   // Log filterer for contract events
}

// ISuperYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type ISuperYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ISuperYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ISuperYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ISuperYieldSourceOracleSession struct {
	Contract     *ISuperYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts            // Call options to use throughout this session
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// ISuperYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ISuperYieldSourceOracleCallerSession struct {
	Contract *ISuperYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                  // Call options to use throughout this session
}

// ISuperYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ISuperYieldSourceOracleTransactorSession struct {
	Contract     *ISuperYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                  // Transaction auth options to use throughout this session
}

// ISuperYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type ISuperYieldSourceOracleRaw struct {
	Contract *ISuperYieldSourceOracle // Generic contract binding to access the raw methods on
}

// ISuperYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ISuperYieldSourceOracleCallerRaw struct {
	Contract *ISuperYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// ISuperYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ISuperYieldSourceOracleTransactorRaw struct {
	Contract *ISuperYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewISuperYieldSourceOracle creates a new instance of ISuperYieldSourceOracle, bound to a specific deployed contract.
func NewISuperYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*ISuperYieldSourceOracle, error) {
	contract, err := bindISuperYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ISuperYieldSourceOracle{ISuperYieldSourceOracleCaller: ISuperYieldSourceOracleCaller{contract: contract}, ISuperYieldSourceOracleTransactor: ISuperYieldSourceOracleTransactor{contract: contract}, ISuperYieldSourceOracleFilterer: ISuperYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewISuperYieldSourceOracleCaller creates a new read-only instance of ISuperYieldSourceOracle, bound to a specific deployed contract.
func NewISuperYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*ISuperYieldSourceOracleCaller, error) {
	contract, err := bindISuperYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperYieldSourceOracleCaller{contract: contract}, nil
}

// NewISuperYieldSourceOracleTransactor creates a new write-only instance of ISuperYieldSourceOracle, bound to a specific deployed contract.
func NewISuperYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*ISuperYieldSourceOracleTransactor, error) {
	contract, err := bindISuperYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperYieldSourceOracleTransactor{contract: contract}, nil
}

// NewISuperYieldSourceOracleFilterer creates a new log filterer instance of ISuperYieldSourceOracle, bound to a specific deployed contract.
func NewISuperYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*ISuperYieldSourceOracleFilterer, error) {
	contract, err := bindISuperYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ISuperYieldSourceOracleFilterer{contract: contract}, nil
}

// bindISuperYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindISuperYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ISuperYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperYieldSourceOracle.Contract.ISuperYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperYieldSourceOracle.Contract.ISuperYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperYieldSourceOracle.Contract.ISuperYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xd292d164.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address baseAsset) view returns(uint256[] pricesPerShare)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses, yieldSourceOracles, baseAsset)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xd292d164.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address baseAsset) view returns(uint256[] pricesPerShare)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetPricePerShareMultiple(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAsset)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xd292d164.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address baseAsset) view returns(uint256[] pricesPerShare)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetPricePerShareMultiple(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAsset)
}

// GetPricePerShareMultipleQuote is a free data retrieval call binding the contract method 0xa36cdfb5.
//
// Solidity: function getPricePerShareMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[] pricesPerShareQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetPricePerShareMultipleQuote(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultipleQuote", yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses, oracles)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultipleQuote is a free data retrieval call binding the contract method 0xa36cdfb5.
//
// Solidity: function getPricePerShareMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[] pricesPerShareQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetPricePerShareMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetPricePerShareMultipleQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses, oracles)
}

// GetPricePerShareMultipleQuote is a free data retrieval call binding the contract method 0xa36cdfb5.
//
// Solidity: function getPricePerShareMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[] pricesPerShareQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetPricePerShareMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetPricePerShareMultipleQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses, oracles)
}

// GetPricePerShareQuote is a free data retrieval call binding the contract method 0xcc84c43c.
//
// Solidity: function getPricePerShareQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote, address oracle) view returns(uint256 pricePerShareQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetPricePerShareQuote(opts *bind.CallOpts, yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareQuote", yieldSourceAddress, yieldSourceOracle, base, quote, oracle)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShareQuote is a free data retrieval call binding the contract method 0xcc84c43c.
//
// Solidity: function getPricePerShareQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote, address oracle) view returns(uint256 pricePerShareQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetPricePerShareQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetPricePerShareQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote, oracle)
}

// GetPricePerShareQuote is a free data retrieval call binding the contract method 0xcc84c43c.
//
// Solidity: function getPricePerShareQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote, address oracle) view returns(uint256 pricePerShareQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetPricePerShareQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetPricePerShareQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote, oracle)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0xcb797d16.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] ownersOfShares, address baseAsset) view returns(uint256[] userTvls)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAsset)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0xcb797d16.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] ownersOfShares, address baseAsset) view returns(uint256[] userTvls)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAsset)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0xcb797d16.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] ownersOfShares, address baseAsset) view returns(uint256[] userTvls)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAsset)
}

// GetTVLByOwnerOfSharesMultipleQuote is a free data retrieval call binding the contract method 0x2a3e703b.
//
// Solidity: function getTVLByOwnerOfSharesMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[][] ownersOfShares, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[][] userTvlsQuote, uint256[] totalTvlsQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultipleQuote(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares [][]common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) (struct {
	UserTvlsQuote  [][]*big.Int
	TotalTvlsQuote []*big.Int
}, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultipleQuote", yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAddresses, quoteAddresses, oracles)

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

// GetTVLByOwnerOfSharesMultipleQuote is a free data retrieval call binding the contract method 0x2a3e703b.
//
// Solidity: function getTVLByOwnerOfSharesMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[][] ownersOfShares, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[][] userTvlsQuote, uint256[] totalTvlsQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetTVLByOwnerOfSharesMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares [][]common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) (struct {
	UserTvlsQuote  [][]*big.Int
	TotalTvlsQuote []*big.Int
}, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultipleQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAddresses, quoteAddresses, oracles)
}

// GetTVLByOwnerOfSharesMultipleQuote is a free data retrieval call binding the contract method 0x2a3e703b.
//
// Solidity: function getTVLByOwnerOfSharesMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[][] ownersOfShares, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[][] userTvlsQuote, uint256[] totalTvlsQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, ownersOfShares [][]common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) (struct {
	UserTvlsQuote  [][]*big.Int
	TotalTvlsQuote []*big.Int
}, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultipleQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, ownersOfShares, baseAddresses, quoteAddresses, oracles)
}

// GetTVLByOwnerOfSharesQuote is a free data retrieval call binding the contract method 0x4a55f4de.
//
// Solidity: function getTVLByOwnerOfSharesQuote(address yieldSourceAddress, address yieldSourceOracle, address ownerOfShares, address base, address quote, address oracle) view returns(uint256 tvlQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetTVLByOwnerOfSharesQuote(opts *bind.CallOpts, yieldSourceAddress common.Address, yieldSourceOracle common.Address, ownerOfShares common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesQuote", yieldSourceAddress, yieldSourceOracle, ownerOfShares, base, quote, oracle)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesQuote is a free data retrieval call binding the contract method 0x4a55f4de.
//
// Solidity: function getTVLByOwnerOfSharesQuote(address yieldSourceAddress, address yieldSourceOracle, address ownerOfShares, address base, address quote, address oracle) view returns(uint256 tvlQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetTVLByOwnerOfSharesQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, ownerOfShares common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, ownerOfShares, base, quote, oracle)
}

// GetTVLByOwnerOfSharesQuote is a free data retrieval call binding the contract method 0x4a55f4de.
//
// Solidity: function getTVLByOwnerOfSharesQuote(address yieldSourceAddress, address yieldSourceOracle, address ownerOfShares, address base, address quote, address oracle) view returns(uint256 tvlQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, ownerOfShares common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLByOwnerOfSharesQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, ownerOfShares, base, quote, oracle)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0x2404a710.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address baseAsset) view returns(uint256[] tvls)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses, yieldSourceOracles, baseAsset)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0x2404a710.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address baseAsset) view returns(uint256[] tvls)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLMultiple(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAsset)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0x2404a710.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses, address[] yieldSourceOracles, address baseAsset) view returns(uint256[] tvls)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAsset common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLMultiple(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAsset)
}

// GetTVLMultipleQuote is a free data retrieval call binding the contract method 0x90df098d.
//
// Solidity: function getTVLMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[] tvlsQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetTVLMultipleQuote(opts *bind.CallOpts, yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getTVLMultipleQuote", yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses, oracles)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultipleQuote is a free data retrieval call binding the contract method 0x90df098d.
//
// Solidity: function getTVLMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[] tvlsQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetTVLMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLMultipleQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses, oracles)
}

// GetTVLMultipleQuote is a free data retrieval call binding the contract method 0x90df098d.
//
// Solidity: function getTVLMultipleQuote(address[] yieldSourceAddresses, address[] yieldSourceOracles, address[] baseAddresses, address[] quoteAddresses, address[] oracles) view returns(uint256[] tvlsQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetTVLMultipleQuote(yieldSourceAddresses []common.Address, yieldSourceOracles []common.Address, baseAddresses []common.Address, quoteAddresses []common.Address, oracles []common.Address) ([]*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLMultipleQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddresses, yieldSourceOracles, baseAddresses, quoteAddresses, oracles)
}

// GetTVLQuote is a free data retrieval call binding the contract method 0x7b9efab7.
//
// Solidity: function getTVLQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote, address oracle) view returns(uint256 tvlQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCaller) GetTVLQuote(opts *bind.CallOpts, yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ISuperYieldSourceOracle.contract.Call(opts, &out, "getTVLQuote", yieldSourceAddress, yieldSourceOracle, base, quote, oracle)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLQuote is a free data retrieval call binding the contract method 0x7b9efab7.
//
// Solidity: function getTVLQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote, address oracle) view returns(uint256 tvlQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleSession) GetTVLQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote, oracle)
}

// GetTVLQuote is a free data retrieval call binding the contract method 0x7b9efab7.
//
// Solidity: function getTVLQuote(address yieldSourceAddress, address yieldSourceOracle, address base, address quote, address oracle) view returns(uint256 tvlQuote)
func (_ISuperYieldSourceOracle *ISuperYieldSourceOracleCallerSession) GetTVLQuote(yieldSourceAddress common.Address, yieldSourceOracle common.Address, base common.Address, quote common.Address, oracle common.Address) (*big.Int, error) {
	return _ISuperYieldSourceOracle.Contract.GetTVLQuote(&_ISuperYieldSourceOracle.CallOpts, yieldSourceAddress, yieldSourceOracle, base, quote, oracle)
}
