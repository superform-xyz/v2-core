// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ERC5115YieldSourceOracle

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

// ERC5115YieldSourceOracleMetaData contains all meta data concerning the ERC5115YieldSourceOracle contract.
var ERC5115YieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetIn\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superLedgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// ERC5115YieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use ERC5115YieldSourceOracleMetaData.ABI instead.
var ERC5115YieldSourceOracleABI = ERC5115YieldSourceOracleMetaData.ABI

// ERC5115YieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type ERC5115YieldSourceOracle struct {
	ERC5115YieldSourceOracleCaller     // Read-only binding to the contract
	ERC5115YieldSourceOracleTransactor // Write-only binding to the contract
	ERC5115YieldSourceOracleFilterer   // Log filterer for contract events
}

// ERC5115YieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type ERC5115YieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC5115YieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ERC5115YieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC5115YieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ERC5115YieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC5115YieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ERC5115YieldSourceOracleSession struct {
	Contract     *ERC5115YieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// ERC5115YieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ERC5115YieldSourceOracleCallerSession struct {
	Contract *ERC5115YieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// ERC5115YieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ERC5115YieldSourceOracleTransactorSession struct {
	Contract     *ERC5115YieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// ERC5115YieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type ERC5115YieldSourceOracleRaw struct {
	Contract *ERC5115YieldSourceOracle // Generic contract binding to access the raw methods on
}

// ERC5115YieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ERC5115YieldSourceOracleCallerRaw struct {
	Contract *ERC5115YieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// ERC5115YieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ERC5115YieldSourceOracleTransactorRaw struct {
	Contract *ERC5115YieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewERC5115YieldSourceOracle creates a new instance of ERC5115YieldSourceOracle, bound to a specific deployed contract.
func NewERC5115YieldSourceOracle(address common.Address, backend bind.ContractBackend) (*ERC5115YieldSourceOracle, error) {
	contract, err := bindERC5115YieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ERC5115YieldSourceOracle{ERC5115YieldSourceOracleCaller: ERC5115YieldSourceOracleCaller{contract: contract}, ERC5115YieldSourceOracleTransactor: ERC5115YieldSourceOracleTransactor{contract: contract}, ERC5115YieldSourceOracleFilterer: ERC5115YieldSourceOracleFilterer{contract: contract}}, nil
}

// NewERC5115YieldSourceOracleCaller creates a new read-only instance of ERC5115YieldSourceOracle, bound to a specific deployed contract.
func NewERC5115YieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*ERC5115YieldSourceOracleCaller, error) {
	contract, err := bindERC5115YieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ERC5115YieldSourceOracleCaller{contract: contract}, nil
}

// NewERC5115YieldSourceOracleTransactor creates a new write-only instance of ERC5115YieldSourceOracle, bound to a specific deployed contract.
func NewERC5115YieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*ERC5115YieldSourceOracleTransactor, error) {
	contract, err := bindERC5115YieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ERC5115YieldSourceOracleTransactor{contract: contract}, nil
}

// NewERC5115YieldSourceOracleFilterer creates a new log filterer instance of ERC5115YieldSourceOracle, bound to a specific deployed contract.
func NewERC5115YieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*ERC5115YieldSourceOracleFilterer, error) {
	contract, err := bindERC5115YieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ERC5115YieldSourceOracleFilterer{contract: contract}, nil
}

// bindERC5115YieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindERC5115YieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ERC5115YieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC5115YieldSourceOracle.Contract.ERC5115YieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC5115YieldSourceOracle.Contract.ERC5115YieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC5115YieldSourceOracle.Contract.ERC5115YieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC5115YieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC5115YieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC5115YieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) Decimals(opts *bind.CallOpts, arg0 common.Address) (uint8, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "decimals", arg0)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) Decimals(arg0 common.Address) (uint8, error) {
	return _ERC5115YieldSourceOracle.Contract.Decimals(&_ERC5115YieldSourceOracle.CallOpts, arg0)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) Decimals(arg0 common.Address) (uint8, error) {
	return _ERC5115YieldSourceOracle.Contract.Decimals(&_ERC5115YieldSourceOracle.CallOpts, arg0)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address assetOut, uint256 sharesIn) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, assetOut common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, assetOut, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address assetOut, uint256 sharesIn) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetAssetOutput(yieldSourceAddress common.Address, assetOut common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetAssetOutput(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, assetOut, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address assetOut, uint256 sharesIn) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, assetOut common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetAssetOutput(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, assetOut, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetAssetOutputWithFees(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetAssetOutputWithFees(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetBalanceOfOwner(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetBalanceOfOwner(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetPricePerShare(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetPricePerShare(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetPricePerShareMultiple(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetPricePerShareMultiple(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, assetIn common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, assetIn, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetShareOutput(yieldSourceAddress common.Address, assetIn common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetShareOutput(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, assetIn, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, assetIn common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetShareOutput(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, assetIn, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVL(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVL(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVLMultiple(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC5115YieldSourceOracle.Contract.GetTVLMultiple(&_ERC5115YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCaller) SuperLedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC5115YieldSourceOracle.contract.Call(opts, &out, "superLedgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleSession) SuperLedgerConfiguration() (common.Address, error) {
	return _ERC5115YieldSourceOracle.Contract.SuperLedgerConfiguration(&_ERC5115YieldSourceOracle.CallOpts)
}

// SuperLedgerConfiguration is a free data retrieval call binding the contract method 0x825e9ec7.
//
// Solidity: function superLedgerConfiguration() view returns(address)
func (_ERC5115YieldSourceOracle *ERC5115YieldSourceOracleCallerSession) SuperLedgerConfiguration() (common.Address, error) {
	return _ERC5115YieldSourceOracle.Contract.SuperLedgerConfiguration(&_ERC5115YieldSourceOracle.CallOpts)
}
