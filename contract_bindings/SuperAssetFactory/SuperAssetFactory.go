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
	Name                 string
	Symbol               string
	SwapFeeInPercentage  *big.Int
	SwapFeeOutPercentage *big.Int
}

// SuperAssetFactoryMetaData contains all meta data concerning the SuperAssetFactory contract.
var SuperAssetFactoryMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"admin\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"DEFAULT_ADMIN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPLOYER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"assetBank\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"createSuperAsset\",\"inputs\":[{\"name\":\"params\",\"type\":\"tuple\",\"internalType\":\"structISuperAssetFactory.AssetCreationParams\",\"components\":[{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"swapFeeInPercentage\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"swapFeeOutPercentage\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"outputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetBank_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveFund\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"incentiveCalc\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getRoleAdmin\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"grantRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"hasRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"incentiveCalculationContract\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"incentiveFundImplementation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"callerConfirmation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"revokeRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superAssetImplementation\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"supportsInterface\",\"inputs\":[{\"name\":\"interfaceId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"RoleAdminChanged\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"previousAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleGranted\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleRevoked\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperAssetCreated\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assetBank\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"incentiveFund\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"incentiveCalc\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"name\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"AccessControlBadConfirmation\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AccessControlUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"neededRole\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"FailedDeployment\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InsufficientBalance\",\"inputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}]",
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

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactoryCaller) DEFAULTADMINROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "DEFAULT_ADMIN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactorySession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperAssetFactory.Contract.DEFAULTADMINROLE(&_SuperAssetFactory.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperAssetFactory.Contract.DEFAULTADMINROLE(&_SuperAssetFactory.CallOpts)
}

// DEPLOYERROLE is a free data retrieval call binding the contract method 0xecd00261.
//
// Solidity: function DEPLOYER_ROLE() view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactoryCaller) DEPLOYERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "DEPLOYER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DEPLOYERROLE is a free data retrieval call binding the contract method 0xecd00261.
//
// Solidity: function DEPLOYER_ROLE() view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactorySession) DEPLOYERROLE() ([32]byte, error) {
	return _SuperAssetFactory.Contract.DEPLOYERROLE(&_SuperAssetFactory.CallOpts)
}

// DEPLOYERROLE is a free data retrieval call binding the contract method 0xecd00261.
//
// Solidity: function DEPLOYER_ROLE() view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) DEPLOYERROLE() ([32]byte, error) {
	return _SuperAssetFactory.Contract.DEPLOYERROLE(&_SuperAssetFactory.CallOpts)
}

// AssetBank is a free data retrieval call binding the contract method 0x4d75f51c.
//
// Solidity: function assetBank() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) AssetBank(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "assetBank")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AssetBank is a free data retrieval call binding the contract method 0x4d75f51c.
//
// Solidity: function assetBank() view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) AssetBank() (common.Address, error) {
	return _SuperAssetFactory.Contract.AssetBank(&_SuperAssetFactory.CallOpts)
}

// AssetBank is a free data retrieval call binding the contract method 0x4d75f51c.
//
// Solidity: function assetBank() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) AssetBank() (common.Address, error) {
	return _SuperAssetFactory.Contract.AssetBank(&_SuperAssetFactory.CallOpts)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactoryCaller) GetRoleAdmin(opts *bind.CallOpts, role [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "getRoleAdmin", role)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactorySession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperAssetFactory.Contract.GetRoleAdmin(&_SuperAssetFactory.CallOpts, role)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperAssetFactory.Contract.GetRoleAdmin(&_SuperAssetFactory.CallOpts, role)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactoryCaller) HasRole(opts *bind.CallOpts, role [32]byte, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "hasRole", role, account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactorySession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperAssetFactory.Contract.HasRole(&_SuperAssetFactory.CallOpts, role, account)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperAssetFactory.Contract.HasRole(&_SuperAssetFactory.CallOpts, role, account)
}

// IncentiveCalculationContract is a free data retrieval call binding the contract method 0xd3b472c5.
//
// Solidity: function incentiveCalculationContract() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCaller) IncentiveCalculationContract(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "incentiveCalculationContract")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// IncentiveCalculationContract is a free data retrieval call binding the contract method 0xd3b472c5.
//
// Solidity: function incentiveCalculationContract() view returns(address)
func (_SuperAssetFactory *SuperAssetFactorySession) IncentiveCalculationContract() (common.Address, error) {
	return _SuperAssetFactory.Contract.IncentiveCalculationContract(&_SuperAssetFactory.CallOpts)
}

// IncentiveCalculationContract is a free data retrieval call binding the contract method 0xd3b472c5.
//
// Solidity: function incentiveCalculationContract() view returns(address)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) IncentiveCalculationContract() (common.Address, error) {
	return _SuperAssetFactory.Contract.IncentiveCalculationContract(&_SuperAssetFactory.CallOpts)
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

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactoryCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _SuperAssetFactory.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactorySession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperAssetFactory.Contract.SupportsInterface(&_SuperAssetFactory.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperAssetFactory *SuperAssetFactoryCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperAssetFactory.Contract.SupportsInterface(&_SuperAssetFactory.CallOpts, interfaceId)
}

// CreateSuperAsset is a paid mutator transaction binding the contract method 0xec5f41e2.
//
// Solidity: function createSuperAsset((string,string,uint256,uint256) params) returns(address superAsset, address assetBank_, address incentiveFund, address incentiveCalc)
func (_SuperAssetFactory *SuperAssetFactoryTransactor) CreateSuperAsset(opts *bind.TransactOpts, params ISuperAssetFactoryAssetCreationParams) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "createSuperAsset", params)
}

// CreateSuperAsset is a paid mutator transaction binding the contract method 0xec5f41e2.
//
// Solidity: function createSuperAsset((string,string,uint256,uint256) params) returns(address superAsset, address assetBank_, address incentiveFund, address incentiveCalc)
func (_SuperAssetFactory *SuperAssetFactorySession) CreateSuperAsset(params ISuperAssetFactoryAssetCreationParams) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.CreateSuperAsset(&_SuperAssetFactory.TransactOpts, params)
}

// CreateSuperAsset is a paid mutator transaction binding the contract method 0xec5f41e2.
//
// Solidity: function createSuperAsset((string,string,uint256,uint256) params) returns(address superAsset, address assetBank_, address incentiveFund, address incentiveCalc)
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) CreateSuperAsset(params ISuperAssetFactoryAssetCreationParams) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.CreateSuperAsset(&_SuperAssetFactory.TransactOpts, params)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) GrantRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "grantRole", role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.GrantRole(&_SuperAssetFactory.TransactOpts, role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.GrantRole(&_SuperAssetFactory.TransactOpts, role, account)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) RenounceRole(opts *bind.TransactOpts, role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "renounceRole", role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.RenounceRole(&_SuperAssetFactory.TransactOpts, role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.RenounceRole(&_SuperAssetFactory.TransactOpts, role, callerConfirmation)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactor) RevokeRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.contract.Transact(opts, "revokeRole", role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperAssetFactory *SuperAssetFactorySession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.RevokeRole(&_SuperAssetFactory.TransactOpts, role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperAssetFactory *SuperAssetFactoryTransactorSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperAssetFactory.Contract.RevokeRole(&_SuperAssetFactory.TransactOpts, role, account)
}

// SuperAssetFactoryRoleAdminChangedIterator is returned from FilterRoleAdminChanged and is used to iterate over the raw logs and unpacked data for RoleAdminChanged events raised by the SuperAssetFactory contract.
type SuperAssetFactoryRoleAdminChangedIterator struct {
	Event *SuperAssetFactoryRoleAdminChanged // Event containing the contract specifics and raw log

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
func (it *SuperAssetFactoryRoleAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetFactoryRoleAdminChanged)
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
		it.Event = new(SuperAssetFactoryRoleAdminChanged)
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
func (it *SuperAssetFactoryRoleAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetFactoryRoleAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetFactoryRoleAdminChanged represents a RoleAdminChanged event raised by the SuperAssetFactory contract.
type SuperAssetFactoryRoleAdminChanged struct {
	Role              [32]byte
	PreviousAdminRole [32]byte
	NewAdminRole      [32]byte
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterRoleAdminChanged is a free log retrieval operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) FilterRoleAdminChanged(opts *bind.FilterOpts, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (*SuperAssetFactoryRoleAdminChangedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.FilterLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactoryRoleAdminChangedIterator{contract: _SuperAssetFactory.contract, event: "RoleAdminChanged", logs: logs, sub: sub}, nil
}

// WatchRoleAdminChanged is a free log subscription operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) WatchRoleAdminChanged(opts *bind.WatchOpts, sink chan<- *SuperAssetFactoryRoleAdminChanged, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.WatchLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetFactoryRoleAdminChanged)
				if err := _SuperAssetFactory.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
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

// ParseRoleAdminChanged is a log parse operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) ParseRoleAdminChanged(log types.Log) (*SuperAssetFactoryRoleAdminChanged, error) {
	event := new(SuperAssetFactoryRoleAdminChanged)
	if err := _SuperAssetFactory.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetFactoryRoleGrantedIterator is returned from FilterRoleGranted and is used to iterate over the raw logs and unpacked data for RoleGranted events raised by the SuperAssetFactory contract.
type SuperAssetFactoryRoleGrantedIterator struct {
	Event *SuperAssetFactoryRoleGranted // Event containing the contract specifics and raw log

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
func (it *SuperAssetFactoryRoleGrantedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetFactoryRoleGranted)
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
		it.Event = new(SuperAssetFactoryRoleGranted)
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
func (it *SuperAssetFactoryRoleGrantedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetFactoryRoleGrantedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetFactoryRoleGranted represents a RoleGranted event raised by the SuperAssetFactory contract.
type SuperAssetFactoryRoleGranted struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleGranted is a free log retrieval operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) FilterRoleGranted(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperAssetFactoryRoleGrantedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.FilterLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactoryRoleGrantedIterator{contract: _SuperAssetFactory.contract, event: "RoleGranted", logs: logs, sub: sub}, nil
}

// WatchRoleGranted is a free log subscription operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) WatchRoleGranted(opts *bind.WatchOpts, sink chan<- *SuperAssetFactoryRoleGranted, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.WatchLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetFactoryRoleGranted)
				if err := _SuperAssetFactory.contract.UnpackLog(event, "RoleGranted", log); err != nil {
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

// ParseRoleGranted is a log parse operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) ParseRoleGranted(log types.Log) (*SuperAssetFactoryRoleGranted, error) {
	event := new(SuperAssetFactoryRoleGranted)
	if err := _SuperAssetFactory.contract.UnpackLog(event, "RoleGranted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperAssetFactoryRoleRevokedIterator is returned from FilterRoleRevoked and is used to iterate over the raw logs and unpacked data for RoleRevoked events raised by the SuperAssetFactory contract.
type SuperAssetFactoryRoleRevokedIterator struct {
	Event *SuperAssetFactoryRoleRevoked // Event containing the contract specifics and raw log

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
func (it *SuperAssetFactoryRoleRevokedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperAssetFactoryRoleRevoked)
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
		it.Event = new(SuperAssetFactoryRoleRevoked)
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
func (it *SuperAssetFactoryRoleRevokedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperAssetFactoryRoleRevokedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperAssetFactoryRoleRevoked represents a RoleRevoked event raised by the SuperAssetFactory contract.
type SuperAssetFactoryRoleRevoked struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleRevoked is a free log retrieval operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) FilterRoleRevoked(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperAssetFactoryRoleRevokedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.FilterLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactoryRoleRevokedIterator{contract: _SuperAssetFactory.contract, event: "RoleRevoked", logs: logs, sub: sub}, nil
}

// WatchRoleRevoked is a free log subscription operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) WatchRoleRevoked(opts *bind.WatchOpts, sink chan<- *SuperAssetFactoryRoleRevoked, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.WatchLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperAssetFactoryRoleRevoked)
				if err := _SuperAssetFactory.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
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

// ParseRoleRevoked is a log parse operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) ParseRoleRevoked(log types.Log) (*SuperAssetFactoryRoleRevoked, error) {
	event := new(SuperAssetFactoryRoleRevoked)
	if err := _SuperAssetFactory.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
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
	AssetBank     common.Address
	IncentiveFund common.Address
	IncentiveCalc common.Address
	Name          string
	Symbol        string
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterSuperAssetCreated is a free log retrieval operation binding the contract event 0x930f63c42f0e288e124b8444d6b548962ed3f7818cd72a56d53de4d3cc4c152e.
//
// Solidity: event SuperAssetCreated(address indexed superAsset, address indexed assetBank, address incentiveFund, address incentiveCalc, string name, string symbol)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) FilterSuperAssetCreated(opts *bind.FilterOpts, superAsset []common.Address, assetBank []common.Address) (*SuperAssetFactorySuperAssetCreatedIterator, error) {

	var superAssetRule []interface{}
	for _, superAssetItem := range superAsset {
		superAssetRule = append(superAssetRule, superAssetItem)
	}
	var assetBankRule []interface{}
	for _, assetBankItem := range assetBank {
		assetBankRule = append(assetBankRule, assetBankItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.FilterLogs(opts, "SuperAssetCreated", superAssetRule, assetBankRule)
	if err != nil {
		return nil, err
	}
	return &SuperAssetFactorySuperAssetCreatedIterator{contract: _SuperAssetFactory.contract, event: "SuperAssetCreated", logs: logs, sub: sub}, nil
}

// WatchSuperAssetCreated is a free log subscription operation binding the contract event 0x930f63c42f0e288e124b8444d6b548962ed3f7818cd72a56d53de4d3cc4c152e.
//
// Solidity: event SuperAssetCreated(address indexed superAsset, address indexed assetBank, address incentiveFund, address incentiveCalc, string name, string symbol)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) WatchSuperAssetCreated(opts *bind.WatchOpts, sink chan<- *SuperAssetFactorySuperAssetCreated, superAsset []common.Address, assetBank []common.Address) (event.Subscription, error) {

	var superAssetRule []interface{}
	for _, superAssetItem := range superAsset {
		superAssetRule = append(superAssetRule, superAssetItem)
	}
	var assetBankRule []interface{}
	for _, assetBankItem := range assetBank {
		assetBankRule = append(assetBankRule, assetBankItem)
	}

	logs, sub, err := _SuperAssetFactory.contract.WatchLogs(opts, "SuperAssetCreated", superAssetRule, assetBankRule)
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

// ParseSuperAssetCreated is a log parse operation binding the contract event 0x930f63c42f0e288e124b8444d6b548962ed3f7818cd72a56d53de4d3cc4c152e.
//
// Solidity: event SuperAssetCreated(address indexed superAsset, address indexed assetBank, address incentiveFund, address incentiveCalc, string name, string symbol)
func (_SuperAssetFactory *SuperAssetFactoryFilterer) ParseSuperAssetCreated(log types.Log) (*SuperAssetFactorySuperAssetCreated, error) {
	event := new(SuperAssetFactorySuperAssetCreated)
	if err := _SuperAssetFactory.contract.UnpackLog(event, "SuperAssetCreated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
