// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package AbstractYieldSourceOracle

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

// AbstractYieldSourceOracleMetaData contains all meta data concerning the AbstractYieldSourceOracle contract.
var AbstractYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetIn\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAsset\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAssets\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"expectedUnderlying\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"isValid\",\"type\":\"bool[]\",\"internalType\":\"bool[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superLedgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// AbstractYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use AbstractYieldSourceOracleMetaData.ABI instead.
var AbstractYieldSourceOracleABI = AbstractYieldSourceOracleMetaData.ABI

// AbstractYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type AbstractYieldSourceOracle struct {
	AbstractYieldSourceOracleCaller     // Read-only binding to the contract
	AbstractYieldSourceOracleTransactor // Write-only binding to the contract
	AbstractYieldSourceOracleFilterer   // Log filterer for contract events
}

// AbstractYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type AbstractYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AbstractYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AbstractYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AbstractYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AbstractYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AbstractYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AbstractYieldSourceOracleSession struct {
	Contract     *AbstractYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts              // Call options to use throughout this session
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// AbstractYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AbstractYieldSourceOracleCallerSession struct {
	Contract *AbstractYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                    // Call options to use throughout this session
}

// AbstractYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AbstractYieldSourceOracleTransactorSession struct {
	Contract     *AbstractYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// AbstractYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type AbstractYieldSourceOracleRaw struct {
	Contract *AbstractYieldSourceOracle // Generic contract binding to access the raw methods on
}

// AbstractYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AbstractYieldSourceOracleCallerRaw struct {
	Contract *AbstractYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// AbstractYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AbstractYieldSourceOracleTransactorRaw struct {
	Contract *AbstractYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAbstractYieldSourceOracle creates a new instance of AbstractYieldSourceOracle, bound to a specific deployed contract.
func NewAbstractYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*AbstractYieldSourceOracle, error) {
	contract, err := bindAbstractYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AbstractYieldSourceOracle{AbstractYieldSourceOracleCaller: AbstractYieldSourceOracleCaller{contract: contract}, AbstractYieldSourceOracleTransactor: AbstractYieldSourceOracleTransactor{contract: contract}, AbstractYieldSourceOracleFilterer: AbstractYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewAbstractYieldSourceOracleCaller creates a new read-only instance of AbstractYieldSourceOracle, bound to a specific deployed contract.
func NewAbstractYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*AbstractYieldSourceOracleCaller, error) {
	contract, err := bindAbstractYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AbstractYieldSourceOracleCaller{contract: contract}, nil
}

// NewAbstractYieldSourceOracleTransactor creates a new write-only instance of AbstractYieldSourceOracle, bound to a specific deployed contract.
func NewAbstractYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*AbstractYieldSourceOracleTransactor, error) {
	contract, err := bindAbstractYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AbstractYieldSourceOracleTransactor{contract: contract}, nil
}

// NewAbstractYieldSourceOracleFilterer creates a new log filterer instance of AbstractYieldSourceOracle, bound to a specific deployed contract.
func NewAbstractYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*AbstractYieldSourceOracleFilterer, error) {
	contract, err := bindAbstractYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AbstractYieldSourceOracleFilterer{contract: contract}, nil
}

// bindAbstractYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindAbstractYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AbstractYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AbstractYieldSourceOracle.Contract.AbstractYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AbstractYieldSourceOracle.Contract.AbstractYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AbstractYieldSourceOracle.Contract.AbstractYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AbstractYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AbstractYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AbstractYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _AbstractYieldSourceOracle.Contract.Decimals(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _AbstractYieldSourceOracle.Contract.Decimals(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address assetOut, uint256 sharesIn) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, assetOut common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, assetOut, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address assetOut, uint256 sharesIn) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetAssetOutput(yieldSourceAddress common.Address, assetOut common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetAssetOutput(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, assetOut, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address assetOut, uint256 sharesIn) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, assetOut common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetAssetOutput(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, assetOut, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetAssetOutputWithFees(&_AbstractYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetAssetOutputWithFees(&_AbstractYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetBalanceOfOwner(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetBalanceOfOwner(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetPricePerShare(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetPricePerShare(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetPricePerShareMultiple(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetPricePerShareMultiple(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, assetIn common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, assetIn, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetShareOutput(yieldSourceAddress common.Address, assetIn common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetShareOutput(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, assetIn, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, assetIn common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetShareOutput(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, assetIn, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVL(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVL(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVLMultiple(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AbstractYieldSourceOracle.Contract.GetTVLMultiple(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address , address ) view returns(bool)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) IsValidUnderlyingAsset(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address) (bool, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAsset", arg0, arg1)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address , address ) view returns(bool)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) IsValidUnderlyingAsset(arg0 common.Address, arg1 common.Address) (bool, error) {
	return _AbstractYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_AbstractYieldSourceOracle.CallOpts, arg0, arg1)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address , address ) view returns(bool)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) IsValidUnderlyingAsset(arg0 common.Address, arg1 common.Address) (bool, error) {
	return _AbstractYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_AbstractYieldSourceOracle.CallOpts, arg0, arg1)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) IsValidUnderlyingAssets(opts *bind.CallOpts, yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAssets", yieldSourceAddresses, expectedUnderlying)

	if err != nil {
		return *new([]bool), err
	}

	out0 := *abi.ConvertType(out[0], new([]bool)).(*[]bool)

	return out0, err

}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _AbstractYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _AbstractYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_AbstractYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCaller) SuperLedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AbstractYieldSourceOracle.contract.Call(opts, &out, "superLedgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleSession) SuperLedgerConfiguration() (common.Address, error) {
	return _AbstractYieldSourceOracle.Contract.SuperLedgerConfiguration(&_AbstractYieldSourceOracle.CallOpts)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_AbstractYieldSourceOracle *AbstractYieldSourceOracleCallerSession) SuperLedgerConfiguration() (common.Address, error) {
	return _AbstractYieldSourceOracle.Contract.SuperLedgerConfiguration(&_AbstractYieldSourceOracle.CallOpts)
}
