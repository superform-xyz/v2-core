// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ERC4626YieldSourceOracle

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

// ERC4626YieldSourceOracleMetaData contains all meta data concerning the ERC4626YieldSourceOracle contract.
var ERC4626YieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAsset\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"expectedUnderlying\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAssets\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"expectedUnderlying\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"isValid\",\"type\":\"bool[]\",\"internalType\":\"bool[]\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// ERC4626YieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use ERC4626YieldSourceOracleMetaData.ABI instead.
var ERC4626YieldSourceOracleABI = ERC4626YieldSourceOracleMetaData.ABI

// ERC4626YieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type ERC4626YieldSourceOracle struct {
	ERC4626YieldSourceOracleCaller     // Read-only binding to the contract
	ERC4626YieldSourceOracleTransactor // Write-only binding to the contract
	ERC4626YieldSourceOracleFilterer   // Log filterer for contract events
}

// ERC4626YieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type ERC4626YieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC4626YieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ERC4626YieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC4626YieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ERC4626YieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC4626YieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ERC4626YieldSourceOracleSession struct {
	Contract     *ERC4626YieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// ERC4626YieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ERC4626YieldSourceOracleCallerSession struct {
	Contract *ERC4626YieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// ERC4626YieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ERC4626YieldSourceOracleTransactorSession struct {
	Contract     *ERC4626YieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// ERC4626YieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type ERC4626YieldSourceOracleRaw struct {
	Contract *ERC4626YieldSourceOracle // Generic contract binding to access the raw methods on
}

// ERC4626YieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ERC4626YieldSourceOracleCallerRaw struct {
	Contract *ERC4626YieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// ERC4626YieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ERC4626YieldSourceOracleTransactorRaw struct {
	Contract *ERC4626YieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewERC4626YieldSourceOracle creates a new instance of ERC4626YieldSourceOracle, bound to a specific deployed contract.
func NewERC4626YieldSourceOracle(address common.Address, backend bind.ContractBackend) (*ERC4626YieldSourceOracle, error) {
	contract, err := bindERC4626YieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ERC4626YieldSourceOracle{ERC4626YieldSourceOracleCaller: ERC4626YieldSourceOracleCaller{contract: contract}, ERC4626YieldSourceOracleTransactor: ERC4626YieldSourceOracleTransactor{contract: contract}, ERC4626YieldSourceOracleFilterer: ERC4626YieldSourceOracleFilterer{contract: contract}}, nil
}

// NewERC4626YieldSourceOracleCaller creates a new read-only instance of ERC4626YieldSourceOracle, bound to a specific deployed contract.
func NewERC4626YieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*ERC4626YieldSourceOracleCaller, error) {
	contract, err := bindERC4626YieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ERC4626YieldSourceOracleCaller{contract: contract}, nil
}

// NewERC4626YieldSourceOracleTransactor creates a new write-only instance of ERC4626YieldSourceOracle, bound to a specific deployed contract.
func NewERC4626YieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*ERC4626YieldSourceOracleTransactor, error) {
	contract, err := bindERC4626YieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ERC4626YieldSourceOracleTransactor{contract: contract}, nil
}

// NewERC4626YieldSourceOracleFilterer creates a new log filterer instance of ERC4626YieldSourceOracle, bound to a specific deployed contract.
func NewERC4626YieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*ERC4626YieldSourceOracleFilterer, error) {
	contract, err := bindERC4626YieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ERC4626YieldSourceOracleFilterer{contract: contract}, nil
}

// bindERC4626YieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindERC4626YieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ERC4626YieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC4626YieldSourceOracle.Contract.ERC4626YieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC4626YieldSourceOracle.Contract.ERC4626YieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC4626YieldSourceOracle.Contract.ERC4626YieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC4626YieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC4626YieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC4626YieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _ERC4626YieldSourceOracle.Contract.Decimals(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _ERC4626YieldSourceOracle.Contract.Decimals(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetAssetOutput(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetAssetOutput(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetBalanceOfOwner(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetBalanceOfOwner(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetPricePerShare(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetPricePerShare(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetPricePerShareMultiple(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetPricePerShareMultiple(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetShareOutput(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetShareOutput(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVL(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVL(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVLMultiple(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC4626YieldSourceOracle.Contract.GetTVLMultiple(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) IsValidUnderlyingAsset(opts *bind.CallOpts, yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAsset", yieldSourceAddress, expectedUnderlying)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) IsValidUnderlyingAsset(yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	return _ERC4626YieldSourceOracle.Contract.IsValidUnderlyingAsset(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, expectedUnderlying)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) IsValidUnderlyingAsset(yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	return _ERC4626YieldSourceOracle.Contract.IsValidUnderlyingAsset(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddress, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCaller) IsValidUnderlyingAssets(opts *bind.CallOpts, yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	var out []interface{}
	err := _ERC4626YieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAssets", yieldSourceAddresses, expectedUnderlying)

	if err != nil {
		return *new([]bool), err
	}

	out0 := *abi.ConvertType(out[0], new([]bool)).(*[]bool)

	return out0, err

}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _ERC4626YieldSourceOracle.Contract.IsValidUnderlyingAssets(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_ERC4626YieldSourceOracle *ERC4626YieldSourceOracleCallerSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _ERC4626YieldSourceOracle.Contract.IsValidUnderlyingAssets(&_ERC4626YieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}
