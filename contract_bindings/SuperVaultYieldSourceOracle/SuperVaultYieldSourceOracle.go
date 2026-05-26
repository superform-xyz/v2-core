// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperVaultYieldSourceOracle

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

// SuperVaultYieldSourceOracleMetaData contains all meta data concerning the SuperVaultYieldSourceOracle contract.
var SuperVaultYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// SuperVaultYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperVaultYieldSourceOracleMetaData.ABI instead.
var SuperVaultYieldSourceOracleABI = SuperVaultYieldSourceOracleMetaData.ABI

// SuperVaultYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type SuperVaultYieldSourceOracle struct {
	SuperVaultYieldSourceOracleCaller     // Read-only binding to the contract
	SuperVaultYieldSourceOracleTransactor // Write-only binding to the contract
	SuperVaultYieldSourceOracleFilterer   // Log filterer for contract events
}

// SuperVaultYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperVaultYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperVaultYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperVaultYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperVaultYieldSourceOracleSession struct {
	Contract     *SuperVaultYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                // Call options to use throughout this session
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// SuperVaultYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperVaultYieldSourceOracleCallerSession struct {
	Contract *SuperVaultYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                      // Call options to use throughout this session
}

// SuperVaultYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperVaultYieldSourceOracleTransactorSession struct {
	Contract     *SuperVaultYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                      // Transaction auth options to use throughout this session
}

// SuperVaultYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperVaultYieldSourceOracleRaw struct {
	Contract *SuperVaultYieldSourceOracle // Generic contract binding to access the raw methods on
}

// SuperVaultYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperVaultYieldSourceOracleCallerRaw struct {
	Contract *SuperVaultYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// SuperVaultYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperVaultYieldSourceOracleTransactorRaw struct {
	Contract *SuperVaultYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperVaultYieldSourceOracle creates a new instance of SuperVaultYieldSourceOracle, bound to a specific deployed contract.
func NewSuperVaultYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*SuperVaultYieldSourceOracle, error) {
	contract, err := bindSuperVaultYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperVaultYieldSourceOracle{SuperVaultYieldSourceOracleCaller: SuperVaultYieldSourceOracleCaller{contract: contract}, SuperVaultYieldSourceOracleTransactor: SuperVaultYieldSourceOracleTransactor{contract: contract}, SuperVaultYieldSourceOracleFilterer: SuperVaultYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewSuperVaultYieldSourceOracleCaller creates a new read-only instance of SuperVaultYieldSourceOracle, bound to a specific deployed contract.
func NewSuperVaultYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*SuperVaultYieldSourceOracleCaller, error) {
	contract, err := bindSuperVaultYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultYieldSourceOracleCaller{contract: contract}, nil
}

// NewSuperVaultYieldSourceOracleTransactor creates a new write-only instance of SuperVaultYieldSourceOracle, bound to a specific deployed contract.
func NewSuperVaultYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperVaultYieldSourceOracleTransactor, error) {
	contract, err := bindSuperVaultYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultYieldSourceOracleTransactor{contract: contract}, nil
}

// NewSuperVaultYieldSourceOracleFilterer creates a new log filterer instance of SuperVaultYieldSourceOracle, bound to a specific deployed contract.
func NewSuperVaultYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperVaultYieldSourceOracleFilterer, error) {
	contract, err := bindSuperVaultYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperVaultYieldSourceOracleFilterer{contract: contract}, nil
}

// bindSuperVaultYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindSuperVaultYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperVaultYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultYieldSourceOracle.Contract.SuperVaultYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultYieldSourceOracle.Contract.SuperVaultYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultYieldSourceOracle.Contract.SuperVaultYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _SuperVaultYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_SuperVaultYieldSourceOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _SuperVaultYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_SuperVaultYieldSourceOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _SuperVaultYieldSourceOracle.Contract.Decimals(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _SuperVaultYieldSourceOracle.Contract.Decimals(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetAssetOutput(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetAssetOutput(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetAssetOutputWithFees(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetAssetOutputWithFees(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetBalanceOfOwner(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetBalanceOfOwner(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetPricePerShare(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetPricePerShare(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetPricePerShareMultiple(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetPricePerShareMultiple(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetShareOutput(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetShareOutput(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVL(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVL(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVLMultiple(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetTVLMultiple(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultYieldSourceOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_SuperVaultYieldSourceOracle *SuperVaultYieldSourceOracleCallerSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _SuperVaultYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_SuperVaultYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}
