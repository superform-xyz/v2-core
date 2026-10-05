// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package StargateAdapterV2Simulations

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

// StargateAdapterV2SimulationsMetaData contains all meta data concerning the StargateAdapterV2Simulations contract.
var StargateAdapterV2SimulationsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"lzEndpoint_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokenMessaging_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"LZ_ENDPOINT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TOKEN_MESSAGING\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractITokenMessaging\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"allowedOFTs\",\"inputs\":[{\"name\":\"oft\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"allowed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"allowedOFTsList\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAllowedOFTs\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleCompose\",\"inputs\":[{\"name\":\"_guid\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amountLD\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"composeFrom\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lzCompose\",\"inputs\":[{\"name\":\"_from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_guid\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"ComposeDecodeFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ComposeMsgTooShort\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"messageLength\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"NoDstProofForChain\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"chainId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TokenResolutionFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UnregisteredPool\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"COMPOSE_EXECUTION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"COMPOSE_MSG_TOO_SHORT\",\"inputs\":[{\"name\":\"messageLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_ADAPTER_BALANCE\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"required\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"available\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_DST_PROOF_FOR_CHAIN\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TRANSFER_FAILED\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"UNREGISTERED_POOL\",\"inputs\":[{\"name\":\"pool\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// StargateAdapterV2SimulationsABI is the input ABI used to generate the binding from.
// Deprecated: Use StargateAdapterV2SimulationsMetaData.ABI instead.
var StargateAdapterV2SimulationsABI = StargateAdapterV2SimulationsMetaData.ABI

// StargateAdapterV2Simulations is an auto generated Go binding around an Ethereum contract.
type StargateAdapterV2Simulations struct {
	StargateAdapterV2SimulationsCaller     // Read-only binding to the contract
	StargateAdapterV2SimulationsTransactor // Write-only binding to the contract
	StargateAdapterV2SimulationsFilterer   // Log filterer for contract events
}

// StargateAdapterV2SimulationsCaller is an auto generated read-only Go binding around an Ethereum contract.
type StargateAdapterV2SimulationsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterV2SimulationsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type StargateAdapterV2SimulationsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterV2SimulationsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type StargateAdapterV2SimulationsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterV2SimulationsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type StargateAdapterV2SimulationsSession struct {
	Contract     *StargateAdapterV2Simulations // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                 // Call options to use throughout this session
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// StargateAdapterV2SimulationsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type StargateAdapterV2SimulationsCallerSession struct {
	Contract *StargateAdapterV2SimulationsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                       // Call options to use throughout this session
}

// StargateAdapterV2SimulationsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type StargateAdapterV2SimulationsTransactorSession struct {
	Contract     *StargateAdapterV2SimulationsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                       // Transaction auth options to use throughout this session
}

// StargateAdapterV2SimulationsRaw is an auto generated low-level Go binding around an Ethereum contract.
type StargateAdapterV2SimulationsRaw struct {
	Contract *StargateAdapterV2Simulations // Generic contract binding to access the raw methods on
}

// StargateAdapterV2SimulationsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type StargateAdapterV2SimulationsCallerRaw struct {
	Contract *StargateAdapterV2SimulationsCaller // Generic read-only contract binding to access the raw methods on
}

// StargateAdapterV2SimulationsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type StargateAdapterV2SimulationsTransactorRaw struct {
	Contract *StargateAdapterV2SimulationsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewStargateAdapterV2Simulations creates a new instance of StargateAdapterV2Simulations, bound to a specific deployed contract.
func NewStargateAdapterV2Simulations(address common.Address, backend bind.ContractBackend) (*StargateAdapterV2Simulations, error) {
	contract, err := bindStargateAdapterV2Simulations(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2Simulations{StargateAdapterV2SimulationsCaller: StargateAdapterV2SimulationsCaller{contract: contract}, StargateAdapterV2SimulationsTransactor: StargateAdapterV2SimulationsTransactor{contract: contract}, StargateAdapterV2SimulationsFilterer: StargateAdapterV2SimulationsFilterer{contract: contract}}, nil
}

// NewStargateAdapterV2SimulationsCaller creates a new read-only instance of StargateAdapterV2Simulations, bound to a specific deployed contract.
func NewStargateAdapterV2SimulationsCaller(address common.Address, caller bind.ContractCaller) (*StargateAdapterV2SimulationsCaller, error) {
	contract, err := bindStargateAdapterV2Simulations(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsCaller{contract: contract}, nil
}

// NewStargateAdapterV2SimulationsTransactor creates a new write-only instance of StargateAdapterV2Simulations, bound to a specific deployed contract.
func NewStargateAdapterV2SimulationsTransactor(address common.Address, transactor bind.ContractTransactor) (*StargateAdapterV2SimulationsTransactor, error) {
	contract, err := bindStargateAdapterV2Simulations(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsTransactor{contract: contract}, nil
}

// NewStargateAdapterV2SimulationsFilterer creates a new log filterer instance of StargateAdapterV2Simulations, bound to a specific deployed contract.
func NewStargateAdapterV2SimulationsFilterer(address common.Address, filterer bind.ContractFilterer) (*StargateAdapterV2SimulationsFilterer, error) {
	contract, err := bindStargateAdapterV2Simulations(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsFilterer{contract: contract}, nil
}

// bindStargateAdapterV2Simulations binds a generic wrapper to an already deployed contract.
func bindStargateAdapterV2Simulations(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := StargateAdapterV2SimulationsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapterV2Simulations.Contract.StargateAdapterV2SimulationsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.StargateAdapterV2SimulationsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.StargateAdapterV2SimulationsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapterV2Simulations.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.contract.Transact(opts, method, params...)
}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCaller) LZENDPOINT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2Simulations.contract.Call(opts, &out, "LZ_ENDPOINT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) LZENDPOINT() (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.LZENDPOINT(&_StargateAdapterV2Simulations.CallOpts)
}

// LZENDPOINT is a free data retrieval call binding the contract method 0xcd4d1c64.
//
// Solidity: function LZ_ENDPOINT() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerSession) LZENDPOINT() (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.LZENDPOINT(&_StargateAdapterV2Simulations.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2Simulations.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.SUPERDESTINATIONEXECUTOR(&_StargateAdapterV2Simulations.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.SUPERDESTINATIONEXECUTOR(&_StargateAdapterV2Simulations.CallOpts)
}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCaller) TOKENMESSAGING(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2Simulations.contract.Call(opts, &out, "TOKEN_MESSAGING")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) TOKENMESSAGING() (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.TOKENMESSAGING(&_StargateAdapterV2Simulations.CallOpts)
}

// TOKENMESSAGING is a free data retrieval call binding the contract method 0xbea9f07c.
//
// Solidity: function TOKEN_MESSAGING() view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerSession) TOKENMESSAGING() (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.TOKENMESSAGING(&_StargateAdapterV2Simulations.CallOpts)
}

// AllowedOFTs is a free data retrieval call binding the contract method 0xf734c14d.
//
// Solidity: function allowedOFTs(address oft) view returns(bool allowed)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCaller) AllowedOFTs(opts *bind.CallOpts, oft common.Address) (bool, error) {
	var out []interface{}
	err := _StargateAdapterV2Simulations.contract.Call(opts, &out, "allowedOFTs", oft)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// AllowedOFTs is a free data retrieval call binding the contract method 0xf734c14d.
//
// Solidity: function allowedOFTs(address oft) view returns(bool allowed)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) AllowedOFTs(oft common.Address) (bool, error) {
	return _StargateAdapterV2Simulations.Contract.AllowedOFTs(&_StargateAdapterV2Simulations.CallOpts, oft)
}

// AllowedOFTs is a free data retrieval call binding the contract method 0xf734c14d.
//
// Solidity: function allowedOFTs(address oft) view returns(bool allowed)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerSession) AllowedOFTs(oft common.Address) (bool, error) {
	return _StargateAdapterV2Simulations.Contract.AllowedOFTs(&_StargateAdapterV2Simulations.CallOpts, oft)
}

// AllowedOFTsList is a free data retrieval call binding the contract method 0x1b664a48.
//
// Solidity: function allowedOFTsList(uint256 ) view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCaller) AllowedOFTsList(opts *bind.CallOpts, arg0 *big.Int) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2Simulations.contract.Call(opts, &out, "allowedOFTsList", arg0)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AllowedOFTsList is a free data retrieval call binding the contract method 0x1b664a48.
//
// Solidity: function allowedOFTsList(uint256 ) view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) AllowedOFTsList(arg0 *big.Int) (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.AllowedOFTsList(&_StargateAdapterV2Simulations.CallOpts, arg0)
}

// AllowedOFTsList is a free data retrieval call binding the contract method 0x1b664a48.
//
// Solidity: function allowedOFTsList(uint256 ) view returns(address)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerSession) AllowedOFTsList(arg0 *big.Int) (common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.AllowedOFTsList(&_StargateAdapterV2Simulations.CallOpts, arg0)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCaller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterV2Simulations.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _StargateAdapterV2Simulations.Contract.FailedTransfers(&_StargateAdapterV2Simulations.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _StargateAdapterV2Simulations.Contract.FailedTransfers(&_StargateAdapterV2Simulations.CallOpts, account, token)
}

// GetAllowedOFTs is a free data retrieval call binding the contract method 0xb17b3642.
//
// Solidity: function getAllowedOFTs() view returns(address[])
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCaller) GetAllowedOFTs(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _StargateAdapterV2Simulations.contract.Call(opts, &out, "getAllowedOFTs")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetAllowedOFTs is a free data retrieval call binding the contract method 0xb17b3642.
//
// Solidity: function getAllowedOFTs() view returns(address[])
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) GetAllowedOFTs() ([]common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.GetAllowedOFTs(&_StargateAdapterV2Simulations.CallOpts)
}

// GetAllowedOFTs is a free data retrieval call binding the contract method 0xb17b3642.
//
// Solidity: function getAllowedOFTs() view returns(address[])
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsCallerSession) GetAllowedOFTs() ([]common.Address, error) {
	return _StargateAdapterV2Simulations.Contract.GetAllowedOFTs(&_StargateAdapterV2Simulations.CallOpts)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.ClaimFailedTransfer(&_StargateAdapterV2Simulations.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.ClaimFailedTransfer(&_StargateAdapterV2Simulations.TransactOpts, token, amount)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactor) HandleCompose(opts *bind.TransactOpts, _guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.contract.Transact(opts, "handleCompose", _guid, _message, tokenSent, amountLD, composeFrom)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) HandleCompose(_guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.HandleCompose(&_StargateAdapterV2Simulations.TransactOpts, _guid, _message, tokenSent, amountLD, composeFrom)
}

// HandleCompose is a paid mutator transaction binding the contract method 0x99c58c75.
//
// Solidity: function handleCompose(bytes32 _guid, bytes _message, address tokenSent, uint256 amountLD, address composeFrom) returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactorSession) HandleCompose(_guid [32]byte, _message []byte, tokenSent common.Address, amountLD *big.Int, composeFrom common.Address) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.HandleCompose(&_StargateAdapterV2Simulations.TransactOpts, _guid, _message, tokenSent, amountLD, composeFrom)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactor) LzCompose(opts *bind.TransactOpts, _from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.contract.Transact(opts, "lzCompose", _from, _guid, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) LzCompose(_from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.LzCompose(&_StargateAdapterV2Simulations.TransactOpts, _from, _guid, _message, arg3, arg4)
}

// LzCompose is a paid mutator transaction binding the contract method 0xd0a10260.
//
// Solidity: function lzCompose(address _from, bytes32 _guid, bytes _message, address , bytes ) payable returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactorSession) LzCompose(_from common.Address, _guid [32]byte, _message []byte, arg3 common.Address, arg4 []byte) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.LzCompose(&_StargateAdapterV2Simulations.TransactOpts, _from, _guid, _message, arg3, arg4)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsSession) Receive() (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.Receive(&_StargateAdapterV2Simulations.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsTransactorSession) Receive() (*types.Transaction, error) {
	return _StargateAdapterV2Simulations.Contract.Receive(&_StargateAdapterV2Simulations.TransactOpts)
}

// StargateAdapterV2SimulationsComposeDecodeFailedIterator is returned from FilterComposeDecodeFailed and is used to iterate over the raw logs and unpacked data for ComposeDecodeFailed events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsComposeDecodeFailedIterator struct {
	Event *StargateAdapterV2SimulationsComposeDecodeFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsComposeDecodeFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsComposeDecodeFailed)
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
		it.Event = new(StargateAdapterV2SimulationsComposeDecodeFailed)
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
func (it *StargateAdapterV2SimulationsComposeDecodeFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsComposeDecodeFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsComposeDecodeFailed represents a ComposeDecodeFailed event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsComposeDecodeFailed struct {
	Guid [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterComposeDecodeFailed is a free log retrieval operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterComposeDecodeFailed(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterV2SimulationsComposeDecodeFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "ComposeDecodeFailed", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsComposeDecodeFailedIterator{contract: _StargateAdapterV2Simulations.contract, event: "ComposeDecodeFailed", logs: logs, sub: sub}, nil
}

// WatchComposeDecodeFailed is a free log subscription operation binding the contract event 0x497a8ff3fd03f4d6d86978d54d197f2c6ccc130969006ee85436be2e208ddaa0.
//
// Solidity: event ComposeDecodeFailed(bytes32 indexed guid)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchComposeDecodeFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsComposeDecodeFailed, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "ComposeDecodeFailed", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsComposeDecodeFailed)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "ComposeDecodeFailed", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseComposeDecodeFailed(log types.Log) (*StargateAdapterV2SimulationsComposeDecodeFailed, error) {
	event := new(StargateAdapterV2SimulationsComposeDecodeFailed)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "ComposeDecodeFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsComposeMsgTooShortIterator is returned from FilterComposeMsgTooShort and is used to iterate over the raw logs and unpacked data for ComposeMsgTooShort events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsComposeMsgTooShortIterator struct {
	Event *StargateAdapterV2SimulationsComposeMsgTooShort // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsComposeMsgTooShortIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsComposeMsgTooShort)
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
		it.Event = new(StargateAdapterV2SimulationsComposeMsgTooShort)
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
func (it *StargateAdapterV2SimulationsComposeMsgTooShortIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsComposeMsgTooShortIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsComposeMsgTooShort represents a ComposeMsgTooShort event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsComposeMsgTooShort struct {
	Guid          [32]byte
	MessageLength *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterComposeMsgTooShort is a free log retrieval operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterComposeMsgTooShort(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterV2SimulationsComposeMsgTooShortIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "ComposeMsgTooShort", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsComposeMsgTooShortIterator{contract: _StargateAdapterV2Simulations.contract, event: "ComposeMsgTooShort", logs: logs, sub: sub}, nil
}

// WatchComposeMsgTooShort is a free log subscription operation binding the contract event 0x63ce4581f3c3d63a5c49f1530150926edb7f095adac5fb57ce383ab4fdfa496d.
//
// Solidity: event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchComposeMsgTooShort(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsComposeMsgTooShort, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "ComposeMsgTooShort", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsComposeMsgTooShort)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "ComposeMsgTooShort", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseComposeMsgTooShort(log types.Log) (*StargateAdapterV2SimulationsComposeMsgTooShort, error) {
	event := new(StargateAdapterV2SimulationsComposeMsgTooShort)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "ComposeMsgTooShort", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsExecutionFailedIterator struct {
	Event *StargateAdapterV2SimulationsExecutionFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsExecutionFailed)
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
		it.Event = new(StargateAdapterV2SimulationsExecutionFailed)
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
func (it *StargateAdapterV2SimulationsExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsExecutionFailed represents a ExecutionFailed event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsExecutionFailed struct {
	Guid    [32]byte
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterExecutionFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address) (*StargateAdapterV2SimulationsExecutionFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsExecutionFailedIterator{contract: _StargateAdapterV2Simulations.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsExecutionFailed, guid [][32]byte, account []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsExecutionFailed)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseExecutionFailed(log types.Log) (*StargateAdapterV2SimulationsExecutionFailed, error) {
	event := new(StargateAdapterV2SimulationsExecutionFailed)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsFailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsFailedTransferClaimedIterator struct {
	Event *StargateAdapterV2SimulationsFailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsFailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsFailedTransferClaimed)
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
		it.Event = new(StargateAdapterV2SimulationsFailedTransferClaimed)
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
func (it *StargateAdapterV2SimulationsFailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsFailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsFailedTransferClaimed represents a FailedTransferClaimed event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsFailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*StargateAdapterV2SimulationsFailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsFailedTransferClaimedIterator{contract: _StargateAdapterV2Simulations.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsFailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsFailedTransferClaimed)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseFailedTransferClaimed(log types.Log) (*StargateAdapterV2SimulationsFailedTransferClaimed, error) {
	event := new(StargateAdapterV2SimulationsFailedTransferClaimed)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsNoDstProofForChainIterator is returned from FilterNoDstProofForChain and is used to iterate over the raw logs and unpacked data for NoDstProofForChain events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsNoDstProofForChainIterator struct {
	Event *StargateAdapterV2SimulationsNoDstProofForChain // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsNoDstProofForChainIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsNoDstProofForChain)
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
		it.Event = new(StargateAdapterV2SimulationsNoDstProofForChain)
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
func (it *StargateAdapterV2SimulationsNoDstProofForChainIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsNoDstProofForChainIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsNoDstProofForChain represents a NoDstProofForChain event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsNoDstProofForChain struct {
	Guid    [32]byte
	ChainId uint64
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterNoDstProofForChain is a free log retrieval operation binding the contract event 0x9d6f695be53eba948a35ab0c43717584bf19bc6547329e81e194c8e9e2dfebe0.
//
// Solidity: event NoDstProofForChain(bytes32 indexed guid, uint64 chainId)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterNoDstProofForChain(opts *bind.FilterOpts, guid [][32]byte) (*StargateAdapterV2SimulationsNoDstProofForChainIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "NoDstProofForChain", guidRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsNoDstProofForChainIterator{contract: _StargateAdapterV2Simulations.contract, event: "NoDstProofForChain", logs: logs, sub: sub}, nil
}

// WatchNoDstProofForChain is a free log subscription operation binding the contract event 0x9d6f695be53eba948a35ab0c43717584bf19bc6547329e81e194c8e9e2dfebe0.
//
// Solidity: event NoDstProofForChain(bytes32 indexed guid, uint64 chainId)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchNoDstProofForChain(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsNoDstProofForChain, guid [][32]byte) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "NoDstProofForChain", guidRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsNoDstProofForChain)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "NoDstProofForChain", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseNoDstProofForChain(log types.Log) (*StargateAdapterV2SimulationsNoDstProofForChain, error) {
	event := new(StargateAdapterV2SimulationsNoDstProofForChain)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "NoDstProofForChain", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsTokenResolutionFailedIterator is returned from FilterTokenResolutionFailed and is used to iterate over the raw logs and unpacked data for TokenResolutionFailed events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsTokenResolutionFailedIterator struct {
	Event *StargateAdapterV2SimulationsTokenResolutionFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsTokenResolutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsTokenResolutionFailed)
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
		it.Event = new(StargateAdapterV2SimulationsTokenResolutionFailed)
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
func (it *StargateAdapterV2SimulationsTokenResolutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsTokenResolutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsTokenResolutionFailed represents a TokenResolutionFailed event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsTokenResolutionFailed struct {
	Guid [32]byte
	From common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterTokenResolutionFailed is a free log retrieval operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterTokenResolutionFailed(opts *bind.FilterOpts, guid [][32]byte, from []common.Address) (*StargateAdapterV2SimulationsTokenResolutionFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "TokenResolutionFailed", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsTokenResolutionFailedIterator{contract: _StargateAdapterV2Simulations.contract, event: "TokenResolutionFailed", logs: logs, sub: sub}, nil
}

// WatchTokenResolutionFailed is a free log subscription operation binding the contract event 0xe3ac115e724e267c583b8cd58499639022892ddb8d98d58297a40d6088f6dd13.
//
// Solidity: event TokenResolutionFailed(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchTokenResolutionFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsTokenResolutionFailed, guid [][32]byte, from []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "TokenResolutionFailed", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsTokenResolutionFailed)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "TokenResolutionFailed", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseTokenResolutionFailed(log types.Log) (*StargateAdapterV2SimulationsTokenResolutionFailed, error) {
	event := new(StargateAdapterV2SimulationsTokenResolutionFailed)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "TokenResolutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsTransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsTransferFailedIterator struct {
	Event *StargateAdapterV2SimulationsTransferFailed // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsTransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsTransferFailed)
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
		it.Event = new(StargateAdapterV2SimulationsTransferFailed)
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
func (it *StargateAdapterV2SimulationsTransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsTransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsTransferFailed represents a TransferFailed event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsTransferFailed struct {
	Guid    [32]byte
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterTransferFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, token []common.Address) (*StargateAdapterV2SimulationsTransferFailedIterator, error) {

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

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsTransferFailedIterator{contract: _StargateAdapterV2Simulations.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsTransferFailed, guid [][32]byte, account []common.Address, token []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsTransferFailed)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseTransferFailed(log types.Log) (*StargateAdapterV2SimulationsTransferFailed, error) {
	event := new(StargateAdapterV2SimulationsTransferFailed)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsTransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsTransferSucceededIterator struct {
	Event *StargateAdapterV2SimulationsTransferSucceeded // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsTransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsTransferSucceeded)
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
		it.Event = new(StargateAdapterV2SimulationsTransferSucceeded)
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
func (it *StargateAdapterV2SimulationsTransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsTransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsTransferSucceeded represents a TransferSucceeded event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsTransferSucceeded struct {
	Guid      [32]byte
	Account   common.Address
	TokenSent common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterTransferSucceeded(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, tokenSent []common.Address) (*StargateAdapterV2SimulationsTransferSucceededIterator, error) {

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

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsTransferSucceededIterator{contract: _StargateAdapterV2Simulations.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsTransferSucceeded, guid [][32]byte, account []common.Address, tokenSent []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsTransferSucceeded)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseTransferSucceeded(log types.Log) (*StargateAdapterV2SimulationsTransferSucceeded, error) {
	event := new(StargateAdapterV2SimulationsTransferSucceeded)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterV2SimulationsUnregisteredPoolIterator is returned from FilterUnregisteredPool and is used to iterate over the raw logs and unpacked data for UnregisteredPool events raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsUnregisteredPoolIterator struct {
	Event *StargateAdapterV2SimulationsUnregisteredPool // Event containing the contract specifics and raw log

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
func (it *StargateAdapterV2SimulationsUnregisteredPoolIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterV2SimulationsUnregisteredPool)
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
		it.Event = new(StargateAdapterV2SimulationsUnregisteredPool)
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
func (it *StargateAdapterV2SimulationsUnregisteredPoolIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterV2SimulationsUnregisteredPoolIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterV2SimulationsUnregisteredPool represents a UnregisteredPool event raised by the StargateAdapterV2Simulations contract.
type StargateAdapterV2SimulationsUnregisteredPool struct {
	Guid [32]byte
	From common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterUnregisteredPool is a free log retrieval operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) FilterUnregisteredPool(opts *bind.FilterOpts, guid [][32]byte, from []common.Address) (*StargateAdapterV2SimulationsUnregisteredPoolIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.FilterLogs(opts, "UnregisteredPool", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterV2SimulationsUnregisteredPoolIterator{contract: _StargateAdapterV2Simulations.contract, event: "UnregisteredPool", logs: logs, sub: sub}, nil
}

// WatchUnregisteredPool is a free log subscription operation binding the contract event 0x4a8edc093fc4e87938cfaa72bb7a6d95abecfc3db7c90f693e5eefb30303c2cf.
//
// Solidity: event UnregisteredPool(bytes32 indexed guid, address indexed from)
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) WatchUnregisteredPool(opts *bind.WatchOpts, sink chan<- *StargateAdapterV2SimulationsUnregisteredPool, guid [][32]byte, from []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _StargateAdapterV2Simulations.contract.WatchLogs(opts, "UnregisteredPool", guidRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterV2SimulationsUnregisteredPool)
				if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "UnregisteredPool", log); err != nil {
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
func (_StargateAdapterV2Simulations *StargateAdapterV2SimulationsFilterer) ParseUnregisteredPool(log types.Log) (*StargateAdapterV2SimulationsUnregisteredPool, error) {
	event := new(StargateAdapterV2SimulationsUnregisteredPool)
	if err := _StargateAdapterV2Simulations.contract.UnpackLog(event, "UnregisteredPool", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
