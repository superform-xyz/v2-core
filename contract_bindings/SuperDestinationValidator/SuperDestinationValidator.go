// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperDestinationValidator

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

// SuperDestinationValidatorMetaData contains all meta data concerning the SuperDestinationValidator contract.
var SuperDestinationValidatorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getAccountOwner\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"isValidDestinationSignature\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidSignatureWithSender\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"namespace\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateUserOp\",\"inputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"ERC7579ValidatorBase.ValidationData\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignature\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureLength\",\"inputs\":[{\"name\":\"length\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ECDSAInvalidSignatureS\",\"inputs\":[{\"name\":\"s\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperDestinationValidatorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperDestinationValidatorMetaData.ABI instead.
var SuperDestinationValidatorABI = SuperDestinationValidatorMetaData.ABI

// SuperDestinationValidator is an auto generated Go binding around an Ethereum contract.
type SuperDestinationValidator struct {
	SuperDestinationValidatorCaller     // Read-only binding to the contract
	SuperDestinationValidatorTransactor // Write-only binding to the contract
	SuperDestinationValidatorFilterer   // Log filterer for contract events
}

// SuperDestinationValidatorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperDestinationValidatorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationValidatorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperDestinationValidatorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationValidatorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperDestinationValidatorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationValidatorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperDestinationValidatorSession struct {
	Contract     *SuperDestinationValidator // Generic contract binding to set the session for
	CallOpts     bind.CallOpts              // Call options to use throughout this session
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// SuperDestinationValidatorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperDestinationValidatorCallerSession struct {
	Contract *SuperDestinationValidatorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                    // Call options to use throughout this session
}

// SuperDestinationValidatorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperDestinationValidatorTransactorSession struct {
	Contract     *SuperDestinationValidatorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// SuperDestinationValidatorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperDestinationValidatorRaw struct {
	Contract *SuperDestinationValidator // Generic contract binding to access the raw methods on
}

// SuperDestinationValidatorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperDestinationValidatorCallerRaw struct {
	Contract *SuperDestinationValidatorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperDestinationValidatorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperDestinationValidatorTransactorRaw struct {
	Contract *SuperDestinationValidatorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperDestinationValidator creates a new instance of SuperDestinationValidator, bound to a specific deployed contract.
func NewSuperDestinationValidator(address common.Address, backend bind.ContractBackend) (*SuperDestinationValidator, error) {
	contract, err := bindSuperDestinationValidator(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationValidator{SuperDestinationValidatorCaller: SuperDestinationValidatorCaller{contract: contract}, SuperDestinationValidatorTransactor: SuperDestinationValidatorTransactor{contract: contract}, SuperDestinationValidatorFilterer: SuperDestinationValidatorFilterer{contract: contract}}, nil
}

// NewSuperDestinationValidatorCaller creates a new read-only instance of SuperDestinationValidator, bound to a specific deployed contract.
func NewSuperDestinationValidatorCaller(address common.Address, caller bind.ContractCaller) (*SuperDestinationValidatorCaller, error) {
	contract, err := bindSuperDestinationValidator(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationValidatorCaller{contract: contract}, nil
}

// NewSuperDestinationValidatorTransactor creates a new write-only instance of SuperDestinationValidator, bound to a specific deployed contract.
func NewSuperDestinationValidatorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperDestinationValidatorTransactor, error) {
	contract, err := bindSuperDestinationValidator(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationValidatorTransactor{contract: contract}, nil
}

// NewSuperDestinationValidatorFilterer creates a new log filterer instance of SuperDestinationValidator, bound to a specific deployed contract.
func NewSuperDestinationValidatorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperDestinationValidatorFilterer, error) {
	contract, err := bindSuperDestinationValidator(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationValidatorFilterer{contract: contract}, nil
}

// bindSuperDestinationValidator binds a generic wrapper to an already deployed contract.
func bindSuperDestinationValidator(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperDestinationValidatorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDestinationValidator *SuperDestinationValidatorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDestinationValidator.Contract.SuperDestinationValidatorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDestinationValidator *SuperDestinationValidatorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.SuperDestinationValidatorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDestinationValidator *SuperDestinationValidatorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.SuperDestinationValidatorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDestinationValidator *SuperDestinationValidatorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDestinationValidator.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDestinationValidator *SuperDestinationValidatorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDestinationValidator *SuperDestinationValidatorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.contract.Transact(opts, method, params...)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperDestinationValidator *SuperDestinationValidatorCaller) GetAccountOwner(opts *bind.CallOpts, account common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperDestinationValidator.contract.Call(opts, &out, "getAccountOwner", account)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperDestinationValidator *SuperDestinationValidatorSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperDestinationValidator.Contract.GetAccountOwner(&_SuperDestinationValidator.CallOpts, account)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperDestinationValidator *SuperDestinationValidatorCallerSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperDestinationValidator.Contract.GetAccountOwner(&_SuperDestinationValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationValidator *SuperDestinationValidatorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperDestinationValidator.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationValidator *SuperDestinationValidatorSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperDestinationValidator.Contract.IsInitialized(&_SuperDestinationValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationValidator *SuperDestinationValidatorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperDestinationValidator.Contract.IsInitialized(&_SuperDestinationValidator.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperDestinationValidator *SuperDestinationValidatorCaller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperDestinationValidator.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperDestinationValidator *SuperDestinationValidatorSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperDestinationValidator.Contract.IsModuleType(&_SuperDestinationValidator.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperDestinationValidator *SuperDestinationValidatorCallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperDestinationValidator.Contract.IsModuleType(&_SuperDestinationValidator.CallOpts, typeID)
}

// IsValidDestinationSignature is a free data retrieval call binding the contract method 0x5c2ec0f3.
//
// Solidity: function isValidDestinationSignature(address sender, bytes data) view returns(bytes4)
func (_SuperDestinationValidator *SuperDestinationValidatorCaller) IsValidDestinationSignature(opts *bind.CallOpts, sender common.Address, data []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperDestinationValidator.contract.Call(opts, &out, "isValidDestinationSignature", sender, data)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidDestinationSignature is a free data retrieval call binding the contract method 0x5c2ec0f3.
//
// Solidity: function isValidDestinationSignature(address sender, bytes data) view returns(bytes4)
func (_SuperDestinationValidator *SuperDestinationValidatorSession) IsValidDestinationSignature(sender common.Address, data []byte) ([4]byte, error) {
	return _SuperDestinationValidator.Contract.IsValidDestinationSignature(&_SuperDestinationValidator.CallOpts, sender, data)
}

// IsValidDestinationSignature is a free data retrieval call binding the contract method 0x5c2ec0f3.
//
// Solidity: function isValidDestinationSignature(address sender, bytes data) view returns(bytes4)
func (_SuperDestinationValidator *SuperDestinationValidatorCallerSession) IsValidDestinationSignature(sender common.Address, data []byte) ([4]byte, error) {
	return _SuperDestinationValidator.Contract.IsValidDestinationSignature(&_SuperDestinationValidator.CallOpts, sender, data)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 , bytes ) pure returns(bytes4)
func (_SuperDestinationValidator *SuperDestinationValidatorCaller) IsValidSignatureWithSender(opts *bind.CallOpts, arg0 common.Address, arg1 [32]byte, arg2 []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperDestinationValidator.contract.Call(opts, &out, "isValidSignatureWithSender", arg0, arg1, arg2)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 , bytes ) pure returns(bytes4)
func (_SuperDestinationValidator *SuperDestinationValidatorSession) IsValidSignatureWithSender(arg0 common.Address, arg1 [32]byte, arg2 []byte) ([4]byte, error) {
	return _SuperDestinationValidator.Contract.IsValidSignatureWithSender(&_SuperDestinationValidator.CallOpts, arg0, arg1, arg2)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 , bytes ) pure returns(bytes4)
func (_SuperDestinationValidator *SuperDestinationValidatorCallerSession) IsValidSignatureWithSender(arg0 common.Address, arg1 [32]byte, arg2 []byte) ([4]byte, error) {
	return _SuperDestinationValidator.Contract.IsValidSignatureWithSender(&_SuperDestinationValidator.CallOpts, arg0, arg1, arg2)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperDestinationValidator *SuperDestinationValidatorCaller) Namespace(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperDestinationValidator.contract.Call(opts, &out, "namespace")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperDestinationValidator *SuperDestinationValidatorSession) Namespace() (string, error) {
	return _SuperDestinationValidator.Contract.Namespace(&_SuperDestinationValidator.CallOpts)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperDestinationValidator *SuperDestinationValidatorCallerSession) Namespace() (string, error) {
	return _SuperDestinationValidator.Contract.Namespace(&_SuperDestinationValidator.CallOpts)
}

// ValidateUserOp is a free data retrieval call binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) , bytes32 ) pure returns(uint256)
func (_SuperDestinationValidator *SuperDestinationValidatorCaller) ValidateUserOp(opts *bind.CallOpts, arg0 PackedUserOperation, arg1 [32]byte) (*big.Int, error) {
	var out []interface{}
	err := _SuperDestinationValidator.contract.Call(opts, &out, "validateUserOp", arg0, arg1)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ValidateUserOp is a free data retrieval call binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) , bytes32 ) pure returns(uint256)
func (_SuperDestinationValidator *SuperDestinationValidatorSession) ValidateUserOp(arg0 PackedUserOperation, arg1 [32]byte) (*big.Int, error) {
	return _SuperDestinationValidator.Contract.ValidateUserOp(&_SuperDestinationValidator.CallOpts, arg0, arg1)
}

// ValidateUserOp is a free data retrieval call binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) , bytes32 ) pure returns(uint256)
func (_SuperDestinationValidator *SuperDestinationValidatorCallerSession) ValidateUserOp(arg0 PackedUserOperation, arg1 [32]byte) (*big.Int, error) {
	return _SuperDestinationValidator.Contract.ValidateUserOp(&_SuperDestinationValidator.CallOpts, arg0, arg1)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperDestinationValidator *SuperDestinationValidatorTransactor) OnInstall(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperDestinationValidator.contract.Transact(opts, "onInstall", data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperDestinationValidator *SuperDestinationValidatorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.OnInstall(&_SuperDestinationValidator.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperDestinationValidator *SuperDestinationValidatorTransactorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.OnInstall(&_SuperDestinationValidator.TransactOpts, data)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationValidator *SuperDestinationValidatorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationValidator.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationValidator *SuperDestinationValidatorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.OnUninstall(&_SuperDestinationValidator.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationValidator *SuperDestinationValidatorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationValidator.Contract.OnUninstall(&_SuperDestinationValidator.TransactOpts, arg0)
}
