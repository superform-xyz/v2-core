// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package EulerDebtOracle

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

// EulerDebtOracleMetaData contains all meta data concerning the EulerDebtOracle contract.
var EulerDebtOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"},{\"name\":\"succeeded\",\"type\":\"bool[][]\",\"internalType\":\"bool[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// EulerDebtOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use EulerDebtOracleMetaData.ABI instead.
var EulerDebtOracleABI = EulerDebtOracleMetaData.ABI

// EulerDebtOracle is an auto generated Go binding around an Ethereum contract.
type EulerDebtOracle struct {
	EulerDebtOracleCaller     // Read-only binding to the contract
	EulerDebtOracleTransactor // Write-only binding to the contract
	EulerDebtOracleFilterer   // Log filterer for contract events
}

// EulerDebtOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type EulerDebtOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// EulerDebtOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type EulerDebtOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// EulerDebtOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type EulerDebtOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// EulerDebtOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type EulerDebtOracleSession struct {
	Contract     *EulerDebtOracle  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// EulerDebtOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type EulerDebtOracleCallerSession struct {
	Contract *EulerDebtOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// EulerDebtOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type EulerDebtOracleTransactorSession struct {
	Contract     *EulerDebtOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// EulerDebtOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type EulerDebtOracleRaw struct {
	Contract *EulerDebtOracle // Generic contract binding to access the raw methods on
}

// EulerDebtOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type EulerDebtOracleCallerRaw struct {
	Contract *EulerDebtOracleCaller // Generic read-only contract binding to access the raw methods on
}

// EulerDebtOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type EulerDebtOracleTransactorRaw struct {
	Contract *EulerDebtOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewEulerDebtOracle creates a new instance of EulerDebtOracle, bound to a specific deployed contract.
func NewEulerDebtOracle(address common.Address, backend bind.ContractBackend) (*EulerDebtOracle, error) {
	contract, err := bindEulerDebtOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &EulerDebtOracle{EulerDebtOracleCaller: EulerDebtOracleCaller{contract: contract}, EulerDebtOracleTransactor: EulerDebtOracleTransactor{contract: contract}, EulerDebtOracleFilterer: EulerDebtOracleFilterer{contract: contract}}, nil
}

// NewEulerDebtOracleCaller creates a new read-only instance of EulerDebtOracle, bound to a specific deployed contract.
func NewEulerDebtOracleCaller(address common.Address, caller bind.ContractCaller) (*EulerDebtOracleCaller, error) {
	contract, err := bindEulerDebtOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &EulerDebtOracleCaller{contract: contract}, nil
}

// NewEulerDebtOracleTransactor creates a new write-only instance of EulerDebtOracle, bound to a specific deployed contract.
func NewEulerDebtOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*EulerDebtOracleTransactor, error) {
	contract, err := bindEulerDebtOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &EulerDebtOracleTransactor{contract: contract}, nil
}

// NewEulerDebtOracleFilterer creates a new log filterer instance of EulerDebtOracle, bound to a specific deployed contract.
func NewEulerDebtOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*EulerDebtOracleFilterer, error) {
	contract, err := bindEulerDebtOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &EulerDebtOracleFilterer{contract: contract}, nil
}

// bindEulerDebtOracle binds a generic wrapper to an already deployed contract.
func bindEulerDebtOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := EulerDebtOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_EulerDebtOracle *EulerDebtOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _EulerDebtOracle.Contract.EulerDebtOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_EulerDebtOracle *EulerDebtOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _EulerDebtOracle.Contract.EulerDebtOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_EulerDebtOracle *EulerDebtOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _EulerDebtOracle.Contract.EulerDebtOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_EulerDebtOracle *EulerDebtOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _EulerDebtOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_EulerDebtOracle *EulerDebtOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _EulerDebtOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_EulerDebtOracle *EulerDebtOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _EulerDebtOracle.Contract.contract.Transact(opts, method, params...)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_EulerDebtOracle *EulerDebtOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_EulerDebtOracle *EulerDebtOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _EulerDebtOracle.Contract.SUPERLEDGERCONFIGURATION(&_EulerDebtOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _EulerDebtOracle.Contract.SUPERLEDGERCONFIGURATION(&_EulerDebtOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_EulerDebtOracle *EulerDebtOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_EulerDebtOracle *EulerDebtOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _EulerDebtOracle.Contract.Decimals(&_EulerDebtOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _EulerDebtOracle.Contract.Decimals(&_EulerDebtOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetAssetOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getAssetOutput", arg0, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetAssetOutput(&_EulerDebtOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetAssetOutput(&_EulerDebtOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetAssetOutputWithFees(&_EulerDebtOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetAssetOutputWithFees(&_EulerDebtOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetBalanceOfOwner(&_EulerDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetBalanceOfOwner(&_EulerDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetPricePerShare(&_EulerDebtOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetPricePerShare(&_EulerDebtOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_EulerDebtOracle *EulerDebtOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _EulerDebtOracle.Contract.GetPricePerShareMultiple(&_EulerDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _EulerDebtOracle.Contract.GetPricePerShareMultiple(&_EulerDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetShareOutput(&_EulerDebtOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetShareOutput(&_EulerDebtOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetTVL(&_EulerDebtOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetTVL(&_EulerDebtOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetTVLByOwnerOfShares(&_EulerDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetTVLByOwnerOfShares(&_EulerDebtOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

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
func (_EulerDebtOracle *EulerDebtOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _EulerDebtOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_EulerDebtOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _EulerDebtOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_EulerDebtOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_EulerDebtOracle *EulerDebtOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _EulerDebtOracle.Contract.GetTVLMultiple(&_EulerDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _EulerDebtOracle.Contract.GetTVLMultiple(&_EulerDebtOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _EulerDebtOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleSession) GetWithdrawalShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetWithdrawalShareOutput(&_EulerDebtOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_EulerDebtOracle *EulerDebtOracleCallerSession) GetWithdrawalShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _EulerDebtOracle.Contract.GetWithdrawalShareOutput(&_EulerDebtOracle.CallOpts, arg0, arg1, assetsIn)
}
