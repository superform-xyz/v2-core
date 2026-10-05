// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ERC20YieldSourceOracle

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

// ERC20YieldSourceOracleMetaData contains all meta data concerning the ERC20YieldSourceOracle contract.
var ERC20YieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"},{\"name\":\"succeeded\",\"type\":\"bool[][]\",\"internalType\":\"bool[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// ERC20YieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use ERC20YieldSourceOracleMetaData.ABI instead.
var ERC20YieldSourceOracleABI = ERC20YieldSourceOracleMetaData.ABI

// ERC20YieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type ERC20YieldSourceOracle struct {
	ERC20YieldSourceOracleCaller     // Read-only binding to the contract
	ERC20YieldSourceOracleTransactor // Write-only binding to the contract
	ERC20YieldSourceOracleFilterer   // Log filterer for contract events
}

// ERC20YieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type ERC20YieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC20YieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ERC20YieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC20YieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ERC20YieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC20YieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ERC20YieldSourceOracleSession struct {
	Contract     *ERC20YieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts           // Call options to use throughout this session
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// ERC20YieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ERC20YieldSourceOracleCallerSession struct {
	Contract *ERC20YieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                 // Call options to use throughout this session
}

// ERC20YieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ERC20YieldSourceOracleTransactorSession struct {
	Contract     *ERC20YieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                 // Transaction auth options to use throughout this session
}

// ERC20YieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type ERC20YieldSourceOracleRaw struct {
	Contract *ERC20YieldSourceOracle // Generic contract binding to access the raw methods on
}

// ERC20YieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ERC20YieldSourceOracleCallerRaw struct {
	Contract *ERC20YieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// ERC20YieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ERC20YieldSourceOracleTransactorRaw struct {
	Contract *ERC20YieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewERC20YieldSourceOracle creates a new instance of ERC20YieldSourceOracle, bound to a specific deployed contract.
func NewERC20YieldSourceOracle(address common.Address, backend bind.ContractBackend) (*ERC20YieldSourceOracle, error) {
	contract, err := bindERC20YieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ERC20YieldSourceOracle{ERC20YieldSourceOracleCaller: ERC20YieldSourceOracleCaller{contract: contract}, ERC20YieldSourceOracleTransactor: ERC20YieldSourceOracleTransactor{contract: contract}, ERC20YieldSourceOracleFilterer: ERC20YieldSourceOracleFilterer{contract: contract}}, nil
}

// NewERC20YieldSourceOracleCaller creates a new read-only instance of ERC20YieldSourceOracle, bound to a specific deployed contract.
func NewERC20YieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*ERC20YieldSourceOracleCaller, error) {
	contract, err := bindERC20YieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ERC20YieldSourceOracleCaller{contract: contract}, nil
}

// NewERC20YieldSourceOracleTransactor creates a new write-only instance of ERC20YieldSourceOracle, bound to a specific deployed contract.
func NewERC20YieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*ERC20YieldSourceOracleTransactor, error) {
	contract, err := bindERC20YieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ERC20YieldSourceOracleTransactor{contract: contract}, nil
}

// NewERC20YieldSourceOracleFilterer creates a new log filterer instance of ERC20YieldSourceOracle, bound to a specific deployed contract.
func NewERC20YieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*ERC20YieldSourceOracleFilterer, error) {
	contract, err := bindERC20YieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ERC20YieldSourceOracleFilterer{contract: contract}, nil
}

// bindERC20YieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindERC20YieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ERC20YieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC20YieldSourceOracle.Contract.ERC20YieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20YieldSourceOracle.Contract.ERC20YieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC20YieldSourceOracle.Contract.ERC20YieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC20YieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20YieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC20YieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _ERC20YieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_ERC20YieldSourceOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _ERC20YieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_ERC20YieldSourceOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _ERC20YieldSourceOracle.Contract.Decimals(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _ERC20YieldSourceOracle.Contract.Decimals(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", arg0, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetAssetOutput(&_ERC20YieldSourceOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetAssetOutput(&_ERC20YieldSourceOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", arg0, yieldSourceAddress, assetOut, arg3, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetAssetOutputWithFees(arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetAssetOutputWithFees(&_ERC20YieldSourceOracle.CallOpts, arg0, yieldSourceAddress, assetOut, arg3, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetAssetOutputWithFees(arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetAssetOutputWithFees(&_ERC20YieldSourceOracle.CallOpts, arg0, yieldSourceAddress, assetOut, arg3, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetBalanceOfOwner(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetBalanceOfOwner(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetPricePerShare(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetPricePerShare(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetPricePerShareMultiple(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetPricePerShareMultiple(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetShareOutput(&_ERC20YieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetShareOutput(&_ERC20YieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVL(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVL(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

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
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVLMultiple(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetTVLMultiple(&_ERC20YieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ERC20YieldSourceOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleSession) GetWithdrawalShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetWithdrawalShareOutput(&_ERC20YieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_ERC20YieldSourceOracle *ERC20YieldSourceOracleCallerSession) GetWithdrawalShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _ERC20YieldSourceOracle.Contract.GetWithdrawalShareOutput(&_ERC20YieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}
