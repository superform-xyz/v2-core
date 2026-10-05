// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package CircleGatewayAdapter

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

// CircleGatewayAdapterHookPayload is an auto generated low-level Go binding around an user-defined struct.
type CircleGatewayAdapterHookPayload struct {
	InitData         []byte
	ExecutorCalldata []byte
	Account          common.Address
	DstTokens        []common.Address
	IntentAmounts    []*big.Int
	SigData          []byte
}

// CircleGatewayAdapterMetaData contains all meta data concerning the CircleGatewayAdapter contract.
var CircleGatewayAdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"gatewayMinter_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usdc_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"GATEWAY_MINTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIGatewayMinter\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIERC20\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"checkDestinationTargets\",\"inputs\":[{\"name\":\"sigData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"code\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decodeHookPayload\",\"inputs\":[{\"name\":\"hookData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"p\",\"type\":\"tuple\",\"internalType\":\"structCircleGatewayAdapter.HookPayload\",\"components\":[{\"name\":\"initData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"executorCalldata\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dstTokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"intentAmounts\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"sigData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"processed\",\"inputs\":[{\"name\":\"specHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"processed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"receiveAndExecute\",\"inputs\":[{\"name\":\"attestationPayload\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"recoverDirectMint\",\"inputs\":[{\"name\":\"attestationPayload\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"totalEscrowed\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"DestinationTargetMismatch\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"code\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"selector\",\"type\":\"bytes4\",\"indexed\":false,\"internalType\":\"bytes4\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MisconfiguredMessageRelayed\",\"inputs\":[{\"name\":\"kind\",\"type\":\"uint8\",\"indexed\":true,\"internalType\":\"uint8\"},{\"name\":\"destinationRecipient\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SpecProcessed\",\"inputs\":[{\"name\":\"specHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"recovered\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ATTESTATION_SET_DUPLICATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ATTESTATION_SET_EMPTY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ATTESTATION_SET_MIXED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CursorOutOfBounds\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_CALLER_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_CONTRACT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_DOMAIN_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_RECIPIENT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"GATEWAY_MINTER_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_PAYLOAD_INVALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_GAS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_RECOVERABLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTransferPayloadMagic\",\"inputs\":[{\"name\":\"actualMagic\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}]},{\"type\":\"error\",\"name\":\"InvalidTransferSpecMagic\",\"inputs\":[{\"name\":\"actualMagic\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}]},{\"type\":\"error\",\"name\":\"InvalidTransferSpecVersion\",\"inputs\":[{\"name\":\"actualVersion\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"type\":\"error\",\"name\":\"NOTHING_MINTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SPEC_ALREADY_PROCESSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SPEC_NOT_MINTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadDataTooShort\",\"inputs\":[{\"name\":\"expectedMinimumLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadHeaderTooShort\",\"inputs\":[{\"name\":\"expectedMinimumLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadOverallLengthMismatch\",\"inputs\":[{\"name\":\"expectedTotalLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualTotalLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadSetElementHeaderTooShort\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"actualSetLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"requiredOffset\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadSetElementTooShort\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"actualSetLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"requiredOffset\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadSetHeaderTooShort\",\"inputs\":[{\"name\":\"expectedMinimumLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadSetInvalidElementMagic\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"actualMagic\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}]},{\"type\":\"error\",\"name\":\"TransferPayloadSetOverallLengthMismatch\",\"inputs\":[{\"name\":\"expectedTotalLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualTotalLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferSpecHeaderTooShort\",\"inputs\":[{\"name\":\"expectedMinimumLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferSpecInvalidHookData\",\"inputs\":[{\"name\":\"expectedHookDataLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"transferSpecLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"TransferSpecOverallLengthMismatch\",\"inputs\":[{\"name\":\"expectedTotalLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualTotalLength\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_DESTINATION_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// CircleGatewayAdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use CircleGatewayAdapterMetaData.ABI instead.
var CircleGatewayAdapterABI = CircleGatewayAdapterMetaData.ABI

// CircleGatewayAdapter is an auto generated Go binding around an Ethereum contract.
type CircleGatewayAdapter struct {
	CircleGatewayAdapterCaller     // Read-only binding to the contract
	CircleGatewayAdapterTransactor // Write-only binding to the contract
	CircleGatewayAdapterFilterer   // Log filterer for contract events
}

// CircleGatewayAdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type CircleGatewayAdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CircleGatewayAdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type CircleGatewayAdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CircleGatewayAdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type CircleGatewayAdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CircleGatewayAdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type CircleGatewayAdapterSession struct {
	Contract     *CircleGatewayAdapter // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// CircleGatewayAdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type CircleGatewayAdapterCallerSession struct {
	Contract *CircleGatewayAdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// CircleGatewayAdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type CircleGatewayAdapterTransactorSession struct {
	Contract     *CircleGatewayAdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// CircleGatewayAdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type CircleGatewayAdapterRaw struct {
	Contract *CircleGatewayAdapter // Generic contract binding to access the raw methods on
}

// CircleGatewayAdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type CircleGatewayAdapterCallerRaw struct {
	Contract *CircleGatewayAdapterCaller // Generic read-only contract binding to access the raw methods on
}

// CircleGatewayAdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type CircleGatewayAdapterTransactorRaw struct {
	Contract *CircleGatewayAdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewCircleGatewayAdapter creates a new instance of CircleGatewayAdapter, bound to a specific deployed contract.
func NewCircleGatewayAdapter(address common.Address, backend bind.ContractBackend) (*CircleGatewayAdapter, error) {
	contract, err := bindCircleGatewayAdapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapter{CircleGatewayAdapterCaller: CircleGatewayAdapterCaller{contract: contract}, CircleGatewayAdapterTransactor: CircleGatewayAdapterTransactor{contract: contract}, CircleGatewayAdapterFilterer: CircleGatewayAdapterFilterer{contract: contract}}, nil
}

// NewCircleGatewayAdapterCaller creates a new read-only instance of CircleGatewayAdapter, bound to a specific deployed contract.
func NewCircleGatewayAdapterCaller(address common.Address, caller bind.ContractCaller) (*CircleGatewayAdapterCaller, error) {
	contract, err := bindCircleGatewayAdapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterCaller{contract: contract}, nil
}

// NewCircleGatewayAdapterTransactor creates a new write-only instance of CircleGatewayAdapter, bound to a specific deployed contract.
func NewCircleGatewayAdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*CircleGatewayAdapterTransactor, error) {
	contract, err := bindCircleGatewayAdapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterTransactor{contract: contract}, nil
}

// NewCircleGatewayAdapterFilterer creates a new log filterer instance of CircleGatewayAdapter, bound to a specific deployed contract.
func NewCircleGatewayAdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*CircleGatewayAdapterFilterer, error) {
	contract, err := bindCircleGatewayAdapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterFilterer{contract: contract}, nil
}

// bindCircleGatewayAdapter binds a generic wrapper to an already deployed contract.
func bindCircleGatewayAdapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := CircleGatewayAdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CircleGatewayAdapter *CircleGatewayAdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CircleGatewayAdapter.Contract.CircleGatewayAdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CircleGatewayAdapter *CircleGatewayAdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.CircleGatewayAdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CircleGatewayAdapter *CircleGatewayAdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.CircleGatewayAdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CircleGatewayAdapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.contract.Transact(opts, method, params...)
}

// GATEWAYMINTER is a free data retrieval call binding the contract method 0x6558b981.
//
// Solidity: function GATEWAY_MINTER() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) GATEWAYMINTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "GATEWAY_MINTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GATEWAYMINTER is a free data retrieval call binding the contract method 0x6558b981.
//
// Solidity: function GATEWAY_MINTER() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) GATEWAYMINTER() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.GATEWAYMINTER(&_CircleGatewayAdapter.CallOpts)
}

// GATEWAYMINTER is a free data retrieval call binding the contract method 0x6558b981.
//
// Solidity: function GATEWAY_MINTER() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) GATEWAYMINTER() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.GATEWAYMINTER(&_CircleGatewayAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_CircleGatewayAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_CircleGatewayAdapter.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) SUPERDESTINATIONVALIDATOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.SUPERDESTINATIONVALIDATOR(&_CircleGatewayAdapter.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.SUPERDESTINATIONVALIDATOR(&_CircleGatewayAdapter.CallOpts)
}

// USDC is a free data retrieval call binding the contract method 0x89a30271.
//
// Solidity: function USDC() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// USDC is a free data retrieval call binding the contract method 0x89a30271.
//
// Solidity: function USDC() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) USDC() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.USDC(&_CircleGatewayAdapter.CallOpts)
}

// USDC is a free data retrieval call binding the contract method 0x89a30271.
//
// Solidity: function USDC() view returns(address)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) USDC() (common.Address, error) {
	return _CircleGatewayAdapter.Contract.USDC(&_CircleGatewayAdapter.CallOpts)
}

// CheckDestinationTargets is a free data retrieval call binding the contract method 0xa048a4ab.
//
// Solidity: function checkDestinationTargets(bytes sigData) view returns(uint8 code)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) CheckDestinationTargets(opts *bind.CallOpts, sigData []byte) (uint8, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "checkDestinationTargets", sigData)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// CheckDestinationTargets is a free data retrieval call binding the contract method 0xa048a4ab.
//
// Solidity: function checkDestinationTargets(bytes sigData) view returns(uint8 code)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) CheckDestinationTargets(sigData []byte) (uint8, error) {
	return _CircleGatewayAdapter.Contract.CheckDestinationTargets(&_CircleGatewayAdapter.CallOpts, sigData)
}

// CheckDestinationTargets is a free data retrieval call binding the contract method 0xa048a4ab.
//
// Solidity: function checkDestinationTargets(bytes sigData) view returns(uint8 code)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) CheckDestinationTargets(sigData []byte) (uint8, error) {
	return _CircleGatewayAdapter.Contract.CheckDestinationTargets(&_CircleGatewayAdapter.CallOpts, sigData)
}

// DecodeHookPayload is a free data retrieval call binding the contract method 0xdd148464.
//
// Solidity: function decodeHookPayload(bytes hookData) view returns((bytes,bytes,address,address[],uint256[],bytes) p)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) DecodeHookPayload(opts *bind.CallOpts, hookData []byte) (CircleGatewayAdapterHookPayload, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "decodeHookPayload", hookData)

	if err != nil {
		return *new(CircleGatewayAdapterHookPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(CircleGatewayAdapterHookPayload)).(*CircleGatewayAdapterHookPayload)

	return out0, err

}

// DecodeHookPayload is a free data retrieval call binding the contract method 0xdd148464.
//
// Solidity: function decodeHookPayload(bytes hookData) view returns((bytes,bytes,address,address[],uint256[],bytes) p)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) DecodeHookPayload(hookData []byte) (CircleGatewayAdapterHookPayload, error) {
	return _CircleGatewayAdapter.Contract.DecodeHookPayload(&_CircleGatewayAdapter.CallOpts, hookData)
}

// DecodeHookPayload is a free data retrieval call binding the contract method 0xdd148464.
//
// Solidity: function decodeHookPayload(bytes hookData) view returns((bytes,bytes,address,address[],uint256[],bytes) p)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) DecodeHookPayload(hookData []byte) (CircleGatewayAdapterHookPayload, error) {
	return _CircleGatewayAdapter.Contract.DecodeHookPayload(&_CircleGatewayAdapter.CallOpts, hookData)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _CircleGatewayAdapter.Contract.FailedTransfers(&_CircleGatewayAdapter.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _CircleGatewayAdapter.Contract.FailedTransfers(&_CircleGatewayAdapter.CallOpts, account, token)
}

// Processed is a free data retrieval call binding the contract method 0xc1f0808a.
//
// Solidity: function processed(bytes32 specHash) view returns(bool processed)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) Processed(opts *bind.CallOpts, specHash [32]byte) (bool, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "processed", specHash)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Processed is a free data retrieval call binding the contract method 0xc1f0808a.
//
// Solidity: function processed(bytes32 specHash) view returns(bool processed)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) Processed(specHash [32]byte) (bool, error) {
	return _CircleGatewayAdapter.Contract.Processed(&_CircleGatewayAdapter.CallOpts, specHash)
}

// Processed is a free data retrieval call binding the contract method 0xc1f0808a.
//
// Solidity: function processed(bytes32 specHash) view returns(bool processed)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) Processed(specHash [32]byte) (bool, error) {
	return _CircleGatewayAdapter.Contract.Processed(&_CircleGatewayAdapter.CallOpts, specHash)
}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterCaller) TotalEscrowed(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _CircleGatewayAdapter.contract.Call(opts, &out, "totalEscrowed", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) TotalEscrowed(token common.Address) (*big.Int, error) {
	return _CircleGatewayAdapter.Contract.TotalEscrowed(&_CircleGatewayAdapter.CallOpts, token)
}

// TotalEscrowed is a free data retrieval call binding the contract method 0x62c9e1be.
//
// Solidity: function totalEscrowed(address token) view returns(uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterCallerSession) TotalEscrowed(token common.Address) (*big.Int, error) {
	return _CircleGatewayAdapter.Contract.TotalEscrowed(&_CircleGatewayAdapter.CallOpts, token)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _CircleGatewayAdapter.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.ClaimFailedTransfer(&_CircleGatewayAdapter.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.ClaimFailedTransfer(&_CircleGatewayAdapter.TransactOpts, token, amount)
}

// ReceiveAndExecute is a paid mutator transaction binding the contract method 0x7c5dc5a5.
//
// Solidity: function receiveAndExecute(bytes attestationPayload, bytes signature) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactor) ReceiveAndExecute(opts *bind.TransactOpts, attestationPayload []byte, signature []byte) (*types.Transaction, error) {
	return _CircleGatewayAdapter.contract.Transact(opts, "receiveAndExecute", attestationPayload, signature)
}

// ReceiveAndExecute is a paid mutator transaction binding the contract method 0x7c5dc5a5.
//
// Solidity: function receiveAndExecute(bytes attestationPayload, bytes signature) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) ReceiveAndExecute(attestationPayload []byte, signature []byte) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.ReceiveAndExecute(&_CircleGatewayAdapter.TransactOpts, attestationPayload, signature)
}

// ReceiveAndExecute is a paid mutator transaction binding the contract method 0x7c5dc5a5.
//
// Solidity: function receiveAndExecute(bytes attestationPayload, bytes signature) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactorSession) ReceiveAndExecute(attestationPayload []byte, signature []byte) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.ReceiveAndExecute(&_CircleGatewayAdapter.TransactOpts, attestationPayload, signature)
}

// RecoverDirectMint is a paid mutator transaction binding the contract method 0xd923a378.
//
// Solidity: function recoverDirectMint(bytes attestationPayload) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactor) RecoverDirectMint(opts *bind.TransactOpts, attestationPayload []byte) (*types.Transaction, error) {
	return _CircleGatewayAdapter.contract.Transact(opts, "recoverDirectMint", attestationPayload)
}

// RecoverDirectMint is a paid mutator transaction binding the contract method 0xd923a378.
//
// Solidity: function recoverDirectMint(bytes attestationPayload) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterSession) RecoverDirectMint(attestationPayload []byte) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.RecoverDirectMint(&_CircleGatewayAdapter.TransactOpts, attestationPayload)
}

// RecoverDirectMint is a paid mutator transaction binding the contract method 0xd923a378.
//
// Solidity: function recoverDirectMint(bytes attestationPayload) returns()
func (_CircleGatewayAdapter *CircleGatewayAdapterTransactorSession) RecoverDirectMint(attestationPayload []byte) (*types.Transaction, error) {
	return _CircleGatewayAdapter.Contract.RecoverDirectMint(&_CircleGatewayAdapter.TransactOpts, attestationPayload)
}

// CircleGatewayAdapterDestinationTargetMismatchIterator is returned from FilterDestinationTargetMismatch and is used to iterate over the raw logs and unpacked data for DestinationTargetMismatch events raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterDestinationTargetMismatchIterator struct {
	Event *CircleGatewayAdapterDestinationTargetMismatch // Event containing the contract specifics and raw log

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
func (it *CircleGatewayAdapterDestinationTargetMismatchIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CircleGatewayAdapterDestinationTargetMismatch)
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
		it.Event = new(CircleGatewayAdapterDestinationTargetMismatch)
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
func (it *CircleGatewayAdapterDestinationTargetMismatchIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CircleGatewayAdapterDestinationTargetMismatchIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CircleGatewayAdapterDestinationTargetMismatch represents a DestinationTargetMismatch event raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterDestinationTargetMismatch struct {
	Account common.Address
	Code    uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterDestinationTargetMismatch is a free log retrieval operation binding the contract event 0x4d170f5ebe8095c90332d055eab1060e9521d04d9e47916e14febb0a7bf513d8.
//
// Solidity: event DestinationTargetMismatch(address indexed account, uint8 code)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) FilterDestinationTargetMismatch(opts *bind.FilterOpts, account []common.Address) (*CircleGatewayAdapterDestinationTargetMismatchIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.FilterLogs(opts, "DestinationTargetMismatch", accountRule)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterDestinationTargetMismatchIterator{contract: _CircleGatewayAdapter.contract, event: "DestinationTargetMismatch", logs: logs, sub: sub}, nil
}

// WatchDestinationTargetMismatch is a free log subscription operation binding the contract event 0x4d170f5ebe8095c90332d055eab1060e9521d04d9e47916e14febb0a7bf513d8.
//
// Solidity: event DestinationTargetMismatch(address indexed account, uint8 code)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) WatchDestinationTargetMismatch(opts *bind.WatchOpts, sink chan<- *CircleGatewayAdapterDestinationTargetMismatch, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.WatchLogs(opts, "DestinationTargetMismatch", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CircleGatewayAdapterDestinationTargetMismatch)
				if err := _CircleGatewayAdapter.contract.UnpackLog(event, "DestinationTargetMismatch", log); err != nil {
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

// ParseDestinationTargetMismatch is a log parse operation binding the contract event 0x4d170f5ebe8095c90332d055eab1060e9521d04d9e47916e14febb0a7bf513d8.
//
// Solidity: event DestinationTargetMismatch(address indexed account, uint8 code)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) ParseDestinationTargetMismatch(log types.Log) (*CircleGatewayAdapterDestinationTargetMismatch, error) {
	event := new(CircleGatewayAdapterDestinationTargetMismatch)
	if err := _CircleGatewayAdapter.contract.UnpackLog(event, "DestinationTargetMismatch", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CircleGatewayAdapterExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterExecutionFailedIterator struct {
	Event *CircleGatewayAdapterExecutionFailed // Event containing the contract specifics and raw log

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
func (it *CircleGatewayAdapterExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CircleGatewayAdapterExecutionFailed)
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
		it.Event = new(CircleGatewayAdapterExecutionFailed)
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
func (it *CircleGatewayAdapterExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CircleGatewayAdapterExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CircleGatewayAdapterExecutionFailed represents a ExecutionFailed event raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterExecutionFailed struct {
	Account  common.Address
	Selector [4]byte
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0x74c824cbfa28ea7b48d49ef06cc5c9d7aea14c6d09207f758d7c63996f60c98c.
//
// Solidity: event ExecutionFailed(address indexed account, bytes4 selector)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) FilterExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*CircleGatewayAdapterExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.FilterLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterExecutionFailedIterator{contract: _CircleGatewayAdapter.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0x74c824cbfa28ea7b48d49ef06cc5c9d7aea14c6d09207f758d7c63996f60c98c.
//
// Solidity: event ExecutionFailed(address indexed account, bytes4 selector)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *CircleGatewayAdapterExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.WatchLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CircleGatewayAdapterExecutionFailed)
				if err := _CircleGatewayAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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

// ParseExecutionFailed is a log parse operation binding the contract event 0x74c824cbfa28ea7b48d49ef06cc5c9d7aea14c6d09207f758d7c63996f60c98c.
//
// Solidity: event ExecutionFailed(address indexed account, bytes4 selector)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) ParseExecutionFailed(log types.Log) (*CircleGatewayAdapterExecutionFailed, error) {
	event := new(CircleGatewayAdapterExecutionFailed)
	if err := _CircleGatewayAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CircleGatewayAdapterFailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterFailedTransferClaimedIterator struct {
	Event *CircleGatewayAdapterFailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *CircleGatewayAdapterFailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CircleGatewayAdapterFailedTransferClaimed)
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
		it.Event = new(CircleGatewayAdapterFailedTransferClaimed)
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
func (it *CircleGatewayAdapterFailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CircleGatewayAdapterFailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CircleGatewayAdapterFailedTransferClaimed represents a FailedTransferClaimed event raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterFailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*CircleGatewayAdapterFailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterFailedTransferClaimedIterator{contract: _CircleGatewayAdapter.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *CircleGatewayAdapterFailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CircleGatewayAdapterFailedTransferClaimed)
				if err := _CircleGatewayAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) ParseFailedTransferClaimed(log types.Log) (*CircleGatewayAdapterFailedTransferClaimed, error) {
	event := new(CircleGatewayAdapterFailedTransferClaimed)
	if err := _CircleGatewayAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CircleGatewayAdapterMisconfiguredMessageRelayedIterator is returned from FilterMisconfiguredMessageRelayed and is used to iterate over the raw logs and unpacked data for MisconfiguredMessageRelayed events raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterMisconfiguredMessageRelayedIterator struct {
	Event *CircleGatewayAdapterMisconfiguredMessageRelayed // Event containing the contract specifics and raw log

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
func (it *CircleGatewayAdapterMisconfiguredMessageRelayedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CircleGatewayAdapterMisconfiguredMessageRelayed)
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
		it.Event = new(CircleGatewayAdapterMisconfiguredMessageRelayed)
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
func (it *CircleGatewayAdapterMisconfiguredMessageRelayedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CircleGatewayAdapterMisconfiguredMessageRelayedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CircleGatewayAdapterMisconfiguredMessageRelayed represents a MisconfiguredMessageRelayed event raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterMisconfiguredMessageRelayed struct {
	Kind                 uint8
	DestinationRecipient common.Address
	Raw                  types.Log // Blockchain specific contextual infos
}

// FilterMisconfiguredMessageRelayed is a free log retrieval operation binding the contract event 0x82411bc8efcebe88d0234ce2a487d82db58b84501958498350a2e4d4f88fca1c.
//
// Solidity: event MisconfiguredMessageRelayed(uint8 indexed kind, address destinationRecipient)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) FilterMisconfiguredMessageRelayed(opts *bind.FilterOpts, kind []uint8) (*CircleGatewayAdapterMisconfiguredMessageRelayedIterator, error) {

	var kindRule []interface{}
	for _, kindItem := range kind {
		kindRule = append(kindRule, kindItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.FilterLogs(opts, "MisconfiguredMessageRelayed", kindRule)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterMisconfiguredMessageRelayedIterator{contract: _CircleGatewayAdapter.contract, event: "MisconfiguredMessageRelayed", logs: logs, sub: sub}, nil
}

// WatchMisconfiguredMessageRelayed is a free log subscription operation binding the contract event 0x82411bc8efcebe88d0234ce2a487d82db58b84501958498350a2e4d4f88fca1c.
//
// Solidity: event MisconfiguredMessageRelayed(uint8 indexed kind, address destinationRecipient)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) WatchMisconfiguredMessageRelayed(opts *bind.WatchOpts, sink chan<- *CircleGatewayAdapterMisconfiguredMessageRelayed, kind []uint8) (event.Subscription, error) {

	var kindRule []interface{}
	for _, kindItem := range kind {
		kindRule = append(kindRule, kindItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.WatchLogs(opts, "MisconfiguredMessageRelayed", kindRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CircleGatewayAdapterMisconfiguredMessageRelayed)
				if err := _CircleGatewayAdapter.contract.UnpackLog(event, "MisconfiguredMessageRelayed", log); err != nil {
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

// ParseMisconfiguredMessageRelayed is a log parse operation binding the contract event 0x82411bc8efcebe88d0234ce2a487d82db58b84501958498350a2e4d4f88fca1c.
//
// Solidity: event MisconfiguredMessageRelayed(uint8 indexed kind, address destinationRecipient)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) ParseMisconfiguredMessageRelayed(log types.Log) (*CircleGatewayAdapterMisconfiguredMessageRelayed, error) {
	event := new(CircleGatewayAdapterMisconfiguredMessageRelayed)
	if err := _CircleGatewayAdapter.contract.UnpackLog(event, "MisconfiguredMessageRelayed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CircleGatewayAdapterSpecProcessedIterator is returned from FilterSpecProcessed and is used to iterate over the raw logs and unpacked data for SpecProcessed events raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterSpecProcessedIterator struct {
	Event *CircleGatewayAdapterSpecProcessed // Event containing the contract specifics and raw log

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
func (it *CircleGatewayAdapterSpecProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CircleGatewayAdapterSpecProcessed)
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
		it.Event = new(CircleGatewayAdapterSpecProcessed)
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
func (it *CircleGatewayAdapterSpecProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CircleGatewayAdapterSpecProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CircleGatewayAdapterSpecProcessed represents a SpecProcessed event raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterSpecProcessed struct {
	SpecHash  [32]byte
	Account   common.Address
	Value     *big.Int
	Recovered bool
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterSpecProcessed is a free log retrieval operation binding the contract event 0xb017e5caa0dbdd862f00364e76e2ef6014d7555ee58623291497e347ae225678.
//
// Solidity: event SpecProcessed(bytes32 indexed specHash, address indexed account, uint256 value, bool recovered)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) FilterSpecProcessed(opts *bind.FilterOpts, specHash [][32]byte, account []common.Address) (*CircleGatewayAdapterSpecProcessedIterator, error) {

	var specHashRule []interface{}
	for _, specHashItem := range specHash {
		specHashRule = append(specHashRule, specHashItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.FilterLogs(opts, "SpecProcessed", specHashRule, accountRule)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterSpecProcessedIterator{contract: _CircleGatewayAdapter.contract, event: "SpecProcessed", logs: logs, sub: sub}, nil
}

// WatchSpecProcessed is a free log subscription operation binding the contract event 0xb017e5caa0dbdd862f00364e76e2ef6014d7555ee58623291497e347ae225678.
//
// Solidity: event SpecProcessed(bytes32 indexed specHash, address indexed account, uint256 value, bool recovered)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) WatchSpecProcessed(opts *bind.WatchOpts, sink chan<- *CircleGatewayAdapterSpecProcessed, specHash [][32]byte, account []common.Address) (event.Subscription, error) {

	var specHashRule []interface{}
	for _, specHashItem := range specHash {
		specHashRule = append(specHashRule, specHashItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.WatchLogs(opts, "SpecProcessed", specHashRule, accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CircleGatewayAdapterSpecProcessed)
				if err := _CircleGatewayAdapter.contract.UnpackLog(event, "SpecProcessed", log); err != nil {
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

// ParseSpecProcessed is a log parse operation binding the contract event 0xb017e5caa0dbdd862f00364e76e2ef6014d7555ee58623291497e347ae225678.
//
// Solidity: event SpecProcessed(bytes32 indexed specHash, address indexed account, uint256 value, bool recovered)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) ParseSpecProcessed(log types.Log) (*CircleGatewayAdapterSpecProcessed, error) {
	event := new(CircleGatewayAdapterSpecProcessed)
	if err := _CircleGatewayAdapter.contract.UnpackLog(event, "SpecProcessed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CircleGatewayAdapterTransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterTransferFailedIterator struct {
	Event *CircleGatewayAdapterTransferFailed // Event containing the contract specifics and raw log

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
func (it *CircleGatewayAdapterTransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CircleGatewayAdapterTransferFailed)
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
		it.Event = new(CircleGatewayAdapterTransferFailed)
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
func (it *CircleGatewayAdapterTransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CircleGatewayAdapterTransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CircleGatewayAdapterTransferFailed represents a TransferFailed event raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterTransferFailed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) FilterTransferFailed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*CircleGatewayAdapterTransferFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.FilterLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterTransferFailedIterator{contract: _CircleGatewayAdapter.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *CircleGatewayAdapterTransferFailed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.WatchLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CircleGatewayAdapterTransferFailed)
				if err := _CircleGatewayAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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

// ParseTransferFailed is a log parse operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) ParseTransferFailed(log types.Log) (*CircleGatewayAdapterTransferFailed, error) {
	event := new(CircleGatewayAdapterTransferFailed)
	if err := _CircleGatewayAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CircleGatewayAdapterTransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterTransferSucceededIterator struct {
	Event *CircleGatewayAdapterTransferSucceeded // Event containing the contract specifics and raw log

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
func (it *CircleGatewayAdapterTransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CircleGatewayAdapterTransferSucceeded)
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
		it.Event = new(CircleGatewayAdapterTransferSucceeded)
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
func (it *CircleGatewayAdapterTransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CircleGatewayAdapterTransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CircleGatewayAdapterTransferSucceeded represents a TransferSucceeded event raised by the CircleGatewayAdapter contract.
type CircleGatewayAdapterTransferSucceeded struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) FilterTransferSucceeded(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*CircleGatewayAdapterTransferSucceededIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.FilterLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &CircleGatewayAdapterTransferSucceededIterator{contract: _CircleGatewayAdapter.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *CircleGatewayAdapterTransferSucceeded, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CircleGatewayAdapter.contract.WatchLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CircleGatewayAdapterTransferSucceeded)
				if err := _CircleGatewayAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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

// ParseTransferSucceeded is a log parse operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_CircleGatewayAdapter *CircleGatewayAdapterFilterer) ParseTransferSucceeded(log types.Log) (*CircleGatewayAdapterTransferSucceeded, error) {
	event := new(CircleGatewayAdapterTransferSucceeded)
	if err := _CircleGatewayAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
