// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package DETHYieldSourceOracle

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

// DETHYieldSourceOracleMetaData contains all meta data concerning the DETHYieldSourceOracle contract.
var DETHYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"foundation_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"FOUNDATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAX_PENDING_REQUESTS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// DETHYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use DETHYieldSourceOracleMetaData.ABI instead.
var DETHYieldSourceOracleABI = DETHYieldSourceOracleMetaData.ABI

// DETHYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type DETHYieldSourceOracle struct {
	DETHYieldSourceOracleCaller     // Read-only binding to the contract
	DETHYieldSourceOracleTransactor // Write-only binding to the contract
	DETHYieldSourceOracleFilterer   // Log filterer for contract events
}

// DETHYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type DETHYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DETHYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type DETHYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DETHYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type DETHYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DETHYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type DETHYieldSourceOracleSession struct {
	Contract     *DETHYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts          // Call options to use throughout this session
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// DETHYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type DETHYieldSourceOracleCallerSession struct {
	Contract *DETHYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                // Call options to use throughout this session
}

// DETHYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type DETHYieldSourceOracleTransactorSession struct {
	Contract     *DETHYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                // Transaction auth options to use throughout this session
}

// DETHYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type DETHYieldSourceOracleRaw struct {
	Contract *DETHYieldSourceOracle // Generic contract binding to access the raw methods on
}

// DETHYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type DETHYieldSourceOracleCallerRaw struct {
	Contract *DETHYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// DETHYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type DETHYieldSourceOracleTransactorRaw struct {
	Contract *DETHYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewDETHYieldSourceOracle creates a new instance of DETHYieldSourceOracle, bound to a specific deployed contract.
func NewDETHYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*DETHYieldSourceOracle, error) {
	contract, err := bindDETHYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &DETHYieldSourceOracle{DETHYieldSourceOracleCaller: DETHYieldSourceOracleCaller{contract: contract}, DETHYieldSourceOracleTransactor: DETHYieldSourceOracleTransactor{contract: contract}, DETHYieldSourceOracleFilterer: DETHYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewDETHYieldSourceOracleCaller creates a new read-only instance of DETHYieldSourceOracle, bound to a specific deployed contract.
func NewDETHYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*DETHYieldSourceOracleCaller, error) {
	contract, err := bindDETHYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &DETHYieldSourceOracleCaller{contract: contract}, nil
}

// NewDETHYieldSourceOracleTransactor creates a new write-only instance of DETHYieldSourceOracle, bound to a specific deployed contract.
func NewDETHYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*DETHYieldSourceOracleTransactor, error) {
	contract, err := bindDETHYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &DETHYieldSourceOracleTransactor{contract: contract}, nil
}

// NewDETHYieldSourceOracleFilterer creates a new log filterer instance of DETHYieldSourceOracle, bound to a specific deployed contract.
func NewDETHYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*DETHYieldSourceOracleFilterer, error) {
	contract, err := bindDETHYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &DETHYieldSourceOracleFilterer{contract: contract}, nil
}

// bindDETHYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindDETHYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := DETHYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DETHYieldSourceOracle *DETHYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DETHYieldSourceOracle.Contract.DETHYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DETHYieldSourceOracle *DETHYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DETHYieldSourceOracle.Contract.DETHYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DETHYieldSourceOracle *DETHYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DETHYieldSourceOracle.Contract.DETHYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _DETHYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_DETHYieldSourceOracle *DETHYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _DETHYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_DETHYieldSourceOracle *DETHYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _DETHYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// FOUNDATION is a free data retrieval call binding the contract method 0x65df2e51.
//
// Solidity: function FOUNDATION() view returns(address)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) FOUNDATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "FOUNDATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FOUNDATION is a free data retrieval call binding the contract method 0x65df2e51.
//
// Solidity: function FOUNDATION() view returns(address)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) FOUNDATION() (common.Address, error) {
	return _DETHYieldSourceOracle.Contract.FOUNDATION(&_DETHYieldSourceOracle.CallOpts)
}

// FOUNDATION is a free data retrieval call binding the contract method 0x65df2e51.
//
// Solidity: function FOUNDATION() view returns(address)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) FOUNDATION() (common.Address, error) {
	return _DETHYieldSourceOracle.Contract.FOUNDATION(&_DETHYieldSourceOracle.CallOpts)
}

// MAXPENDINGREQUESTS is a free data retrieval call binding the contract method 0x363c6b81.
//
// Solidity: function MAX_PENDING_REQUESTS() view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) MAXPENDINGREQUESTS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "MAX_PENDING_REQUESTS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MAXPENDINGREQUESTS is a free data retrieval call binding the contract method 0x363c6b81.
//
// Solidity: function MAX_PENDING_REQUESTS() view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) MAXPENDINGREQUESTS() (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.MAXPENDINGREQUESTS(&_DETHYieldSourceOracle.CallOpts)
}

// MAXPENDINGREQUESTS is a free data retrieval call binding the contract method 0x363c6b81.
//
// Solidity: function MAX_PENDING_REQUESTS() view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) MAXPENDINGREQUESTS() (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.MAXPENDINGREQUESTS(&_DETHYieldSourceOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _DETHYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_DETHYieldSourceOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _DETHYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_DETHYieldSourceOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _DETHYieldSourceOracle.Contract.Decimals(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _DETHYieldSourceOracle.Contract.Decimals(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetAssetOutput(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetAssetOutput(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetAssetOutputWithFees(&_DETHYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetAssetOutputWithFees(&_DETHYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetBalanceOfOwner(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetBalanceOfOwner(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetPricePerShare(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetPricePerShare(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetPricePerShareMultiple(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetPricePerShareMultiple(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetShareOutput(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetShareOutput(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVL(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVL(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVLMultiple(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetTVLMultiple(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _DETHYieldSourceOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_DETHYieldSourceOracle *DETHYieldSourceOracleCallerSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _DETHYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_DETHYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}
