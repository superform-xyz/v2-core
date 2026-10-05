// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package MorphoBlueDebtOracle

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

// MorphoBlueDebtOracleMetaData contains all meta data concerning the MorphoBlueDebtOracle contract.
var MorphoBlueDebtOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"REGISTRY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractMorphoBlueMarketRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastUpdate\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"},{\"name\":\"succeeded\",\"type\":\"bool[][]\",\"internalType\":\"bool[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeCastOverflowedUintDowncast\",\"inputs\":[{\"name\":\"bits\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// MorphoBlueDebtOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use MorphoBlueDebtOracleMetaData.ABI instead.
var MorphoBlueDebtOracleABI = MorphoBlueDebtOracleMetaData.ABI

// MorphoBlueDebtOracle is an auto generated Go binding around an Ethereum contract.
type MorphoBlueDebtOracle struct {
	MorphoBlueDebtOracleCaller     // Read-only binding to the contract
	MorphoBlueDebtOracleTransactor // Write-only binding to the contract
	MorphoBlueDebtOracleFilterer   // Log filterer for contract events
}

// MorphoBlueDebtOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type MorphoBlueDebtOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MorphoBlueDebtOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type MorphoBlueDebtOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MorphoBlueDebtOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type MorphoBlueDebtOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MorphoBlueDebtOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type MorphoBlueDebtOracleSession struct {
	Contract     *MorphoBlueDebtOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// MorphoBlueDebtOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type MorphoBlueDebtOracleCallerSession struct {
	Contract *MorphoBlueDebtOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// MorphoBlueDebtOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type MorphoBlueDebtOracleTransactorSession struct {
	Contract     *MorphoBlueDebtOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// MorphoBlueDebtOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type MorphoBlueDebtOracleRaw struct {
	Contract *MorphoBlueDebtOracle // Generic contract binding to access the raw methods on
}

// MorphoBlueDebtOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type MorphoBlueDebtOracleCallerRaw struct {
	Contract *MorphoBlueDebtOracleCaller // Generic read-only contract binding to access the raw methods on
}

// MorphoBlueDebtOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type MorphoBlueDebtOracleTransactorRaw struct {
	Contract *MorphoBlueDebtOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewMorphoBlueDebtOracle creates a new instance of MorphoBlueDebtOracle, bound to a specific deployed contract.
func NewMorphoBlueDebtOracle(address common.Address, backend bind.ContractBackend) (*MorphoBlueDebtOracle, error) {
	contract, err := bindMorphoBlueDebtOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &MorphoBlueDebtOracle{MorphoBlueDebtOracleCaller: MorphoBlueDebtOracleCaller{contract: contract}, MorphoBlueDebtOracleTransactor: MorphoBlueDebtOracleTransactor{contract: contract}, MorphoBlueDebtOracleFilterer: MorphoBlueDebtOracleFilterer{contract: contract}}, nil
}

// NewMorphoBlueDebtOracleCaller creates a new read-only instance of MorphoBlueDebtOracle, bound to a specific deployed contract.
func NewMorphoBlueDebtOracleCaller(address common.Address, caller bind.ContractCaller) (*MorphoBlueDebtOracleCaller, error) {
	contract, err := bindMorphoBlueDebtOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &MorphoBlueDebtOracleCaller{contract: contract}, nil
}

// NewMorphoBlueDebtOracleTransactor creates a new write-only instance of MorphoBlueDebtOracle, bound to a specific deployed contract.
func NewMorphoBlueDebtOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*MorphoBlueDebtOracleTransactor, error) {
	contract, err := bindMorphoBlueDebtOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &MorphoBlueDebtOracleTransactor{contract: contract}, nil
}

// NewMorphoBlueDebtOracleFilterer creates a new log filterer instance of MorphoBlueDebtOracle, bound to a specific deployed contract.
func NewMorphoBlueDebtOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*MorphoBlueDebtOracleFilterer, error) {
	contract, err := bindMorphoBlueDebtOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &MorphoBlueDebtOracleFilterer{contract: contract}, nil
}

// bindMorphoBlueDebtOracle binds a generic wrapper to an already deployed contract.
func bindMorphoBlueDebtOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := MorphoBlueDebtOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MorphoBlueDebtOracle.Contract.MorphoBlueDebtOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MorphoBlueDebtOracle.Contract.MorphoBlueDebtOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MorphoBlueDebtOracle.Contract.MorphoBlueDebtOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MorphoBlueDebtOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MorphoBlueDebtOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MorphoBlueDebtOracle.Contract.contract.Transact(opts, method, params...)
}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) REGISTRY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "REGISTRY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) REGISTRY() (common.Address, error) {
	return _MorphoBlueDebtOracle.Contract.REGISTRY(&_MorphoBlueDebtOracle.CallOpts)
}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) REGISTRY() (common.Address, error) {
	return _MorphoBlueDebtOracle.Contract.REGISTRY(&_MorphoBlueDebtOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _MorphoBlueDebtOracle.Contract.SUPERLEDGERCONFIGURATION(&_MorphoBlueDebtOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _MorphoBlueDebtOracle.Contract.SUPERLEDGERCONFIGURATION(&_MorphoBlueDebtOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _MorphoBlueDebtOracle.Contract.Decimals(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _MorphoBlueDebtOracle.Contract.Decimals(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetAssetOutput(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetAssetOutput(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getAssetOutputWithFees", arg0, yieldSourceAddress, assetOut, arg3, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetAssetOutputWithFees(arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetAssetOutputWithFees(&_MorphoBlueDebtOracle.CallOpts, arg0, yieldSourceAddress, assetOut, arg3, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetAssetOutputWithFees(arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetAssetOutputWithFees(&_MorphoBlueDebtOracle.CallOpts, arg0, yieldSourceAddress, assetOut, arg3, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetBalanceOfOwner(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetBalanceOfOwner(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetLastUpdate is a free data retrieval call binding the contract method 0x5a7e1989.
//
// Solidity: function getLastUpdate(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetLastUpdate(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getLastUpdate", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetLastUpdate is a free data retrieval call binding the contract method 0x5a7e1989.
//
// Solidity: function getLastUpdate(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetLastUpdate(yieldSourceAddress common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetLastUpdate(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// GetLastUpdate is a free data retrieval call binding the contract method 0x5a7e1989.
//
// Solidity: function getLastUpdate(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetLastUpdate(yieldSourceAddress common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetLastUpdate(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetPricePerShare(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetPricePerShare(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetPricePerShareMultiple(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetPricePerShareMultiple(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetShareOutput(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetShareOutput(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVL(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVL(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVLByOwnerOfShares(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVLByOwnerOfShares(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	outstruct := new(struct {
		UserTvls  [][]*big.Int
		Succeeded [][]bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.UserTvls = *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)
	outstruct.Succeeded = *abi.ConvertType(out[1], new([][]bool)).(*[][]bool)

	return *outstruct, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVLMultiple(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetTVLMultiple(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MorphoBlueDebtOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetWithdrawalShareOutput(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_MorphoBlueDebtOracle *MorphoBlueDebtOracleCallerSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _MorphoBlueDebtOracle.Contract.GetWithdrawalShareOutput(&_MorphoBlueDebtOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}
