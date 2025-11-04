// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperValidatorBaseSimulations

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

// SuperValidatorBaseSimulationsMetaData contains all meta data concerning the SuperValidatorBaseSimulations contract.
var SuperValidatorBaseSimulationsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getAccountOwner\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"isValidSignatureWithSender\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"namespace\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateUserOp\",\"inputs\":[{\"name\":\"userOp\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"userOpHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"ERC7579ValidatorBase.ValidationData\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AccountOwnerSet\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AccountUnset\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EMPTY_DESTINATION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_DESTINATION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MERKLE_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_EIP1271_SIGNER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"PROOF_COUNT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PROOF_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNEXPECTED_CHAIN_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperValidatorBaseSimulationsABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperValidatorBaseSimulationsMetaData.ABI instead.
var SuperValidatorBaseSimulationsABI = SuperValidatorBaseSimulationsMetaData.ABI

// SuperValidatorBaseSimulations is an auto generated Go binding around an Ethereum contract.
type SuperValidatorBaseSimulations struct {
	SuperValidatorBaseSimulationsCaller     // Read-only binding to the contract
	SuperValidatorBaseSimulationsTransactor // Write-only binding to the contract
	SuperValidatorBaseSimulationsFilterer   // Log filterer for contract events
}

// SuperValidatorBaseSimulationsCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperValidatorBaseSimulationsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorBaseSimulationsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperValidatorBaseSimulationsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorBaseSimulationsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperValidatorBaseSimulationsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorBaseSimulationsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperValidatorBaseSimulationsSession struct {
	Contract     *SuperValidatorBaseSimulations // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                  // Call options to use throughout this session
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// SuperValidatorBaseSimulationsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperValidatorBaseSimulationsCallerSession struct {
	Contract *SuperValidatorBaseSimulationsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                        // Call options to use throughout this session
}

// SuperValidatorBaseSimulationsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperValidatorBaseSimulationsTransactorSession struct {
	Contract     *SuperValidatorBaseSimulationsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                        // Transaction auth options to use throughout this session
}

// SuperValidatorBaseSimulationsRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperValidatorBaseSimulationsRaw struct {
	Contract *SuperValidatorBaseSimulations // Generic contract binding to access the raw methods on
}

// SuperValidatorBaseSimulationsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperValidatorBaseSimulationsCallerRaw struct {
	Contract *SuperValidatorBaseSimulationsCaller // Generic read-only contract binding to access the raw methods on
}

// SuperValidatorBaseSimulationsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperValidatorBaseSimulationsTransactorRaw struct {
	Contract *SuperValidatorBaseSimulationsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperValidatorBaseSimulations creates a new instance of SuperValidatorBaseSimulations, bound to a specific deployed contract.
func NewSuperValidatorBaseSimulations(address common.Address, backend bind.ContractBackend) (*SuperValidatorBaseSimulations, error) {
	contract, err := bindSuperValidatorBaseSimulations(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorBaseSimulations{SuperValidatorBaseSimulationsCaller: SuperValidatorBaseSimulationsCaller{contract: contract}, SuperValidatorBaseSimulationsTransactor: SuperValidatorBaseSimulationsTransactor{contract: contract}, SuperValidatorBaseSimulationsFilterer: SuperValidatorBaseSimulationsFilterer{contract: contract}}, nil
}

// NewSuperValidatorBaseSimulationsCaller creates a new read-only instance of SuperValidatorBaseSimulations, bound to a specific deployed contract.
func NewSuperValidatorBaseSimulationsCaller(address common.Address, caller bind.ContractCaller) (*SuperValidatorBaseSimulationsCaller, error) {
	contract, err := bindSuperValidatorBaseSimulations(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorBaseSimulationsCaller{contract: contract}, nil
}

// NewSuperValidatorBaseSimulationsTransactor creates a new write-only instance of SuperValidatorBaseSimulations, bound to a specific deployed contract.
func NewSuperValidatorBaseSimulationsTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperValidatorBaseSimulationsTransactor, error) {
	contract, err := bindSuperValidatorBaseSimulations(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorBaseSimulationsTransactor{contract: contract}, nil
}

// NewSuperValidatorBaseSimulationsFilterer creates a new log filterer instance of SuperValidatorBaseSimulations, bound to a specific deployed contract.
func NewSuperValidatorBaseSimulationsFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperValidatorBaseSimulationsFilterer, error) {
	contract, err := bindSuperValidatorBaseSimulations(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorBaseSimulationsFilterer{contract: contract}, nil
}

// bindSuperValidatorBaseSimulations binds a generic wrapper to an already deployed contract.
func bindSuperValidatorBaseSimulations(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperValidatorBaseSimulationsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidatorBaseSimulations.Contract.SuperValidatorBaseSimulationsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.SuperValidatorBaseSimulationsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.SuperValidatorBaseSimulationsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidatorBaseSimulations.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.contract.Transact(opts, method, params...)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCaller) GetAccountOwner(opts *bind.CallOpts, account common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperValidatorBaseSimulations.contract.Call(opts, &out, "getAccountOwner", account)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperValidatorBaseSimulations.Contract.GetAccountOwner(&_SuperValidatorBaseSimulations.CallOpts, account)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCallerSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperValidatorBaseSimulations.Contract.GetAccountOwner(&_SuperValidatorBaseSimulations.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperValidatorBaseSimulations.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperValidatorBaseSimulations.Contract.IsInitialized(&_SuperValidatorBaseSimulations.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperValidatorBaseSimulations.Contract.IsInitialized(&_SuperValidatorBaseSimulations.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCaller) IsModuleType(opts *bind.CallOpts, typeId *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperValidatorBaseSimulations.contract.Call(opts, &out, "isModuleType", typeId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperValidatorBaseSimulations.Contract.IsModuleType(&_SuperValidatorBaseSimulations.CallOpts, typeId)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCallerSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperValidatorBaseSimulations.Contract.IsModuleType(&_SuperValidatorBaseSimulations.CallOpts, typeId)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address sender, bytes32 hash, bytes data) view returns(bytes4)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCaller) IsValidSignatureWithSender(opts *bind.CallOpts, sender common.Address, hash [32]byte, data []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperValidatorBaseSimulations.contract.Call(opts, &out, "isValidSignatureWithSender", sender, hash, data)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address sender, bytes32 hash, bytes data) view returns(bytes4)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) IsValidSignatureWithSender(sender common.Address, hash [32]byte, data []byte) ([4]byte, error) {
	return _SuperValidatorBaseSimulations.Contract.IsValidSignatureWithSender(&_SuperValidatorBaseSimulations.CallOpts, sender, hash, data)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address sender, bytes32 hash, bytes data) view returns(bytes4)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCallerSession) IsValidSignatureWithSender(sender common.Address, hash [32]byte, data []byte) ([4]byte, error) {
	return _SuperValidatorBaseSimulations.Contract.IsValidSignatureWithSender(&_SuperValidatorBaseSimulations.CallOpts, sender, hash, data)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCaller) Namespace(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperValidatorBaseSimulations.contract.Call(opts, &out, "namespace")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) Namespace() (string, error) {
	return _SuperValidatorBaseSimulations.Contract.Namespace(&_SuperValidatorBaseSimulations.CallOpts)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsCallerSession) Namespace() (string, error) {
	return _SuperValidatorBaseSimulations.Contract.Namespace(&_SuperValidatorBaseSimulations.CallOpts)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactor) OnInstall(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.contract.Transact(opts, "onInstall", data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.OnInstall(&_SuperValidatorBaseSimulations.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.OnInstall(&_SuperValidatorBaseSimulations.TransactOpts, data)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.OnUninstall(&_SuperValidatorBaseSimulations.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.OnUninstall(&_SuperValidatorBaseSimulations.TransactOpts, arg0)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash) returns(uint256)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactor) ValidateUserOp(opts *bind.TransactOpts, userOp PackedUserOperation, userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.contract.Transact(opts, "validateUserOp", userOp, userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash) returns(uint256)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsSession) ValidateUserOp(userOp PackedUserOperation, userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.ValidateUserOp(&_SuperValidatorBaseSimulations.TransactOpts, userOp, userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash) returns(uint256)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsTransactorSession) ValidateUserOp(userOp PackedUserOperation, userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperValidatorBaseSimulations.Contract.ValidateUserOp(&_SuperValidatorBaseSimulations.TransactOpts, userOp, userOpHash)
}

// SuperValidatorBaseSimulationsAccountOwnerSetIterator is returned from FilterAccountOwnerSet and is used to iterate over the raw logs and unpacked data for AccountOwnerSet events raised by the SuperValidatorBaseSimulations contract.
type SuperValidatorBaseSimulationsAccountOwnerSetIterator struct {
	Event *SuperValidatorBaseSimulationsAccountOwnerSet // Event containing the contract specifics and raw log

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
func (it *SuperValidatorBaseSimulationsAccountOwnerSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperValidatorBaseSimulationsAccountOwnerSet)
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
		it.Event = new(SuperValidatorBaseSimulationsAccountOwnerSet)
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
func (it *SuperValidatorBaseSimulationsAccountOwnerSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperValidatorBaseSimulationsAccountOwnerSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperValidatorBaseSimulationsAccountOwnerSet represents a AccountOwnerSet event raised by the SuperValidatorBaseSimulations contract.
type SuperValidatorBaseSimulationsAccountOwnerSet struct {
	Account common.Address
	Owner   common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountOwnerSet is a free log retrieval operation binding the contract event 0xbe3f5c5c79d582b53d2c89a48a099e3d039cd3a249a2ad0f932cc39357c69fad.
//
// Solidity: event AccountOwnerSet(address indexed account, address indexed owner)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsFilterer) FilterAccountOwnerSet(opts *bind.FilterOpts, account []common.Address, owner []common.Address) (*SuperValidatorBaseSimulationsAccountOwnerSetIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperValidatorBaseSimulations.contract.FilterLogs(opts, "AccountOwnerSet", accountRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorBaseSimulationsAccountOwnerSetIterator{contract: _SuperValidatorBaseSimulations.contract, event: "AccountOwnerSet", logs: logs, sub: sub}, nil
}

// WatchAccountOwnerSet is a free log subscription operation binding the contract event 0xbe3f5c5c79d582b53d2c89a48a099e3d039cd3a249a2ad0f932cc39357c69fad.
//
// Solidity: event AccountOwnerSet(address indexed account, address indexed owner)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsFilterer) WatchAccountOwnerSet(opts *bind.WatchOpts, sink chan<- *SuperValidatorBaseSimulationsAccountOwnerSet, account []common.Address, owner []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperValidatorBaseSimulations.contract.WatchLogs(opts, "AccountOwnerSet", accountRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperValidatorBaseSimulationsAccountOwnerSet)
				if err := _SuperValidatorBaseSimulations.contract.UnpackLog(event, "AccountOwnerSet", log); err != nil {
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
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsFilterer) ParseAccountOwnerSet(log types.Log) (*SuperValidatorBaseSimulationsAccountOwnerSet, error) {
	event := new(SuperValidatorBaseSimulationsAccountOwnerSet)
	if err := _SuperValidatorBaseSimulations.contract.UnpackLog(event, "AccountOwnerSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperValidatorBaseSimulationsAccountUnsetIterator is returned from FilterAccountUnset and is used to iterate over the raw logs and unpacked data for AccountUnset events raised by the SuperValidatorBaseSimulations contract.
type SuperValidatorBaseSimulationsAccountUnsetIterator struct {
	Event *SuperValidatorBaseSimulationsAccountUnset // Event containing the contract specifics and raw log

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
func (it *SuperValidatorBaseSimulationsAccountUnsetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperValidatorBaseSimulationsAccountUnset)
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
		it.Event = new(SuperValidatorBaseSimulationsAccountUnset)
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
func (it *SuperValidatorBaseSimulationsAccountUnsetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperValidatorBaseSimulationsAccountUnsetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperValidatorBaseSimulationsAccountUnset represents a AccountUnset event raised by the SuperValidatorBaseSimulations contract.
type SuperValidatorBaseSimulationsAccountUnset struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountUnset is a free log retrieval operation binding the contract event 0x231ed5455a8a61ef69418a03c2725cbfb235bcb6c08ca6ad51a9064465f7c3a2.
//
// Solidity: event AccountUnset(address indexed account)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsFilterer) FilterAccountUnset(opts *bind.FilterOpts, account []common.Address) (*SuperValidatorBaseSimulationsAccountUnsetIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperValidatorBaseSimulations.contract.FilterLogs(opts, "AccountUnset", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorBaseSimulationsAccountUnsetIterator{contract: _SuperValidatorBaseSimulations.contract, event: "AccountUnset", logs: logs, sub: sub}, nil
}

// WatchAccountUnset is a free log subscription operation binding the contract event 0x231ed5455a8a61ef69418a03c2725cbfb235bcb6c08ca6ad51a9064465f7c3a2.
//
// Solidity: event AccountUnset(address indexed account)
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsFilterer) WatchAccountUnset(opts *bind.WatchOpts, sink chan<- *SuperValidatorBaseSimulationsAccountUnset, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperValidatorBaseSimulations.contract.WatchLogs(opts, "AccountUnset", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperValidatorBaseSimulationsAccountUnset)
				if err := _SuperValidatorBaseSimulations.contract.UnpackLog(event, "AccountUnset", log); err != nil {
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
func (_SuperValidatorBaseSimulations *SuperValidatorBaseSimulationsFilterer) ParseAccountUnset(log types.Log) (*SuperValidatorBaseSimulationsAccountUnset, error) {
	event := new(SuperValidatorBaseSimulationsAccountUnset)
	if err := _SuperValidatorBaseSimulations.contract.UnpackLog(event, "AccountUnset", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
