// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperAssetFactory

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

// ISuperAssetFactoryAssetCreationParams is an auto generated low-level Go binding around an user-defined struct.
type ISuperAssetFactoryAssetCreationParams struct {
	Name                         string
	Symbol                       string
	SwapFeeInPercentage          *big.Int
	SwapFeeOutPercentage         *big.Int
	Asset                        common.Address
	SuperAssetManager            common.Address
	SuperAssetStrategist         common.Address
	IncentiveFundManager         common.Address
	IncentiveCalculationContract common.Address
	TokenInIncentive             common.Address
	TokenOutIncentive            common.Address
}

// SuperAssetFactoryMetaData contains all meta data concerning the SuperAssetFactory contract.
var SuperAssetFactoryMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_superGovernor\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addICCToWhitelist\",\"inputs\":[{\"name\":\"icc\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"createSuperAsset\",\"inputs\":[{\"name\":\"params\",\"type\":\"tuple\",\"internalType\":\"structISuperAssetFactory.AssetCreationParams\",\"components\":[{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"swapFeeInPercentage\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFeeOutPercentage\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"asset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superAssetManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superAssetStrategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveFundManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveCalculationContract\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokenInIncentive\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokenOutIncentive\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveFundContract\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"data\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"superAssetStrategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superAssetManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveFundManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveCalculationContract\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveFundContract\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getIncentiveCalculationContract\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getIncentiveFundContract\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getIncentiveFundManager\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getSuperAssetManager\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getSuperAssetStrategist\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"incentiveCalculationContractsWhitelist\",\"inputs\":[{\"name\":\"icc\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isValid\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"incentiveFundImplementation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isICCWhitelisted\",\"inputs\":[{\"name\":\"icc\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"removeICCFromWhitelist\",\"inputs\":[{\"name\":\"icc\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setIncentiveCalculationContract\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_incentiveCalculationContract\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setIncentiveFundManager\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_incentiveFundManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSuperAssetManager\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_superAssetManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSuperAssetStrategist\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_superAssetStrategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superAssetImplementation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superGovernor\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"SuperAssetCreated\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"incentiveFund\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"incentiveCalc\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"name\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"FailedDeployment\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ICC_NOT_WHITELISTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InsufficientBalance\",\"inputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperAssetFactoryABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperAssetFactoryMetaData.ABI instead.
var SuperAssetFactoryABI = SuperAssetFactoryMetaData.ABI

// SuperAssetFactory is an auto generated Go binding around an Ethereum contract.
type SuperAssetFactory struct {
	SuperAssetFactoryCaller     // Read-only binding to the contract
	SuperAssetFactoryTransactor // Write-only binding to the contract
	SuperAssetFactoryFilterer   // Log filterer for contract events
}

// SuperAssetFactoryCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperAssetFactoryCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetFactoryTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperAssetFactoryTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetFactoryFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperAssetFactoryFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetFactorySession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperAssetFactorySession struct {
	Contract     *SuperAssetFactory // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// SuperAssetFactoryCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperAssetFactoryCallerSession struct {
	Contract *SuperAssetFactoryCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// SuperAssetFactoryTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperAssetFactoryTransactorSession struct {
	Contract     *SuperAssetFactoryTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// SuperAssetFactoryRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperAssetFactoryRaw struct {
	Contract *SuperAssetFactory // Generic contract binding to access the raw methods on
}

// SuperAssetFactoryCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperAssetFactoryCallerRaw struct {
	Contract *SuperAssetFactoryCaller // Generic read-only contract binding to access the raw methods on
}

// SuperAssetFactoryTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperAssetFactoryTransactorRaw struct {
	Contract *SuperAssetFactoryTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperAssetFactory creates a new instance of SuperAssetFactory, bound to a specific deployed contract.
func NewSuperAssetFactory(address common.Address, backend bind.ContractBackend) (*SuperAssetFactory, error) {
	contract, err := bindSuperAssetFactory(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactory{SuperAssetFactoryCaller: SuperAssetFactoryCaller{contract: contract}, SuperAssetFactoryTransactor: SuperAssetFactoryTransactor{contract: contract}, SuperAssetFactoryFilterer: SuperAssetFactoryFilterer{contract: contract}}, nil
}

// NewSuperAssetFactoryCaller creates a new read-only instance of SuperAssetFactory, bound to a specific deployed contract.
func NewSuperAssetFactoryCaller(address common.Address, caller bind.ContractCaller) (*SuperAssetFactoryCaller, error) {
	contract, err := bindSuperAssetFactory(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactoryCaller{contract: contract}, nil
}

// NewSuperAssetFactoryTransactor creates a new write-only instance of SuperAssetFactory, bound to a specific deployed contract.
func NewSuperAssetFactoryTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperAssetFactoryTransactor, error) {
	contract, err := bindSuperAssetFactory(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactoryTransactor{contract: contract}, nil
}

// NewSuperAssetFactoryFilterer creates a new log filterer instance of SuperAssetFactory, bound to a specific deployed contract.
func NewSuperAssetFactoryFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperAssetFactoryFilterer, error) {
	contract, err := bindSuperAssetFactory(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactoryFilterer{contract: contract}, nil
}

// bindSuperAssetFactory binds a generic wrapper to an already deployed contract.
func bindSuperAssetFactory(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperAssetFactoryMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperAssetFactory *SuperAssetFactoryRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperAssetFactory.Contract.SuperAssetFactoryCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperAssetFactory *SuperAssetFactoryRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SuperAssetFactoryTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperAssetFactory *SuperAssetFactoryRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SuperAssetFactoryTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperAssetFactory *SuperAssetFactoryCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperAssetFactory.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperAssetFactory *SuperAssetFactoryTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperAssetFactory *SuperAssetFactoryTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.contract.Transact(opts, method, params...)
}

// Data is a free data retrieval call binding the contract method 0xb90d3d0c.
//
// Solidity: function data(address superAsset) view returns(address superAssetStrategist, address superAssetManager, address incentiveFundManager, address incentiveCalculationContract, address incentiveFundContract)
func (_SuperAssetFactory *SuperAssetFactoryCaller) Data(opts *bind.CallOpts, superAsset common.Address) (struct {
	SuperAssetStrategist         common.Address
	SuperAssetManager            common.Address
	IncentiveFundManager         common.Address
	IncentiveCalculationContract common.Address
	IncentiveFundContract        common.Address
}, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "data", superAsset)

	outstruct := new(struct {
		SuperAssetStrategist         common.Address
		SuperAssetManager            common.Address
		IncentiveFundManager         common.Address
		IncentiveCalculationContract common.Address
		IncentiveFundContract        common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.SuperAssetStrategist = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.SuperAssetManager = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.IncentiveFundManager = *abi.ConvertType(out[2], new(common.Address)).(*common.Address)
	outstruct.IncentiveCalculationContract = *abi.ConvertType(out[3], new(common.Address)).(*common.Address)
	outstruct.IncentiveFundContract = *abi.ConvertType(out[4], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// Data is a free data retrieval call binding the contract method 0xb90d3d0c.
//
// Solidity: function data(address superAsset) view returns(address superAssetStrategist, address superAssetManager, address incentiveFundManager, address incentiveCalculationContract, address incentiveFundContract)
func (_SuperAssetFactory *SuperAssetFactorySession) Data(superAsset common.Address) (struct {
	SuperAssetStrategist         common.Address
	SuperAssetManager            common.Address
	IncentiveFundManager         common.Address
	IncentiveCalculationContract common.Address
	IncentiveFundContract        common.Address
}, error) {
	return _SuperAssetFactory.Contract.Data(&_SuperAssetFactory.CallOpts, superAsset)
}

// Data is a free data retrieval call binding the contract method 0xb90d3d0c.
//
// Solidity: function data(address superAsset) view returns(address superAssetStrategist, address superAssetManager, address incentiveFundManager, address incentiveCalculationContract, address incentiveFundContract)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) Data(superAsset common.Address) (struct {
	SuperAssetStrategist         common.Address
	SuperAssetManager            common.Address
	IncentiveFundManager         common.Address
	IncentiveCalculationContract common.Address
	IncentiveFundContract        common.Address
}, error) {
	return _SuperAssetFactory.Contract.Data(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetIncentiveCalculationContract is a free data retrieval call binding the contract method 0x49252552.
//
// Solidity: function getIncentiveCalculationContract(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) GetIncentiveCalculationContract(opts *bind.CallOpts, superAsset common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "getIncentiveCalculationContract", superAsset)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetIncentiveCalculationContract is a free data retrieval call binding the contract method 0x49252552.
//
// Solidity: function getIncentiveCalculationContract(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) GetIncentiveCalculationContract(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetIncentiveCalculationContract(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetIncentiveCalculationContract is a free data retrieval call binding the contract method 0x49252552.
//
// Solidity: function getIncentiveCalculationContract(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) GetIncentiveCalculationContract(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetIncentiveCalculationContract(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetIncentiveFundContract is a free data retrieval call binding the contract method 0xcaaf7e54.
//
// Solidity: function getIncentiveFundContract(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) GetIncentiveFundContract(opts *bind.CallOpts, superAsset common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "getIncentiveFundContract", superAsset)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetIncentiveFundContract is a free data retrieval call binding the contract method 0xcaaf7e54.
//
// Solidity: function getIncentiveFundContract(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) GetIncentiveFundContract(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetIncentiveFundContract(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetIncentiveFundContract is a free data retrieval call binding the contract method 0xcaaf7e54.
//
// Solidity: function getIncentiveFundContract(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) GetIncentiveFundContract(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetIncentiveFundContract(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetIncentiveFundManager is a free data retrieval call binding the contract method 0x3adcaeb9.
//
// Solidity: function getIncentiveFundManager(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) GetIncentiveFundManager(opts *bind.CallOpts, superAsset common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "getIncentiveFundManager", superAsset)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetIncentiveFundManager is a free data retrieval call binding the contract method 0x3adcaeb9.
//
// Solidity: function getIncentiveFundManager(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) GetIncentiveFundManager(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetIncentiveFundManager(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetIncentiveFundManager is a free data retrieval call binding the contract method 0x3adcaeb9.
//
// Solidity: function getIncentiveFundManager(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) GetIncentiveFundManager(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetIncentiveFundManager(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetSuperAssetManager is a free data retrieval call binding the contract method 0xa774b2e0.
//
// Solidity: function getSuperAssetManager(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) GetSuperAssetManager(opts *bind.CallOpts, superAsset common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "getSuperAssetManager", superAsset)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetSuperAssetManager is a free data retrieval call binding the contract method 0xa774b2e0.
//
// Solidity: function getSuperAssetManager(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) GetSuperAssetManager(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetSuperAssetManager(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetSuperAssetManager is a free data retrieval call binding the contract method 0xa774b2e0.
//
// Solidity: function getSuperAssetManager(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) GetSuperAssetManager(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetSuperAssetManager(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetSuperAssetStrategist is a free data retrieval call binding the contract method 0xd18026c1.
//
// Solidity: function getSuperAssetStrategist(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) GetSuperAssetStrategist(opts *bind.CallOpts, superAsset common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "getSuperAssetStrategist", superAsset)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetSuperAssetStrategist is a free data retrieval call binding the contract method 0xd18026c1.
//
// Solidity: function getSuperAssetStrategist(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) GetSuperAssetStrategist(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetSuperAssetStrategist(&_SuperAssetFactory.CallOpts, superAsset)
}

// GetSuperAssetStrategist is a free data retrieval call binding the contract method 0xd18026c1.
//
// Solidity: function getSuperAssetStrategist(address superAsset) view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) GetSuperAssetStrategist(superAsset common.Address) (common.Address, error) {
	return _SuperAssetFactory.Contract.GetSuperAssetStrategist(&_SuperAssetFactory.CallOpts, superAsset)
}

// IncentiveCalculationContractsWhitelist is a free data retrieval call binding the contract method 0x3ac171fe.
//
// Solidity: function incentiveCalculationContractsWhitelist(address icc) view returns(bool isValid)
func (_SuperAssetFactory *SuperAssetFactoryCaller) IncentiveCalculationContractsWhitelist(opts *bind.CallOpts, icc common.Address) (bool, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "incentiveCalculationContractsWhitelist", icc)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IncentiveCalculationContractsWhitelist is a free data retrieval call binding the contract method 0x3ac171fe.
//
// Solidity: function incentiveCalculationContractsWhitelist(address icc) view returns(bool isValid)
func (_SuperAssetFactory *SuperAssetFactorySession) IncentiveCalculationContractsWhitelist(icc common.Address) (bool, error) {
	return _SuperAssetFactory.Contract.IncentiveCalculationContractsWhitelist(&_SuperAssetFactory.CallOpts, icc)
}

// IncentiveCalculationContractsWhitelist is a free data retrieval call binding the contract method 0x3ac171fe.
//
// Solidity: function incentiveCalculationContractsWhitelist(address icc) view returns(bool isValid)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) IncentiveCalculationContractsWhitelist(icc common.Address) (bool, error) {
	return _SuperAssetFactory.Contract.IncentiveCalculationContractsWhitelist(&_SuperAssetFactory.CallOpts, icc)
}

// IncentiveFundImplementation is a free data retrieval call binding the contract method 0x0d309e73.
//
// Solidity: function incentiveFundImplementation() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) IncentiveFundImplementation(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "incentiveFundImplementation")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// IncentiveFundImplementation is a free data retrieval call binding the contract method 0x0d309e73.
//
// Solidity: function incentiveFundImplementation() view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) IncentiveFundImplementation() (common.Address, error) {
	return _SuperAssetFactory.Contract.IncentiveFundImplementation(&_SuperAssetFactory.CallOpts)
}

// IncentiveFundImplementation is a free data retrieval call binding the contract method 0x0d309e73.
//
// Solidity: function incentiveFundImplementation() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) IncentiveFundImplementation() (common.Address, error) {
	return _SuperAssetFactory.Contract.IncentiveFundImplementation(&_SuperAssetFactory.CallOpts)
}

// IsICCWhitelisted is a free data retrieval call binding the contract method 0xa3e7a82c.
//
// Solidity: function isICCWhitelisted(address icc) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactoryCaller) IsICCWhitelisted(opts *bind.CallOpts, icc common.Address) (bool, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "isICCWhitelisted", icc)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsICCWhitelisted is a free data retrieval call binding the contract method 0xa3e7a82c.
//
// Solidity: function isICCWhitelisted(address icc) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactorySession) IsICCWhitelisted(icc common.Address) (bool, error) {
	return _SuperAssetFactory.Contract.IsICCWhitelisted(&_SuperAssetFactory.CallOpts, icc)
}

// IsICCWhitelisted is a free data retrieval call binding the contract method 0xa3e7a82c.
//
// Solidity: function isICCWhitelisted(address icc) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) IsICCWhitelisted(icc common.Address) (bool, error) {
	return _SuperAssetFactory.Contract.IsICCWhitelisted(&_SuperAssetFactory.CallOpts, icc)
}

// SuperAssetImplementation is a free data retrieval call binding the contract method 0xf2cc6ed6.
//
// Solidity: function superAssetImplementation() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) SuperAssetImplementation(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "superAssetImplementation")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperAssetImplementation is a free data retrieval call binding the contract method 0xf2cc6ed6.
//
// Solidity: function superAssetImplementation() view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) SuperAssetImplementation() (common.Address, error) {
	return _SuperAssetFactory.Contract.SuperAssetImplementation(&_SuperAssetFactory.CallOpts)
}

// SuperAssetImplementation is a free data retrieval call binding the contract method 0xf2cc6ed6.
//
// Solidity: function superAssetImplementation() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) SuperAssetImplementation() (common.Address, error) {
	return _SuperAssetFactory.Contract.SuperAssetImplementation(&_SuperAssetFactory.CallOpts)
}

// SuperGovernor is a free data retrieval call binding the contract method 0x3289cbfb.
//
// Solidity: function superGovernor() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) SuperGovernor(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "superGovernor")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperGovernor is a free data retrieval call binding the contract method 0x3289cbfb.
//
// Solidity: function superGovernor() view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) SuperGovernor() (common.Address, error) {
	return _SuperAssetFactory.Contract.SuperGovernor(&_SuperAssetFactory.CallOpts)
}

// SuperGovernor is a free data retrieval call binding the contract method 0x3289cbfb.
//
// Solidity: function superGovernor() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) SuperGovernor() (common.Address, error) {
	return _SuperAssetFactory.Contract.SuperGovernor(&_SuperAssetFactory.CallOpts)
}

// AddICCToWhitelist is a paid mutator transaction binding the contract method 0xd070909e.
//
// Solidity: function addICCToWhitelist(address icc) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) AddICCToWhitelist(opts *bind.TransactOpts, icc common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "addICCToWhitelist", icc)
}

// AddICCToWhitelist is a paid mutator transaction binding the contract method 0xd070909e.
//
// Solidity: function addICCToWhitelist(address icc) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) AddICCToWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.AddICCToWhitelist(&_SuperAssetFactory.TransactOpts, icc)
}

// AddICCToWhitelist is a paid mutator transaction binding the contract method 0xd070909e.
//
// Solidity: function addICCToWhitelist(address icc) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) AddICCToWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.AddICCToWhitelist(&_SuperAssetFactory.TransactOpts, icc)
}

// CreateSuperAsset is a paid mutator transaction binding the contract method 0x8b91bea7.
//
// Solidity: function createSuperAsset((string,string,uint256,uint256,address,address,address,address,address,address,address) params) returns(address superAsset, address incentiveFundContract)
func (_SuperAssetFactory *SuperAssetFactoryTransactor) CreateSuperAsset(opts *bind.TransactOpts, params ISuperAssetFactoryAssetCreationParams) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "createSuperAsset", params)
}

// CreateSuperAsset is a paid mutator transaction binding the contract method 0x8b91bea7.
//
// Solidity: function createSuperAsset((string,string,uint256,uint256,address,address,address,address,address,address,address) params) returns(address superAsset, address incentiveFundContract)
func (_SuperAssetFactory *SuperAssetFactorySession) CreateSuperAsset(params ISuperAssetFactoryAssetCreationParams) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.CreateSuperAsset(&_SuperAssetFactory.TransactOpts, params)
}

// CreateSuperAsset is a paid mutator transaction binding the contract method 0x8b91bea7.
//
// Solidity: function createSuperAsset((string,string,uint256,uint256,address,address,address,address,address,address,address) params) returns(address superAsset, address incentiveFundContract)
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) CreateSuperAsset(params ISuperAssetFactoryAssetCreationParams) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.CreateSuperAsset(&_SuperAssetFactory.TransactOpts, params)
}

// RemoveICCFromWhitelist is a paid mutator transaction binding the contract method 0x256b71a0.
//
// Solidity: function removeICCFromWhitelist(address icc) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) RemoveICCFromWhitelist(opts *bind.TransactOpts, icc common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "removeICCFromWhitelist", icc)
}

// RemoveICCFromWhitelist is a paid mutator transaction binding the contract method 0x256b71a0.
//
// Solidity: function removeICCFromWhitelist(address icc) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) RemoveICCFromWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.RemoveICCFromWhitelist(&_SuperAssetFactory.TransactOpts, icc)
}

// RemoveICCFromWhitelist is a paid mutator transaction binding the contract method 0x256b71a0.
//
// Solidity: function removeICCFromWhitelist(address icc) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) RemoveICCFromWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.RemoveICCFromWhitelist(&_SuperAssetFactory.TransactOpts, icc)
}

// SetIncentiveCalculationContract is a paid mutator transaction binding the contract method 0x9d1f9cc2.
//
// Solidity: function setIncentiveCalculationContract(address superAsset, address _incentiveCalculationContract) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) SetIncentiveCalculationContract(opts *bind.TransactOpts, superAsset common.Address, _incentiveCalculationContract common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "setIncentiveCalculationContract", superAsset, _incentiveCalculationContract)
}

// SetIncentiveCalculationContract is a paid mutator transaction binding the contract method 0x9d1f9cc2.
//
// Solidity: function setIncentiveCalculationContract(address superAsset, address _incentiveCalculationContract) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) SetIncentiveCalculationContract(superAsset common.Address, _incentiveCalculationContract common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetIncentiveCalculationContract(&_SuperAssetFactory.TransactOpts, superAsset, _incentiveCalculationContract)
}

// SetIncentiveCalculationContract is a paid mutator transaction binding the contract method 0x9d1f9cc2.
//
// Solidity: function setIncentiveCalculationContract(address superAsset, address _incentiveCalculationContract) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) SetIncentiveCalculationContract(superAsset common.Address, _incentiveCalculationContract common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetIncentiveCalculationContract(&_SuperAssetFactory.TransactOpts, superAsset, _incentiveCalculationContract)
}

// SetIncentiveFundManager is a paid mutator transaction binding the contract method 0x6b8db4d5.
//
// Solidity: function setIncentiveFundManager(address superAsset, address _incentiveFundManager) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) SetIncentiveFundManager(opts *bind.TransactOpts, superAsset common.Address, _incentiveFundManager common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "setIncentiveFundManager", superAsset, _incentiveFundManager)
}

// SetIncentiveFundManager is a paid mutator transaction binding the contract method 0x6b8db4d5.
//
// Solidity: function setIncentiveFundManager(address superAsset, address _incentiveFundManager) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) SetIncentiveFundManager(superAsset common.Address, _incentiveFundManager common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetIncentiveFundManager(&_SuperAssetFactory.TransactOpts, superAsset, _incentiveFundManager)
}

// SetIncentiveFundManager is a paid mutator transaction binding the contract method 0x6b8db4d5.
//
// Solidity: function setIncentiveFundManager(address superAsset, address _incentiveFundManager) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) SetIncentiveFundManager(superAsset common.Address, _incentiveFundManager common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetIncentiveFundManager(&_SuperAssetFactory.TransactOpts, superAsset, _incentiveFundManager)
}

// SetSuperAssetManager is a paid mutator transaction binding the contract method 0xe778f632.
//
// Solidity: function setSuperAssetManager(address superAsset, address _superAssetManager) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) SetSuperAssetManager(opts *bind.TransactOpts, superAsset common.Address, _superAssetManager common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "setSuperAssetManager", superAsset, _superAssetManager)
}

// SetSuperAssetManager is a paid mutator transaction binding the contract method 0xe778f632.
//
// Solidity: function setSuperAssetManager(address superAsset, address _superAssetManager) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) SetSuperAssetManager(superAsset common.Address, _superAssetManager common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetSuperAssetManager(&_SuperAssetFactory.TransactOpts, superAsset, _superAssetManager)
}

// SetSuperAssetManager is a paid mutator transaction binding the contract method 0xe778f632.
//
// Solidity: function setSuperAssetManager(address superAsset, address _superAssetManager) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) SetSuperAssetManager(superAsset common.Address, _superAssetManager common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetSuperAssetManager(&_SuperAssetFactory.TransactOpts, superAsset, _superAssetManager)
}

// SetSuperAssetStrategist is a paid mutator transaction binding the contract method 0x8aaff57a.
//
// Solidity: function setSuperAssetStrategist(address superAsset, address _superAssetStrategist) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) SetSuperAssetStrategist(opts *bind.TransactOpts, superAsset common.Address, _superAssetStrategist common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "setSuperAssetStrategist", superAsset, _superAssetStrategist)
}

// SetSuperAssetStrategist is a paid mutator transaction binding the contract method 0x8aaff57a.
//
// Solidity: function setSuperAssetStrategist(address superAsset, address _superAssetStrategist) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) SetSuperAssetStrategist(superAsset common.Address, _superAssetStrategist common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetSuperAssetStrategist(&_SuperAssetFactory.TransactOpts, superAsset, _superAssetStrategist)
}

// SetSuperAssetStrategist is a paid mutator transaction binding the contract method 0x8aaff57a.
//
// Solidity: function setSuperAssetStrategist(address superAsset, address _superAssetStrategist) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) SetSuperAssetStrategist(superAsset common.Address, _superAssetStrategist common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.SetSuperAssetStrategist(&_SuperAssetFactory.TransactOpts, superAsset, _superAssetStrategist)
}

// SuperAssetFactorySuperAssetCreatedIterator is returned from FilterSuperAssetCreated and is used to iterate over the raw logs and unpacked data for SuperAssetCreated events raised by the SuperAssetFactory contract.
type SuperAssetFactorySuperAssetCreatedIterator struct {
	Event *SuperAssetFactorySuperAssetCreated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *SuperAssetFactorySuperAssetCreatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetFactorySuperAssetCreated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(SuperAssetFactorySuperAssetCreated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *SuperAssetFactorySuperAssetCreatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetFactorySuperAssetCreatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetFactorySuperAssetCreated represents a SuperAssetCreated event raised by the SuperAssetFactory contract.
type SuperAssetFactorySuperAssetCreated struct {
	SuperAsset    common.Address
	IncentiveFund common.Address
	IncentiveCalc common.Address
	Name          string
	Symbol        string
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterSuperAssetCreated is a free log retrieval operation binding the contract event 0xc6cd233131908f0fb5895136f109dea0e14a9479c099a9041249ad3455cb0afa.
//
// Solidity: event SuperAssetCreated(address indexed superAsset, address indexed incentiveFund, address incentiveCalc, string name, string symbol)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) FilterSuperAssetCreated(opts *bind.FilterOpts, superAsset []common.Address, incentiveFund []common.Address) (*SuperAssetFactorySuperAssetCreatedIterator, error) {

	var superAssetRule []interface{}
	for _, superAssetItem := range superAsset {
		superAssetRule = append(superAssetRule, superAssetItem)
	}
	var incentiveFundRule []interface{}
	for _, incentiveFundItem := range incentiveFund {
		incentiveFundRule = append(incentiveFundRule, incentiveFundItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.FilterLogs(opts, "SuperAssetCreated", superAssetRule, incentiveFundRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactorySuperAssetCreatedIterator{contract: _SuperAssetFactory.contract, event: "SuperAssetCreated", logs: logs, sub: sub}, nil
}

// WatchSuperAssetCreated is a free log subscription operation binding the contract event 0xc6cd233131908f0fb5895136f109dea0e14a9479c099a9041249ad3455cb0afa.
//
// Solidity: event SuperAssetCreated(address indexed superAsset, address indexed incentiveFund, address incentiveCalc, string name, string symbol)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) WatchSuperAssetCreated(opts *bind.WatchOpts, sink chan<- *SuperAssetFactorySuperAssetCreated, superAsset []common.Address, incentiveFund []common.Address) (event.Subscription, error) {

	var superAssetRule []interface{}
	for _, superAssetItem := range superAsset {
		superAssetRule = append(superAssetRule, superAssetItem)
	}
	var incentiveFundRule []interface{}
	for _, incentiveFundItem := range incentiveFund {
		incentiveFundRule = append(incentiveFundRule, incentiveFundItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.WatchLogs(opts, "SuperAssetCreated", superAssetRule, incentiveFundRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetFactorySuperAssetCreated)
				if err := _SuperAssetFactory.contract.UnpackLog(event, "SuperAssetCreated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSuperAssetCreated is a log parse operation binding the contract event 0xc6cd233131908f0fb5895136f109dea0e14a9479c099a9041249ad3455cb0afa.
//
// Solidity: event SuperAssetCreated(address indexed superAsset, address indexed incentiveFund, address incentiveCalc, string name, string symbol)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) ParseSuperAssetCreated(log types.Log) (*SuperAssetFactorySuperAssetCreated, error) {
	event := new(SuperAssetFactorySuperAssetCreated)
	if err := _SuperAssetFactory.contract.UnpackLog(event, "SuperAssetCreated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
