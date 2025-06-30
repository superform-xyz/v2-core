// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package StakingYieldSourceOracle

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

// StakingYieldSourceOracleMetaData contains all meta data concerning the StakingYieldSourceOracle contract.
var StakingYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAsset\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"expectedUnderlying\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidUnderlyingAssets\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"expectedUnderlying\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"isValid\",\"type\":\"bool[]\",\"internalType\":\"bool[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superLedgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// StakingYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use StakingYieldSourceOracleMetaData.ABI instead.
var StakingYieldSourceOracleABI = StakingYieldSourceOracleMetaData.ABI

// StakingYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type StakingYieldSourceOracle struct {
	StakingYieldSourceOracleCaller     // Read-only binding to the contract
	StakingYieldSourceOracleTransactor // Write-only binding to the contract
	StakingYieldSourceOracleFilterer   // Log filterer for contract events
}

// StakingYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type StakingYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StakingYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type StakingYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StakingYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type StakingYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StakingYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type StakingYieldSourceOracleSession struct {
	Contract     *StakingYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// StakingYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type StakingYieldSourceOracleCallerSession struct {
	Contract *StakingYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// StakingYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type StakingYieldSourceOracleTransactorSession struct {
	Contract     *StakingYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// StakingYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type StakingYieldSourceOracleRaw struct {
	Contract *StakingYieldSourceOracle // Generic contract binding to access the raw methods on
}

// StakingYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type StakingYieldSourceOracleCallerRaw struct {
	Contract *StakingYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// StakingYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type StakingYieldSourceOracleTransactorRaw struct {
	Contract *StakingYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewStakingYieldSourceOracle creates a new instance of StakingYieldSourceOracle, bound to a specific deployed contract.
func NewStakingYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*StakingYieldSourceOracle, error) {
	contract, err := bindStakingYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &StakingYieldSourceOracle{StakingYieldSourceOracleCaller: StakingYieldSourceOracleCaller{contract: contract}, StakingYieldSourceOracleTransactor: StakingYieldSourceOracleTransactor{contract: contract}, StakingYieldSourceOracleFilterer: StakingYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewStakingYieldSourceOracleCaller creates a new read-only instance of StakingYieldSourceOracle, bound to a specific deployed contract.
func NewStakingYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*StakingYieldSourceOracleCaller, error) {
	contract, err := bindStakingYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &StakingYieldSourceOracleCaller{contract: contract}, nil
}

// NewStakingYieldSourceOracleTransactor creates a new write-only instance of StakingYieldSourceOracle, bound to a specific deployed contract.
func NewStakingYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*StakingYieldSourceOracleTransactor, error) {
	contract, err := bindStakingYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &StakingYieldSourceOracleTransactor{contract: contract}, nil
}

// NewStakingYieldSourceOracleFilterer creates a new log filterer instance of StakingYieldSourceOracle, bound to a specific deployed contract.
func NewStakingYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*StakingYieldSourceOracleFilterer, error) {
	contract, err := bindStakingYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &StakingYieldSourceOracleFilterer{contract: contract}, nil
}

// bindStakingYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindStakingYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := StakingYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StakingYieldSourceOracle *StakingYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StakingYieldSourceOracle.Contract.StakingYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StakingYieldSourceOracle *StakingYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StakingYieldSourceOracle.Contract.StakingYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StakingYieldSourceOracle *StakingYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StakingYieldSourceOracle.Contract.StakingYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StakingYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StakingYieldSourceOracle *StakingYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StakingYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StakingYieldSourceOracle *StakingYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StakingYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, arg0 common.Address) (uint8, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "decimals", arg0)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) Decimals(arg0 common.Address) (uint8, error) {
	return _StakingYieldSourceOracle.Contract.Decimals(&_StakingYieldSourceOracle.CallOpts, arg0)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) Decimals(arg0 common.Address) (uint8, error) {
	return _StakingYieldSourceOracle.Contract.Decimals(&_StakingYieldSourceOracle.CallOpts, arg0)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", arg0, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetAssetOutput(&_StakingYieldSourceOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetAssetOutput(&_StakingYieldSourceOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetAssetOutputWithFees(&_StakingYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x8896905f.
//
// Solidity: function getAssetOutputWithFees(bytes4 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [4]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetAssetOutputWithFees(&_StakingYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetBalanceOfOwner(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetBalanceOfOwner(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, arg0 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetPricePerShare(arg0 common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetPricePerShare(&_StakingYieldSourceOracle.CallOpts, arg0)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetPricePerShare(arg0 common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetPricePerShare(&_StakingYieldSourceOracle.CallOpts, arg0)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetPricePerShareMultiple(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetPricePerShareMultiple(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetShareOutput(&_StakingYieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetShareOutput(&_StakingYieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVL(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVL(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVLMultiple(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _StakingYieldSourceOracle.Contract.GetTVLMultiple(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) IsValidUnderlyingAsset(opts *bind.CallOpts, yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAsset", yieldSourceAddress, expectedUnderlying)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) IsValidUnderlyingAsset(yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	return _StakingYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress, expectedUnderlying)
}

// IsValidUnderlyingAsset is a free data retrieval call binding the contract method 0x6e7f28b2.
//
// Solidity: function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying) view returns(bool)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) IsValidUnderlyingAsset(yieldSourceAddress common.Address, expectedUnderlying common.Address) (bool, error) {
	return _StakingYieldSourceOracle.Contract.IsValidUnderlyingAsset(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddress, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) IsValidUnderlyingAssets(opts *bind.CallOpts, yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "isValidUnderlyingAssets", yieldSourceAddresses, expectedUnderlying)

	if err != nil {
		return *new([]bool), err
	}

	out0 := *abi.ConvertType(out[0], new([]bool)).(*[]bool)

	return out0, err

}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _StakingYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// IsValidUnderlyingAssets is a free data retrieval call binding the contract method 0xb25736fc.
//
// Solidity: function isValidUnderlyingAssets(address[] yieldSourceAddresses, address[] expectedUnderlying) view returns(bool[] isValid)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) IsValidUnderlyingAssets(yieldSourceAddresses []common.Address, expectedUnderlying []common.Address) ([]bool, error) {
	return _StakingYieldSourceOracle.Contract.IsValidUnderlyingAssets(&_StakingYieldSourceOracle.CallOpts, yieldSourceAddresses, expectedUnderlying)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCaller) SuperLedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StakingYieldSourceOracle.contract.Call(opts, &out, "superLedgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleSession) SuperLedgerConfiguration() (common.Address, error) {
	return _StakingYieldSourceOracle.Contract.SuperLedgerConfiguration(&_StakingYieldSourceOracle.CallOpts)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_StakingYieldSourceOracle *StakingYieldSourceOracleCallerSession) SuperLedgerConfiguration() (common.Address, error) {
	return _StakingYieldSourceOracle.Contract.SuperLedgerConfiguration(&_StakingYieldSourceOracle.CallOpts)
}
