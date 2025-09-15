// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package MockYieldSourceOracle

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

// MockYieldSourceOracleMetaData contains all meta data concerning the MockYieldSourceOracle contract.
var MockYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_pricePerShare\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_tvlByOwner\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_validity\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSources\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pricePerShare\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"setPricePerShare\",\"inputs\":[{\"name\":\"_pricePerShare\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setTVL\",\"inputs\":[{\"name\":\"_tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setTVLByOwner\",\"inputs\":[{\"name\":\"_tvlByOwner\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setValidAsset\",\"inputs\":[{\"name\":\"asset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isValid\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setValidity\",\"inputs\":[{\"name\":\"_validity\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"tvl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"tvlByOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"validAssetMap\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"validity\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]}]",
}

// MockYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use MockYieldSourceOracleMetaData.ABI instead.
var MockYieldSourceOracleABI = MockYieldSourceOracleMetaData.ABI

// MockYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type MockYieldSourceOracle struct {
	MockYieldSourceOracleCaller     // Read-only binding to the contract
	MockYieldSourceOracleTransactor // Write-only binding to the contract
	MockYieldSourceOracleFilterer   // Log filterer for contract events
}

// MockYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type MockYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type MockYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type MockYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// MockYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type MockYieldSourceOracleSession struct {
	Contract     *MockYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts          // Call options to use throughout this session
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// MockYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type MockYieldSourceOracleCallerSession struct {
	Contract *MockYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                // Call options to use throughout this session
}

// MockYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type MockYieldSourceOracleTransactorSession struct {
	Contract     *MockYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                // Transaction auth options to use throughout this session
}

// MockYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type MockYieldSourceOracleRaw struct {
	Contract *MockYieldSourceOracle // Generic contract binding to access the raw methods on
}

// MockYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type MockYieldSourceOracleCallerRaw struct {
	Contract *MockYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// MockYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type MockYieldSourceOracleTransactorRaw struct {
	Contract *MockYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewMockYieldSourceOracle creates a new instance of MockYieldSourceOracle, bound to a specific deployed contract.
func NewMockYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*MockYieldSourceOracle, error) {
	contract, err := bindMockYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &MockYieldSourceOracle{MockYieldSourceOracleCaller: MockYieldSourceOracleCaller{contract: contract}, MockYieldSourceOracleTransactor: MockYieldSourceOracleTransactor{contract: contract}, MockYieldSourceOracleFilterer: MockYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewMockYieldSourceOracleCaller creates a new read-only instance of MockYieldSourceOracle, bound to a specific deployed contract.
func NewMockYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*MockYieldSourceOracleCaller, error) {
	contract, err := bindMockYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &MockYieldSourceOracleCaller{contract: contract}, nil
}

// NewMockYieldSourceOracleTransactor creates a new write-only instance of MockYieldSourceOracle, bound to a specific deployed contract.
func NewMockYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*MockYieldSourceOracleTransactor, error) {
	contract, err := bindMockYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &MockYieldSourceOracleTransactor{contract: contract}, nil
}

// NewMockYieldSourceOracleFilterer creates a new log filterer instance of MockYieldSourceOracle, bound to a specific deployed contract.
func NewMockYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*MockYieldSourceOracleFilterer, error) {
	contract, err := bindMockYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &MockYieldSourceOracleFilterer{contract: contract}, nil
}

// bindMockYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindMockYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := MockYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MockYieldSourceOracle *MockYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MockYieldSourceOracle.Contract.MockYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MockYieldSourceOracle *MockYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.MockYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MockYieldSourceOracle *MockYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.MockYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _MockYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, arg0 common.Address) (uint8, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "decimals", arg0)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) Decimals(arg0 common.Address) (uint8, error) {
	return _MockYieldSourceOracle.Contract.Decimals(&_MockYieldSourceOracle.CallOpts, arg0)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) Decimals(arg0 common.Address) (uint8, error) {
	return _MockYieldSourceOracle.Contract.Decimals(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", arg0, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetAssetOutput(&_MockYieldSourceOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetAssetOutput(&_MockYieldSourceOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address , address , address , uint256 sharesIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, arg0 [32]byte, arg1 common.Address, arg2 common.Address, arg3 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", arg0, arg1, arg2, arg3, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address , address , address , uint256 sharesIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetAssetOutputWithFees(arg0 [32]byte, arg1 common.Address, arg2 common.Address, arg3 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetAssetOutputWithFees(&_MockYieldSourceOracle.CallOpts, arg0, arg1, arg2, arg3, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address , address , address , uint256 sharesIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetAssetOutputWithFees(arg0 [32]byte, arg1 common.Address, arg2 common.Address, arg3 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetAssetOutputWithFees(&_MockYieldSourceOracle.CallOpts, arg0, arg1, arg2, arg3, sharesIn)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address , address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", arg0, arg1)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address , address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetBalanceOfOwner(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetBalanceOfOwner(&_MockYieldSourceOracle.CallOpts, arg0, arg1)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address , address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetBalanceOfOwner(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetBalanceOfOwner(&_MockYieldSourceOracle.CallOpts, arg0, arg1)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, arg0 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetPricePerShare(arg0 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetPricePerShare(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetPricePerShare(arg0 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetPricePerShare(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] ) view returns(uint256[])
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, arg0 []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", arg0)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] ) view returns(uint256[])
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetPricePerShareMultiple(arg0 []common.Address) ([]*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetPricePerShareMultiple(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] ) view returns(uint256[])
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetPricePerShareMultiple(arg0 []common.Address) ([]*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetPricePerShareMultiple(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetShareOutput(&_MockYieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetShareOutput(&_MockYieldSourceOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, arg0 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getTVL", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetTVL(arg0 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVL(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetTVL(arg0 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVL(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address , address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", arg0, arg1)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address , address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetTVLByOwnerOfShares(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_MockYieldSourceOracle.CallOpts, arg0, arg1)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address , address ) view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(arg0 common.Address, arg1 common.Address) (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_MockYieldSourceOracle.CallOpts, arg0, arg1)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSources, address[][] ) view returns(uint256[][])
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSources []common.Address, arg1 [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSources, arg1)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSources, address[][] ) view returns(uint256[][])
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSources []common.Address, arg1 [][]common.Address) ([][]*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_MockYieldSourceOracle.CallOpts, yieldSources, arg1)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSources, address[][] ) view returns(uint256[][])
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSources []common.Address, arg1 [][]common.Address) ([][]*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_MockYieldSourceOracle.CallOpts, yieldSources, arg1)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] ) view returns(uint256[])
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, arg0 []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", arg0)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] ) view returns(uint256[])
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) GetTVLMultiple(arg0 []common.Address) ([]*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVLMultiple(&_MockYieldSourceOracle.CallOpts, arg0)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] ) view returns(uint256[])
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) GetTVLMultiple(arg0 []common.Address) ([]*big.Int, error) {
	return _MockYieldSourceOracle.Contract.GetTVLMultiple(&_MockYieldSourceOracle.CallOpts, arg0)
}

// PricePerShare is a free data retrieval call binding the contract method 0x99530b06.
//
// Solidity: function pricePerShare() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) PricePerShare(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "pricePerShare")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PricePerShare is a free data retrieval call binding the contract method 0x99530b06.
//
// Solidity: function pricePerShare() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) PricePerShare() (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.PricePerShare(&_MockYieldSourceOracle.CallOpts)
}

// PricePerShare is a free data retrieval call binding the contract method 0x99530b06.
//
// Solidity: function pricePerShare() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) PricePerShare() (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.PricePerShare(&_MockYieldSourceOracle.CallOpts)
}

// Tvl is a free data retrieval call binding the contract method 0xe5328e06.
//
// Solidity: function tvl() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) Tvl(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "tvl")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Tvl is a free data retrieval call binding the contract method 0xe5328e06.
//
// Solidity: function tvl() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) Tvl() (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.Tvl(&_MockYieldSourceOracle.CallOpts)
}

// Tvl is a free data retrieval call binding the contract method 0xe5328e06.
//
// Solidity: function tvl() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) Tvl() (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.Tvl(&_MockYieldSourceOracle.CallOpts)
}

// TvlByOwner is a free data retrieval call binding the contract method 0xffd3d904.
//
// Solidity: function tvlByOwner() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) TvlByOwner(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "tvlByOwner")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TvlByOwner is a free data retrieval call binding the contract method 0xffd3d904.
//
// Solidity: function tvlByOwner() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) TvlByOwner() (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.TvlByOwner(&_MockYieldSourceOracle.CallOpts)
}

// TvlByOwner is a free data retrieval call binding the contract method 0xffd3d904.
//
// Solidity: function tvlByOwner() view returns(uint256)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) TvlByOwner() (*big.Int, error) {
	return _MockYieldSourceOracle.Contract.TvlByOwner(&_MockYieldSourceOracle.CallOpts)
}

// ValidAssetMap is a free data retrieval call binding the contract method 0xfaea9b66.
//
// Solidity: function validAssetMap(address ) view returns(bool)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) ValidAssetMap(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "validAssetMap", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ValidAssetMap is a free data retrieval call binding the contract method 0xfaea9b66.
//
// Solidity: function validAssetMap(address ) view returns(bool)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) ValidAssetMap(arg0 common.Address) (bool, error) {
	return _MockYieldSourceOracle.Contract.ValidAssetMap(&_MockYieldSourceOracle.CallOpts, arg0)
}

// ValidAssetMap is a free data retrieval call binding the contract method 0xfaea9b66.
//
// Solidity: function validAssetMap(address ) view returns(bool)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) ValidAssetMap(arg0 common.Address) (bool, error) {
	return _MockYieldSourceOracle.Contract.ValidAssetMap(&_MockYieldSourceOracle.CallOpts, arg0)
}

// Validity is a free data retrieval call binding the contract method 0x3e98d1fb.
//
// Solidity: function validity() view returns(bool)
func (_MockYieldSourceOracle *MockYieldSourceOracleCaller) Validity(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _MockYieldSourceOracle.contract.Call(opts, &out, "validity")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Validity is a free data retrieval call binding the contract method 0x3e98d1fb.
//
// Solidity: function validity() view returns(bool)
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) Validity() (bool, error) {
	return _MockYieldSourceOracle.Contract.Validity(&_MockYieldSourceOracle.CallOpts)
}

// Validity is a free data retrieval call binding the contract method 0x3e98d1fb.
//
// Solidity: function validity() view returns(bool)
func (_MockYieldSourceOracle *MockYieldSourceOracleCallerSession) Validity() (bool, error) {
	return _MockYieldSourceOracle.Contract.Validity(&_MockYieldSourceOracle.CallOpts)
}

// SetPricePerShare is a paid mutator transaction binding the contract method 0x118c9a07.
//
// Solidity: function setPricePerShare(uint256 _pricePerShare) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactor) SetPricePerShare(opts *bind.TransactOpts, _pricePerShare *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.contract.Transact(opts, "setPricePerShare", _pricePerShare)
}

// SetPricePerShare is a paid mutator transaction binding the contract method 0x118c9a07.
//
// Solidity: function setPricePerShare(uint256 _pricePerShare) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) SetPricePerShare(_pricePerShare *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetPricePerShare(&_MockYieldSourceOracle.TransactOpts, _pricePerShare)
}

// SetPricePerShare is a paid mutator transaction binding the contract method 0x118c9a07.
//
// Solidity: function setPricePerShare(uint256 _pricePerShare) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactorSession) SetPricePerShare(_pricePerShare *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetPricePerShare(&_MockYieldSourceOracle.TransactOpts, _pricePerShare)
}

// SetTVL is a paid mutator transaction binding the contract method 0x05ebd4a7.
//
// Solidity: function setTVL(uint256 _tvl) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactor) SetTVL(opts *bind.TransactOpts, _tvl *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.contract.Transact(opts, "setTVL", _tvl)
}

// SetTVL is a paid mutator transaction binding the contract method 0x05ebd4a7.
//
// Solidity: function setTVL(uint256 _tvl) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) SetTVL(_tvl *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetTVL(&_MockYieldSourceOracle.TransactOpts, _tvl)
}

// SetTVL is a paid mutator transaction binding the contract method 0x05ebd4a7.
//
// Solidity: function setTVL(uint256 _tvl) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactorSession) SetTVL(_tvl *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetTVL(&_MockYieldSourceOracle.TransactOpts, _tvl)
}

// SetTVLByOwner is a paid mutator transaction binding the contract method 0x236bb3b3.
//
// Solidity: function setTVLByOwner(uint256 _tvlByOwner) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactor) SetTVLByOwner(opts *bind.TransactOpts, _tvlByOwner *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.contract.Transact(opts, "setTVLByOwner", _tvlByOwner)
}

// SetTVLByOwner is a paid mutator transaction binding the contract method 0x236bb3b3.
//
// Solidity: function setTVLByOwner(uint256 _tvlByOwner) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) SetTVLByOwner(_tvlByOwner *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetTVLByOwner(&_MockYieldSourceOracle.TransactOpts, _tvlByOwner)
}

// SetTVLByOwner is a paid mutator transaction binding the contract method 0x236bb3b3.
//
// Solidity: function setTVLByOwner(uint256 _tvlByOwner) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactorSession) SetTVLByOwner(_tvlByOwner *big.Int) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetTVLByOwner(&_MockYieldSourceOracle.TransactOpts, _tvlByOwner)
}

// SetValidAsset is a paid mutator transaction binding the contract method 0xcb46fa63.
//
// Solidity: function setValidAsset(address asset, bool isValid) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactor) SetValidAsset(opts *bind.TransactOpts, asset common.Address, isValid bool) (*types.Transaction, error) {
	return _MockYieldSourceOracle.contract.Transact(opts, "setValidAsset", asset, isValid)
}

// SetValidAsset is a paid mutator transaction binding the contract method 0xcb46fa63.
//
// Solidity: function setValidAsset(address asset, bool isValid) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) SetValidAsset(asset common.Address, isValid bool) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetValidAsset(&_MockYieldSourceOracle.TransactOpts, asset, isValid)
}

// SetValidAsset is a paid mutator transaction binding the contract method 0xcb46fa63.
//
// Solidity: function setValidAsset(address asset, bool isValid) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactorSession) SetValidAsset(asset common.Address, isValid bool) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetValidAsset(&_MockYieldSourceOracle.TransactOpts, asset, isValid)
}

// SetValidity is a paid mutator transaction binding the contract method 0xb8a35a01.
//
// Solidity: function setValidity(bool _validity) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactor) SetValidity(opts *bind.TransactOpts, _validity bool) (*types.Transaction, error) {
	return _MockYieldSourceOracle.contract.Transact(opts, "setValidity", _validity)
}

// SetValidity is a paid mutator transaction binding the contract method 0xb8a35a01.
//
// Solidity: function setValidity(bool _validity) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleSession) SetValidity(_validity bool) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetValidity(&_MockYieldSourceOracle.TransactOpts, _validity)
}

// SetValidity is a paid mutator transaction binding the contract method 0xb8a35a01.
//
// Solidity: function setValidity(bool _validity) returns()
func (_MockYieldSourceOracle *MockYieldSourceOracleTransactorSession) SetValidity(_validity bool) (*types.Transaction, error) {
	return _MockYieldSourceOracle.Contract.SetValidity(&_MockYieldSourceOracle.TransactOpts, _validity)
}
