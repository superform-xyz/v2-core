// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperNativePaymaster

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

// SuperNativePaymasterMetaData contains all meta data concerning the SuperNativePaymaster contract.
var SuperNativePaymasterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_entryPoint\",\"type\":\"address\",\"internalType\":\"contractIEntryPoint\"}],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addStake\",\"inputs\":[{\"name\":\"unstakeDelaySec\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"calculateRefund\",\"inputs\":[{\"name\":\"maxGasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"maxFeePerGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualGasCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"nodeOperatorPremium\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"refund\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"entryPoint\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIEntryPoint\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getDeposit\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleOps\",\"inputs\":[{\"name\":\"ops\",\"type\":\"tuple[]\",\"internalType\":\"structPackedUserOperation[]\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"postOp\",\"inputs\":[{\"name\":\"mode\",\"type\":\"uint8\",\"internalType\":\"enumIPaymaster.PostOpMode\"},{\"name\":\"context\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"actualGasCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualUserOpFeePerGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unlockStake\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validatePaymasterUserOp\",\"inputs\":[{\"name\":\"userOp\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"userOpHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"maxCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"context\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"validationData\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawStake\",\"inputs\":[{\"name\":\"withdrawAddress\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawTo\",\"inputs\":[{\"name\":\"withdrawAddress\",\"type\":\"address\",\"internalType\":\"addresspayable\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperNativePaymasterPostOp\",\"inputs\":[{\"name\":\"context\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperNativePaymsterRefund\",\"inputs\":[{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"refund\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"EMPTY_MESSAGE_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MAX_GAS_LIMIT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_NODE_OPERATOR_PREMIUM\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OwnableInvalidOwner\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperNativePaymasterABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperNativePaymasterMetaData.ABI instead.
var SuperNativePaymasterABI = SuperNativePaymasterMetaData.ABI

// SuperNativePaymaster is an auto generated Go binding around an Ethereum contract.
type SuperNativePaymaster struct {
	SuperNativePaymasterCaller     // Read-only binding to the contract
	SuperNativePaymasterTransactor // Write-only binding to the contract
	SuperNativePaymasterFilterer   // Log filterer for contract events
}

// SuperNativePaymasterCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperNativePaymasterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperNativePaymasterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperNativePaymasterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperNativePaymasterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperNativePaymasterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperNativePaymasterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperNativePaymasterSession struct {
	Contract     *SuperNativePaymaster // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// SuperNativePaymasterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperNativePaymasterCallerSession struct {
	Contract *SuperNativePaymasterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// SuperNativePaymasterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperNativePaymasterTransactorSession struct {
	Contract     *SuperNativePaymasterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// SuperNativePaymasterRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperNativePaymasterRaw struct {
	Contract *SuperNativePaymaster // Generic contract binding to access the raw methods on
}

// SuperNativePaymasterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperNativePaymasterCallerRaw struct {
	Contract *SuperNativePaymasterCaller // Generic read-only contract binding to access the raw methods on
}

// SuperNativePaymasterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperNativePaymasterTransactorRaw struct {
	Contract *SuperNativePaymasterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperNativePaymaster creates a new instance of SuperNativePaymaster, bound to a specific deployed contract.
func NewSuperNativePaymaster(address common.Address, backend bind.ContractBackend) (*SuperNativePaymaster, error) {
	contract, err := bindSuperNativePaymaster(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymaster{SuperNativePaymasterCaller: SuperNativePaymasterCaller{contract: contract}, SuperNativePaymasterTransactor: SuperNativePaymasterTransactor{contract: contract}, SuperNativePaymasterFilterer: SuperNativePaymasterFilterer{contract: contract}}, nil
}

// NewSuperNativePaymasterCaller creates a new read-only instance of SuperNativePaymaster, bound to a specific deployed contract.
func NewSuperNativePaymasterCaller(address common.Address, caller bind.ContractCaller) (*SuperNativePaymasterCaller, error) {
	contract, err := bindSuperNativePaymaster(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymasterCaller{contract: contract}, nil
}

// NewSuperNativePaymasterTransactor creates a new write-only instance of SuperNativePaymaster, bound to a specific deployed contract.
func NewSuperNativePaymasterTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperNativePaymasterTransactor, error) {
	contract, err := bindSuperNativePaymaster(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymasterTransactor{contract: contract}, nil
}

// NewSuperNativePaymasterFilterer creates a new log filterer instance of SuperNativePaymaster, bound to a specific deployed contract.
func NewSuperNativePaymasterFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperNativePaymasterFilterer, error) {
	contract, err := bindSuperNativePaymaster(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymasterFilterer{contract: contract}, nil
}

// bindSuperNativePaymaster binds a generic wrapper to an already deployed contract.
func bindSuperNativePaymaster(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperNativePaymasterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperNativePaymaster *SuperNativePaymasterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperNativePaymaster.Contract.SuperNativePaymasterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperNativePaymaster *SuperNativePaymasterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.SuperNativePaymasterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperNativePaymaster *SuperNativePaymasterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.SuperNativePaymasterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperNativePaymaster *SuperNativePaymasterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperNativePaymaster.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperNativePaymaster *SuperNativePaymasterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperNativePaymaster *SuperNativePaymasterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.contract.Transact(opts, method, params...)
}

// CalculateRefund is a free data retrieval call binding the contract method 0x24a29b4f.
//
// Solidity: function calculateRefund(uint256 maxGasLimit, uint256 maxFeePerGas, uint256 actualGasCost, uint256 nodeOperatorPremium) pure returns(uint256 refund)
func (_SuperNativePaymaster *SuperNativePaymasterCaller) CalculateRefund(opts *bind.CallOpts, maxGasLimit *big.Int, maxFeePerGas *big.Int, actualGasCost *big.Int, nodeOperatorPremium *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _SuperNativePaymaster.contract.Call(opts, &out, "calculateRefund", maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// CalculateRefund is a free data retrieval call binding the contract method 0x24a29b4f.
//
// Solidity: function calculateRefund(uint256 maxGasLimit, uint256 maxFeePerGas, uint256 actualGasCost, uint256 nodeOperatorPremium) pure returns(uint256 refund)
func (_SuperNativePaymaster *SuperNativePaymasterSession) CalculateRefund(maxGasLimit *big.Int, maxFeePerGas *big.Int, actualGasCost *big.Int, nodeOperatorPremium *big.Int) (*big.Int, error) {
	return _SuperNativePaymaster.Contract.CalculateRefund(&_SuperNativePaymaster.CallOpts, maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium)
}

// CalculateRefund is a free data retrieval call binding the contract method 0x24a29b4f.
//
// Solidity: function calculateRefund(uint256 maxGasLimit, uint256 maxFeePerGas, uint256 actualGasCost, uint256 nodeOperatorPremium) pure returns(uint256 refund)
func (_SuperNativePaymaster *SuperNativePaymasterCallerSession) CalculateRefund(maxGasLimit *big.Int, maxFeePerGas *big.Int, actualGasCost *big.Int, nodeOperatorPremium *big.Int) (*big.Int, error) {
	return _SuperNativePaymaster.Contract.CalculateRefund(&_SuperNativePaymaster.CallOpts, maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium)
}

// EntryPoint is a free data retrieval call binding the contract method 0xb0d691fe.
//
// Solidity: function entryPoint() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterCaller) EntryPoint(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperNativePaymaster.contract.Call(opts, &out, "entryPoint")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// EntryPoint is a free data retrieval call binding the contract method 0xb0d691fe.
//
// Solidity: function entryPoint() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterSession) EntryPoint() (common.Address, error) {
	return _SuperNativePaymaster.Contract.EntryPoint(&_SuperNativePaymaster.CallOpts)
}

// EntryPoint is a free data retrieval call binding the contract method 0xb0d691fe.
//
// Solidity: function entryPoint() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterCallerSession) EntryPoint() (common.Address, error) {
	return _SuperNativePaymaster.Contract.EntryPoint(&_SuperNativePaymaster.CallOpts)
}

// GetDeposit is a free data retrieval call binding the contract method 0xc399ec88.
//
// Solidity: function getDeposit() view returns(uint256)
func (_SuperNativePaymaster *SuperNativePaymasterCaller) GetDeposit(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperNativePaymaster.contract.Call(opts, &out, "getDeposit")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetDeposit is a free data retrieval call binding the contract method 0xc399ec88.
//
// Solidity: function getDeposit() view returns(uint256)
func (_SuperNativePaymaster *SuperNativePaymasterSession) GetDeposit() (*big.Int, error) {
	return _SuperNativePaymaster.Contract.GetDeposit(&_SuperNativePaymaster.CallOpts)
}

// GetDeposit is a free data retrieval call binding the contract method 0xc399ec88.
//
// Solidity: function getDeposit() view returns(uint256)
func (_SuperNativePaymaster *SuperNativePaymasterCallerSession) GetDeposit() (*big.Int, error) {
	return _SuperNativePaymaster.Contract.GetDeposit(&_SuperNativePaymaster.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperNativePaymaster.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterSession) Owner() (common.Address, error) {
	return _SuperNativePaymaster.Contract.Owner(&_SuperNativePaymaster.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterCallerSession) Owner() (common.Address, error) {
	return _SuperNativePaymaster.Contract.Owner(&_SuperNativePaymaster.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperNativePaymaster.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterSession) PendingOwner() (common.Address, error) {
	return _SuperNativePaymaster.Contract.PendingOwner(&_SuperNativePaymaster.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SuperNativePaymaster *SuperNativePaymasterCallerSession) PendingOwner() (common.Address, error) {
	return _SuperNativePaymaster.Contract.PendingOwner(&_SuperNativePaymaster.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) AcceptOwnership() (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.AcceptOwnership(&_SuperNativePaymaster.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.AcceptOwnership(&_SuperNativePaymaster.TransactOpts)
}

// AddStake is a paid mutator transaction binding the contract method 0x0396cb60.
//
// Solidity: function addStake(uint32 unstakeDelaySec) payable returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) AddStake(opts *bind.TransactOpts, unstakeDelaySec uint32) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "addStake", unstakeDelaySec)
}

// AddStake is a paid mutator transaction binding the contract method 0x0396cb60.
//
// Solidity: function addStake(uint32 unstakeDelaySec) payable returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) AddStake(unstakeDelaySec uint32) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.AddStake(&_SuperNativePaymaster.TransactOpts, unstakeDelaySec)
}

// AddStake is a paid mutator transaction binding the contract method 0x0396cb60.
//
// Solidity: function addStake(uint32 unstakeDelaySec) payable returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) AddStake(unstakeDelaySec uint32) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.AddStake(&_SuperNativePaymaster.TransactOpts, unstakeDelaySec)
}

// HandleOps is a paid mutator transaction binding the contract method 0x57956b58.
//
// Solidity: function handleOps((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes)[] ops) payable returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) HandleOps(opts *bind.TransactOpts, ops []PackedUserOperation) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "handleOps", ops)
}

// HandleOps is a paid mutator transaction binding the contract method 0x57956b58.
//
// Solidity: function handleOps((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes)[] ops) payable returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) HandleOps(ops []PackedUserOperation) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.HandleOps(&_SuperNativePaymaster.TransactOpts, ops)
}

// HandleOps is a paid mutator transaction binding the contract method 0x57956b58.
//
// Solidity: function handleOps((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes)[] ops) payable returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) HandleOps(ops []PackedUserOperation) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.HandleOps(&_SuperNativePaymaster.TransactOpts, ops)
}

// PostOp is a paid mutator transaction binding the contract method 0x7c627b21.
//
// Solidity: function postOp(uint8 mode, bytes context, uint256 actualGasCost, uint256 actualUserOpFeePerGas) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) PostOp(opts *bind.TransactOpts, mode uint8, context []byte, actualGasCost *big.Int, actualUserOpFeePerGas *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "postOp", mode, context, actualGasCost, actualUserOpFeePerGas)
}

// PostOp is a paid mutator transaction binding the contract method 0x7c627b21.
//
// Solidity: function postOp(uint8 mode, bytes context, uint256 actualGasCost, uint256 actualUserOpFeePerGas) returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) PostOp(mode uint8, context []byte, actualGasCost *big.Int, actualUserOpFeePerGas *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.PostOp(&_SuperNativePaymaster.TransactOpts, mode, context, actualGasCost, actualUserOpFeePerGas)
}

// PostOp is a paid mutator transaction binding the contract method 0x7c627b21.
//
// Solidity: function postOp(uint8 mode, bytes context, uint256 actualGasCost, uint256 actualUserOpFeePerGas) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) PostOp(mode uint8, context []byte, actualGasCost *big.Int, actualUserOpFeePerGas *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.PostOp(&_SuperNativePaymaster.TransactOpts, mode, context, actualGasCost, actualUserOpFeePerGas)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) RenounceOwnership() (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.RenounceOwnership(&_SuperNativePaymaster.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.RenounceOwnership(&_SuperNativePaymaster.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.TransferOwnership(&_SuperNativePaymaster.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.TransferOwnership(&_SuperNativePaymaster.TransactOpts, newOwner)
}

// UnlockStake is a paid mutator transaction binding the contract method 0xbb9fe6bf.
//
// Solidity: function unlockStake() returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) UnlockStake(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "unlockStake")
}

// UnlockStake is a paid mutator transaction binding the contract method 0xbb9fe6bf.
//
// Solidity: function unlockStake() returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) UnlockStake() (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.UnlockStake(&_SuperNativePaymaster.TransactOpts)
}

// UnlockStake is a paid mutator transaction binding the contract method 0xbb9fe6bf.
//
// Solidity: function unlockStake() returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) UnlockStake() (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.UnlockStake(&_SuperNativePaymaster.TransactOpts)
}

// ValidatePaymasterUserOp is a paid mutator transaction binding the contract method 0x52b7512c.
//
// Solidity: function validatePaymasterUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash, uint256 maxCost) returns(bytes context, uint256 validationData)
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) ValidatePaymasterUserOp(opts *bind.TransactOpts, userOp PackedUserOperation, userOpHash [32]byte, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "validatePaymasterUserOp", userOp, userOpHash, maxCost)
}

// ValidatePaymasterUserOp is a paid mutator transaction binding the contract method 0x52b7512c.
//
// Solidity: function validatePaymasterUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash, uint256 maxCost) returns(bytes context, uint256 validationData)
func (_SuperNativePaymaster *SuperNativePaymasterSession) ValidatePaymasterUserOp(userOp PackedUserOperation, userOpHash [32]byte, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.ValidatePaymasterUserOp(&_SuperNativePaymaster.TransactOpts, userOp, userOpHash, maxCost)
}

// ValidatePaymasterUserOp is a paid mutator transaction binding the contract method 0x52b7512c.
//
// Solidity: function validatePaymasterUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash, uint256 maxCost) returns(bytes context, uint256 validationData)
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) ValidatePaymasterUserOp(userOp PackedUserOperation, userOpHash [32]byte, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.ValidatePaymasterUserOp(&_SuperNativePaymaster.TransactOpts, userOp, userOpHash, maxCost)
}

// WithdrawStake is a paid mutator transaction binding the contract method 0xc23a5cea.
//
// Solidity: function withdrawStake(address withdrawAddress) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) WithdrawStake(opts *bind.TransactOpts, withdrawAddress common.Address) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "withdrawStake", withdrawAddress)
}

// WithdrawStake is a paid mutator transaction binding the contract method 0xc23a5cea.
//
// Solidity: function withdrawStake(address withdrawAddress) returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) WithdrawStake(withdrawAddress common.Address) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.WithdrawStake(&_SuperNativePaymaster.TransactOpts, withdrawAddress)
}

// WithdrawStake is a paid mutator transaction binding the contract method 0xc23a5cea.
//
// Solidity: function withdrawStake(address withdrawAddress) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) WithdrawStake(withdrawAddress common.Address) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.WithdrawStake(&_SuperNativePaymaster.TransactOpts, withdrawAddress)
}

// WithdrawTo is a paid mutator transaction binding the contract method 0x205c2878.
//
// Solidity: function withdrawTo(address withdrawAddress, uint256 amount) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactor) WithdrawTo(opts *bind.TransactOpts, withdrawAddress common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.contract.Transact(opts, "withdrawTo", withdrawAddress, amount)
}

// WithdrawTo is a paid mutator transaction binding the contract method 0x205c2878.
//
// Solidity: function withdrawTo(address withdrawAddress, uint256 amount) returns()
func (_SuperNativePaymaster *SuperNativePaymasterSession) WithdrawTo(withdrawAddress common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.WithdrawTo(&_SuperNativePaymaster.TransactOpts, withdrawAddress, amount)
}

// WithdrawTo is a paid mutator transaction binding the contract method 0x205c2878.
//
// Solidity: function withdrawTo(address withdrawAddress, uint256 amount) returns()
func (_SuperNativePaymaster *SuperNativePaymasterTransactorSession) WithdrawTo(withdrawAddress common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperNativePaymaster.Contract.WithdrawTo(&_SuperNativePaymaster.TransactOpts, withdrawAddress, amount)
}

// SuperNativePaymasterOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the SuperNativePaymaster contract.
type SuperNativePaymasterOwnershipTransferStartedIterator struct {
	Event *SuperNativePaymasterOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *SuperNativePaymasterOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperNativePaymasterOwnershipTransferStarted)
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
		it.Event = new(SuperNativePaymasterOwnershipTransferStarted)
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
func (it *SuperNativePaymasterOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperNativePaymasterOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperNativePaymasterOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the SuperNativePaymaster contract.
type SuperNativePaymasterOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SuperNativePaymasterOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperNativePaymaster.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymasterOwnershipTransferStartedIterator{contract: _SuperNativePaymaster.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *SuperNativePaymasterOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperNativePaymaster.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperNativePaymasterOwnershipTransferStarted)
				if err := _SuperNativePaymaster.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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

// ParseOwnershipTransferStarted is a log parse operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) ParseOwnershipTransferStarted(log types.Log) (*SuperNativePaymasterOwnershipTransferStarted, error) {
	event := new(SuperNativePaymasterOwnershipTransferStarted)
	if err := _SuperNativePaymaster.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperNativePaymasterOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SuperNativePaymaster contract.
type SuperNativePaymasterOwnershipTransferredIterator struct {
	Event *SuperNativePaymasterOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SuperNativePaymasterOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperNativePaymasterOwnershipTransferred)
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
		it.Event = new(SuperNativePaymasterOwnershipTransferred)
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
func (it *SuperNativePaymasterOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperNativePaymasterOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperNativePaymasterOwnershipTransferred represents a OwnershipTransferred event raised by the SuperNativePaymaster contract.
type SuperNativePaymasterOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SuperNativePaymasterOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperNativePaymaster.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymasterOwnershipTransferredIterator{contract: _SuperNativePaymaster.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SuperNativePaymasterOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperNativePaymaster.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperNativePaymasterOwnershipTransferred)
				if err := _SuperNativePaymaster.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) ParseOwnershipTransferred(log types.Log) (*SuperNativePaymasterOwnershipTransferred, error) {
	event := new(SuperNativePaymasterOwnershipTransferred)
	if err := _SuperNativePaymaster.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperNativePaymasterSuperNativePaymasterPostOpIterator is returned from FilterSuperNativePaymasterPostOp and is used to iterate over the raw logs and unpacked data for SuperNativePaymasterPostOp events raised by the SuperNativePaymaster contract.
type SuperNativePaymasterSuperNativePaymasterPostOpIterator struct {
	Event *SuperNativePaymasterSuperNativePaymasterPostOp // Event containing the contract specifics and raw log

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
func (it *SuperNativePaymasterSuperNativePaymasterPostOpIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperNativePaymasterSuperNativePaymasterPostOp)
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
		it.Event = new(SuperNativePaymasterSuperNativePaymasterPostOp)
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
func (it *SuperNativePaymasterSuperNativePaymasterPostOpIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperNativePaymasterSuperNativePaymasterPostOpIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperNativePaymasterSuperNativePaymasterPostOp represents a SuperNativePaymasterPostOp event raised by the SuperNativePaymaster contract.
type SuperNativePaymasterSuperNativePaymasterPostOp struct {
	Context []byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperNativePaymasterPostOp is a free log retrieval operation binding the contract event 0x34b2c95a547acd4b4fa4f6947733d3b663b320b4c98ce28006f00f0d4756de54.
//
// Solidity: event SuperNativePaymasterPostOp(bytes context)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) FilterSuperNativePaymasterPostOp(opts *bind.FilterOpts) (*SuperNativePaymasterSuperNativePaymasterPostOpIterator, error) {

	logs, sub, err := _SuperNativePaymaster.contract.FilterLogs(opts, "SuperNativePaymasterPostOp")
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymasterSuperNativePaymasterPostOpIterator{contract: _SuperNativePaymaster.contract, event: "SuperNativePaymasterPostOp", logs: logs, sub: sub}, nil
}

// WatchSuperNativePaymasterPostOp is a free log subscription operation binding the contract event 0x34b2c95a547acd4b4fa4f6947733d3b663b320b4c98ce28006f00f0d4756de54.
//
// Solidity: event SuperNativePaymasterPostOp(bytes context)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) WatchSuperNativePaymasterPostOp(opts *bind.WatchOpts, sink chan<- *SuperNativePaymasterSuperNativePaymasterPostOp) (event.Subscription, error) {

	logs, sub, err := _SuperNativePaymaster.contract.WatchLogs(opts, "SuperNativePaymasterPostOp")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperNativePaymasterSuperNativePaymasterPostOp)
				if err := _SuperNativePaymaster.contract.UnpackLog(event, "SuperNativePaymasterPostOp", log); err != nil {
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

// ParseSuperNativePaymasterPostOp is a log parse operation binding the contract event 0x34b2c95a547acd4b4fa4f6947733d3b663b320b4c98ce28006f00f0d4756de54.
//
// Solidity: event SuperNativePaymasterPostOp(bytes context)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) ParseSuperNativePaymasterPostOp(log types.Log) (*SuperNativePaymasterSuperNativePaymasterPostOp, error) {
	event := new(SuperNativePaymasterSuperNativePaymasterPostOp)
	if err := _SuperNativePaymaster.contract.UnpackLog(event, "SuperNativePaymasterPostOp", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperNativePaymasterSuperNativePaymsterRefundIterator is returned from FilterSuperNativePaymsterRefund and is used to iterate over the raw logs and unpacked data for SuperNativePaymsterRefund events raised by the SuperNativePaymaster contract.
type SuperNativePaymasterSuperNativePaymsterRefundIterator struct {
	Event *SuperNativePaymasterSuperNativePaymsterRefund // Event containing the contract specifics and raw log

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
func (it *SuperNativePaymasterSuperNativePaymsterRefundIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperNativePaymasterSuperNativePaymsterRefund)
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
		it.Event = new(SuperNativePaymasterSuperNativePaymsterRefund)
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
func (it *SuperNativePaymasterSuperNativePaymsterRefundIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperNativePaymasterSuperNativePaymsterRefundIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperNativePaymasterSuperNativePaymsterRefund represents a SuperNativePaymsterRefund event raised by the SuperNativePaymaster contract.
type SuperNativePaymasterSuperNativePaymsterRefund struct {
	Sender common.Address
	Refund *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterSuperNativePaymsterRefund is a free log retrieval operation binding the contract event 0x8dc60f2aa916a6eb8cd704fb0865096c718ff92fdf75bba53075164ab027464a.
//
// Solidity: event SuperNativePaymsterRefund(address indexed sender, uint256 refund)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) FilterSuperNativePaymsterRefund(opts *bind.FilterOpts, sender []common.Address) (*SuperNativePaymasterSuperNativePaymsterRefundIterator, error) {

	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperNativePaymaster.contract.FilterLogs(opts, "SuperNativePaymsterRefund", senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperNativePaymasterSuperNativePaymsterRefundIterator{contract: _SuperNativePaymaster.contract, event: "SuperNativePaymsterRefund", logs: logs, sub: sub}, nil
}

// WatchSuperNativePaymsterRefund is a free log subscription operation binding the contract event 0x8dc60f2aa916a6eb8cd704fb0865096c718ff92fdf75bba53075164ab027464a.
//
// Solidity: event SuperNativePaymsterRefund(address indexed sender, uint256 refund)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) WatchSuperNativePaymsterRefund(opts *bind.WatchOpts, sink chan<- *SuperNativePaymasterSuperNativePaymsterRefund, sender []common.Address) (event.Subscription, error) {

	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperNativePaymaster.contract.WatchLogs(opts, "SuperNativePaymsterRefund", senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperNativePaymasterSuperNativePaymsterRefund)
				if err := _SuperNativePaymaster.contract.UnpackLog(event, "SuperNativePaymsterRefund", log); err != nil {
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

// ParseSuperNativePaymsterRefund is a log parse operation binding the contract event 0x8dc60f2aa916a6eb8cd704fb0865096c718ff92fdf75bba53075164ab027464a.
//
// Solidity: event SuperNativePaymsterRefund(address indexed sender, uint256 refund)
func (_SuperNativePaymaster *SuperNativePaymasterFilterer) ParseSuperNativePaymsterRefund(log types.Log) (*SuperNativePaymasterSuperNativePaymsterRefund, error) {
	event := new(SuperNativePaymasterSuperNativePaymsterRefund)
	if err := _SuperNativePaymaster.contract.UnpackLog(event, "SuperNativePaymsterRefund", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
