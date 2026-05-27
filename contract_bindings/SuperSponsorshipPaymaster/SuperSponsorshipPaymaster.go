// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperSponsorshipPaymaster

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

// ISuperSponsorshipPaymasterStrategyBudget is an auto generated low-level Go binding around an user-defined struct.
type ISuperSponsorshipPaymasterStrategyBudget struct {
	Balance         *big.Int
	TotalDebited    *big.Int
	MaxSingleOpCost *big.Int
	Paused          bool
}

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

// SuperSponsorshipPaymasterMetaData contains all meta data concerning the SuperSponsorshipPaymaster contract.
var SuperSponsorshipPaymasterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"entryPoint_\",\"type\":\"address\",\"internalType\":\"contractIEntryPoint\"},{\"name\":\"admin_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"payable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"DEFAULT_ADMIN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FUNDING_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MANAGER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAX_POST_OP_GAS_OVERHEAD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MIN_POST_OP_OVERHEAD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"creditStrategy\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"emergencyWithdrawFromEntryPoint\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"entryPoint\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIEntryPoint\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"fundStrategy\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"getDeposit\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRoleAdmin\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStrategyBudget\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structISuperSponsorshipPaymaster.StrategyBudget\",\"components\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"totalDebited\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"maxSingleOpCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"globalPaused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"grantRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"hasRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pauseStrategy\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"postOp\",\"inputs\":[{\"name\":\"mode\",\"type\":\"uint8\",\"internalType\":\"enumIPaymaster.PostOpMode\"},{\"name\":\"context\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"actualGasCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"actualUserOpFeePerGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"postOpGasOverhead\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"reconcile\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"callerConfirmation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"revokeRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setGlobalPause\",\"inputs\":[{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setMaxSingleOpCost\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"maxCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setPostOpGasOverhead\",\"inputs\":[{\"name\":\"overhead\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"supportsInterface\",\"inputs\":[{\"name\":\"interfaceId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sweepETH\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"totalAllocated\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"unallocatedBalance\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"unpauseStrategy\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validatePaymasterUserOp\",\"inputs\":[{\"name\":\"userOp\",\"type\":\"tuple\",\"internalType\":\"structPackedUserOperation\",\"components\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nonce\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"accountGasLimits\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"preVerificationGas\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasFees\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"paymasterAndData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"userOpHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"maxCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"context\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"validationData\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawStrategyFunds\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"ETHSwept\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EmergencyWithdrawn\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"GlobalPauseSet\",\"inputs\":[{\"name\":\"paused\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MaxSingleOpCostSet\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"maxCost\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PostOpGasOverheadSet\",\"inputs\":[{\"name\":\"overhead\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Reconciled\",\"inputs\":[{\"name\":\"drift\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleAdminChanged\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"previousAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleGranted\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleRevoked\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyCredited\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyDebited\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyFunded\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyPaused\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyUnpaused\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyWithdrawn\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"AccessControlBadConfirmation\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AccessControlUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"neededRole\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EXCEEDS_MAX_POST_OP_OVERHEAD\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EXCEEDS_SINGLE_OP_CAP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"GLOBAL_PAUSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_ENTRYPOINT_DEPOSIT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_STRATEGY_BUDGET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_UNALLOCATED_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"POST_OP_OVERHEAD_BELOW_MINIMUM\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGY_PAUSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"WITHDRAW_EXCEEDS_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// SuperSponsorshipPaymasterABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperSponsorshipPaymasterMetaData.ABI instead.
var SuperSponsorshipPaymasterABI = SuperSponsorshipPaymasterMetaData.ABI

// SuperSponsorshipPaymaster is an auto generated Go binding around an Ethereum contract.
type SuperSponsorshipPaymaster struct {
	SuperSponsorshipPaymasterCaller     // Read-only binding to the contract
	SuperSponsorshipPaymasterTransactor // Write-only binding to the contract
	SuperSponsorshipPaymasterFilterer   // Log filterer for contract events
}

// SuperSponsorshipPaymasterCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperSponsorshipPaymasterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSponsorshipPaymasterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperSponsorshipPaymasterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSponsorshipPaymasterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperSponsorshipPaymasterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSponsorshipPaymasterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperSponsorshipPaymasterSession struct {
	Contract     *SuperSponsorshipPaymaster // Generic contract binding to set the session for
	CallOpts     bind.CallOpts              // Call options to use throughout this session
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// SuperSponsorshipPaymasterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperSponsorshipPaymasterCallerSession struct {
	Contract *SuperSponsorshipPaymasterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                    // Call options to use throughout this session
}

// SuperSponsorshipPaymasterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperSponsorshipPaymasterTransactorSession struct {
	Contract     *SuperSponsorshipPaymasterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// SuperSponsorshipPaymasterRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperSponsorshipPaymasterRaw struct {
	Contract *SuperSponsorshipPaymaster // Generic contract binding to access the raw methods on
}

// SuperSponsorshipPaymasterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperSponsorshipPaymasterCallerRaw struct {
	Contract *SuperSponsorshipPaymasterCaller // Generic read-only contract binding to access the raw methods on
}

// SuperSponsorshipPaymasterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperSponsorshipPaymasterTransactorRaw struct {
	Contract *SuperSponsorshipPaymasterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperSponsorshipPaymaster creates a new instance of SuperSponsorshipPaymaster, bound to a specific deployed contract.
func NewSuperSponsorshipPaymaster(address common.Address, backend bind.ContractBackend) (*SuperSponsorshipPaymaster, error) {
	contract, err := bindSuperSponsorshipPaymaster(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymaster{SuperSponsorshipPaymasterCaller: SuperSponsorshipPaymasterCaller{contract: contract}, SuperSponsorshipPaymasterTransactor: SuperSponsorshipPaymasterTransactor{contract: contract}, SuperSponsorshipPaymasterFilterer: SuperSponsorshipPaymasterFilterer{contract: contract}}, nil
}

// NewSuperSponsorshipPaymasterCaller creates a new read-only instance of SuperSponsorshipPaymaster, bound to a specific deployed contract.
func NewSuperSponsorshipPaymasterCaller(address common.Address, caller bind.ContractCaller) (*SuperSponsorshipPaymasterCaller, error) {
	contract, err := bindSuperSponsorshipPaymaster(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterCaller{contract: contract}, nil
}

// NewSuperSponsorshipPaymasterTransactor creates a new write-only instance of SuperSponsorshipPaymaster, bound to a specific deployed contract.
func NewSuperSponsorshipPaymasterTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperSponsorshipPaymasterTransactor, error) {
	contract, err := bindSuperSponsorshipPaymaster(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterTransactor{contract: contract}, nil
}

// NewSuperSponsorshipPaymasterFilterer creates a new log filterer instance of SuperSponsorshipPaymaster, bound to a specific deployed contract.
func NewSuperSponsorshipPaymasterFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperSponsorshipPaymasterFilterer, error) {
	contract, err := bindSuperSponsorshipPaymaster(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterFilterer{contract: contract}, nil
}

// bindSuperSponsorshipPaymaster binds a generic wrapper to an already deployed contract.
func bindSuperSponsorshipPaymaster(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperSponsorshipPaymasterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSponsorshipPaymaster.Contract.SuperSponsorshipPaymasterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SuperSponsorshipPaymasterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SuperSponsorshipPaymasterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSponsorshipPaymaster.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.contract.Transact(opts, method, params...)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) DEFAULTADMINROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "DEFAULT_ADMIN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.DEFAULTADMINROLE(&_SuperSponsorshipPaymaster.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.DEFAULTADMINROLE(&_SuperSponsorshipPaymaster.CallOpts)
}

// FUNDINGROLE is a free data retrieval call binding the contract method 0xd7bd51f5.
//
// Solidity: function FUNDING_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) FUNDINGROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "FUNDING_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// FUNDINGROLE is a free data retrieval call binding the contract method 0xd7bd51f5.
//
// Solidity: function FUNDING_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) FUNDINGROLE() ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.FUNDINGROLE(&_SuperSponsorshipPaymaster.CallOpts)
}

// FUNDINGROLE is a free data retrieval call binding the contract method 0xd7bd51f5.
//
// Solidity: function FUNDING_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) FUNDINGROLE() ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.FUNDINGROLE(&_SuperSponsorshipPaymaster.CallOpts)
}

// MANAGERROLE is a free data retrieval call binding the contract method 0xec87621c.
//
// Solidity: function MANAGER_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) MANAGERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "MANAGER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// MANAGERROLE is a free data retrieval call binding the contract method 0xec87621c.
//
// Solidity: function MANAGER_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) MANAGERROLE() ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.MANAGERROLE(&_SuperSponsorshipPaymaster.CallOpts)
}

// MANAGERROLE is a free data retrieval call binding the contract method 0xec87621c.
//
// Solidity: function MANAGER_ROLE() view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) MANAGERROLE() ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.MANAGERROLE(&_SuperSponsorshipPaymaster.CallOpts)
}

// MAXPOSTOPGASOVERHEAD is a free data retrieval call binding the contract method 0x0d27a3bc.
//
// Solidity: function MAX_POST_OP_GAS_OVERHEAD() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) MAXPOSTOPGASOVERHEAD(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "MAX_POST_OP_GAS_OVERHEAD")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MAXPOSTOPGASOVERHEAD is a free data retrieval call binding the contract method 0x0d27a3bc.
//
// Solidity: function MAX_POST_OP_GAS_OVERHEAD() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) MAXPOSTOPGASOVERHEAD() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.MAXPOSTOPGASOVERHEAD(&_SuperSponsorshipPaymaster.CallOpts)
}

// MAXPOSTOPGASOVERHEAD is a free data retrieval call binding the contract method 0x0d27a3bc.
//
// Solidity: function MAX_POST_OP_GAS_OVERHEAD() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) MAXPOSTOPGASOVERHEAD() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.MAXPOSTOPGASOVERHEAD(&_SuperSponsorshipPaymaster.CallOpts)
}

// MINPOSTOPOVERHEAD is a free data retrieval call binding the contract method 0x0f877344.
//
// Solidity: function MIN_POST_OP_OVERHEAD() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) MINPOSTOPOVERHEAD(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "MIN_POST_OP_OVERHEAD")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MINPOSTOPOVERHEAD is a free data retrieval call binding the contract method 0x0f877344.
//
// Solidity: function MIN_POST_OP_OVERHEAD() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) MINPOSTOPOVERHEAD() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.MINPOSTOPOVERHEAD(&_SuperSponsorshipPaymaster.CallOpts)
}

// MINPOSTOPOVERHEAD is a free data retrieval call binding the contract method 0x0f877344.
//
// Solidity: function MIN_POST_OP_OVERHEAD() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) MINPOSTOPOVERHEAD() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.MINPOSTOPOVERHEAD(&_SuperSponsorshipPaymaster.CallOpts)
}

// EntryPoint is a free data retrieval call binding the contract method 0xb0d691fe.
//
// Solidity: function entryPoint() view returns(address)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) EntryPoint(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "entryPoint")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// EntryPoint is a free data retrieval call binding the contract method 0xb0d691fe.
//
// Solidity: function entryPoint() view returns(address)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) EntryPoint() (common.Address, error) {
	return _SuperSponsorshipPaymaster.Contract.EntryPoint(&_SuperSponsorshipPaymaster.CallOpts)
}

// EntryPoint is a free data retrieval call binding the contract method 0xb0d691fe.
//
// Solidity: function entryPoint() view returns(address)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) EntryPoint() (common.Address, error) {
	return _SuperSponsorshipPaymaster.Contract.EntryPoint(&_SuperSponsorshipPaymaster.CallOpts)
}

// GetDeposit is a free data retrieval call binding the contract method 0xc399ec88.
//
// Solidity: function getDeposit() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) GetDeposit(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "getDeposit")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetDeposit is a free data retrieval call binding the contract method 0xc399ec88.
//
// Solidity: function getDeposit() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) GetDeposit() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.GetDeposit(&_SuperSponsorshipPaymaster.CallOpts)
}

// GetDeposit is a free data retrieval call binding the contract method 0xc399ec88.
//
// Solidity: function getDeposit() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) GetDeposit() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.GetDeposit(&_SuperSponsorshipPaymaster.CallOpts)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) GetRoleAdmin(opts *bind.CallOpts, role [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "getRoleAdmin", role)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.GetRoleAdmin(&_SuperSponsorshipPaymaster.CallOpts, role)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperSponsorshipPaymaster.Contract.GetRoleAdmin(&_SuperSponsorshipPaymaster.CallOpts, role)
}

// GetStrategyBudget is a free data retrieval call binding the contract method 0x2893ed34.
//
// Solidity: function getStrategyBudget(address strategy) view returns((uint256,uint256,uint256,bool))
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) GetStrategyBudget(opts *bind.CallOpts, strategy common.Address) (ISuperSponsorshipPaymasterStrategyBudget, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "getStrategyBudget", strategy)

	if err != nil {
		return *new(ISuperSponsorshipPaymasterStrategyBudget), err
	}

	out0 := *abi.ConvertType(out[0], new(ISuperSponsorshipPaymasterStrategyBudget)).(*ISuperSponsorshipPaymasterStrategyBudget)

	return out0, err

}

// GetStrategyBudget is a free data retrieval call binding the contract method 0x2893ed34.
//
// Solidity: function getStrategyBudget(address strategy) view returns((uint256,uint256,uint256,bool))
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) GetStrategyBudget(strategy common.Address) (ISuperSponsorshipPaymasterStrategyBudget, error) {
	return _SuperSponsorshipPaymaster.Contract.GetStrategyBudget(&_SuperSponsorshipPaymaster.CallOpts, strategy)
}

// GetStrategyBudget is a free data retrieval call binding the contract method 0x2893ed34.
//
// Solidity: function getStrategyBudget(address strategy) view returns((uint256,uint256,uint256,bool))
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) GetStrategyBudget(strategy common.Address) (ISuperSponsorshipPaymasterStrategyBudget, error) {
	return _SuperSponsorshipPaymaster.Contract.GetStrategyBudget(&_SuperSponsorshipPaymaster.CallOpts, strategy)
}

// GlobalPaused is a free data retrieval call binding the contract method 0x61a552dc.
//
// Solidity: function globalPaused() view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) GlobalPaused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "globalPaused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// GlobalPaused is a free data retrieval call binding the contract method 0x61a552dc.
//
// Solidity: function globalPaused() view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) GlobalPaused() (bool, error) {
	return _SuperSponsorshipPaymaster.Contract.GlobalPaused(&_SuperSponsorshipPaymaster.CallOpts)
}

// GlobalPaused is a free data retrieval call binding the contract method 0x61a552dc.
//
// Solidity: function globalPaused() view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) GlobalPaused() (bool, error) {
	return _SuperSponsorshipPaymaster.Contract.GlobalPaused(&_SuperSponsorshipPaymaster.CallOpts)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) HasRole(opts *bind.CallOpts, role [32]byte, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "hasRole", role, account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperSponsorshipPaymaster.Contract.HasRole(&_SuperSponsorshipPaymaster.CallOpts, role, account)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperSponsorshipPaymaster.Contract.HasRole(&_SuperSponsorshipPaymaster.CallOpts, role, account)
}

// PostOpGasOverhead is a free data retrieval call binding the contract method 0x6ec5f681.
//
// Solidity: function postOpGasOverhead() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) PostOpGasOverhead(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "postOpGasOverhead")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PostOpGasOverhead is a free data retrieval call binding the contract method 0x6ec5f681.
//
// Solidity: function postOpGasOverhead() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) PostOpGasOverhead() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.PostOpGasOverhead(&_SuperSponsorshipPaymaster.CallOpts)
}

// PostOpGasOverhead is a free data retrieval call binding the contract method 0x6ec5f681.
//
// Solidity: function postOpGasOverhead() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) PostOpGasOverhead() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.PostOpGasOverhead(&_SuperSponsorshipPaymaster.CallOpts)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperSponsorshipPaymaster.Contract.SupportsInterface(&_SuperSponsorshipPaymaster.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperSponsorshipPaymaster.Contract.SupportsInterface(&_SuperSponsorshipPaymaster.CallOpts, interfaceId)
}

// TotalAllocated is a free data retrieval call binding the contract method 0x45f7f249.
//
// Solidity: function totalAllocated() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) TotalAllocated(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "totalAllocated")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TotalAllocated is a free data retrieval call binding the contract method 0x45f7f249.
//
// Solidity: function totalAllocated() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) TotalAllocated() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.TotalAllocated(&_SuperSponsorshipPaymaster.CallOpts)
}

// TotalAllocated is a free data retrieval call binding the contract method 0x45f7f249.
//
// Solidity: function totalAllocated() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) TotalAllocated() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.TotalAllocated(&_SuperSponsorshipPaymaster.CallOpts)
}

// UnallocatedBalance is a free data retrieval call binding the contract method 0x9583612e.
//
// Solidity: function unallocatedBalance() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCaller) UnallocatedBalance(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperSponsorshipPaymaster.contract.Call(opts, &out, "unallocatedBalance")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// UnallocatedBalance is a free data retrieval call binding the contract method 0x9583612e.
//
// Solidity: function unallocatedBalance() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) UnallocatedBalance() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.UnallocatedBalance(&_SuperSponsorshipPaymaster.CallOpts)
}

// UnallocatedBalance is a free data retrieval call binding the contract method 0x9583612e.
//
// Solidity: function unallocatedBalance() view returns(uint256)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterCallerSession) UnallocatedBalance() (*big.Int, error) {
	return _SuperSponsorshipPaymaster.Contract.UnallocatedBalance(&_SuperSponsorshipPaymaster.CallOpts)
}

// CreditStrategy is a paid mutator transaction binding the contract method 0xda161445.
//
// Solidity: function creditStrategy(address strategy, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) CreditStrategy(opts *bind.TransactOpts, strategy common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "creditStrategy", strategy, amount)
}

// CreditStrategy is a paid mutator transaction binding the contract method 0xda161445.
//
// Solidity: function creditStrategy(address strategy, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) CreditStrategy(strategy common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.CreditStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy, amount)
}

// CreditStrategy is a paid mutator transaction binding the contract method 0xda161445.
//
// Solidity: function creditStrategy(address strategy, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) CreditStrategy(strategy common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.CreditStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy, amount)
}

// EmergencyWithdrawFromEntryPoint is a paid mutator transaction binding the contract method 0x17087e99.
//
// Solidity: function emergencyWithdrawFromEntryPoint(address to, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) EmergencyWithdrawFromEntryPoint(opts *bind.TransactOpts, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "emergencyWithdrawFromEntryPoint", to, amount)
}

// EmergencyWithdrawFromEntryPoint is a paid mutator transaction binding the contract method 0x17087e99.
//
// Solidity: function emergencyWithdrawFromEntryPoint(address to, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) EmergencyWithdrawFromEntryPoint(to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.EmergencyWithdrawFromEntryPoint(&_SuperSponsorshipPaymaster.TransactOpts, to, amount)
}

// EmergencyWithdrawFromEntryPoint is a paid mutator transaction binding the contract method 0x17087e99.
//
// Solidity: function emergencyWithdrawFromEntryPoint(address to, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) EmergencyWithdrawFromEntryPoint(to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.EmergencyWithdrawFromEntryPoint(&_SuperSponsorshipPaymaster.TransactOpts, to, amount)
}

// FundStrategy is a paid mutator transaction binding the contract method 0x04d8e660.
//
// Solidity: function fundStrategy(address strategy) payable returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) FundStrategy(opts *bind.TransactOpts, strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "fundStrategy", strategy)
}

// FundStrategy is a paid mutator transaction binding the contract method 0x04d8e660.
//
// Solidity: function fundStrategy(address strategy) payable returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) FundStrategy(strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.FundStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy)
}

// FundStrategy is a paid mutator transaction binding the contract method 0x04d8e660.
//
// Solidity: function fundStrategy(address strategy) payable returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) FundStrategy(strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.FundStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) GrantRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "grantRole", role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.GrantRole(&_SuperSponsorshipPaymaster.TransactOpts, role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.GrantRole(&_SuperSponsorshipPaymaster.TransactOpts, role, account)
}

// PauseStrategy is a paid mutator transaction binding the contract method 0xd3f6b598.
//
// Solidity: function pauseStrategy(address strategy) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) PauseStrategy(opts *bind.TransactOpts, strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "pauseStrategy", strategy)
}

// PauseStrategy is a paid mutator transaction binding the contract method 0xd3f6b598.
//
// Solidity: function pauseStrategy(address strategy) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) PauseStrategy(strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.PauseStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy)
}

// PauseStrategy is a paid mutator transaction binding the contract method 0xd3f6b598.
//
// Solidity: function pauseStrategy(address strategy) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) PauseStrategy(strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.PauseStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy)
}

// PostOp is a paid mutator transaction binding the contract method 0x7c627b21.
//
// Solidity: function postOp(uint8 mode, bytes context, uint256 actualGasCost, uint256 actualUserOpFeePerGas) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) PostOp(opts *bind.TransactOpts, mode uint8, context []byte, actualGasCost *big.Int, actualUserOpFeePerGas *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "postOp", mode, context, actualGasCost, actualUserOpFeePerGas)
}

// PostOp is a paid mutator transaction binding the contract method 0x7c627b21.
//
// Solidity: function postOp(uint8 mode, bytes context, uint256 actualGasCost, uint256 actualUserOpFeePerGas) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) PostOp(mode uint8, context []byte, actualGasCost *big.Int, actualUserOpFeePerGas *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.PostOp(&_SuperSponsorshipPaymaster.TransactOpts, mode, context, actualGasCost, actualUserOpFeePerGas)
}

// PostOp is a paid mutator transaction binding the contract method 0x7c627b21.
//
// Solidity: function postOp(uint8 mode, bytes context, uint256 actualGasCost, uint256 actualUserOpFeePerGas) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) PostOp(mode uint8, context []byte, actualGasCost *big.Int, actualUserOpFeePerGas *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.PostOp(&_SuperSponsorshipPaymaster.TransactOpts, mode, context, actualGasCost, actualUserOpFeePerGas)
}

// Reconcile is a paid mutator transaction binding the contract method 0x8f0d7e35.
//
// Solidity: function reconcile() returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) Reconcile(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "reconcile")
}

// Reconcile is a paid mutator transaction binding the contract method 0x8f0d7e35.
//
// Solidity: function reconcile() returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) Reconcile() (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.Reconcile(&_SuperSponsorshipPaymaster.TransactOpts)
}

// Reconcile is a paid mutator transaction binding the contract method 0x8f0d7e35.
//
// Solidity: function reconcile() returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) Reconcile() (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.Reconcile(&_SuperSponsorshipPaymaster.TransactOpts)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) RenounceRole(opts *bind.TransactOpts, role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "renounceRole", role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.RenounceRole(&_SuperSponsorshipPaymaster.TransactOpts, role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.RenounceRole(&_SuperSponsorshipPaymaster.TransactOpts, role, callerConfirmation)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) RevokeRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "revokeRole", role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.RevokeRole(&_SuperSponsorshipPaymaster.TransactOpts, role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.RevokeRole(&_SuperSponsorshipPaymaster.TransactOpts, role, account)
}

// SetGlobalPause is a paid mutator transaction binding the contract method 0x69a6b3db.
//
// Solidity: function setGlobalPause(bool paused) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) SetGlobalPause(opts *bind.TransactOpts, paused bool) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "setGlobalPause", paused)
}

// SetGlobalPause is a paid mutator transaction binding the contract method 0x69a6b3db.
//
// Solidity: function setGlobalPause(bool paused) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) SetGlobalPause(paused bool) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SetGlobalPause(&_SuperSponsorshipPaymaster.TransactOpts, paused)
}

// SetGlobalPause is a paid mutator transaction binding the contract method 0x69a6b3db.
//
// Solidity: function setGlobalPause(bool paused) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) SetGlobalPause(paused bool) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SetGlobalPause(&_SuperSponsorshipPaymaster.TransactOpts, paused)
}

// SetMaxSingleOpCost is a paid mutator transaction binding the contract method 0x3a00cf58.
//
// Solidity: function setMaxSingleOpCost(address strategy, uint256 maxCost) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) SetMaxSingleOpCost(opts *bind.TransactOpts, strategy common.Address, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "setMaxSingleOpCost", strategy, maxCost)
}

// SetMaxSingleOpCost is a paid mutator transaction binding the contract method 0x3a00cf58.
//
// Solidity: function setMaxSingleOpCost(address strategy, uint256 maxCost) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) SetMaxSingleOpCost(strategy common.Address, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SetMaxSingleOpCost(&_SuperSponsorshipPaymaster.TransactOpts, strategy, maxCost)
}

// SetMaxSingleOpCost is a paid mutator transaction binding the contract method 0x3a00cf58.
//
// Solidity: function setMaxSingleOpCost(address strategy, uint256 maxCost) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) SetMaxSingleOpCost(strategy common.Address, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SetMaxSingleOpCost(&_SuperSponsorshipPaymaster.TransactOpts, strategy, maxCost)
}

// SetPostOpGasOverhead is a paid mutator transaction binding the contract method 0xfb79777d.
//
// Solidity: function setPostOpGasOverhead(uint256 overhead) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) SetPostOpGasOverhead(opts *bind.TransactOpts, overhead *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "setPostOpGasOverhead", overhead)
}

// SetPostOpGasOverhead is a paid mutator transaction binding the contract method 0xfb79777d.
//
// Solidity: function setPostOpGasOverhead(uint256 overhead) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) SetPostOpGasOverhead(overhead *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SetPostOpGasOverhead(&_SuperSponsorshipPaymaster.TransactOpts, overhead)
}

// SetPostOpGasOverhead is a paid mutator transaction binding the contract method 0xfb79777d.
//
// Solidity: function setPostOpGasOverhead(uint256 overhead) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) SetPostOpGasOverhead(overhead *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SetPostOpGasOverhead(&_SuperSponsorshipPaymaster.TransactOpts, overhead)
}

// SweepETH is a paid mutator transaction binding the contract method 0x1163b2b0.
//
// Solidity: function sweepETH(address to) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) SweepETH(opts *bind.TransactOpts, to common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "sweepETH", to)
}

// SweepETH is a paid mutator transaction binding the contract method 0x1163b2b0.
//
// Solidity: function sweepETH(address to) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) SweepETH(to common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SweepETH(&_SuperSponsorshipPaymaster.TransactOpts, to)
}

// SweepETH is a paid mutator transaction binding the contract method 0x1163b2b0.
//
// Solidity: function sweepETH(address to) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) SweepETH(to common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.SweepETH(&_SuperSponsorshipPaymaster.TransactOpts, to)
}

// UnpauseStrategy is a paid mutator transaction binding the contract method 0x0ff323a3.
//
// Solidity: function unpauseStrategy(address strategy) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) UnpauseStrategy(opts *bind.TransactOpts, strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "unpauseStrategy", strategy)
}

// UnpauseStrategy is a paid mutator transaction binding the contract method 0x0ff323a3.
//
// Solidity: function unpauseStrategy(address strategy) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) UnpauseStrategy(strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.UnpauseStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy)
}

// UnpauseStrategy is a paid mutator transaction binding the contract method 0x0ff323a3.
//
// Solidity: function unpauseStrategy(address strategy) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) UnpauseStrategy(strategy common.Address) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.UnpauseStrategy(&_SuperSponsorshipPaymaster.TransactOpts, strategy)
}

// ValidatePaymasterUserOp is a paid mutator transaction binding the contract method 0x52b7512c.
//
// Solidity: function validatePaymasterUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash, uint256 maxCost) returns(bytes context, uint256 validationData)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) ValidatePaymasterUserOp(opts *bind.TransactOpts, userOp PackedUserOperation, userOpHash [32]byte, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "validatePaymasterUserOp", userOp, userOpHash, maxCost)
}

// ValidatePaymasterUserOp is a paid mutator transaction binding the contract method 0x52b7512c.
//
// Solidity: function validatePaymasterUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash, uint256 maxCost) returns(bytes context, uint256 validationData)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) ValidatePaymasterUserOp(userOp PackedUserOperation, userOpHash [32]byte, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.ValidatePaymasterUserOp(&_SuperSponsorshipPaymaster.TransactOpts, userOp, userOpHash, maxCost)
}

// ValidatePaymasterUserOp is a paid mutator transaction binding the contract method 0x52b7512c.
//
// Solidity: function validatePaymasterUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes) userOp, bytes32 userOpHash, uint256 maxCost) returns(bytes context, uint256 validationData)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) ValidatePaymasterUserOp(userOp PackedUserOperation, userOpHash [32]byte, maxCost *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.ValidatePaymasterUserOp(&_SuperSponsorshipPaymaster.TransactOpts, userOp, userOpHash, maxCost)
}

// WithdrawStrategyFunds is a paid mutator transaction binding the contract method 0xf3dd646c.
//
// Solidity: function withdrawStrategyFunds(address strategy, address to, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) WithdrawStrategyFunds(opts *bind.TransactOpts, strategy common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.Transact(opts, "withdrawStrategyFunds", strategy, to, amount)
}

// WithdrawStrategyFunds is a paid mutator transaction binding the contract method 0xf3dd646c.
//
// Solidity: function withdrawStrategyFunds(address strategy, address to, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) WithdrawStrategyFunds(strategy common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.WithdrawStrategyFunds(&_SuperSponsorshipPaymaster.TransactOpts, strategy, to, amount)
}

// WithdrawStrategyFunds is a paid mutator transaction binding the contract method 0xf3dd646c.
//
// Solidity: function withdrawStrategyFunds(address strategy, address to, uint256 amount) returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) WithdrawStrategyFunds(strategy common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.WithdrawStrategyFunds(&_SuperSponsorshipPaymaster.TransactOpts, strategy, to, amount)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterSession) Receive() (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.Receive(&_SuperSponsorshipPaymaster.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterTransactorSession) Receive() (*types.Transaction, error) {
	return _SuperSponsorshipPaymaster.Contract.Receive(&_SuperSponsorshipPaymaster.TransactOpts)
}

// SuperSponsorshipPaymasterETHSweptIterator is returned from FilterETHSwept and is used to iterate over the raw logs and unpacked data for ETHSwept events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterETHSweptIterator struct {
	Event *SuperSponsorshipPaymasterETHSwept // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterETHSweptIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterETHSwept)
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
		it.Event = new(SuperSponsorshipPaymasterETHSwept)
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
func (it *SuperSponsorshipPaymasterETHSweptIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterETHSweptIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterETHSwept represents a ETHSwept event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterETHSwept struct {
	To     common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterETHSwept is a free log retrieval operation binding the contract event 0xab31ddb82a9ca2de51c9befe9da7c6e815e12eac49ae58b8d9cb6b7a181cbc71.
//
// Solidity: event ETHSwept(address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterETHSwept(opts *bind.FilterOpts, to []common.Address) (*SuperSponsorshipPaymasterETHSweptIterator, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "ETHSwept", toRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterETHSweptIterator{contract: _SuperSponsorshipPaymaster.contract, event: "ETHSwept", logs: logs, sub: sub}, nil
}

// WatchETHSwept is a free log subscription operation binding the contract event 0xab31ddb82a9ca2de51c9befe9da7c6e815e12eac49ae58b8d9cb6b7a181cbc71.
//
// Solidity: event ETHSwept(address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchETHSwept(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterETHSwept, to []common.Address) (event.Subscription, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "ETHSwept", toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterETHSwept)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "ETHSwept", log); err != nil {
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

// ParseETHSwept is a log parse operation binding the contract event 0xab31ddb82a9ca2de51c9befe9da7c6e815e12eac49ae58b8d9cb6b7a181cbc71.
//
// Solidity: event ETHSwept(address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseETHSwept(log types.Log) (*SuperSponsorshipPaymasterETHSwept, error) {
	event := new(SuperSponsorshipPaymasterETHSwept)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "ETHSwept", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterEmergencyWithdrawnIterator is returned from FilterEmergencyWithdrawn and is used to iterate over the raw logs and unpacked data for EmergencyWithdrawn events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterEmergencyWithdrawnIterator struct {
	Event *SuperSponsorshipPaymasterEmergencyWithdrawn // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterEmergencyWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterEmergencyWithdrawn)
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
		it.Event = new(SuperSponsorshipPaymasterEmergencyWithdrawn)
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
func (it *SuperSponsorshipPaymasterEmergencyWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterEmergencyWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterEmergencyWithdrawn represents a EmergencyWithdrawn event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterEmergencyWithdrawn struct {
	To     common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterEmergencyWithdrawn is a free log retrieval operation binding the contract event 0x2e39961a70a10f4d46383948095ac2752b3ee642a7c76aa827410aaff08c2e51.
//
// Solidity: event EmergencyWithdrawn(address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterEmergencyWithdrawn(opts *bind.FilterOpts, to []common.Address) (*SuperSponsorshipPaymasterEmergencyWithdrawnIterator, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "EmergencyWithdrawn", toRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterEmergencyWithdrawnIterator{contract: _SuperSponsorshipPaymaster.contract, event: "EmergencyWithdrawn", logs: logs, sub: sub}, nil
}

// WatchEmergencyWithdrawn is a free log subscription operation binding the contract event 0x2e39961a70a10f4d46383948095ac2752b3ee642a7c76aa827410aaff08c2e51.
//
// Solidity: event EmergencyWithdrawn(address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchEmergencyWithdrawn(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterEmergencyWithdrawn, to []common.Address) (event.Subscription, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "EmergencyWithdrawn", toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterEmergencyWithdrawn)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "EmergencyWithdrawn", log); err != nil {
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

// ParseEmergencyWithdrawn is a log parse operation binding the contract event 0x2e39961a70a10f4d46383948095ac2752b3ee642a7c76aa827410aaff08c2e51.
//
// Solidity: event EmergencyWithdrawn(address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseEmergencyWithdrawn(log types.Log) (*SuperSponsorshipPaymasterEmergencyWithdrawn, error) {
	event := new(SuperSponsorshipPaymasterEmergencyWithdrawn)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "EmergencyWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterGlobalPauseSetIterator is returned from FilterGlobalPauseSet and is used to iterate over the raw logs and unpacked data for GlobalPauseSet events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterGlobalPauseSetIterator struct {
	Event *SuperSponsorshipPaymasterGlobalPauseSet // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterGlobalPauseSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterGlobalPauseSet)
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
		it.Event = new(SuperSponsorshipPaymasterGlobalPauseSet)
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
func (it *SuperSponsorshipPaymasterGlobalPauseSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterGlobalPauseSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterGlobalPauseSet represents a GlobalPauseSet event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterGlobalPauseSet struct {
	Paused bool
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterGlobalPauseSet is a free log retrieval operation binding the contract event 0x971be26fcde2df81b2b63dfb7fa1d2294b524eb1896b10e5228d9c154a30af09.
//
// Solidity: event GlobalPauseSet(bool paused)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterGlobalPauseSet(opts *bind.FilterOpts) (*SuperSponsorshipPaymasterGlobalPauseSetIterator, error) {

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "GlobalPauseSet")
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterGlobalPauseSetIterator{contract: _SuperSponsorshipPaymaster.contract, event: "GlobalPauseSet", logs: logs, sub: sub}, nil
}

// WatchGlobalPauseSet is a free log subscription operation binding the contract event 0x971be26fcde2df81b2b63dfb7fa1d2294b524eb1896b10e5228d9c154a30af09.
//
// Solidity: event GlobalPauseSet(bool paused)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchGlobalPauseSet(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterGlobalPauseSet) (event.Subscription, error) {

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "GlobalPauseSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterGlobalPauseSet)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "GlobalPauseSet", log); err != nil {
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

// ParseGlobalPauseSet is a log parse operation binding the contract event 0x971be26fcde2df81b2b63dfb7fa1d2294b524eb1896b10e5228d9c154a30af09.
//
// Solidity: event GlobalPauseSet(bool paused)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseGlobalPauseSet(log types.Log) (*SuperSponsorshipPaymasterGlobalPauseSet, error) {
	event := new(SuperSponsorshipPaymasterGlobalPauseSet)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "GlobalPauseSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterMaxSingleOpCostSetIterator is returned from FilterMaxSingleOpCostSet and is used to iterate over the raw logs and unpacked data for MaxSingleOpCostSet events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterMaxSingleOpCostSetIterator struct {
	Event *SuperSponsorshipPaymasterMaxSingleOpCostSet // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterMaxSingleOpCostSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterMaxSingleOpCostSet)
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
		it.Event = new(SuperSponsorshipPaymasterMaxSingleOpCostSet)
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
func (it *SuperSponsorshipPaymasterMaxSingleOpCostSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterMaxSingleOpCostSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterMaxSingleOpCostSet represents a MaxSingleOpCostSet event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterMaxSingleOpCostSet struct {
	Strategy common.Address
	MaxCost  *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterMaxSingleOpCostSet is a free log retrieval operation binding the contract event 0x0d39e25b23eefdb97cc74b567080ccc4ec5695b8b5dacea60bd464bcc7a6bafe.
//
// Solidity: event MaxSingleOpCostSet(address indexed strategy, uint256 maxCost)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterMaxSingleOpCostSet(opts *bind.FilterOpts, strategy []common.Address) (*SuperSponsorshipPaymasterMaxSingleOpCostSetIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "MaxSingleOpCostSet", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterMaxSingleOpCostSetIterator{contract: _SuperSponsorshipPaymaster.contract, event: "MaxSingleOpCostSet", logs: logs, sub: sub}, nil
}

// WatchMaxSingleOpCostSet is a free log subscription operation binding the contract event 0x0d39e25b23eefdb97cc74b567080ccc4ec5695b8b5dacea60bd464bcc7a6bafe.
//
// Solidity: event MaxSingleOpCostSet(address indexed strategy, uint256 maxCost)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchMaxSingleOpCostSet(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterMaxSingleOpCostSet, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "MaxSingleOpCostSet", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterMaxSingleOpCostSet)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "MaxSingleOpCostSet", log); err != nil {
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

// ParseMaxSingleOpCostSet is a log parse operation binding the contract event 0x0d39e25b23eefdb97cc74b567080ccc4ec5695b8b5dacea60bd464bcc7a6bafe.
//
// Solidity: event MaxSingleOpCostSet(address indexed strategy, uint256 maxCost)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseMaxSingleOpCostSet(log types.Log) (*SuperSponsorshipPaymasterMaxSingleOpCostSet, error) {
	event := new(SuperSponsorshipPaymasterMaxSingleOpCostSet)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "MaxSingleOpCostSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterPostOpGasOverheadSetIterator is returned from FilterPostOpGasOverheadSet and is used to iterate over the raw logs and unpacked data for PostOpGasOverheadSet events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterPostOpGasOverheadSetIterator struct {
	Event *SuperSponsorshipPaymasterPostOpGasOverheadSet // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterPostOpGasOverheadSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterPostOpGasOverheadSet)
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
		it.Event = new(SuperSponsorshipPaymasterPostOpGasOverheadSet)
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
func (it *SuperSponsorshipPaymasterPostOpGasOverheadSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterPostOpGasOverheadSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterPostOpGasOverheadSet represents a PostOpGasOverheadSet event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterPostOpGasOverheadSet struct {
	Overhead *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterPostOpGasOverheadSet is a free log retrieval operation binding the contract event 0x4f1a3370498c6b44f94b32ce89628d8ebc9592222cf780e524a90d1c6d85f5e1.
//
// Solidity: event PostOpGasOverheadSet(uint256 overhead)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterPostOpGasOverheadSet(opts *bind.FilterOpts) (*SuperSponsorshipPaymasterPostOpGasOverheadSetIterator, error) {

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "PostOpGasOverheadSet")
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterPostOpGasOverheadSetIterator{contract: _SuperSponsorshipPaymaster.contract, event: "PostOpGasOverheadSet", logs: logs, sub: sub}, nil
}

// WatchPostOpGasOverheadSet is a free log subscription operation binding the contract event 0x4f1a3370498c6b44f94b32ce89628d8ebc9592222cf780e524a90d1c6d85f5e1.
//
// Solidity: event PostOpGasOverheadSet(uint256 overhead)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchPostOpGasOverheadSet(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterPostOpGasOverheadSet) (event.Subscription, error) {

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "PostOpGasOverheadSet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterPostOpGasOverheadSet)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "PostOpGasOverheadSet", log); err != nil {
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

// ParsePostOpGasOverheadSet is a log parse operation binding the contract event 0x4f1a3370498c6b44f94b32ce89628d8ebc9592222cf780e524a90d1c6d85f5e1.
//
// Solidity: event PostOpGasOverheadSet(uint256 overhead)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParsePostOpGasOverheadSet(log types.Log) (*SuperSponsorshipPaymasterPostOpGasOverheadSet, error) {
	event := new(SuperSponsorshipPaymasterPostOpGasOverheadSet)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "PostOpGasOverheadSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterReconciledIterator is returned from FilterReconciled and is used to iterate over the raw logs and unpacked data for Reconciled events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterReconciledIterator struct {
	Event *SuperSponsorshipPaymasterReconciled // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterReconciledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterReconciled)
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
		it.Event = new(SuperSponsorshipPaymasterReconciled)
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
func (it *SuperSponsorshipPaymasterReconciledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterReconciledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterReconciled represents a Reconciled event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterReconciled struct {
	Drift *big.Int
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterReconciled is a free log retrieval operation binding the contract event 0xbd74aafc6f03cb39cafc2cd77915e0eb30f792762cf157f639125ece96edc25f.
//
// Solidity: event Reconciled(uint256 drift)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterReconciled(opts *bind.FilterOpts) (*SuperSponsorshipPaymasterReconciledIterator, error) {

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "Reconciled")
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterReconciledIterator{contract: _SuperSponsorshipPaymaster.contract, event: "Reconciled", logs: logs, sub: sub}, nil
}

// WatchReconciled is a free log subscription operation binding the contract event 0xbd74aafc6f03cb39cafc2cd77915e0eb30f792762cf157f639125ece96edc25f.
//
// Solidity: event Reconciled(uint256 drift)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchReconciled(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterReconciled) (event.Subscription, error) {

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "Reconciled")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterReconciled)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "Reconciled", log); err != nil {
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

// ParseReconciled is a log parse operation binding the contract event 0xbd74aafc6f03cb39cafc2cd77915e0eb30f792762cf157f639125ece96edc25f.
//
// Solidity: event Reconciled(uint256 drift)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseReconciled(log types.Log) (*SuperSponsorshipPaymasterReconciled, error) {
	event := new(SuperSponsorshipPaymasterReconciled)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "Reconciled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterRoleAdminChangedIterator is returned from FilterRoleAdminChanged and is used to iterate over the raw logs and unpacked data for RoleAdminChanged events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterRoleAdminChangedIterator struct {
	Event *SuperSponsorshipPaymasterRoleAdminChanged // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterRoleAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterRoleAdminChanged)
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
		it.Event = new(SuperSponsorshipPaymasterRoleAdminChanged)
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
func (it *SuperSponsorshipPaymasterRoleAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterRoleAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterRoleAdminChanged represents a RoleAdminChanged event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterRoleAdminChanged struct {
	Role              [32]byte
	PreviousAdminRole [32]byte
	NewAdminRole      [32]byte
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterRoleAdminChanged is a free log retrieval operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterRoleAdminChanged(opts *bind.FilterOpts, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (*SuperSponsorshipPaymasterRoleAdminChangedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterRoleAdminChangedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "RoleAdminChanged", logs: logs, sub: sub}, nil
}

// WatchRoleAdminChanged is a free log subscription operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchRoleAdminChanged(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterRoleAdminChanged, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterRoleAdminChanged)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
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

// ParseRoleAdminChanged is a log parse operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseRoleAdminChanged(log types.Log) (*SuperSponsorshipPaymasterRoleAdminChanged, error) {
	event := new(SuperSponsorshipPaymasterRoleAdminChanged)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterRoleGrantedIterator is returned from FilterRoleGranted and is used to iterate over the raw logs and unpacked data for RoleGranted events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterRoleGrantedIterator struct {
	Event *SuperSponsorshipPaymasterRoleGranted // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterRoleGrantedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterRoleGranted)
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
		it.Event = new(SuperSponsorshipPaymasterRoleGranted)
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
func (it *SuperSponsorshipPaymasterRoleGrantedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterRoleGrantedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterRoleGranted represents a RoleGranted event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterRoleGranted struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleGranted is a free log retrieval operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterRoleGranted(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperSponsorshipPaymasterRoleGrantedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterRoleGrantedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "RoleGranted", logs: logs, sub: sub}, nil
}

// WatchRoleGranted is a free log subscription operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchRoleGranted(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterRoleGranted, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterRoleGranted)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "RoleGranted", log); err != nil {
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

// ParseRoleGranted is a log parse operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseRoleGranted(log types.Log) (*SuperSponsorshipPaymasterRoleGranted, error) {
	event := new(SuperSponsorshipPaymasterRoleGranted)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "RoleGranted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterRoleRevokedIterator is returned from FilterRoleRevoked and is used to iterate over the raw logs and unpacked data for RoleRevoked events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterRoleRevokedIterator struct {
	Event *SuperSponsorshipPaymasterRoleRevoked // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterRoleRevokedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterRoleRevoked)
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
		it.Event = new(SuperSponsorshipPaymasterRoleRevoked)
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
func (it *SuperSponsorshipPaymasterRoleRevokedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterRoleRevokedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterRoleRevoked represents a RoleRevoked event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterRoleRevoked struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleRevoked is a free log retrieval operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterRoleRevoked(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperSponsorshipPaymasterRoleRevokedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterRoleRevokedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "RoleRevoked", logs: logs, sub: sub}, nil
}

// WatchRoleRevoked is a free log subscription operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchRoleRevoked(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterRoleRevoked, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterRoleRevoked)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
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

// ParseRoleRevoked is a log parse operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseRoleRevoked(log types.Log) (*SuperSponsorshipPaymasterRoleRevoked, error) {
	event := new(SuperSponsorshipPaymasterRoleRevoked)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterStrategyCreditedIterator is returned from FilterStrategyCredited and is used to iterate over the raw logs and unpacked data for StrategyCredited events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyCreditedIterator struct {
	Event *SuperSponsorshipPaymasterStrategyCredited // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterStrategyCreditedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterStrategyCredited)
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
		it.Event = new(SuperSponsorshipPaymasterStrategyCredited)
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
func (it *SuperSponsorshipPaymasterStrategyCreditedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterStrategyCreditedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterStrategyCredited represents a StrategyCredited event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyCredited struct {
	Strategy common.Address
	Amount   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyCredited is a free log retrieval operation binding the contract event 0x1a6e4e6142fa7199a00ff3ba4630ae17a0897fe282cab51f3afcc4d27a95f15e.
//
// Solidity: event StrategyCredited(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterStrategyCredited(opts *bind.FilterOpts, strategy []common.Address) (*SuperSponsorshipPaymasterStrategyCreditedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "StrategyCredited", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterStrategyCreditedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "StrategyCredited", logs: logs, sub: sub}, nil
}

// WatchStrategyCredited is a free log subscription operation binding the contract event 0x1a6e4e6142fa7199a00ff3ba4630ae17a0897fe282cab51f3afcc4d27a95f15e.
//
// Solidity: event StrategyCredited(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchStrategyCredited(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterStrategyCredited, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "StrategyCredited", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterStrategyCredited)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyCredited", log); err != nil {
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

// ParseStrategyCredited is a log parse operation binding the contract event 0x1a6e4e6142fa7199a00ff3ba4630ae17a0897fe282cab51f3afcc4d27a95f15e.
//
// Solidity: event StrategyCredited(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseStrategyCredited(log types.Log) (*SuperSponsorshipPaymasterStrategyCredited, error) {
	event := new(SuperSponsorshipPaymasterStrategyCredited)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyCredited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterStrategyDebitedIterator is returned from FilterStrategyDebited and is used to iterate over the raw logs and unpacked data for StrategyDebited events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyDebitedIterator struct {
	Event *SuperSponsorshipPaymasterStrategyDebited // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterStrategyDebitedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterStrategyDebited)
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
		it.Event = new(SuperSponsorshipPaymasterStrategyDebited)
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
func (it *SuperSponsorshipPaymasterStrategyDebitedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterStrategyDebitedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterStrategyDebited represents a StrategyDebited event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyDebited struct {
	Strategy common.Address
	Amount   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyDebited is a free log retrieval operation binding the contract event 0x9705a055ef6a909aea6ed32a376f3ea2a717a9fb70ba1cf12738802069bac644.
//
// Solidity: event StrategyDebited(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterStrategyDebited(opts *bind.FilterOpts, strategy []common.Address) (*SuperSponsorshipPaymasterStrategyDebitedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "StrategyDebited", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterStrategyDebitedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "StrategyDebited", logs: logs, sub: sub}, nil
}

// WatchStrategyDebited is a free log subscription operation binding the contract event 0x9705a055ef6a909aea6ed32a376f3ea2a717a9fb70ba1cf12738802069bac644.
//
// Solidity: event StrategyDebited(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchStrategyDebited(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterStrategyDebited, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "StrategyDebited", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterStrategyDebited)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyDebited", log); err != nil {
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

// ParseStrategyDebited is a log parse operation binding the contract event 0x9705a055ef6a909aea6ed32a376f3ea2a717a9fb70ba1cf12738802069bac644.
//
// Solidity: event StrategyDebited(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseStrategyDebited(log types.Log) (*SuperSponsorshipPaymasterStrategyDebited, error) {
	event := new(SuperSponsorshipPaymasterStrategyDebited)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyDebited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterStrategyFundedIterator is returned from FilterStrategyFunded and is used to iterate over the raw logs and unpacked data for StrategyFunded events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyFundedIterator struct {
	Event *SuperSponsorshipPaymasterStrategyFunded // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterStrategyFundedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterStrategyFunded)
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
		it.Event = new(SuperSponsorshipPaymasterStrategyFunded)
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
func (it *SuperSponsorshipPaymasterStrategyFundedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterStrategyFundedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterStrategyFunded represents a StrategyFunded event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyFunded struct {
	Strategy common.Address
	Amount   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyFunded is a free log retrieval operation binding the contract event 0x8b783bfd1b55a57f44fd85a71bd5eaf6cda6a9d54b5562665b0fa05dda700ec9.
//
// Solidity: event StrategyFunded(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterStrategyFunded(opts *bind.FilterOpts, strategy []common.Address) (*SuperSponsorshipPaymasterStrategyFundedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "StrategyFunded", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterStrategyFundedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "StrategyFunded", logs: logs, sub: sub}, nil
}

// WatchStrategyFunded is a free log subscription operation binding the contract event 0x8b783bfd1b55a57f44fd85a71bd5eaf6cda6a9d54b5562665b0fa05dda700ec9.
//
// Solidity: event StrategyFunded(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchStrategyFunded(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterStrategyFunded, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "StrategyFunded", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterStrategyFunded)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyFunded", log); err != nil {
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

// ParseStrategyFunded is a log parse operation binding the contract event 0x8b783bfd1b55a57f44fd85a71bd5eaf6cda6a9d54b5562665b0fa05dda700ec9.
//
// Solidity: event StrategyFunded(address indexed strategy, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseStrategyFunded(log types.Log) (*SuperSponsorshipPaymasterStrategyFunded, error) {
	event := new(SuperSponsorshipPaymasterStrategyFunded)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyFunded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterStrategyPausedIterator is returned from FilterStrategyPaused and is used to iterate over the raw logs and unpacked data for StrategyPaused events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyPausedIterator struct {
	Event *SuperSponsorshipPaymasterStrategyPaused // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterStrategyPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterStrategyPaused)
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
		it.Event = new(SuperSponsorshipPaymasterStrategyPaused)
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
func (it *SuperSponsorshipPaymasterStrategyPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterStrategyPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterStrategyPaused represents a StrategyPaused event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyPaused struct {
	Strategy common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyPaused is a free log retrieval operation binding the contract event 0xc2897a3765ea6cd9ed9ce463d3bc9c9cf968f21f8664b62684e1254d3b0f9ee5.
//
// Solidity: event StrategyPaused(address indexed strategy)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterStrategyPaused(opts *bind.FilterOpts, strategy []common.Address) (*SuperSponsorshipPaymasterStrategyPausedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "StrategyPaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterStrategyPausedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "StrategyPaused", logs: logs, sub: sub}, nil
}

// WatchStrategyPaused is a free log subscription operation binding the contract event 0xc2897a3765ea6cd9ed9ce463d3bc9c9cf968f21f8664b62684e1254d3b0f9ee5.
//
// Solidity: event StrategyPaused(address indexed strategy)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchStrategyPaused(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterStrategyPaused, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "StrategyPaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterStrategyPaused)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyPaused", log); err != nil {
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

// ParseStrategyPaused is a log parse operation binding the contract event 0xc2897a3765ea6cd9ed9ce463d3bc9c9cf968f21f8664b62684e1254d3b0f9ee5.
//
// Solidity: event StrategyPaused(address indexed strategy)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseStrategyPaused(log types.Log) (*SuperSponsorshipPaymasterStrategyPaused, error) {
	event := new(SuperSponsorshipPaymasterStrategyPaused)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyPaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterStrategyUnpausedIterator is returned from FilterStrategyUnpaused and is used to iterate over the raw logs and unpacked data for StrategyUnpaused events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyUnpausedIterator struct {
	Event *SuperSponsorshipPaymasterStrategyUnpaused // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterStrategyUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterStrategyUnpaused)
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
		it.Event = new(SuperSponsorshipPaymasterStrategyUnpaused)
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
func (it *SuperSponsorshipPaymasterStrategyUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterStrategyUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterStrategyUnpaused represents a StrategyUnpaused event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyUnpaused struct {
	Strategy common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyUnpaused is a free log retrieval operation binding the contract event 0x9de75c520457842eb5fe159114348bf5358100a1acaf1bcb5052f64f347503df.
//
// Solidity: event StrategyUnpaused(address indexed strategy)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterStrategyUnpaused(opts *bind.FilterOpts, strategy []common.Address) (*SuperSponsorshipPaymasterStrategyUnpausedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "StrategyUnpaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterStrategyUnpausedIterator{contract: _SuperSponsorshipPaymaster.contract, event: "StrategyUnpaused", logs: logs, sub: sub}, nil
}

// WatchStrategyUnpaused is a free log subscription operation binding the contract event 0x9de75c520457842eb5fe159114348bf5358100a1acaf1bcb5052f64f347503df.
//
// Solidity: event StrategyUnpaused(address indexed strategy)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchStrategyUnpaused(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterStrategyUnpaused, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "StrategyUnpaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterStrategyUnpaused)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyUnpaused", log); err != nil {
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

// ParseStrategyUnpaused is a log parse operation binding the contract event 0x9de75c520457842eb5fe159114348bf5358100a1acaf1bcb5052f64f347503df.
//
// Solidity: event StrategyUnpaused(address indexed strategy)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseStrategyUnpaused(log types.Log) (*SuperSponsorshipPaymasterStrategyUnpaused, error) {
	event := new(SuperSponsorshipPaymasterStrategyUnpaused)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyUnpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperSponsorshipPaymasterStrategyWithdrawnIterator is returned from FilterStrategyWithdrawn and is used to iterate over the raw logs and unpacked data for StrategyWithdrawn events raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyWithdrawnIterator struct {
	Event *SuperSponsorshipPaymasterStrategyWithdrawn // Event containing the contract specifics and raw log

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
func (it *SuperSponsorshipPaymasterStrategyWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperSponsorshipPaymasterStrategyWithdrawn)
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
		it.Event = new(SuperSponsorshipPaymasterStrategyWithdrawn)
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
func (it *SuperSponsorshipPaymasterStrategyWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperSponsorshipPaymasterStrategyWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperSponsorshipPaymasterStrategyWithdrawn represents a StrategyWithdrawn event raised by the SuperSponsorshipPaymaster contract.
type SuperSponsorshipPaymasterStrategyWithdrawn struct {
	Strategy common.Address
	To       common.Address
	Amount   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyWithdrawn is a free log retrieval operation binding the contract event 0xbabc8124ddaa11119abddcffd699924f857c9a15f1fc50be38069e96a47ae8c0.
//
// Solidity: event StrategyWithdrawn(address indexed strategy, address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) FilterStrategyWithdrawn(opts *bind.FilterOpts, strategy []common.Address, to []common.Address) (*SuperSponsorshipPaymasterStrategyWithdrawnIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.FilterLogs(opts, "StrategyWithdrawn", strategyRule, toRule)
	if err != nil {
		return nil, err
	}
	return &SuperSponsorshipPaymasterStrategyWithdrawnIterator{contract: _SuperSponsorshipPaymaster.contract, event: "StrategyWithdrawn", logs: logs, sub: sub}, nil
}

// WatchStrategyWithdrawn is a free log subscription operation binding the contract event 0xbabc8124ddaa11119abddcffd699924f857c9a15f1fc50be38069e96a47ae8c0.
//
// Solidity: event StrategyWithdrawn(address indexed strategy, address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) WatchStrategyWithdrawn(opts *bind.WatchOpts, sink chan<- *SuperSponsorshipPaymasterStrategyWithdrawn, strategy []common.Address, to []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _SuperSponsorshipPaymaster.contract.WatchLogs(opts, "StrategyWithdrawn", strategyRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperSponsorshipPaymasterStrategyWithdrawn)
				if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyWithdrawn", log); err != nil {
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

// ParseStrategyWithdrawn is a log parse operation binding the contract event 0xbabc8124ddaa11119abddcffd699924f857c9a15f1fc50be38069e96a47ae8c0.
//
// Solidity: event StrategyWithdrawn(address indexed strategy, address indexed to, uint256 amount)
func (_SuperSponsorshipPaymaster *SuperSponsorshipPaymasterFilterer) ParseStrategyWithdrawn(log types.Log) (*SuperSponsorshipPaymasterStrategyWithdrawn, error) {
	event := new(SuperSponsorshipPaymasterStrategyWithdrawn)
	if err := _SuperSponsorshipPaymaster.contract.UnpackLog(event, "StrategyWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
