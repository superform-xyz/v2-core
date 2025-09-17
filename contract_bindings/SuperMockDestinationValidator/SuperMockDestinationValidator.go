// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperMockDestinationValidator

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

// SuperMockDestinationValidatorMetaData contains all meta data concerning the SuperMockDestinationValidator contract.
var SuperMockDestinationValidatorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getAccountOwner\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"isValidDestinationSignature\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidSignatureWithSender\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"namespace\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateUserOp\",\"inputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"ERC7579ValidatorBase.ValidationData\"}],\"stateMutability\":\"pure\"},{\"type\":\"event\",\"name\":\"AccountOwnerSet\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AccountUnset\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EMPTY_DESTINATION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_DESTINATION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MERKLE_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_EIP1271_SIGNER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"PROOF_COUNT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PROOF_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNEXPECTED_CHAIN_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperMockDestinationValidatorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperMockDestinationValidatorMetaData.ABI instead.
var SuperMockDestinationValidatorABI = SuperMockDestinationValidatorMetaData.ABI

// SuperMockDestinationValidator is an auto generated Go binding around an Ethereum contract.
type SuperMockDestinationValidator struct {
	SuperMockDestinationValidatorCaller     // Read-only binding to the contract
	SuperMockDestinationValidatorTransactor // Write-only binding to the contract
	SuperMockDestinationValidatorFilterer   // Log filterer for contract events
}

// SuperMockDestinationValidatorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperMockDestinationValidatorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockDestinationValidatorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperMockDestinationValidatorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockDestinationValidatorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperMockDestinationValidatorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockDestinationValidatorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperMockDestinationValidatorSession struct {
	Contract     *SuperMockDestinationValidator // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                  // Call options to use throughout this session
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// SuperMockDestinationValidatorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperMockDestinationValidatorCallerSession struct {
	Contract *SuperMockDestinationValidatorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                        // Call options to use throughout this session
}

// SuperMockDestinationValidatorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperMockDestinationValidatorTransactorSession struct {
	Contract     *SuperMockDestinationValidatorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                        // Transaction auth options to use throughout this session
}

// SuperMockDestinationValidatorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperMockDestinationValidatorRaw struct {
	Contract *SuperMockDestinationValidator // Generic contract binding to access the raw methods on
}

// SuperMockDestinationValidatorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperMockDestinationValidatorCallerRaw struct {
	Contract *SuperMockDestinationValidatorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperMockDestinationValidatorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperMockDestinationValidatorTransactorRaw struct {
	Contract *SuperMockDestinationValidatorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperMockDestinationValidator creates a new instance of SuperMockDestinationValidator, bound to a specific deployed contract.
func NewSuperMockDestinationValidator(address common.Address, backend bind.ContractBackend) (*SuperMockDestinationValidator, error) {
	contract, err := bindSuperMockDestinationValidator(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationValidator{SuperMockDestinationValidatorCaller: SuperMockDestinationValidatorCaller{contract: contract}, SuperMockDestinationValidatorTransactor: SuperMockDestinationValidatorTransactor{contract: contract}, SuperMockDestinationValidatorFilterer: SuperMockDestinationValidatorFilterer{contract: contract}}, nil
}

// NewSuperMockDestinationValidatorCaller creates a new read-only instance of SuperMockDestinationValidator, bound to a specific deployed contract.
func NewSuperMockDestinationValidatorCaller(address common.Address, caller bind.ContractCaller) (*SuperMockDestinationValidatorCaller, error) {
	contract, err := bindSuperMockDestinationValidator(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationValidatorCaller{contract: contract}, nil
}

// NewSuperMockDestinationValidatorTransactor creates a new write-only instance of SuperMockDestinationValidator, bound to a specific deployed contract.
func NewSuperMockDestinationValidatorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperMockDestinationValidatorTransactor, error) {
	contract, err := bindSuperMockDestinationValidator(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationValidatorTransactor{contract: contract}, nil
}

// NewSuperMockDestinationValidatorFilterer creates a new log filterer instance of SuperMockDestinationValidator, bound to a specific deployed contract.
func NewSuperMockDestinationValidatorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperMockDestinationValidatorFilterer, error) {
	contract, err := bindSuperMockDestinationValidator(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationValidatorFilterer{contract: contract}, nil
}

// bindSuperMockDestinationValidator binds a generic wrapper to an already deployed contract.
func bindSuperMockDestinationValidator(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperMockDestinationValidatorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockDestinationValidator.Contract.SuperMockDestinationValidatorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.SuperMockDestinationValidatorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.SuperMockDestinationValidatorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockDestinationValidator.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.contract.Transact(opts, method, params...)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCaller) GetAccountOwner(opts *bind.CallOpts, account common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperMockDestinationValidator.contract.Call(opts, &out, "getAccountOwner", account)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperMockDestinationValidator.Contract.GetAccountOwner(&_SuperMockDestinationValidator.CallOpts, account)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperMockDestinationValidator.Contract.GetAccountOwner(&_SuperMockDestinationValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperMockDestinationValidator.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockDestinationValidator.Contract.IsInitialized(&_SuperMockDestinationValidator.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockDestinationValidator.Contract.IsInitialized(&_SuperMockDestinationValidator.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCaller) IsModuleType(opts *bind.CallOpts, typeId *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperMockDestinationValidator.contract.Call(opts, &out, "isModuleType", typeId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockDestinationValidator.Contract.IsModuleType(&_SuperMockDestinationValidator.CallOpts, typeId)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockDestinationValidator.Contract.IsModuleType(&_SuperMockDestinationValidator.CallOpts, typeId)
}

// IsValidDestinationSignature is a free data retrieval call binding the contract method 0x5c2ec0f3.
//
// Solidity: function isValidDestinationSignature(address sender, bytes data) view returns(bytes4)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCaller) IsValidDestinationSignature(opts *bind.CallOpts, sender common.Address, data []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperMockDestinationValidator.contract.Call(opts, &out, "isValidDestinationSignature", sender, data)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidDestinationSignature is a free data retrieval call binding the contract method 0x5c2ec0f3.
//
// Solidity: function isValidDestinationSignature(address sender, bytes data) view returns(bytes4)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) IsValidDestinationSignature(sender common.Address, data []byte) ([4]byte, error) {
	return _SuperMockDestinationValidator.Contract.IsValidDestinationSignature(&_SuperMockDestinationValidator.CallOpts, sender, data)
}

// IsValidDestinationSignature is a free data retrieval call binding the contract method 0x5c2ec0f3.
//
// Solidity: function isValidDestinationSignature(address sender, bytes data) view returns(bytes4)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerSession) IsValidDestinationSignature(sender common.Address, data []byte) ([4]byte, error) {
	return _SuperMockDestinationValidator.Contract.IsValidDestinationSignature(&_SuperMockDestinationValidator.CallOpts, sender, data)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 , bytes ) pure returns(bytes4)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCaller) IsValidSignatureWithSender(opts *bind.CallOpts, arg0 common.Address, arg1 [32]byte, arg2 []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperMockDestinationValidator.contract.Call(opts, &out, "isValidSignatureWithSender", arg0, arg1, arg2)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 , bytes ) pure returns(bytes4)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) IsValidSignatureWithSender(arg0 common.Address, arg1 [32]byte, arg2 []byte) ([4]byte, error) {
	return _SuperMockDestinationValidator.Contract.IsValidSignatureWithSender(&_SuperMockDestinationValidator.CallOpts, arg0, arg1, arg2)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address , bytes32 , bytes ) pure returns(bytes4)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerSession) IsValidSignatureWithSender(arg0 common.Address, arg1 [32]byte, arg2 []byte) ([4]byte, error) {
	return _SuperMockDestinationValidator.Contract.IsValidSignatureWithSender(&_SuperMockDestinationValidator.CallOpts, arg0, arg1, arg2)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCaller) Namespace(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperMockDestinationValidator.contract.Call(opts, &out, "namespace")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) Namespace() (string, error) {
	return _SuperMockDestinationValidator.Contract.Namespace(&_SuperMockDestinationValidator.CallOpts)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerSession) Namespace() (string, error) {
	return _SuperMockDestinationValidator.Contract.Namespace(&_SuperMockDestinationValidator.CallOpts)
}

// ValidateUserOp is a free data retrieval call binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) , bytes32 ) pure returns(uint256)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCaller) ValidateUserOp(opts *bind.CallOpts, arg0 PackedUserOperation, arg1 [32]byte) (*big.Int, error) {
	var out []interface{}
	err := _SuperMockDestinationValidator.contract.Call(opts, &out, "validateUserOp", arg0, arg1)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ValidateUserOp is a free data retrieval call binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) , bytes32 ) pure returns(uint256)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) ValidateUserOp(arg0 PackedUserOperation, arg1 [32]byte) (*big.Int, error) {
	return _SuperMockDestinationValidator.Contract.ValidateUserOp(&_SuperMockDestinationValidator.CallOpts, arg0, arg1)
}

// ValidateUserOp is a free data retrieval call binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) , bytes32 ) pure returns(uint256)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorCallerSession) ValidateUserOp(arg0 PackedUserOperation, arg1 [32]byte) (*big.Int, error) {
	return _SuperMockDestinationValidator.Contract.ValidateUserOp(&_SuperMockDestinationValidator.CallOpts, arg0, arg1)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorTransactor) OnInstall(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.contract.Transact(opts, "onInstall", data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.OnInstall(&_SuperMockDestinationValidator.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorTransactorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.OnInstall(&_SuperMockDestinationValidator.TransactOpts, data)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.OnUninstall(&_SuperMockDestinationValidator.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationValidator.Contract.OnUninstall(&_SuperMockDestinationValidator.TransactOpts, arg0)
}

// SuperMockDestinationValidatorAccountOwnerSetIterator is returned from FilterAccountOwnerSet and is used to iterate over the raw logs and unpacked data for AccountOwnerSet events raised by the SuperMockDestinationValidator contract.
type SuperMockDestinationValidatorAccountOwnerSetIterator struct {
	Event *SuperMockDestinationValidatorAccountOwnerSet // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationValidatorAccountOwnerSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationValidatorAccountOwnerSet)
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
		it.Event = new(SuperMockDestinationValidatorAccountOwnerSet)
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
func (it *SuperMockDestinationValidatorAccountOwnerSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationValidatorAccountOwnerSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationValidatorAccountOwnerSet represents a AccountOwnerSet event raised by the SuperMockDestinationValidator contract.
type SuperMockDestinationValidatorAccountOwnerSet struct {
	Account common.Address
	Owner   common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountOwnerSet is a free log retrieval operation binding the contract event 0xbe3f5c5c79d582b53d2c89a48a099e3d039cd3a249a2ad0f932cc39357c69fad.
//
// Solidity: event AccountOwnerSet(address indexed account, address indexed owner)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorFilterer) FilterAccountOwnerSet(opts *bind.FilterOpts, account []common.Address, owner []common.Address) (*SuperMockDestinationValidatorAccountOwnerSetIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperMockDestinationValidator.contract.FilterLogs(opts, "AccountOwnerSet", accountRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationValidatorAccountOwnerSetIterator{contract: _SuperMockDestinationValidator.contract, event: "AccountOwnerSet", logs: logs, sub: sub}, nil
}

// WatchAccountOwnerSet is a free log subscription operation binding the contract event 0xbe3f5c5c79d582b53d2c89a48a099e3d039cd3a249a2ad0f932cc39357c69fad.
//
// Solidity: event AccountOwnerSet(address indexed account, address indexed owner)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorFilterer) WatchAccountOwnerSet(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationValidatorAccountOwnerSet, account []common.Address, owner []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperMockDestinationValidator.contract.WatchLogs(opts, "AccountOwnerSet", accountRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationValidatorAccountOwnerSet)
				if err := _SuperMockDestinationValidator.contract.UnpackLog(event, "AccountOwnerSet", log); err != nil {
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

// ParseAccountOwnerSet is a log parse operation binding the contract event 0xbe3f5c5c79d582b53d2c89a48a099e3d039cd3a249a2ad0f932cc39357c69fad.
//
// Solidity: event AccountOwnerSet(address indexed account, address indexed owner)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorFilterer) ParseAccountOwnerSet(log types.Log) (*SuperMockDestinationValidatorAccountOwnerSet, error) {
	event := new(SuperMockDestinationValidatorAccountOwnerSet)
	if err := _SuperMockDestinationValidator.contract.UnpackLog(event, "AccountOwnerSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationValidatorAccountUnsetIterator is returned from FilterAccountUnset and is used to iterate over the raw logs and unpacked data for AccountUnset events raised by the SuperMockDestinationValidator contract.
type SuperMockDestinationValidatorAccountUnsetIterator struct {
	Event *SuperMockDestinationValidatorAccountUnset // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationValidatorAccountUnsetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationValidatorAccountUnset)
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
		it.Event = new(SuperMockDestinationValidatorAccountUnset)
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
func (it *SuperMockDestinationValidatorAccountUnsetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationValidatorAccountUnsetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationValidatorAccountUnset represents a AccountUnset event raised by the SuperMockDestinationValidator contract.
type SuperMockDestinationValidatorAccountUnset struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountUnset is a free log retrieval operation binding the contract event 0x231ed5455a8a61ef69418a03c2725cbfb235bcb6c08ca6ad51a9064465f7c3a2.
//
// Solidity: event AccountUnset(address indexed account)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorFilterer) FilterAccountUnset(opts *bind.FilterOpts, account []common.Address) (*SuperMockDestinationValidatorAccountUnsetIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationValidator.contract.FilterLogs(opts, "AccountUnset", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationValidatorAccountUnsetIterator{contract: _SuperMockDestinationValidator.contract, event: "AccountUnset", logs: logs, sub: sub}, nil
}

// WatchAccountUnset is a free log subscription operation binding the contract event 0x231ed5455a8a61ef69418a03c2725cbfb235bcb6c08ca6ad51a9064465f7c3a2.
//
// Solidity: event AccountUnset(address indexed account)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorFilterer) WatchAccountUnset(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationValidatorAccountUnset, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationValidator.contract.WatchLogs(opts, "AccountUnset", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationValidatorAccountUnset)
				if err := _SuperMockDestinationValidator.contract.UnpackLog(event, "AccountUnset", log); err != nil {
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

// ParseAccountUnset is a log parse operation binding the contract event 0x231ed5455a8a61ef69418a03c2725cbfb235bcb6c08ca6ad51a9064465f7c3a2.
//
// Solidity: event AccountUnset(address indexed account)
func (_SuperMockDestinationValidator *SuperMockDestinationValidatorFilterer) ParseAccountUnset(log types.Log) (*SuperMockDestinationValidatorAccountUnset, error) {
	event := new(SuperMockDestinationValidatorAccountUnset)
	if err := _SuperMockDestinationValidator.contract.UnpackLog(event, "AccountUnset", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
