// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package YoYieldSourceOracle

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

// YoYieldSourceOracleMetaData contains all meta data concerning the YoYieldSourceOracle contract.
var YoYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// YoYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use YoYieldSourceOracleMetaData.ABI instead.
var YoYieldSourceOracleABI = YoYieldSourceOracleMetaData.ABI

// YoYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type YoYieldSourceOracle struct {
	YoYieldSourceOracleCaller     // Read-only binding to the contract
	YoYieldSourceOracleTransactor // Write-only binding to the contract
	YoYieldSourceOracleFilterer   // Log filterer for contract events
}

// YoYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type YoYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// YoYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type YoYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// YoYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type YoYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// YoYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type YoYieldSourceOracleSession struct {
	Contract     *YoYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts        // Call options to use throughout this session
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// YoYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type YoYieldSourceOracleCallerSession struct {
	Contract *YoYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts              // Call options to use throughout this session
}

// YoYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type YoYieldSourceOracleTransactorSession struct {
	Contract     *YoYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// YoYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type YoYieldSourceOracleRaw struct {
	Contract *YoYieldSourceOracle // Generic contract binding to access the raw methods on
}

// YoYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type YoYieldSourceOracleCallerRaw struct {
	Contract *YoYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// YoYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type YoYieldSourceOracleTransactorRaw struct {
	Contract *YoYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewYoYieldSourceOracle creates a new instance of YoYieldSourceOracle, bound to a specific deployed contract.
func NewYoYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*YoYieldSourceOracle, error) {
	contract, err := bindYoYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &YoYieldSourceOracle{YoYieldSourceOracleCaller: YoYieldSourceOracleCaller{contract: contract}, YoYieldSourceOracleTransactor: YoYieldSourceOracleTransactor{contract: contract}, YoYieldSourceOracleFilterer: YoYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewYoYieldSourceOracleCaller creates a new read-only instance of YoYieldSourceOracle, bound to a specific deployed contract.
func NewYoYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*YoYieldSourceOracleCaller, error) {
	contract, err := bindYoYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &YoYieldSourceOracleCaller{contract: contract}, nil
}

// NewYoYieldSourceOracleTransactor creates a new write-only instance of YoYieldSourceOracle, bound to a specific deployed contract.
func NewYoYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*YoYieldSourceOracleTransactor, error) {
	contract, err := bindYoYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &YoYieldSourceOracleTransactor{contract: contract}, nil
}

// NewYoYieldSourceOracleFilterer creates a new log filterer instance of YoYieldSourceOracle, bound to a specific deployed contract.
func NewYoYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*YoYieldSourceOracleFilterer, error) {
	contract, err := bindYoYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &YoYieldSourceOracleFilterer{contract: contract}, nil
}

// bindYoYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindYoYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := YoYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_YoYieldSourceOracle *YoYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _YoYieldSourceOracle.Contract.YoYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_YoYieldSourceOracle *YoYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _YoYieldSourceOracle.Contract.YoYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_YoYieldSourceOracle *YoYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _YoYieldSourceOracle.Contract.YoYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _YoYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_YoYieldSourceOracle *YoYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _YoYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_YoYieldSourceOracle *YoYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _YoYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _YoYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_YoYieldSourceOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _YoYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_YoYieldSourceOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _YoYieldSourceOracle.Contract.Decimals(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _YoYieldSourceOracle.Contract.Decimals(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetAssetOutput(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetAssetOutput(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetAssetOutputWithFees(&_YoYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetAssetOutputWithFees(&_YoYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetBalanceOfOwner(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetBalanceOfOwner(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetPricePerShare(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetPricePerShare(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetPricePerShareMultiple(&_YoYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetPricePerShareMultiple(&_YoYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetShareOutput(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetShareOutput(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVL(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVL(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_YoYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_YoYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVLMultiple(&_YoYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetTVLMultiple(&_YoYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _YoYieldSourceOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_YoYieldSourceOracle *YoYieldSourceOracleCallerSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _YoYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_YoYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}
