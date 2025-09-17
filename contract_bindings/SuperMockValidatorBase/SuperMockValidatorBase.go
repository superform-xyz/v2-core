// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperMockValidatorBase

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

// SuperMockValidatorBaseMetaData contains all meta data concerning the SuperMockValidatorBase contract.
var SuperMockValidatorBaseMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getAccountOwner\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"isValidSignatureWithSender\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"namespace\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateUserOp\",\"inputs\":[{\"name\":\"userOp\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"userOpHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"ERC7579ValidatorBase.ValidationData\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AccountOwnerSet\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AccountUnset\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EMPTY_DESTINATION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_DESTINATION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MERKLE_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_EIP1271_SIGNER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"PROOF_COUNT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PROOF_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNEXPECTED_CHAIN_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperMockValidatorBaseABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperMockValidatorBaseMetaData.ABI instead.
var SuperMockValidatorBaseABI = SuperMockValidatorBaseMetaData.ABI

// SuperMockValidatorBase is an auto generated Go binding around an Ethereum contract.
type SuperMockValidatorBase struct {
	SuperMockValidatorBaseCaller     // Read-only binding to the contract
	SuperMockValidatorBaseTransactor // Write-only binding to the contract
	SuperMockValidatorBaseFilterer   // Log filterer for contract events
}

// SuperMockValidatorBaseCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperMockValidatorBaseCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockValidatorBaseTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperMockValidatorBaseTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockValidatorBaseFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperMockValidatorBaseFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockValidatorBaseSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperMockValidatorBaseSession struct {
	Contract     *SuperMockValidatorBase // Generic contract binding to set the session for
	CallOpts     bind.CallOpts           // Call options to use throughout this session
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// SuperMockValidatorBaseCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperMockValidatorBaseCallerSession struct {
	Contract *SuperMockValidatorBaseCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                 // Call options to use throughout this session
}

// SuperMockValidatorBaseTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperMockValidatorBaseTransactorSession struct {
	Contract     *SuperMockValidatorBaseTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                 // Transaction auth options to use throughout this session
}

// SuperMockValidatorBaseRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperMockValidatorBaseRaw struct {
	Contract *SuperMockValidatorBase // Generic contract binding to access the raw methods on
}

// SuperMockValidatorBaseCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperMockValidatorBaseCallerRaw struct {
	Contract *SuperMockValidatorBaseCaller // Generic read-only contract binding to access the raw methods on
}

// SuperMockValidatorBaseTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperMockValidatorBaseTransactorRaw struct {
	Contract *SuperMockValidatorBaseTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperMockValidatorBase creates a new instance of SuperMockValidatorBase, bound to a specific deployed contract.
func NewSuperMockValidatorBase(address common.Address, backend bind.ContractBackend) (*SuperMockValidatorBase, error) {
	contract, err := bindSuperMockValidatorBase(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperMockValidatorBase{SuperMockValidatorBaseCaller: SuperMockValidatorBaseCaller{contract: contract}, SuperMockValidatorBaseTransactor: SuperMockValidatorBaseTransactor{contract: contract}, SuperMockValidatorBaseFilterer: SuperMockValidatorBaseFilterer{contract: contract}}, nil
}

// NewSuperMockValidatorBaseCaller creates a new read-only instance of SuperMockValidatorBase, bound to a specific deployed contract.
func NewSuperMockValidatorBaseCaller(address common.Address, caller bind.ContractCaller) (*SuperMockValidatorBaseCaller, error) {
	contract, err := bindSuperMockValidatorBase(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockValidatorBaseCaller{contract: contract}, nil
}

// NewSuperMockValidatorBaseTransactor creates a new write-only instance of SuperMockValidatorBase, bound to a specific deployed contract.
func NewSuperMockValidatorBaseTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperMockValidatorBaseTransactor, error) {
	contract, err := bindSuperMockValidatorBase(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockValidatorBaseTransactor{contract: contract}, nil
}

// NewSuperMockValidatorBaseFilterer creates a new log filterer instance of SuperMockValidatorBase, bound to a specific deployed contract.
func NewSuperMockValidatorBaseFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperMockValidatorBaseFilterer, error) {
	contract, err := bindSuperMockValidatorBase(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperMockValidatorBaseFilterer{contract: contract}, nil
}

// bindSuperMockValidatorBase binds a generic wrapper to an already deployed contract.
func bindSuperMockValidatorBase(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperMockValidatorBaseMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockValidatorBase *SuperMockValidatorBaseRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockValidatorBase.Contract.SuperMockValidatorBaseCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockValidatorBase *SuperMockValidatorBaseRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.SuperMockValidatorBaseTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockValidatorBase *SuperMockValidatorBaseRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.SuperMockValidatorBaseTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockValidatorBase *SuperMockValidatorBaseCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockValidatorBase.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.contract.Transact(opts, method, params...)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCaller) GetAccountOwner(opts *bind.CallOpts, account common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperMockValidatorBase.contract.Call(opts, &out, "getAccountOwner", account)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperMockValidatorBase.Contract.GetAccountOwner(&_SuperMockValidatorBase.CallOpts, account)
}

// GetAccountOwner is a free data retrieval call binding the contract method 0x442b172c.
//
// Solidity: function getAccountOwner(address account) view returns(address)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCallerSession) GetAccountOwner(account common.Address) (common.Address, error) {
	return _SuperMockValidatorBase.Contract.GetAccountOwner(&_SuperMockValidatorBase.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperMockValidatorBase.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockValidatorBase.Contract.IsInitialized(&_SuperMockValidatorBase.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockValidatorBase.Contract.IsInitialized(&_SuperMockValidatorBase.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCaller) IsModuleType(opts *bind.CallOpts, typeId *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperMockValidatorBase.contract.Call(opts, &out, "isModuleType", typeId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockValidatorBase.Contract.IsModuleType(&_SuperMockValidatorBase.CallOpts, typeId)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCallerSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockValidatorBase.Contract.IsModuleType(&_SuperMockValidatorBase.CallOpts, typeId)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address sender, bytes32 hash, bytes data) view returns(bytes4)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCaller) IsValidSignatureWithSender(opts *bind.CallOpts, sender common.Address, hash [32]byte, data []byte) ([4]byte, error) {
	var out []interface{}
	err := _SuperMockValidatorBase.contract.Call(opts, &out, "isValidSignatureWithSender", sender, hash, data)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address sender, bytes32 hash, bytes data) view returns(bytes4)
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) IsValidSignatureWithSender(sender common.Address, hash [32]byte, data []byte) ([4]byte, error) {
	return _SuperMockValidatorBase.Contract.IsValidSignatureWithSender(&_SuperMockValidatorBase.CallOpts, sender, hash, data)
}

// IsValidSignatureWithSender is a free data retrieval call binding the contract method 0xf551e2ee.
//
// Solidity: function isValidSignatureWithSender(address sender, bytes32 hash, bytes data) view returns(bytes4)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCallerSession) IsValidSignatureWithSender(sender common.Address, hash [32]byte, data []byte) ([4]byte, error) {
	return _SuperMockValidatorBase.Contract.IsValidSignatureWithSender(&_SuperMockValidatorBase.CallOpts, sender, hash, data)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCaller) Namespace(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperMockValidatorBase.contract.Call(opts, &out, "namespace")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) Namespace() (string, error) {
	return _SuperMockValidatorBase.Contract.Namespace(&_SuperMockValidatorBase.CallOpts)
}

// Namespace is a free data retrieval call binding the contract method 0x7c015a89.
//
// Solidity: function namespace() pure returns(string)
func (_SuperMockValidatorBase *SuperMockValidatorBaseCallerSession) Namespace() (string, error) {
	return _SuperMockValidatorBase.Contract.Namespace(&_SuperMockValidatorBase.CallOpts)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactor) OnInstall(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.contract.Transact(opts, "onInstall", data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.OnInstall(&_SuperMockValidatorBase.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes data) returns()
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactorSession) OnInstall(data []byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.OnInstall(&_SuperMockValidatorBase.TransactOpts, data)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.OnUninstall(&_SuperMockValidatorBase.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.OnUninstall(&_SuperMockValidatorBase.TransactOpts, arg0)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash) returns(uint256)
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactor) ValidateUserOp(opts *bind.TransactOpts, userOp PackedUserOperation, userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.contract.Transact(opts, "validateUserOp", userOp, userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash) returns(uint256)
func (_SuperMockValidatorBase *SuperMockValidatorBaseSession) ValidateUserOp(userOp PackedUserOperation, userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.ValidateUserOp(&_SuperMockValidatorBase.TransactOpts, userOp, userOpHash)
}

// ValidateUserOp is a paid mutator transaction binding the contract method 0x97003203.
//
// Solidity: function validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash) returns(uint256)
func (_SuperMockValidatorBase *SuperMockValidatorBaseTransactorSession) ValidateUserOp(userOp PackedUserOperation, userOpHash [32]byte) (*types.Transaction, error) {
	return _SuperMockValidatorBase.Contract.ValidateUserOp(&_SuperMockValidatorBase.TransactOpts, userOp, userOpHash)
}

// SuperMockValidatorBaseAccountOwnerSetIterator is returned from FilterAccountOwnerSet and is used to iterate over the raw logs and unpacked data for AccountOwnerSet events raised by the SuperMockValidatorBase contract.
type SuperMockValidatorBaseAccountOwnerSetIterator struct {
	Event *SuperMockValidatorBaseAccountOwnerSet // Event containing the contract specifics and raw log

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
func (it *SuperMockValidatorBaseAccountOwnerSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockValidatorBaseAccountOwnerSet)
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
		it.Event = new(SuperMockValidatorBaseAccountOwnerSet)
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
func (it *SuperMockValidatorBaseAccountOwnerSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockValidatorBaseAccountOwnerSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockValidatorBaseAccountOwnerSet represents a AccountOwnerSet event raised by the SuperMockValidatorBase contract.
type SuperMockValidatorBaseAccountOwnerSet struct {
	Account common.Address
	Owner   common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountOwnerSet is a free log retrieval operation binding the contract event 0xbe3f5c5c79d582b53d2c89a48a099e3d039cd3a249a2ad0f932cc39357c69fad.
//
// Solidity: event AccountOwnerSet(address indexed account, address indexed owner)
func (_SuperMockValidatorBase *SuperMockValidatorBaseFilterer) FilterAccountOwnerSet(opts *bind.FilterOpts, account []common.Address, owner []common.Address) (*SuperMockValidatorBaseAccountOwnerSetIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperMockValidatorBase.contract.FilterLogs(opts, "AccountOwnerSet", accountRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockValidatorBaseAccountOwnerSetIterator{contract: _SuperMockValidatorBase.contract, event: "AccountOwnerSet", logs: logs, sub: sub}, nil
}

// WatchAccountOwnerSet is a free log subscription operation binding the contract event 0xbe3f5c5c79d582b53d2c89a48a099e3d039cd3a249a2ad0f932cc39357c69fad.
//
// Solidity: event AccountOwnerSet(address indexed account, address indexed owner)
func (_SuperMockValidatorBase *SuperMockValidatorBaseFilterer) WatchAccountOwnerSet(opts *bind.WatchOpts, sink chan<- *SuperMockValidatorBaseAccountOwnerSet, account []common.Address, owner []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperMockValidatorBase.contract.WatchLogs(opts, "AccountOwnerSet", accountRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockValidatorBaseAccountOwnerSet)
				if err := _SuperMockValidatorBase.contract.UnpackLog(event, "AccountOwnerSet", log); err != nil {
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
func (_SuperMockValidatorBase *SuperMockValidatorBaseFilterer) ParseAccountOwnerSet(log types.Log) (*SuperMockValidatorBaseAccountOwnerSet, error) {
	event := new(SuperMockValidatorBaseAccountOwnerSet)
	if err := _SuperMockValidatorBase.contract.UnpackLog(event, "AccountOwnerSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockValidatorBaseAccountUnsetIterator is returned from FilterAccountUnset and is used to iterate over the raw logs and unpacked data for AccountUnset events raised by the SuperMockValidatorBase contract.
type SuperMockValidatorBaseAccountUnsetIterator struct {
	Event *SuperMockValidatorBaseAccountUnset // Event containing the contract specifics and raw log

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
func (it *SuperMockValidatorBaseAccountUnsetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockValidatorBaseAccountUnset)
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
		it.Event = new(SuperMockValidatorBaseAccountUnset)
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
func (it *SuperMockValidatorBaseAccountUnsetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockValidatorBaseAccountUnsetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockValidatorBaseAccountUnset represents a AccountUnset event raised by the SuperMockValidatorBase contract.
type SuperMockValidatorBaseAccountUnset struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountUnset is a free log retrieval operation binding the contract event 0x231ed5455a8a61ef69418a03c2725cbfb235bcb6c08ca6ad51a9064465f7c3a2.
//
// Solidity: event AccountUnset(address indexed account)
func (_SuperMockValidatorBase *SuperMockValidatorBaseFilterer) FilterAccountUnset(opts *bind.FilterOpts, account []common.Address) (*SuperMockValidatorBaseAccountUnsetIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockValidatorBase.contract.FilterLogs(opts, "AccountUnset", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockValidatorBaseAccountUnsetIterator{contract: _SuperMockValidatorBase.contract, event: "AccountUnset", logs: logs, sub: sub}, nil
}

// WatchAccountUnset is a free log subscription operation binding the contract event 0x231ed5455a8a61ef69418a03c2725cbfb235bcb6c08ca6ad51a9064465f7c3a2.
//
// Solidity: event AccountUnset(address indexed account)
func (_SuperMockValidatorBase *SuperMockValidatorBaseFilterer) WatchAccountUnset(opts *bind.WatchOpts, sink chan<- *SuperMockValidatorBaseAccountUnset, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockValidatorBase.contract.WatchLogs(opts, "AccountUnset", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockValidatorBaseAccountUnset)
				if err := _SuperMockValidatorBase.contract.UnpackLog(event, "AccountUnset", log); err != nil {
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
func (_SuperMockValidatorBase *SuperMockValidatorBaseFilterer) ParseAccountUnset(log types.Log) (*SuperMockValidatorBaseAccountUnset, error) {
	event := new(SuperMockValidatorBaseAccountUnset)
	if err := _SuperMockValidatorBase.contract.UnpackLog(event, "AccountUnset", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
