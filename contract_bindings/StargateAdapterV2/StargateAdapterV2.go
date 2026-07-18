// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package StargateAdapterV2

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

// StargateAdapterV2MetaData contains all meta data concerning the StargateAdapterV2 contract.
var StargateAdapterV2MetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"lzEndpoint_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokenMessaging_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"allowedOFTs_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"LZ_ENDPOINT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TOKEN_MESSAGING\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractITokenMessaging\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"allowedOFTs\",\"inputs\":[{\"name\":\"oft\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"allowed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"allowedOFTsList\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAllowedOFTs\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleCompose\",\"inputs\":[{\"name\":\"_guid\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountLD\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"composeFrom\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lzCompose\",\"inputs\":[{\"name\":\"_from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_guid\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"ComposeDecodeFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ComposeMsgTooShort\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"messageLength\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"NoDstProofForChain\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TokenResolutionFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UnregisteredPool\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// StargateAdapterV2ABI is the input ABI used to generate the binding from.
// Deprecated: Use StargateAdapterV2MetaData.ABI instead.
var StargateAdapterV2ABI = StargateAdapterV2MetaData.ABI

// StargateAdapterV2 is an auto generated Go binding around an Ethereum contract.
type StargateAdapterV2 struct {
	StargateAdapterV2Caller     // Read-only binding to the contract
	StargateAdapterV2Transactor // Write-only binding to the contract
	StargateAdapterV2Filterer   // Log filterer for contract events
}

// StargateAdapterV2Caller is an auto generated read-only Go binding around an Ethereum contract.
type StargateAdapterV2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterV2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type StargateAdapterV2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterV2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type StargateAdapterV2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterV2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type StargateAdapterV2Session struct {
	Contract     *StargateAdapterV2 // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// StargateAdapterV2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type StargateAdapterV2CallerSession struct {
	Contract *StargateAdapterV2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// StargateAdapterV2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type StargateAdapterV2TransactorSession struct {
	Contract     *StargateAdapterV2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// StargateAdapterV2Raw is an auto generated low-level Go binding around an Ethereum contract.
type StargateAdapterV2Raw struct {
	Contract *StargateAdapterV2 // Generic contract binding to access the raw methods on
}

// StargateAdapterV2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type StargateAdapterV2CallerRaw struct {
	Contract *StargateAdapterV2Caller // Generic read-only contract binding to access the raw methods on
}

// StargateAdapterV2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type StargateAdapterV2TransactorRaw struct {
	Contract *StargateAdapterV2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewStargateAdapterV2 creates a new instance of StargateAdapterV2, bound to a specific deployed contract.
func NewStargateAdapterV2(address common.Address, backend bind.ContractBackend) (*StargateAdapterV2, error) {
	contract, err := bindStargateAdapterV2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2{StargateAdapterV2Caller: StargateAdapterV2Caller{contract: contract}, StargateAdapterV2Transactor: StargateAdapterV2Transactor{contract: contract}, StargateAdapterV2Filterer: StargateAdapterV2Filterer{contract: contract}}, nil
}

// NewStargateAdapterV2Caller creates a new read-only instance of StargateAdapterV2, bound to a specific deployed contract.
func NewStargateAdapterV2Caller(address common.Address, caller bind.ContractCaller) (*StargateAdapterV2Caller, error) {
	contract, err := bindStargateAdapterV2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2Caller{contract: contract}, nil
}

// NewStargateAdapterV2Transactor creates a new write-only instance of StargateAdapterV2, bound to a specific deployed contract.
func NewStargateAdapterV2Transactor(address common.Address, transactor bind.ContractTransactor) (*StargateAdapterV2Transactor, error) {
	contract, err := bindStargateAdapterV2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2Transactor{contract: contract}, nil
}

// NewStargateAdapterV2Filterer creates a new log filterer instance of StargateAdapterV2, bound to a specific deployed contract.
func NewStargateAdapterV2Filterer(address common.Address, filterer bind.ContractFilterer) (*StargateAdapterV2Filterer, error) {
	contract, err := bindStargateAdapterV2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2Filterer{contract: contract}, nil
}

// bindStargateAdapterV2 binds a generic wrapper to an already deployed contract.
func bindStargateAdapterV2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := StargateAdapterV2MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapterV2 *StargateAdapterV2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapterV2.Contract.StargateAdapterV2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapterV2 *StargateAdapterV2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.StargateAdapterV2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapterV2 *StargateAdapterV2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.StargateAdapterV2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapterV2 *StargateAdapterV2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapterV2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapterV2 *StargateAdapterV2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapterV2 *StargateAdapterV2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.contract.Transact(opts, method, params...)
}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Caller) LZENDPOINT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2.contract.Call(opts, &out, "LZ_ENDPOINT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Session) LZENDPOINT() (common.Address, error) {
	return _StargateAdapterV2.Contract.LZENDPOINT(&_StargateAdapterV2.CallOpts)
}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2CallerSession) LZENDPOINT() (common.Address, error) {
	return _StargateAdapterV2.Contract.LZENDPOINT(&_StargateAdapterV2.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Caller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Session) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _StargateAdapterV2.Contract.SUPERDESTINATIONEXECUTOR(&_StargateAdapterV2.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2CallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _StargateAdapterV2.Contract.SUPERDESTINATIONEXECUTOR(&_StargateAdapterV2.CallOpts)
}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Caller) TOKENMESSAGING(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2.contract.Call(opts, &out, "TOKEN_MESSAGING")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Session) TOKENMESSAGING() (common.Address, error) {
	return _StargateAdapterV2.Contract.TOKENMESSAGING(&_StargateAdapterV2.CallOpts)
}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2CallerSession) TOKENMESSAGING() (common.Address, error) {
	return _StargateAdapterV2.Contract.TOKENMESSAGING(&_StargateAdapterV2.CallOpts)
}

// AllowedOFTs is a free data retrieval call binding the contract method 0xf734c14d.
//
// Solidity: function allowedOFTs(address oft) view returns(bool allowed)
func (_StargateAdapterV2 *StargateAdapterV2Caller) AllowedOFTs(opts *bind.CallOpts, oft common.Address) (bool, error) {
	var out []interface{}
	err := _StargateAdapterV2.contract.Call(opts, &out, "allowedOFTs", oft)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// AllowedOFTs is a free data retrieval call binding the contract method 0xf734c14d.
//
// Solidity: function allowedOFTs(address oft) view returns(bool allowed)
func (_StargateAdapterV2 *StargateAdapterV2Session) AllowedOFTs(oft common.Address) (bool, error) {
	return _StargateAdapterV2.Contract.AllowedOFTs(&_StargateAdapterV2.CallOpts, oft)
}

// AllowedOFTs is a free data retrieval call binding the contract method 0xf734c14d.
//
// Solidity: function allowedOFTs(address oft) view returns(bool allowed)
func (_StargateAdapterV2 *StargateAdapterV2CallerSession) AllowedOFTs(oft common.Address) (bool, error) {
	return _StargateAdapterV2.Contract.AllowedOFTs(&_StargateAdapterV2.CallOpts, oft)
}

// AllowedOFTsList is a free data retrieval call binding the contract method 0x1b664a48.
//
// Solidity: function allowedOFTsList(uint256 ) view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Caller) AllowedOFTsList(opts *bind.CallOpts, arg0 *big.Int) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2.contract.Call(opts, &out, "allowedOFTsList", arg0)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AllowedOFTsList is a free data retrieval call binding the contract method 0x1b664a48.
//
// Solidity: function allowedOFTsList(uint256 ) view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2Session) AllowedOFTsList(arg0 *big.Int) (common.Address, error) {
	return _StargateAdapterV2.Contract.AllowedOFTsList(&_StargateAdapterV2.CallOpts, arg0)
}

// AllowedOFTsList is a free data retrieval call binding the contract method 0x1b664a48.
//
// Solidity: function allowedOFTsList(uint256 ) view returns(address)
func (_StargateAdapterV2 *StargateAdapterV2CallerSession) AllowedOFTsList(arg0 *big.Int) (common.Address, error) {
	return _StargateAdapterV2.Contract.AllowedOFTsList(&_StargateAdapterV2.CallOpts, arg0)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Caller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterV2.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Session) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _StargateAdapterV2.Contract.FailedTransfers(&_StargateAdapterV2.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2CallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _StargateAdapterV2.Contract.FailedTransfers(&_StargateAdapterV2.CallOpts, account, token)
}

// GetAllowedOFTs is a free data retrieval call binding the contract method 0xb17b3642.
//
// Solidity: function getAllowedOFTs() view returns(address[])
func (_StargateAdapterV2 *StargateAdapterV2Caller) GetAllowedOFTs(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2.contract.Call(opts, &out, "getAllowedOFTs")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetAllowedOFTs is a free data retrieval call binding the contract method 0xb17b3642.
//
// Solidity: function getAllowedOFTs() view returns(address[])
func (_StargateAdapterV2 *StargateAdapterV2Session) GetAllowedOFTs() ([]common.Address, error) {
	return _StargateAdapterV2.Contract.GetAllowedOFTs(&_StargateAdapterV2.CallOpts)
}

// GetAllowedOFTs is a free data retrieval call binding the contract method 0xb17b3642.
//
// Solidity: function getAllowedOFTs() view returns(address[])
func (_StargateAdapterV2 *StargateAdapterV2CallerSession) GetAllowedOFTs() ([]common.Address, error) {
	return _StargateAdapterV2.Contract.GetAllowedOFTs(&_StargateAdapterV2.CallOpts)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapterV2 *StargateAdapterV2Transactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapterV2.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapterV2 *StargateAdapterV2Session) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.ClaimFailedTransfer(&_StargateAdapterV2.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapterV2 *StargateAdapterV2TransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.ClaimFailedTransfer(&_StargateAdapterV2.TransactOpts, token, amount)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapterV2 *StargateAdapterV2Transactor) HandleCompose(opts *bind.TransactOpts, _guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapterV2.contract.Transact(opts, "handleCompose", _guid, _message, tokenSent, amountLD, composeFrom)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapterV2 *StargateAdapterV2Session) HandleCompose(_guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.HandleCompose(&_StargateAdapterV2.TransactOpts, _guid, _message, tokenSent, amountLD, composeFrom)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapterV2 *StargateAdapterV2TransactorSession) HandleCompose(_guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.HandleCompose(&_StargateAdapterV2.TransactOpts, _guid, _message, tokenSent, amountLD, composeFrom)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapterV2 *StargateAdapterV2Transactor) LzCompose(opts *bind.TransactOpts, _from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapterV2.contract.Transact(opts, "lzCompose", _from, _guid, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapterV2 *StargateAdapterV2Session) LzCompose(_from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.LzCompose(&_StargateAdapterV2.TransactOpts, _from, _guid, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapterV2 *StargateAdapterV2TransactorSession) LzCompose(_from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.LzCompose(&_StargateAdapterV2.TransactOpts, _from, _guid, _message, arg3, arg4)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterV2 *StargateAdapterV2Transactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterV2.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterV2 *StargateAdapterV2Session) Receive() (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.Receive(&_StargateAdapterV2.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterV2 *StargateAdapterV2TransactorSession) Receive() (*types.Transaction, error) {
	return _StargateAdapterV2.Contract.Receive(&_StargateAdapterV2.TransactOpts)
}

// StargateAdapterV2ComposeDecodeFailedIterator is returned from FilterComposeDecodeFailed and is used to iterate over the raw logs and unpacked data for ComposeDecodeFailed events raised by the StargateAdapterV2 contract.
type StargateAdapterV2ComposeDecodeFailedIterator struct {
	Event *StargateAdapterV2ComposeDecodeFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2ComposeDecodeFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2ComposeDecodeFailed)
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
		it.Event = new(StargateAdapterV2ComposeDecodeFailed)
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
func (it *StargateAdapterV2ComposeDecodeFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2ComposeDecodeFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2ComposeDecodeFailed represents a ComposeDecodeFailed event raised by the StargateAdapterV2 contract.
type StargateAdapterV2ComposeDecodeFailed struct {
	Guid [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterComposeDecodeFailed is a free log retrieval operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterComposeDecodeFailed(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterV2ComposeDecodeFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "ComposeDecodeFailed", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2ComposeDecodeFailedIterator{contract: _StargateAdapterV2.contract, event: "ComposeDecodeFailed", logs: logs, sub: sub}, nil
}

// WatchComposeDecodeFailed is a free log subscription operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchComposeDecodeFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2ComposeDecodeFailed, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "ComposeDecodeFailed", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2ComposeDecodeFailed)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "ComposeDecodeFailed", log); err != nil {
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

// ParseComposeDecodeFailed is a log parse operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseComposeDecodeFailed(log types.Log) (*StargateAdapterV2ComposeDecodeFailed, error) {
	event := new(StargateAdapterV2ComposeDecodeFailed)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "ComposeDecodeFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2ComposeMsgTooShortIterator is returned from FilterComposeMsgTooShort and is used to iterate over the raw logs and unpacked data for ComposeMsgTooShort events raised by the StargateAdapterV2 contract.
type StargateAdapterV2ComposeMsgTooShortIterator struct {
	Event *StargateAdapterV2ComposeMsgTooShort // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2ComposeMsgTooShortIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2ComposeMsgTooShort)
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
		it.Event = new(StargateAdapterV2ComposeMsgTooShort)
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
func (it *StargateAdapterV2ComposeMsgTooShortIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2ComposeMsgTooShortIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2ComposeMsgTooShort represents a ComposeMsgTooShort event raised by the StargateAdapterV2 contract.
type StargateAdapterV2ComposeMsgTooShort struct {
	Guid          [32]byte
	MessageLength *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterComposeMsgTooShort is a free log retrieval operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterComposeMsgTooShort(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterV2ComposeMsgTooShortIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "ComposeMsgTooShort", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2ComposeMsgTooShortIterator{contract: _StargateAdapterV2.contract, event: "ComposeMsgTooShort", logs: logs, sub: sub}, nil
}

// WatchComposeMsgTooShort is a free log subscription operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchComposeMsgTooShort(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2ComposeMsgTooShort, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "ComposeMsgTooShort", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2ComposeMsgTooShort)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "ComposeMsgTooShort", log); err != nil {
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

// ParseComposeMsgTooShort is a log parse operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseComposeMsgTooShort(log types.Log) (*StargateAdapterV2ComposeMsgTooShort, error) {
	event := new(StargateAdapterV2ComposeMsgTooShort)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "ComposeMsgTooShort", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2ExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the StargateAdapterV2 contract.
type StargateAdapterV2ExecutionFailedIterator struct {
	Event *StargateAdapterV2ExecutionFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2ExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2ExecutionFailed)
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
		it.Event = new(StargateAdapterV2ExecutionFailed)
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
func (it *StargateAdapterV2ExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2ExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2ExecutionFailed represents a ExecutionFailed event raised by the StargateAdapterV2 contract.
type StargateAdapterV2ExecutionFailed struct {
	Guid    [32]byte
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterExecutionFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address) (*StargateAdapterV2ExecutionFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2ExecutionFailedIterator{contract: _StargateAdapterV2.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2ExecutionFailed, guid [][32]byte, account []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2ExecutionFailed)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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

// ParseExecutionFailed is a log parse operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseExecutionFailed(log types.Log) (*StargateAdapterV2ExecutionFailed, error) {
	event := new(StargateAdapterV2ExecutionFailed)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2FailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the StargateAdapterV2 contract.
type StargateAdapterV2FailedTransferClaimedIterator struct {
	Event *StargateAdapterV2FailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2FailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2FailedTransferClaimed)
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
		it.Event = new(StargateAdapterV2FailedTransferClaimed)
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
func (it *StargateAdapterV2FailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2FailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2FailedTransferClaimed represents a FailedTransferClaimed event raised by the StargateAdapterV2 contract.
type StargateAdapterV2FailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*StargateAdapterV2FailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2FailedTransferClaimedIterator{contract: _StargateAdapterV2.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2FailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2FailedTransferClaimed)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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

// ParseFailedTransferClaimed is a log parse operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseFailedTransferClaimed(log types.Log) (*StargateAdapterV2FailedTransferClaimed, error) {
	event := new(StargateAdapterV2FailedTransferClaimed)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2NoDstProofForChainIterator is returned from FilterNoDstProofForChain and is used to iterate over the raw logs and unpacked data for NoDstProofForChain events raised by the StargateAdapterV2 contract.
type StargateAdapterV2NoDstProofForChainIterator struct {
	Event *StargateAdapterV2NoDstProofForChain // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2NoDstProofForChainIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2NoDstProofForChain)
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
		it.Event = new(StargateAdapterV2NoDstProofForChain)
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
func (it *StargateAdapterV2NoDstProofForChainIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2NoDstProofForChainIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2NoDstProofForChain represents a NoDstProofForChain event raised by the StargateAdapterV2 contract.
type StargateAdapterV2NoDstProofForChain struct {
	Guid    [32]byte
	ChainId uint64
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterNoDstProofForChain is a free log retrieval operation binding the contract event 0x9d6f695be53eba948a35ab0c43717584bf19bc6547329e81e194c8e9e2dfebe0.
//
// Solidity: event NoDstProofForChain(bytes32 indexed guid, uint64 chainId)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterNoDstProofForChain(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterV2NoDstProofForChainIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "NoDstProofForChain", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2NoDstProofForChainIterator{contract: _StargateAdapterV2.contract, event: "NoDstProofForChain", logs: logs, sub: sub}, nil
}

// WatchNoDstProofForChain is a free log subscription operation binding the contract event 0x9d6f695be53eba948a35ab0c43717584bf19bc6547329e81e194c8e9e2dfebe0.
//
// Solidity: event NoDstProofForChain(bytes32 indexed guid, uint64 chainId)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchNoDstProofForChain(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2NoDstProofForChain, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "NoDstProofForChain", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2NoDstProofForChain)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "NoDstProofForChain", log); err != nil {
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

// ParseNoDstProofForChain is a log parse operation binding the contract event 0x9d6f695be53eba948a35ab0c43717584bf19bc6547329e81e194c8e9e2dfebe0.
//
// Solidity: event NoDstProofForChain(bytes32 indexed guid, uint64 chainId)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseNoDstProofForChain(log types.Log) (*StargateAdapterV2NoDstProofForChain, error) {
	event := new(StargateAdapterV2NoDstProofForChain)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "NoDstProofForChain", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2TokenResolutionFailedIterator is returned from FilterTokenResolutionFailed and is used to iterate over the raw logs and unpacked data for TokenResolutionFailed events raised by the StargateAdapterV2 contract.
type StargateAdapterV2TokenResolutionFailedIterator struct {
	Event *StargateAdapterV2TokenResolutionFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2TokenResolutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2TokenResolutionFailed)
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
		it.Event = new(StargateAdapterV2TokenResolutionFailed)
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
func (it *StargateAdapterV2TokenResolutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2TokenResolutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2TokenResolutionFailed represents a TokenResolutionFailed event raised by the StargateAdapterV2 contract.
type StargateAdapterV2TokenResolutionFailed struct {
	Guid [32]byte
	From common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterTokenResolutionFailed is a free log retrieval operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterTokenResolutionFailed(opts *bind.FilterOpts, guid [][32]byte, from []common.Address) (*StargateAdapterV2TokenResolutionFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "TokenResolutionFailed", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2TokenResolutionFailedIterator{contract: _StargateAdapterV2.contract, event: "TokenResolutionFailed", logs: logs, sub: sub}, nil
}

// WatchTokenResolutionFailed is a free log subscription operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchTokenResolutionFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2TokenResolutionFailed, guid [][32]byte, from []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "TokenResolutionFailed", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2TokenResolutionFailed)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "TokenResolutionFailed", log); err != nil {
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

// ParseTokenResolutionFailed is a log parse operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseTokenResolutionFailed(log types.Log) (*StargateAdapterV2TokenResolutionFailed, error) {
	event := new(StargateAdapterV2TokenResolutionFailed)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "TokenResolutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2TransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the StargateAdapterV2 contract.
type StargateAdapterV2TransferFailedIterator struct {
	Event *StargateAdapterV2TransferFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2TransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2TransferFailed)
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
		it.Event = new(StargateAdapterV2TransferFailed)
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
func (it *StargateAdapterV2TransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2TransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2TransferFailed represents a TransferFailed event raised by the StargateAdapterV2 contract.
type StargateAdapterV2TransferFailed struct {
	Guid    [32]byte
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterTransferFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, token []common.Address) (*StargateAdapterV2TransferFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2TransferFailedIterator{contract: _StargateAdapterV2.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2TransferFailed, guid [][32]byte, account []common.Address, token []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2TransferFailed)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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

// ParseTransferFailed is a log parse operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseTransferFailed(log types.Log) (*StargateAdapterV2TransferFailed, error) {
	event := new(StargateAdapterV2TransferFailed)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2TransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the StargateAdapterV2 contract.
type StargateAdapterV2TransferSucceededIterator struct {
	Event *StargateAdapterV2TransferSucceeded // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2TransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2TransferSucceeded)
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
		it.Event = new(StargateAdapterV2TransferSucceeded)
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
func (it *StargateAdapterV2TransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2TransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2TransferSucceeded represents a TransferSucceeded event raised by the StargateAdapterV2 contract.
type StargateAdapterV2TransferSucceeded struct {
	Guid      [32]byte
	Account   common.Address
	TokenSent common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterTransferSucceeded(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, tokenSent []common.Address) (*StargateAdapterV2TransferSucceededIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2TransferSucceededIterator{contract: _StargateAdapterV2.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2TransferSucceeded, guid [][32]byte, account []common.Address, tokenSent []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2TransferSucceeded)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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

// ParseTransferSucceeded is a log parse operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseTransferSucceeded(log types.Log) (*StargateAdapterV2TransferSucceeded, error) {
	event := new(StargateAdapterV2TransferSucceeded)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2UnregisteredPoolIterator is returned from FilterUnregisteredPool and is used to iterate over the raw logs and unpacked data for UnregisteredPool events raised by the StargateAdapterV2 contract.
type StargateAdapterV2UnregisteredPoolIterator struct {
	Event *StargateAdapterV2UnregisteredPool // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2UnregisteredPoolIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2UnregisteredPool)
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
		it.Event = new(StargateAdapterV2UnregisteredPool)
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
func (it *StargateAdapterV2UnregisteredPoolIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2UnregisteredPoolIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2UnregisteredPool represents a UnregisteredPool event raised by the StargateAdapterV2 contract.
type StargateAdapterV2UnregisteredPool struct {
	Guid [32]byte
	From common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterUnregisteredPool is a free log retrieval operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) FilterUnregisteredPool(opts *bind.FilterOpts, guid [][32]byte, from []common.Address) (*StargateAdapterV2UnregisteredPoolIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.FilterLogs(opts, "UnregisteredPool", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2UnregisteredPoolIterator{contract: _StargateAdapterV2.contract, event: "UnregisteredPool", logs: logs, sub: sub}, nil
}

// WatchUnregisteredPool is a free log subscription operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) WatchUnregisteredPool(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2UnregisteredPool, guid [][32]byte, from []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2.contract.WatchLogs(opts, "UnregisteredPool", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2UnregisteredPool)
				if err := _StargateAdapterV2.contract.UnpackLog(event, "UnregisteredPool", log); err != nil {
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

// ParseUnregisteredPool is a log parse operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2 *StargateAdapterV2Filterer) ParseUnregisteredPool(log types.Log) (*StargateAdapterV2UnregisteredPool, error) {
	event := new(StargateAdapterV2UnregisteredPool)
	if err := _StargateAdapterV2.contract.UnpackLog(event, "UnregisteredPool", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
