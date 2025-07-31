// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperValidator

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

// PackedUserOperation is an auto generated low-level Go binding around an user-defined struct.
type PackedUserOperation struct {
	Sender             common.Address
	Nonce              *big.Int
	InitCode           []byte
	CallData           []byte
	AccountGasLimits   [32]byte
	PreVerificationGas *big.Int
	GasFees            [32]byte
	PaymasterAndData   []byte
	Signature          []byte
}

// SuperValidatorMetaData contains all meta data concerning the SuperValidator contract.
var SuperValidatorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"VALID_SIGNATURE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAccountOwner\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"isValidSignatureWithSender\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dataHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"namespace\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"retrieveSignatureData\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"validateUserOp\",\"inputs\":[{\"name\":\"_userOp\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"_userOpHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"ERC7579ValidatorBase.ValidationData\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureLength\",\"inputs\":[{\"name\":\"length\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureS\",\"inputs\":[{\"name\":\"s\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_DESTINATION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_USER_OP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_USER_OP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"PROOF_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperValidatorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperValidatorMetaData.ABI instead.
var SuperValidatorABI = SuperValidatorMetaData.ABI

// SuperValidator is an auto generated Go binding around an Ethereum contract.
type SuperValidator struct {
	SuperValidatorCaller     // Read-only binding to the contract
	SuperValidatorTransactor // Write-only binding to the contract
	SuperValidatorFilterer   // Log filterer for contract events
}

// SuperValidatorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperValidatorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperValidatorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperValidatorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperValidatorSession struct {
	Contract     *SuperValidator   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperValidatorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperValidatorCallerSession struct {
	Contract *SuperValidatorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// SuperValidatorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperValidatorTransactorSession struct {
	Contract     *SuperValidatorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// SuperValidatorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperValidatorRaw struct {
	Contract *SuperValidator // Generic contract binding to access the raw methods on
}

// SuperValidatorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperValidatorCallerRaw struct {
	Contract *SuperValidatorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperValidatorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperValidatorTransactorRaw struct {
	Contract *SuperValidatorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperValidator creates a new instance of SuperValidator, bound to a specific deployed contract.
func NewSuperValidator(address common.Address, backend bind.ContractBackend) (*SuperValidator, error) {
	contract, err := bindSuperValidator(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperValidator{SuperValidatorCaller: SuperValidatorCaller{contract: contract}, SuperValidatorTransactor: SuperValidatorTransactor{contract: contract}, SuperValidatorFilterer: SuperValidatorFilterer{contract: contract}}, nil
}

// NewSuperValidatorCaller creates a new read-only instance of SuperValidator, bound to a specific deployed contract.
func NewSuperValidatorCaller(address common.Address, caller bind.ContractCaller) (*SuperValidatorCaller, error) {
	contract, err := bindSuperValidator(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorCaller{contract: contract}, nil
}

// NewSuperValidatorTransactor creates a new write-only instance of SuperValidator, bound to a specific deployed contract.
func NewSuperValidatorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperValidatorTransactor, error) {
	contract, err := bindSuperValidator(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorTransactor{contract: contract}, nil
}

// NewSuperValidatorFilterer creates a new log filterer instance of SuperValidator, bound to a specific deployed contract.
func NewSuperValidatorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperValidatorFilterer, error) {
	contract, err := bindSuperValidator(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorFilterer{contract: contract}, nil
}

// bindSuperValidator binds a generic wrapper to an already deployed contract.
func bindSuperValidator(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperValidatorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidator *SuperValidatorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidator.Contract.SuperValidatorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidator *SuperValidatorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidator.Contract.SuperValidatorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidator *SuperValidatorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidator.Contract.SuperValidatorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidator *SuperValidatorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidator.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidator *SuperValidatorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidator.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidator *SuperValidatorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidator.Contract.contract.Transact(opts, method, params...)
}

// VALIDSIGNATURE is a free data retrieval call binding the contract method 0x8ee749ca.
//
// Solidity: function VALID_SIGNATURE() view returns(bytes4)
func (_SuperValidator *SuperValidatorCaller) VALIDSIGNATURE(opts *bind.CallOpts) ([4]byte, error) {
	var out []interface{}
	err := _SuperValidator.contract.Call(opts, &out, "VALID_SIGNATURE")

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// VALIDSIGNATURE is a free data retrieval call binding the contract method 0x8ee749ca.
//
// Solidity: function VALID_SIGNATURE() view returns(bytes4)
func (_SuperValidator *SuperValidatorSession) VALIDSIGNATURE() ([4]byte, error) {
	return _SuperValidator.Contract.VALIDSIGNATURE(&_SuperValidator.CallOpts)
}

// VALIDSIGNATURE is a free data retrieval call binding the contract method 0x8ee749ca.
//
// Solidity: function VALID_SIGNATURE() view returns(bytes4)
func (_SuperValidator *SuperValidatorCallerSession) VALIDSIGNATURE() ([4]byte, error) {
	return _SuperValidator.Contract.VALIDSIGNATURE(&_SuperValidator.CallOpts)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperValidator *SuperValidatorCaller) GetAccountOwner(opts *bind.CallOpts, account common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperValidator.contract.Call(opts, &out, "getAccountOwner", account)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperValidator *SuperValidatorSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperValidator.Contract.GetAccountOwner(&_SuperValidator.CallOpts, account)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperValidator *SuperValidatorCallerSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperValidator.Contract.GetAccountOwner(&_SuperValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperValidator *SuperValidatorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperValidator.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperValidator *SuperValidatorSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperValidator.Contract.IsInitialized(&_SuperValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperValidator *SuperValidatorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperValidator.Contract.IsInitialized(&_SuperValidator.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperValidator *SuperValidatorCaller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperValidator.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperValidator *SuperValidatorSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperValidator.Contract.IsModuleType(&_SuperValidator.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperValidator *SuperValidatorCallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperValidator.Contract.IsModuleType(&_SuperValidator.CallOpts, typeID)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 dataHash, bytes data) view returns(bytes4)
func (_SuperValidator *SuperValidatorCaller) IsValidSignatureWithSender(opts *bind.CallOpts, arg0 common.Address, dataHash [32]byte, data []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperValidator.contract.Call(opts, &out, "isValidSignatureWithSender", arg0, dataHash, data)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 dataHash, bytes data) view returns(bytes4)
func (_SuperValidator *SuperValidatorSession) IsValidSignatureWithSender(arg0 common.Address, dataHash [32]byte, data []byte) ([4]byte, error) {
	return _SuperValidator.Contract.IsValidSignatureWithSender(&_SuperValidator.CallOpts, arg0, dataHash, data)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 dataHash, bytes data) view returns(bytes4)
func (_SuperValidator *SuperValidatorCallerSession) IsValidSignatureWithSender(arg0 common.Address, dataHash [32]byte, data []byte) ([4]byte, error) {
	return _SuperValidator.Contract.IsValidSignatureWithSender(&_SuperValidator.CallOpts, arg0, dataHash, data)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperValidator *SuperValidatorCaller) Namespace(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperValidator.contract.Call(opts, &out, "namespace")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperValidator *SuperValidatorSession) Namespace() (string, error) {
	return _SuperValidator.Contract.Namespace(&_SuperValidator.CallOpts)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperValidator *SuperValidatorCallerSession) Namespace() (string, error) {
	return _SuperValidator.Contract.Namespace(&_SuperValidator.CallOpts)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidator *SuperValidatorCaller) RetrieveSignatureData(opts *bind.CallOpts, account common.Address) ([]byte, error) {
	var out []interface{}
	err := _SuperValidator.contract.Call(opts, &out, "retrieveSignatureData", account)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidator *SuperValidatorSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperValidator.Contract.RetrieveSignatureData(&_SuperValidator.CallOpts, account)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidator *SuperValidatorCallerSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperValidator.Contract.RetrieveSignatureData(&_SuperValidator.CallOpts, account)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperValidator *SuperValidatorTransactor) OnInstall(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperValidator.contract.Transact(opts, "onInstall", data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperValidator *SuperValidatorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperValidator.Contract.OnInstall(&_SuperValidator.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperValidator *SuperValidatorTransactorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperValidator.Contract.OnInstall(&_SuperValidator.TransactOpts, data)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperValidator *SuperValidatorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperValidator.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperValidator *SuperValidatorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperValidator.Contract.OnUninstall(&_SuperValidator.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperValidator *SuperValidatorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperValidator.Contract.OnUninstall(&_SuperValidator.TransactOpts, arg0)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) _userOp, bytes32 _userOpHash) returns(uint256)
func (_SuperValidator *SuperValidatorTransactor) ValidateUserOp(opts *bind.TransactOpts, _userOp PackedUserOperation, _userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperValidator.contract.Transact(opts, "validateUserOp", _userOp, _userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) _userOp, bytes32 _userOpHash) returns(uint256)
func (_SuperValidator *SuperValidatorSession) ValidateUserOp(_userOp PackedUserOperation, _userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperValidator.Contract.ValidateUserOp(&_SuperValidator.TransactOpts, _userOp, _userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) _userOp, bytes32 _userOpHash) returns(uint256)
func (_SuperValidator *SuperValidatorTransactorSession) ValidateUserOp(_userOp PackedUserOperation, _userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperValidator.Contract.ValidateUserOp(&_SuperValidator.TransactOpts, _userOp, _userOpHash)
}
