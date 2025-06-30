// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package PendlePTYieldSourceOracle

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

// PendlePTYieldSourceOracleMetaData contains all meta data concerning the PendlePTYieldSourceOracle contract.
var PendlePTYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"TWAP_DURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"assetsOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"price\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"sharesOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAsset\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"expectedUnderlying\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAssets\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"expectedUnderlying\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"isValid\",\"type\":\"bool[]\",\"internalType\":\"bool[]\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"TwapDurationSet\",\"inputs\":[{\"name\":\"newDuration\",\"type\":\"uint32\",\"indexed\":false,\"internalType\":\"uint32\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AVAILABLE_ERC20_ON_CHAIN\",\"inputs\":[]}]",
}

// PendlePTYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use PendlePTYieldSourceOracleMetaData.ABI instead.
var PendlePTYieldSourceOracleABI = PendlePTYieldSourceOracleMetaData.ABI

// PendlePTYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type PendlePTYieldSourceOracle struct {
	PendlePTYieldSourceOracleCaller     // Read-only binding to the contract
	PendlePTYieldSourceOracleTransactor // Write-only binding to the contract
	PendlePTYieldSourceOracleFilterer   // Log filterer for contract events
}

// PendlePTYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type PendlePTYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PendlePTYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type PendlePTYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PendlePTYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type PendlePTYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PendlePTYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type PendlePTYieldSourceOracleSession struct {
	Contract     *PendlePTYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts              // Call options to use throughout this session
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// PendlePTYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type PendlePTYieldSourceOracleCallerSession struct {
	Contract *PendlePTYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                    // Call options to use throughout this session
}

// PendlePTYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type PendlePTYieldSourceOracleTransactorSession struct {
	Contract     *PendlePTYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// PendlePTYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type PendlePTYieldSourceOracleRaw struct {
	Contract *PendlePTYieldSourceOracle // Generic contract binding to access the raw methods on
}

// PendlePTYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type PendlePTYieldSourceOracleCallerRaw struct {
	Contract *PendlePTYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// PendlePTYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type PendlePTYieldSourceOracleTransactorRaw struct {
	Contract *PendlePTYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewPendlePTYieldSourceOracle creates a new instance of PendlePTYieldSourceOracle, bound to a specific deployed contract.
func NewPendlePTYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*PendlePTYieldSourceOracle, error) {
	contract, err := bindPendlePTYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &PendlePTYieldSourceOracle{PendlePTYieldSourceOracleCaller: PendlePTYieldSourceOracleCaller{contract: contract}, PendlePTYieldSourceOracleTransactor: PendlePTYieldSourceOracleTransactor{contract: contract}, PendlePTYieldSourceOracleFilterer: PendlePTYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewPendlePTYieldSourceOracleCaller creates a new read-only instance of PendlePTYieldSourceOracle, bound to a specific deployed contract.
func NewPendlePTYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*PendlePTYieldSourceOracleCaller, error) {
	contract, err := bindPendlePTYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &PendlePTYieldSourceOracleCaller{contract: contract}, nil
}

// NewPendlePTYieldSourceOracleTransactor creates a new write-only instance of PendlePTYieldSourceOracle, bound to a specific deployed contract.
func NewPendlePTYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*PendlePTYieldSourceOracleTransactor, error) {
	contract, err := bindPendlePTYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &PendlePTYieldSourceOracleTransactor{contract: contract}, nil
}

// NewPendlePTYieldSourceOracleFilterer creates a new log filterer instance of PendlePTYieldSourceOracle, bound to a specific deployed contract.
func NewPendlePTYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*PendlePTYieldSourceOracleFilterer, error) {
	contract, err := bindPendlePTYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &PendlePTYieldSourceOracleFilterer{contract: contract}, nil
}

// bindPendlePTYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindPendlePTYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := PendlePTYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PendlePTYieldSourceOracle.Contract.PendlePTYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PendlePTYieldSourceOracle.Contract.PendlePTYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PendlePTYieldSourceOracle.Contract.PendlePTYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PendlePTYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PendlePTYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PendlePTYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// TWAPDURATION is a free data retrieval call binding the contract method 0x879ac8f8.
//
// Solidity: function TWAP_DURATION() view returns(uint32)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) TWAPDURATION(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "TWAP_DURATION")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// TWAPDURATION is a free data retrieval call binding the contract method 0x879ac8f8.
//
// Solidity: function TWAP_DURATION() view returns(uint32)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) TWAPDURATION() (uint32, error) {
	return _PendlePTYieldSourceOracle.Contract.TWAPDURATION(&_PendlePTYieldSourceOracle.CallOpts)
}

// TWAPDURATION is a free data retrieval call binding the contract method 0x879ac8f8.
//
// Solidity: function TWAP_DURATION() view returns(uint32)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) TWAPDURATION() (uint32, error) {
	return _PendlePTYieldSourceOracle.Contract.TWAPDURATION(&_PendlePTYieldSourceOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, arg0 common.Address) (uint8, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "decimals", arg0)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) Decimals(arg0 common.Address) (uint8, error) {
	return _PendlePTYieldSourceOracle.Contract.Decimals(&_PendlePTYieldSourceOracle.CallOpts, arg0)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) Decimals(arg0 common.Address) (uint8, error) {
	return _PendlePTYieldSourceOracle.Contract.Decimals(&_PendlePTYieldSourceOracle.CallOpts, arg0)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address market, address , uint256 sharesIn) view returns(uint256 assetsOut)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, market common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", market, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address market, address , uint256 sharesIn) view returns(uint256 assetsOut)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetAssetOutput(market common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetAssetOutput(&_PendlePTYieldSourceOracle.CallOpts, market, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address market, address , uint256 sharesIn) view returns(uint256 assetsOut)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetAssetOutput(market common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetAssetOutput(&_PendlePTYieldSourceOracle.CallOpts, market, arg1, sharesIn)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address market, address ownerOfShares) view returns(uint256 balance)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", market, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address market, address ownerOfShares) view returns(uint256 balance)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetBalanceOfOwner(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetBalanceOfOwner(&_PendlePTYieldSourceOracle.CallOpts, market, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address market, address ownerOfShares) view returns(uint256 balance)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetBalanceOfOwner(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetBalanceOfOwner(&_PendlePTYieldSourceOracle.CallOpts, market, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address market) view returns(uint256 price)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, market common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", market)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address market) view returns(uint256 price)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetPricePerShare(market common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetPricePerShare(&_PendlePTYieldSourceOracle.CallOpts, market)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address market) view returns(uint256 price)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetPricePerShare(market common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetPricePerShare(&_PendlePTYieldSourceOracle.CallOpts, market)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetPricePerShareMultiple(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetPricePerShareMultiple(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address market, address , uint256 assetsIn) view returns(uint256 sharesOut)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", market, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address market, address , uint256 assetsIn) view returns(uint256 sharesOut)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetShareOutput(market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetShareOutput(&_PendlePTYieldSourceOracle.CallOpts, market, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address market, address , uint256 assetsIn) view returns(uint256 sharesOut)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetShareOutput(market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetShareOutput(&_PendlePTYieldSourceOracle.CallOpts, market, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address market) view returns(uint256 tvl)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, market common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getTVL", market)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address market) view returns(uint256 tvl)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetTVL(market common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVL(&_PendlePTYieldSourceOracle.CallOpts, market)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address market) view returns(uint256 tvl)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetTVL(market common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVL(&_PendlePTYieldSourceOracle.CallOpts, market)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address market, address ownerOfShares) view returns(uint256 tvl)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", market, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address market, address ownerOfShares) view returns(uint256 tvl)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetTVLByOwnerOfShares(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_PendlePTYieldSourceOracle.CallOpts, market, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address market, address ownerOfShares) view returns(uint256 tvl)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_PendlePTYieldSourceOracle.CallOpts, market, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVLMultiple(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTYieldSourceOracle.Contract.GetTVLMultiple(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address market, address expectedUnderlying) view returns(bool)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) IsValidUnderlyingAsset(opts *bind.CallOpts, market common.Address, expectedUnderlying common.Address) (bool, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAsset", market, expectedUnderlying)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address market, address expectedUnderlying) view returns(bool)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) IsValidUnderlyingAsset(market common.Address, expectedUnderlying common.Address) (bool, error) {
	return _PendlePTYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_PendlePTYieldSourceOracle.CallOpts, market, expectedUnderlying)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address market, address expectedUnderlying) view returns(bool)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) IsValidUnderlyingAsset(market common.Address, expectedUnderlying common.Address) (bool, error) {
	return _PendlePTYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_PendlePTYieldSourceOracle.CallOpts, market, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCaller) IsValidUnderlyingAssets(opts *bind.CallOpts, yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	var out []interface{}
	err := _PendlePTYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAssets", yieldSourceAddresses, expectedUnderlying)

	if err != nil {
		return *new([]bool), err
	}

	out0 := *abi.ConvertType(out[0], new([]bool)).(*[]bool)

	return out0, err

}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _PendlePTYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleCallerSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _PendlePTYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_PendlePTYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// PendlePTYieldSourceOracleTwapDurationSetIterator is returned from FilterTwapDurationSet and is used to iterate over the raw logs and unpacked data for TwapDurationSet events raised by the PendlePTYieldSourceOracle contract.
type PendlePTYieldSourceOracleTwapDurationSetIterator struct {
	Event *PendlePTYieldSourceOracleTwapDurationSet // Event containing the contract specifics and raw log

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
func (it *PendlePTYieldSourceOracleTwapDurationSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTYieldSourceOracleTwapDurationSet)
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
		it.Event = new(PendlePTYieldSourceOracleTwapDurationSet)
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
func (it *PendlePTYieldSourceOracleTwapDurationSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTYieldSourceOracleTwapDurationSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTYieldSourceOracleTwapDurationSet represents a TwapDurationSet event raised by the PendlePTYieldSourceOracle contract.
type PendlePTYieldSourceOracleTwapDurationSet struct {
	NewDuration uint32
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterTwapDurationSet is a free log retrieval operation binding the contract event 0xae45eae27fdd572bcc5daa11e5155fef7d0b5081d88a374f0580bf91bfdc29b9.
//
// Solidity: event TwapDurationSet(uint32 newDuration)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleFilterer) FilterTwapDurationSet(opts *bind.FilterOpts) (*PendlePTYieldSourceOracleTwapDurationSetIterator, error) {

	logs, sub, err := _PendlePTYieldSourceOracle.contract.FilterLogs(opts, "TwapDurationSet")
	if err != nil {
		return nil, err
	}
	return &PendlePTYieldSourceOracleTwapDurationSetIterator{contract: _PendlePTYieldSourceOracle.contract, event: "TwapDurationSet", logs: logs, sub: sub}, nil
}

// WatchTwapDurationSet is a free log subscription operation binding the contract event 0xae45eae27fdd572bcc5daa11e5155fef7d0b5081d88a374f0580bf91bfdc29b9.
//
// Solidity: event TwapDurationSet(uint32 newDuration)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleFilterer) WatchTwapDurationSet(opts *bind.WatchOpts, sink chan<- *PendlePTYieldSourceOracleTwapDurationSet) (event.Subscription, error) {

	logs, sub, err := _PendlePTYieldSourceOracle.contract.WatchLogs(opts, "TwapDurationSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTYieldSourceOracleTwapDurationSet)
				if err := _PendlePTYieldSourceOracle.contract.UnpackLog(event, "TwapDurationSet", log); err != nil {
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

// ParseTwapDurationSet is a log parse operation binding the contract event 0xae45eae27fdd572bcc5daa11e5155fef7d0b5081d88a374f0580bf91bfdc29b9.
//
// Solidity: event TwapDurationSet(uint32 newDuration)
func (_PendlePTYieldSourceOracle *PendlePTYieldSourceOracleFilterer) ParseTwapDurationSet(log types.Log) (*PendlePTYieldSourceOracleTwapDurationSet, error) {
	event := new(PendlePTYieldSourceOracleTwapDurationSet)
	if err := _PendlePTYieldSourceOracle.contract.UnpackLog(event, "TwapDurationSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
