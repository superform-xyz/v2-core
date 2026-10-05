// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package CCTPAdapter

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

// CCTPAdapterHookPayload is an auto generated low-level Go binding around an user-defined struct.
type CCTPAdapterHookPayload struct {
	InitData         []byte
	ExecutorCalldata []byte
	Account          common.Address
	DstTokens        []common.Address
	IntentAmounts    []*big.Int
	SigData          []byte
}

// CCTPAdapterMetaData contains all meta data concerning the CCTPAdapter contract.
var CCTPAdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"messageTransmitter_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokenMessenger_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usdc_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"MESSAGE_TRANSMITTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIMessageTransmitterV2\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TOKEN_MESSENGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractITokenMessengerV2MinterSource\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIERC20\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"checkDestinationTargets\",\"inputs\":[{\"name\":\"sigData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"code\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimFailedTransfer\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decodeHookPayload\",\"inputs\":[{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"p\",\"type\":\"tuple\",\"internalType\":\"structCCTPAdapter.HookPayload\",\"components\":[{\"name\":\"initData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"executorCalldata\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dstTokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"intentAmounts\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"sigData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"failedTransfers\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"receiveAndExecute\",\"inputs\":[{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"attestation\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"DestinationTargetMismatch\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"code\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"selector\",\"type\":\"bytes4\",\"indexed\":false,\"internalType\":\"bytes4\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookPayloadUndecodable\",\"inputs\":[{\"name\":\"messageSender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MisconfiguredMessageRelayed\",\"inputs\":[{\"name\":\"kind\",\"type\":\"uint8\",\"indexed\":true,\"internalType\":\"uint8\"},{\"name\":\"mintRecipient\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"NonUsdcMintEscrowed\",\"inputs\":[{\"name\":\"messageSender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_CALLER_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FAILED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_GAS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MESSAGE_TOO_SHORT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MINT_RECIPIENT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOTHING_MINTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RECEIVE_MESSAGE_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RECIPIENT_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TOKEN_MESSENGER_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_BODY_VERSION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_BURN_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNSUPPORTED_MESSAGE_VERSION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// CCTPAdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use CCTPAdapterMetaData.ABI instead.
var CCTPAdapterABI = CCTPAdapterMetaData.ABI

// CCTPAdapter is an auto generated Go binding around an Ethereum contract.
type CCTPAdapter struct {
	CCTPAdapterCaller     // Read-only binding to the contract
	CCTPAdapterTransactor // Write-only binding to the contract
	CCTPAdapterFilterer   // Log filterer for contract events
}

// CCTPAdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type CCTPAdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CCTPAdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type CCTPAdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CCTPAdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type CCTPAdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CCTPAdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type CCTPAdapterSession struct {
	Contract     *CCTPAdapter      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// CCTPAdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type CCTPAdapterCallerSession struct {
	Contract *CCTPAdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// CCTPAdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type CCTPAdapterTransactorSession struct {
	Contract     *CCTPAdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// CCTPAdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type CCTPAdapterRaw struct {
	Contract *CCTPAdapter // Generic contract binding to access the raw methods on
}

// CCTPAdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type CCTPAdapterCallerRaw struct {
	Contract *CCTPAdapterCaller // Generic read-only contract binding to access the raw methods on
}

// CCTPAdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type CCTPAdapterTransactorRaw struct {
	Contract *CCTPAdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewCCTPAdapter creates a new instance of CCTPAdapter, bound to a specific deployed contract.
func NewCCTPAdapter(address common.Address, backend bind.ContractBackend) (*CCTPAdapter, error) {
	contract, err := bindCCTPAdapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapter{CCTPAdapterCaller: CCTPAdapterCaller{contract: contract}, CCTPAdapterTransactor: CCTPAdapterTransactor{contract: contract}, CCTPAdapterFilterer: CCTPAdapterFilterer{contract: contract}}, nil
}

// NewCCTPAdapterCaller creates a new read-only instance of CCTPAdapter, bound to a specific deployed contract.
func NewCCTPAdapterCaller(address common.Address, caller bind.ContractCaller) (*CCTPAdapterCaller, error) {
	contract, err := bindCCTPAdapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterCaller{contract: contract}, nil
}

// NewCCTPAdapterTransactor creates a new write-only instance of CCTPAdapter, bound to a specific deployed contract.
func NewCCTPAdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*CCTPAdapterTransactor, error) {
	contract, err := bindCCTPAdapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterTransactor{contract: contract}, nil
}

// NewCCTPAdapterFilterer creates a new log filterer instance of CCTPAdapter, bound to a specific deployed contract.
func NewCCTPAdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*CCTPAdapterFilterer, error) {
	contract, err := bindCCTPAdapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterFilterer{contract: contract}, nil
}

// bindCCTPAdapter binds a generic wrapper to an already deployed contract.
func bindCCTPAdapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := CCTPAdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CCTPAdapter *CCTPAdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CCTPAdapter.Contract.CCTPAdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CCTPAdapter *CCTPAdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.CCTPAdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CCTPAdapter *CCTPAdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.CCTPAdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CCTPAdapter *CCTPAdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CCTPAdapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CCTPAdapter *CCTPAdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CCTPAdapter *CCTPAdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.contract.Transact(opts, method, params...)
}

// MESSAGETRANSMITTER is a free data retrieval call binding the contract method 0xb6a84a5f.
//
// Solidity: function MESSAGE_TRANSMITTER() view returns(address)
func (_CCTPAdapter *CCTPAdapterCaller) MESSAGETRANSMITTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "MESSAGE_TRANSMITTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MESSAGETRANSMITTER is a free data retrieval call binding the contract method 0xb6a84a5f.
//
// Solidity: function MESSAGE_TRANSMITTER() view returns(address)
func (_CCTPAdapter *CCTPAdapterSession) MESSAGETRANSMITTER() (common.Address, error) {
	return _CCTPAdapter.Contract.MESSAGETRANSMITTER(&_CCTPAdapter.CallOpts)
}

// MESSAGETRANSMITTER is a free data retrieval call binding the contract method 0xb6a84a5f.
//
// Solidity: function MESSAGE_TRANSMITTER() view returns(address)
func (_CCTPAdapter *CCTPAdapterCallerSession) MESSAGETRANSMITTER() (common.Address, error) {
	return _CCTPAdapter.Contract.MESSAGETRANSMITTER(&_CCTPAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_CCTPAdapter *CCTPAdapterCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_CCTPAdapter *CCTPAdapterSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _CCTPAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_CCTPAdapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_CCTPAdapter *CCTPAdapterCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _CCTPAdapter.Contract.SUPERDESTINATIONEXECUTOR(&_CCTPAdapter.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_CCTPAdapter *CCTPAdapterCaller) SUPERDESTINATIONVALIDATOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_CCTPAdapter *CCTPAdapterSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _CCTPAdapter.Contract.SUPERDESTINATIONVALIDATOR(&_CCTPAdapter.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_CCTPAdapter *CCTPAdapterCallerSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _CCTPAdapter.Contract.SUPERDESTINATIONVALIDATOR(&_CCTPAdapter.CallOpts)
}

// TOKENMESSENGER is a free data retrieval call binding the contract method 0xb8b32ff7.
//
// Solidity: function TOKEN_MESSENGER() view returns(address)
func (_CCTPAdapter *CCTPAdapterCaller) TOKENMESSENGER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "TOKEN_MESSENGER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TOKENMESSENGER is a free data retrieval call binding the contract method 0xb8b32ff7.
//
// Solidity: function TOKEN_MESSENGER() view returns(address)
func (_CCTPAdapter *CCTPAdapterSession) TOKENMESSENGER() (common.Address, error) {
	return _CCTPAdapter.Contract.TOKENMESSENGER(&_CCTPAdapter.CallOpts)
}

// TOKENMESSENGER is a free data retrieval call binding the contract method 0xb8b32ff7.
//
// Solidity: function TOKEN_MESSENGER() view returns(address)
func (_CCTPAdapter *CCTPAdapterCallerSession) TOKENMESSENGER() (common.Address, error) {
	return _CCTPAdapter.Contract.TOKENMESSENGER(&_CCTPAdapter.CallOpts)
}

// USDC is a free data retrieval call binding the contract method 0x89a30271.
//
// Solidity: function USDC() view returns(address)
func (_CCTPAdapter *CCTPAdapterCaller) USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// USDC is a free data retrieval call binding the contract method 0x89a30271.
//
// Solidity: function USDC() view returns(address)
func (_CCTPAdapter *CCTPAdapterSession) USDC() (common.Address, error) {
	return _CCTPAdapter.Contract.USDC(&_CCTPAdapter.CallOpts)
}

// USDC is a free data retrieval call binding the contract method 0x89a30271.
//
// Solidity: function USDC() view returns(address)
func (_CCTPAdapter *CCTPAdapterCallerSession) USDC() (common.Address, error) {
	return _CCTPAdapter.Contract.USDC(&_CCTPAdapter.CallOpts)
}

// CheckDestinationTargets is a free data retrieval call binding the contract method 0xa048a4ab.
//
// Solidity: function checkDestinationTargets(bytes sigData) view returns(uint8 code)
func (_CCTPAdapter *CCTPAdapterCaller) CheckDestinationTargets(opts *bind.CallOpts, sigData []byte) (uint8, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "checkDestinationTargets", sigData)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// CheckDestinationTargets is a free data retrieval call binding the contract method 0xa048a4ab.
//
// Solidity: function checkDestinationTargets(bytes sigData) view returns(uint8 code)
func (_CCTPAdapter *CCTPAdapterSession) CheckDestinationTargets(sigData []byte) (uint8, error) {
	return _CCTPAdapter.Contract.CheckDestinationTargets(&_CCTPAdapter.CallOpts, sigData)
}

// CheckDestinationTargets is a free data retrieval call binding the contract method 0xa048a4ab.
//
// Solidity: function checkDestinationTargets(bytes sigData) view returns(uint8 code)
func (_CCTPAdapter *CCTPAdapterCallerSession) CheckDestinationTargets(sigData []byte) (uint8, error) {
	return _CCTPAdapter.Contract.CheckDestinationTargets(&_CCTPAdapter.CallOpts, sigData)
}

// DecodeHookPayload is a free data retrieval call binding the contract method 0xdd148464.
//
// Solidity: function decodeHookPayload(bytes message) view returns((bytes,bytes,address,address[],uint256[],bytes) p)
func (_CCTPAdapter *CCTPAdapterCaller) DecodeHookPayload(opts *bind.CallOpts, message []byte) (CCTPAdapterHookPayload, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "decodeHookPayload", message)

	if err != nil {
		return *new(CCTPAdapterHookPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(CCTPAdapterHookPayload)).(*CCTPAdapterHookPayload)

	return out0, err

}

// DecodeHookPayload is a free data retrieval call binding the contract method 0xdd148464.
//
// Solidity: function decodeHookPayload(bytes message) view returns((bytes,bytes,address,address[],uint256[],bytes) p)
func (_CCTPAdapter *CCTPAdapterSession) DecodeHookPayload(message []byte) (CCTPAdapterHookPayload, error) {
	return _CCTPAdapter.Contract.DecodeHookPayload(&_CCTPAdapter.CallOpts, message)
}

// DecodeHookPayload is a free data retrieval call binding the contract method 0xdd148464.
//
// Solidity: function decodeHookPayload(bytes message) view returns((bytes,bytes,address,address[],uint256[],bytes) p)
func (_CCTPAdapter *CCTPAdapterCallerSession) DecodeHookPayload(message []byte) (CCTPAdapterHookPayload, error) {
	return _CCTPAdapter.Contract.DecodeHookPayload(&_CCTPAdapter.CallOpts, message)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_CCTPAdapter *CCTPAdapterCaller) FailedTransfers(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _CCTPAdapter.contract.Call(opts, &out, "failedTransfers", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_CCTPAdapter *CCTPAdapterSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _CCTPAdapter.Contract.FailedTransfers(&_CCTPAdapter.CallOpts, account, token)
}

// FailedTransfers is a free data retrieval call binding the contract method 0x1b60f266.
//
// Solidity: function failedTransfers(address account, address token) view returns(uint256 amount)
func (_CCTPAdapter *CCTPAdapterCallerSession) FailedTransfers(account common.Address, token common.Address) (*big.Int, error) {
	return _CCTPAdapter.Contract.FailedTransfers(&_CCTPAdapter.CallOpts, account, token)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_CCTPAdapter *CCTPAdapterTransactor) ClaimFailedTransfer(opts *bind.TransactOpts, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _CCTPAdapter.contract.Transact(opts, "claimFailedTransfer", token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_CCTPAdapter *CCTPAdapterSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.ClaimFailedTransfer(&_CCTPAdapter.TransactOpts, token, amount)
}

// ClaimFailedTransfer is a paid mutator transaction binding the contract method 0x9ceb3049.
//
// Solidity: function claimFailedTransfer(address token, uint256 amount) returns()
func (_CCTPAdapter *CCTPAdapterTransactorSession) ClaimFailedTransfer(token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.ClaimFailedTransfer(&_CCTPAdapter.TransactOpts, token, amount)
}

// ReceiveAndExecute is a paid mutator transaction binding the contract method 0x7c5dc5a5.
//
// Solidity: function receiveAndExecute(bytes message, bytes attestation) returns()
func (_CCTPAdapter *CCTPAdapterTransactor) ReceiveAndExecute(opts *bind.TransactOpts, message []byte, attestation []byte) (*types.Transaction, error) {
	return _CCTPAdapter.contract.Transact(opts, "receiveAndExecute", message, attestation)
}

// ReceiveAndExecute is a paid mutator transaction binding the contract method 0x7c5dc5a5.
//
// Solidity: function receiveAndExecute(bytes message, bytes attestation) returns()
func (_CCTPAdapter *CCTPAdapterSession) ReceiveAndExecute(message []byte, attestation []byte) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.ReceiveAndExecute(&_CCTPAdapter.TransactOpts, message, attestation)
}

// ReceiveAndExecute is a paid mutator transaction binding the contract method 0x7c5dc5a5.
//
// Solidity: function receiveAndExecute(bytes message, bytes attestation) returns()
func (_CCTPAdapter *CCTPAdapterTransactorSession) ReceiveAndExecute(message []byte, attestation []byte) (*types.Transaction, error) {
	return _CCTPAdapter.Contract.ReceiveAndExecute(&_CCTPAdapter.TransactOpts, message, attestation)
}

// CCTPAdapterDestinationTargetMismatchIterator is returned from FilterDestinationTargetMismatch and is used to iterate over the raw logs and unpacked data for DestinationTargetMismatch events raised by the CCTPAdapter contract.
type CCTPAdapterDestinationTargetMismatchIterator struct {
	Event *CCTPAdapterDestinationTargetMismatch // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterDestinationTargetMismatchIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterDestinationTargetMismatch)
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
		it.Event = new(CCTPAdapterDestinationTargetMismatch)
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
func (it *CCTPAdapterDestinationTargetMismatchIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterDestinationTargetMismatchIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterDestinationTargetMismatch represents a DestinationTargetMismatch event raised by the CCTPAdapter contract.
type CCTPAdapterDestinationTargetMismatch struct {
	Account common.Address
	Code    uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterDestinationTargetMismatch is a free log retrieval operation binding the contract event 0x4d170f5ebe8095c90332d055eab1060e9521d04d9e47916e14febb0a7bf513d8.
//
// Solidity: event DestinationTargetMismatch(address indexed account, uint8 code)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterDestinationTargetMismatch(opts *bind.FilterOpts, account []common.Address) (*CCTPAdapterDestinationTargetMismatchIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "DestinationTargetMismatch", accountRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterDestinationTargetMismatchIterator{contract: _CCTPAdapter.contract, event: "DestinationTargetMismatch", logs: logs, sub: sub}, nil
}

// WatchDestinationTargetMismatch is a free log subscription operation binding the contract event 0x4d170f5ebe8095c90332d055eab1060e9521d04d9e47916e14febb0a7bf513d8.
//
// Solidity: event DestinationTargetMismatch(address indexed account, uint8 code)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchDestinationTargetMismatch(opts *bind.WatchOpts, sink chan<- *CCTPAdapterDestinationTargetMismatch, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "DestinationTargetMismatch", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterDestinationTargetMismatch)
				if err := _CCTPAdapter.contract.UnpackLog(event, "DestinationTargetMismatch", log); err != nil {
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
func (_CCTPAdapter *CCTPAdapterFilterer) ParseDestinationTargetMismatch(log types.Log) (*CCTPAdapterDestinationTargetMismatch, error) {
	event := new(CCTPAdapterDestinationTargetMismatch)
	if err := _CCTPAdapter.contract.UnpackLog(event, "DestinationTargetMismatch", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CCTPAdapterExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the CCTPAdapter contract.
type CCTPAdapterExecutionFailedIterator struct {
	Event *CCTPAdapterExecutionFailed // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterExecutionFailed)
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
		it.Event = new(CCTPAdapterExecutionFailed)
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
func (it *CCTPAdapterExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterExecutionFailed represents a ExecutionFailed event raised by the CCTPAdapter contract.
type CCTPAdapterExecutionFailed struct {
	Account  common.Address
	Selector [4]byte
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0x74c824cbfa28ea7b48d49ef06cc5c9d7aea14c6d09207f758d7c63996f60c98c.
//
// Solidity: event ExecutionFailed(address indexed account, bytes4 selector)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*CCTPAdapterExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterExecutionFailedIterator{contract: _CCTPAdapter.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0x74c824cbfa28ea7b48d49ef06cc5c9d7aea14c6d09207f758d7c63996f60c98c.
//
// Solidity: event ExecutionFailed(address indexed account, bytes4 selector)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *CCTPAdapterExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "ExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterExecutionFailed)
				if err := _CCTPAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
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
func (_CCTPAdapter *CCTPAdapterFilterer) ParseExecutionFailed(log types.Log) (*CCTPAdapterExecutionFailed, error) {
	event := new(CCTPAdapterExecutionFailed)
	if err := _CCTPAdapter.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CCTPAdapterFailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the CCTPAdapter contract.
type CCTPAdapterFailedTransferClaimedIterator struct {
	Event *CCTPAdapterFailedTransferClaimed // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterFailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterFailedTransferClaimed)
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
		it.Event = new(CCTPAdapterFailedTransferClaimed)
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
func (it *CCTPAdapterFailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterFailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterFailedTransferClaimed represents a FailedTransferClaimed event raised by the CCTPAdapter contract.
type CCTPAdapterFailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*CCTPAdapterFailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterFailedTransferClaimedIterator{contract: _CCTPAdapter.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *CCTPAdapterFailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterFailedTransferClaimed)
				if err := _CCTPAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
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
func (_CCTPAdapter *CCTPAdapterFilterer) ParseFailedTransferClaimed(log types.Log) (*CCTPAdapterFailedTransferClaimed, error) {
	event := new(CCTPAdapterFailedTransferClaimed)
	if err := _CCTPAdapter.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CCTPAdapterHookPayloadUndecodableIterator is returned from FilterHookPayloadUndecodable and is used to iterate over the raw logs and unpacked data for HookPayloadUndecodable events raised by the CCTPAdapter contract.
type CCTPAdapterHookPayloadUndecodableIterator struct {
	Event *CCTPAdapterHookPayloadUndecodable // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterHookPayloadUndecodableIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterHookPayloadUndecodable)
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
		it.Event = new(CCTPAdapterHookPayloadUndecodable)
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
func (it *CCTPAdapterHookPayloadUndecodableIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterHookPayloadUndecodableIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterHookPayloadUndecodable represents a HookPayloadUndecodable event raised by the CCTPAdapter contract.
type CCTPAdapterHookPayloadUndecodable struct {
	MessageSender common.Address
	Amount        *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterHookPayloadUndecodable is a free log retrieval operation binding the contract event 0x80d1c6e48e229e5648855ab0f19d3cbbae8c9579c44670e8b514b1573ffffbb7.
//
// Solidity: event HookPayloadUndecodable(address indexed messageSender, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterHookPayloadUndecodable(opts *bind.FilterOpts, messageSender []common.Address) (*CCTPAdapterHookPayloadUndecodableIterator, error) {

	var messageSenderRule []interface{}
	for _, messageSenderItem := range messageSender {
		messageSenderRule = append(messageSenderRule, messageSenderItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "HookPayloadUndecodable", messageSenderRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterHookPayloadUndecodableIterator{contract: _CCTPAdapter.contract, event: "HookPayloadUndecodable", logs: logs, sub: sub}, nil
}

// WatchHookPayloadUndecodable is a free log subscription operation binding the contract event 0x80d1c6e48e229e5648855ab0f19d3cbbae8c9579c44670e8b514b1573ffffbb7.
//
// Solidity: event HookPayloadUndecodable(address indexed messageSender, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchHookPayloadUndecodable(opts *bind.WatchOpts, sink chan<- *CCTPAdapterHookPayloadUndecodable, messageSender []common.Address) (event.Subscription, error) {

	var messageSenderRule []interface{}
	for _, messageSenderItem := range messageSender {
		messageSenderRule = append(messageSenderRule, messageSenderItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "HookPayloadUndecodable", messageSenderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterHookPayloadUndecodable)
				if err := _CCTPAdapter.contract.UnpackLog(event, "HookPayloadUndecodable", log); err != nil {
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

// ParseHookPayloadUndecodable is a log parse operation binding the contract event 0x80d1c6e48e229e5648855ab0f19d3cbbae8c9579c44670e8b514b1573ffffbb7.
//
// Solidity: event HookPayloadUndecodable(address indexed messageSender, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) ParseHookPayloadUndecodable(log types.Log) (*CCTPAdapterHookPayloadUndecodable, error) {
	event := new(CCTPAdapterHookPayloadUndecodable)
	if err := _CCTPAdapter.contract.UnpackLog(event, "HookPayloadUndecodable", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CCTPAdapterMisconfiguredMessageRelayedIterator is returned from FilterMisconfiguredMessageRelayed and is used to iterate over the raw logs and unpacked data for MisconfiguredMessageRelayed events raised by the CCTPAdapter contract.
type CCTPAdapterMisconfiguredMessageRelayedIterator struct {
	Event *CCTPAdapterMisconfiguredMessageRelayed // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterMisconfiguredMessageRelayedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterMisconfiguredMessageRelayed)
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
		it.Event = new(CCTPAdapterMisconfiguredMessageRelayed)
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
func (it *CCTPAdapterMisconfiguredMessageRelayedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterMisconfiguredMessageRelayedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterMisconfiguredMessageRelayed represents a MisconfiguredMessageRelayed event raised by the CCTPAdapter contract.
type CCTPAdapterMisconfiguredMessageRelayed struct {
	Kind          uint8
	MintRecipient [32]byte
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterMisconfiguredMessageRelayed is a free log retrieval operation binding the contract event 0xd53250053d51f76e9837441bb201665d419e0312b12ff10f9e770ee3d5f1e190.
//
// Solidity: event MisconfiguredMessageRelayed(uint8 indexed kind, bytes32 mintRecipient)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterMisconfiguredMessageRelayed(opts *bind.FilterOpts, kind []uint8) (*CCTPAdapterMisconfiguredMessageRelayedIterator, error) {

	var kindRule []interface{}
	for _, kindItem := range kind {
		kindRule = append(kindRule, kindItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "MisconfiguredMessageRelayed", kindRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterMisconfiguredMessageRelayedIterator{contract: _CCTPAdapter.contract, event: "MisconfiguredMessageRelayed", logs: logs, sub: sub}, nil
}

// WatchMisconfiguredMessageRelayed is a free log subscription operation binding the contract event 0xd53250053d51f76e9837441bb201665d419e0312b12ff10f9e770ee3d5f1e190.
//
// Solidity: event MisconfiguredMessageRelayed(uint8 indexed kind, bytes32 mintRecipient)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchMisconfiguredMessageRelayed(opts *bind.WatchOpts, sink chan<- *CCTPAdapterMisconfiguredMessageRelayed, kind []uint8) (event.Subscription, error) {

	var kindRule []interface{}
	for _, kindItem := range kind {
		kindRule = append(kindRule, kindItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "MisconfiguredMessageRelayed", kindRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterMisconfiguredMessageRelayed)
				if err := _CCTPAdapter.contract.UnpackLog(event, "MisconfiguredMessageRelayed", log); err != nil {
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

// ParseMisconfiguredMessageRelayed is a log parse operation binding the contract event 0xd53250053d51f76e9837441bb201665d419e0312b12ff10f9e770ee3d5f1e190.
//
// Solidity: event MisconfiguredMessageRelayed(uint8 indexed kind, bytes32 mintRecipient)
func (_CCTPAdapter *CCTPAdapterFilterer) ParseMisconfiguredMessageRelayed(log types.Log) (*CCTPAdapterMisconfiguredMessageRelayed, error) {
	event := new(CCTPAdapterMisconfiguredMessageRelayed)
	if err := _CCTPAdapter.contract.UnpackLog(event, "MisconfiguredMessageRelayed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CCTPAdapterNonUsdcMintEscrowedIterator is returned from FilterNonUsdcMintEscrowed and is used to iterate over the raw logs and unpacked data for NonUsdcMintEscrowed events raised by the CCTPAdapter contract.
type CCTPAdapterNonUsdcMintEscrowedIterator struct {
	Event *CCTPAdapterNonUsdcMintEscrowed // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterNonUsdcMintEscrowedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterNonUsdcMintEscrowed)
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
		it.Event = new(CCTPAdapterNonUsdcMintEscrowed)
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
func (it *CCTPAdapterNonUsdcMintEscrowedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterNonUsdcMintEscrowedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterNonUsdcMintEscrowed represents a NonUsdcMintEscrowed event raised by the CCTPAdapter contract.
type CCTPAdapterNonUsdcMintEscrowed struct {
	MessageSender common.Address
	Token         common.Address
	Amount        *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterNonUsdcMintEscrowed is a free log retrieval operation binding the contract event 0x47cea96184d36c40883fb12513894c01884bbabd91f61d94db36045e5a85fd86.
//
// Solidity: event NonUsdcMintEscrowed(address indexed messageSender, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterNonUsdcMintEscrowed(opts *bind.FilterOpts, messageSender []common.Address, token []common.Address) (*CCTPAdapterNonUsdcMintEscrowedIterator, error) {

	var messageSenderRule []interface{}
	for _, messageSenderItem := range messageSender {
		messageSenderRule = append(messageSenderRule, messageSenderItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "NonUsdcMintEscrowed", messageSenderRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterNonUsdcMintEscrowedIterator{contract: _CCTPAdapter.contract, event: "NonUsdcMintEscrowed", logs: logs, sub: sub}, nil
}

// WatchNonUsdcMintEscrowed is a free log subscription operation binding the contract event 0x47cea96184d36c40883fb12513894c01884bbabd91f61d94db36045e5a85fd86.
//
// Solidity: event NonUsdcMintEscrowed(address indexed messageSender, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchNonUsdcMintEscrowed(opts *bind.WatchOpts, sink chan<- *CCTPAdapterNonUsdcMintEscrowed, messageSender []common.Address, token []common.Address) (event.Subscription, error) {

	var messageSenderRule []interface{}
	for _, messageSenderItem := range messageSender {
		messageSenderRule = append(messageSenderRule, messageSenderItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "NonUsdcMintEscrowed", messageSenderRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterNonUsdcMintEscrowed)
				if err := _CCTPAdapter.contract.UnpackLog(event, "NonUsdcMintEscrowed", log); err != nil {
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

// ParseNonUsdcMintEscrowed is a log parse operation binding the contract event 0x47cea96184d36c40883fb12513894c01884bbabd91f61d94db36045e5a85fd86.
//
// Solidity: event NonUsdcMintEscrowed(address indexed messageSender, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) ParseNonUsdcMintEscrowed(log types.Log) (*CCTPAdapterNonUsdcMintEscrowed, error) {
	event := new(CCTPAdapterNonUsdcMintEscrowed)
	if err := _CCTPAdapter.contract.UnpackLog(event, "NonUsdcMintEscrowed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CCTPAdapterTransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the CCTPAdapter contract.
type CCTPAdapterTransferFailedIterator struct {
	Event *CCTPAdapterTransferFailed // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterTransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterTransferFailed)
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
		it.Event = new(CCTPAdapterTransferFailed)
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
func (it *CCTPAdapterTransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterTransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterTransferFailed represents a TransferFailed event raised by the CCTPAdapter contract.
type CCTPAdapterTransferFailed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterTransferFailed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*CCTPAdapterTransferFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterTransferFailedIterator{contract: _CCTPAdapter.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xbf182be802245e8ed88e4b8d3e4344c0863dd2a70334f089fd07265389306fcf.
//
// Solidity: event TransferFailed(address indexed account, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *CCTPAdapterTransferFailed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "TransferFailed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterTransferFailed)
				if err := _CCTPAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
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
func (_CCTPAdapter *CCTPAdapterFilterer) ParseTransferFailed(log types.Log) (*CCTPAdapterTransferFailed, error) {
	event := new(CCTPAdapterTransferFailed)
	if err := _CCTPAdapter.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// CCTPAdapterTransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the CCTPAdapter contract.
type CCTPAdapterTransferSucceededIterator struct {
	Event *CCTPAdapterTransferSucceeded // Event containing the contract specifics and raw log

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
func (it *CCTPAdapterTransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(CCTPAdapterTransferSucceeded)
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
		it.Event = new(CCTPAdapterTransferSucceeded)
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
func (it *CCTPAdapterTransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *CCTPAdapterTransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// CCTPAdapterTransferSucceeded represents a TransferSucceeded event raised by the CCTPAdapter contract.
type CCTPAdapterTransferSucceeded struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) FilterTransferSucceeded(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*CCTPAdapterTransferSucceededIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.FilterLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &CCTPAdapterTransferSucceededIterator{contract: _CCTPAdapter.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_CCTPAdapter *CCTPAdapterFilterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *CCTPAdapterTransferSucceeded, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _CCTPAdapter.contract.WatchLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(CCTPAdapterTransferSucceeded)
				if err := _CCTPAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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
func (_CCTPAdapter *CCTPAdapterFilterer) ParseTransferSucceeded(log types.Log) (*CCTPAdapterTransferSucceeded, error) {
	event := new(CCTPAdapterTransferSucceeded)
	if err := _CCTPAdapter.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
