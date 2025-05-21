// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperMerkleValidator

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

// SuperMerkleValidatorMetaData contains all meta data concerning the SuperMerkleValidator contract.
var SuperMerkleValidatorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getAccountOwner\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"isValidSignatureWithSender\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dataHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"namespace\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"retrieveSignatureData\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"validateUserOp\",\"inputs\":[{\"name\":\"_userOp\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"_userOpHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"ERC7579ValidatorBase.ValidationData\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureLength\",\"inputs\":[{\"name\":\"length\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureS\",\"inputs\":[{\"name\":\"s\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperMerkleValidatorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperMerkleValidatorMetaData.ABI instead.
var SuperMerkleValidatorABI = SuperMerkleValidatorMetaData.ABI

// SuperMerkleValidator is an auto generated Go binding around an Ethereum contract.
type SuperMerkleValidator struct {
	SuperMerkleValidatorCaller     // Read-only binding to the contract
	SuperMerkleValidatorTransactor // Write-only binding to the contract
	SuperMerkleValidatorFilterer   // Log filterer for contract events
}

// SuperMerkleValidatorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperMerkleValidatorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMerkleValidatorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperMerkleValidatorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMerkleValidatorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperMerkleValidatorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMerkleValidatorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperMerkleValidatorSession struct {
	Contract     *SuperMerkleValidator // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// SuperMerkleValidatorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperMerkleValidatorCallerSession struct {
	Contract *SuperMerkleValidatorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// SuperMerkleValidatorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperMerkleValidatorTransactorSession struct {
	Contract     *SuperMerkleValidatorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// SuperMerkleValidatorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperMerkleValidatorRaw struct {
	Contract *SuperMerkleValidator // Generic contract binding to access the raw methods on
}

// SuperMerkleValidatorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperMerkleValidatorCallerRaw struct {
	Contract *SuperMerkleValidatorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperMerkleValidatorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperMerkleValidatorTransactorRaw struct {
	Contract *SuperMerkleValidatorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperMerkleValidator creates a new instance of SuperMerkleValidator, bound to a specific deployed contract.
func NewSuperMerkleValidator(address common.Address, backend bind.ContractBackend) (*SuperMerkleValidator, error) {
	contract, err := bindSuperMerkleValidator(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperMerkleValidator{SuperMerkleValidatorCaller: SuperMerkleValidatorCaller{contract: contract}, SuperMerkleValidatorTransactor: SuperMerkleValidatorTransactor{contract: contract}, SuperMerkleValidatorFilterer: SuperMerkleValidatorFilterer{contract: contract}}, nil
}

// NewSuperMerkleValidatorCaller creates a new read-only instance of SuperMerkleValidator, bound to a specific deployed contract.
func NewSuperMerkleValidatorCaller(address common.Address, caller bind.ContractCaller) (*SuperMerkleValidatorCaller, error) {
	contract, err := bindSuperMerkleValidator(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMerkleValidatorCaller{contract: contract}, nil
}

// NewSuperMerkleValidatorTransactor creates a new write-only instance of SuperMerkleValidator, bound to a specific deployed contract.
func NewSuperMerkleValidatorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperMerkleValidatorTransactor, error) {
	contract, err := bindSuperMerkleValidator(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMerkleValidatorTransactor{contract: contract}, nil
}

// NewSuperMerkleValidatorFilterer creates a new log filterer instance of SuperMerkleValidator, bound to a specific deployed contract.
func NewSuperMerkleValidatorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperMerkleValidatorFilterer, error) {
	contract, err := bindSuperMerkleValidator(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperMerkleValidatorFilterer{contract: contract}, nil
}

// bindSuperMerkleValidator binds a generic wrapper to an already deployed contract.
func bindSuperMerkleValidator(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperMerkleValidatorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMerkleValidator *SuperMerkleValidatorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMerkleValidator.Contract.SuperMerkleValidatorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMerkleValidator *SuperMerkleValidatorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.SuperMerkleValidatorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMerkleValidator *SuperMerkleValidatorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.SuperMerkleValidatorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMerkleValidator *SuperMerkleValidatorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMerkleValidator.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMerkleValidator *SuperMerkleValidatorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMerkleValidator *SuperMerkleValidatorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.contract.Transact(opts, method, params...)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMerkleValidator *SuperMerkleValidatorCaller) GetAccountOwner(opts *bind.CallOpts, account common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperMerkleValidator.contract.Call(opts, &out, "getAccountOwner", account)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMerkleValidator *SuperMerkleValidatorSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperMerkleValidator.Contract.GetAccountOwner(&_SuperMerkleValidator.CallOpts, account)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMerkleValidator *SuperMerkleValidatorCallerSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperMerkleValidator.Contract.GetAccountOwner(&_SuperMerkleValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMerkleValidator *SuperMerkleValidatorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperMerkleValidator.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMerkleValidator *SuperMerkleValidatorSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMerkleValidator.Contract.IsInitialized(&_SuperMerkleValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMerkleValidator *SuperMerkleValidatorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMerkleValidator.Contract.IsInitialized(&_SuperMerkleValidator.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperMerkleValidator *SuperMerkleValidatorCaller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperMerkleValidator.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperMerkleValidator *SuperMerkleValidatorSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperMerkleValidator.Contract.IsModuleType(&_SuperMerkleValidator.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperMerkleValidator *SuperMerkleValidatorCallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperMerkleValidator.Contract.IsModuleType(&_SuperMerkleValidator.CallOpts, typeID)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 dataHash, bytes data) view returns(bytes4)
func (_SuperMerkleValidator *SuperMerkleValidatorCaller) IsValidSignatureWithSender(opts *bind.CallOpts, arg0 common.Address, dataHash [32]byte, data []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperMerkleValidator.contract.Call(opts, &out, "isValidSignatureWithSender", arg0, dataHash, data)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 dataHash, bytes data) view returns(bytes4)
func (_SuperMerkleValidator *SuperMerkleValidatorSession) IsValidSignatureWithSender(arg0 common.Address, dataHash [32]byte, data []byte) ([4]byte, error) {
	return _SuperMerkleValidator.Contract.IsValidSignatureWithSender(&_SuperMerkleValidator.CallOpts, arg0, dataHash, data)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 dataHash, bytes data) view returns(bytes4)
func (_SuperMerkleValidator *SuperMerkleValidatorCallerSession) IsValidSignatureWithSender(arg0 common.Address, dataHash [32]byte, data []byte) ([4]byte, error) {
	return _SuperMerkleValidator.Contract.IsValidSignatureWithSender(&_SuperMerkleValidator.CallOpts, arg0, dataHash, data)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMerkleValidator *SuperMerkleValidatorCaller) Namespace(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperMerkleValidator.contract.Call(opts, &out, "namespace")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMerkleValidator *SuperMerkleValidatorSession) Namespace() (string, error) {
	return _SuperMerkleValidator.Contract.Namespace(&_SuperMerkleValidator.CallOpts)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMerkleValidator *SuperMerkleValidatorCallerSession) Namespace() (string, error) {
	return _SuperMerkleValidator.Contract.Namespace(&_SuperMerkleValidator.CallOpts)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperMerkleValidator *SuperMerkleValidatorCaller) RetrieveSignatureData(opts *bind.CallOpts, account common.Address) ([]byte, error) {
	var out []interface{}
	err := _SuperMerkleValidator.contract.Call(opts, &out, "retrieveSignatureData", account)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperMerkleValidator *SuperMerkleValidatorSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperMerkleValidator.Contract.RetrieveSignatureData(&_SuperMerkleValidator.CallOpts, account)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperMerkleValidator *SuperMerkleValidatorCallerSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperMerkleValidator.Contract.RetrieveSignatureData(&_SuperMerkleValidator.CallOpts, account)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMerkleValidator *SuperMerkleValidatorTransactor) OnInstall(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.contract.Transact(opts, "onInstall", data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMerkleValidator *SuperMerkleValidatorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.OnInstall(&_SuperMerkleValidator.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMerkleValidator *SuperMerkleValidatorTransactorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.OnInstall(&_SuperMerkleValidator.TransactOpts, data)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMerkleValidator *SuperMerkleValidatorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMerkleValidator *SuperMerkleValidatorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.OnUninstall(&_SuperMerkleValidator.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMerkleValidator *SuperMerkleValidatorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.OnUninstall(&_SuperMerkleValidator.TransactOpts, arg0)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) _userOp, bytes32 _userOpHash) returns(uint256)
func (_SuperMerkleValidator *SuperMerkleValidatorTransactor) ValidateUserOp(opts *bind.TransactOpts, _userOp PackedUserOperation, _userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.contract.Transact(opts, "validateUserOp", _userOp, _userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) _userOp, bytes32 _userOpHash) returns(uint256)
func (_SuperMerkleValidator *SuperMerkleValidatorSession) ValidateUserOp(_userOp PackedUserOperation, _userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.ValidateUserOp(&_SuperMerkleValidator.TransactOpts, _userOp, _userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) _userOp, bytes32 _userOpHash) returns(uint256)
func (_SuperMerkleValidator *SuperMerkleValidatorTransactorSession) ValidateUserOp(_userOp PackedUserOperation, _userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperMerkleValidator.Contract.ValidateUserOp(&_SuperMerkleValidator.TransactOpts, _userOp, _userOpHash)
}
