// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperVaultStrategy

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

// ISuperVaultStrategyExecuteArgs is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyExecuteArgs struct {
	Hooks                     []common.Address
	HookCalldata              [][]byte
	ExpectedAssetsOrSharesOut []*big.Int
	GlobalProofs              [][][32]byte
	StrategyProofs            [][][32]byte
}

// ISuperVaultStrategyFeeConfig is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyFeeConfig struct {
	PerformanceFeeBps *big.Int
	Recipient         common.Address
}

// ISuperVaultStrategyFulfillArgs is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyFulfillArgs struct {
	Controllers               []common.Address
	Hooks                     []common.Address
	HookCalldata              [][]byte
	ExpectedAssetsOrSharesOut []*big.Int
	GlobalProofs              [][][32]byte
	StrategyProofs            [][][32]byte
}

// ISuperVaultStrategyYieldSource is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyYieldSource struct {
	Oracle   common.Address
	IsActive bool
}

// ISuperVaultStrategyYieldSourceInfo is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyYieldSourceInfo struct {
	SourceAddress common.Address
	Oracle        common.Address
	IsActive      bool
}

// SuperVaultStrategyMetaData contains all meta data concerning the SuperVaultStrategy contract.
var SuperVaultStrategyMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"PRECISION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimableWithdraw\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"claimableAssets\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"emergencyWithdrawable\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"emergencyWithdrawableEffectiveTime\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"executeHooks\",\"inputs\":[{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.ExecuteArgs\",\"components\":[{\"name\":\"hooks\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"hookCalldata\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"expectedAssetsOrSharesOut\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"globalProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"},{\"name\":\"strategyProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeVaultFeeConfigUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"fulfillRedeemRequests\",\"inputs\":[{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.FulfillArgs\",\"components\":[{\"name\":\"controllers\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"hooks\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"hookCalldata\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"expectedAssetsOrSharesOut\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"globalProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"},{\"name\":\"strategyProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getAverageWithdrawPrice\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"averageWithdrawPrice\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getConfigInfo\",\"inputs\":[],\"outputs\":[{\"name\":\"feeConfig_\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.FeeConfig\",\"components\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStoredPPS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getVaultInfo\",\"inputs\":[],\"outputs\":[{\"name\":\"vault_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"asset_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"vaultDecimals_\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYieldSource\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.YieldSource\",\"components\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isActive\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYieldSourcesList\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple[]\",\"internalType\":\"structISuperVaultStrategy.YieldSourceInfo[]\",\"components\":[{\"name\":\"sourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isActive\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleOperation\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"shares\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"operation\",\"type\":\"uint8\",\"internalType\":\"enumISuperVaultStrategy.Operation\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":[{\"name\":\"vault_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superGovernor_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feeConfig_\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.FeeConfig\",\"components\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"manageEmergencyWithdraw\",\"inputs\":[{\"name\":\"action\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"manageYieldSource\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actionType\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"activate\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"manageYieldSources\",\"inputs\":[{\"name\":\"sources\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"oracles\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"actionTypes\",\"type\":\"uint8[]\",\"internalType\":\"uint8[]\"},{\"name\":\"activates\",\"type\":\"bool[]\",\"internalType\":\"bool[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"pendingRedeemRequest\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pendingShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"previewPerformanceFee\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesToRedeem\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"totalFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"superformFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"recipientFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeVaultFeeConfigUpdate\",\"inputs\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposedEmergencyWithdrawable\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"updateMaxPPSSlippage\",\"inputs\":[{\"name\":\"maxSlippageBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"DepositHandled\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"shares\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EmergencyWithdrawableProposed\",\"inputs\":[{\"name\":\"newWithdrawable\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EmergencyWithdrawableUpdated\",\"inputs\":[{\"name\":\"withdrawable\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EmergencyWithdrawal\",\"inputs\":[{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeePaid\",\"inputs\":[{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FulfillHookExecuted\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"targetedYieldSource\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"hookCalldata\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookExecuted\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"prevHook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"targetedYieldSource\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"usePrevHookAmount\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"hookCalldata\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookRootProposed\",\"inputs\":[{\"name\":\"proposedRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookRootUpdated\",\"inputs\":[{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HooksExecuted\",\"inputs\":[{\"name\":\"hooks\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"superGovernor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MaxPPSSlippageUpdated\",\"inputs\":[{\"name\":\"maxSlippageBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PPSUpdated\",\"inputs\":[{\"name\":\"newPPS\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"calculationBlock\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RedeemRequestCanceled\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"shares\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RedeemRequestFulfilled\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"shares\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RedeemRequestPlaced\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"shares\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RedeemRequestsFulfilled\",\"inputs\":[{\"name\":\"hooks\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"controllers\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"processedShares\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"currentPPS\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultFeeConfigProposed\",\"inputs\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultFeeConfigUpdated\",\"inputs\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceAdded\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceDeactivated\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceOracleUpdated\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oldOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceReactivated\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ACTION_TYPE_DISALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ASYNC_REQUEST_BLOCKING\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CALCULATION_BLOCK_TOO_OLD\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_VALIDATION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FUNDS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_SHARES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_AMOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_EMERGENCY_ADMIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_EMERGENCY_WITHDRAWAL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_HOOK\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_HOOK_ROOT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_HOOK_TYPE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MAX_SLIPPAGE_BPS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PERFORMANCE_FEE_BPS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PERIPHERY_REGISTRY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PPS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_REDEEM_CLAIM\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_REDEEM_FILL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_STRATEGIST\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_TIMESTAMP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_VAULT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MINIMUM_OUTPUT_AMOUNT_ASSETS_NOT_MET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MINIMUM_PREVIOUS_HOOK_OUT_AMOUNT_NOT_MET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OPERATIONS_BLOCKED_BY_VETO\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OPERATION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PPS_OUT_OF_BOUNDS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PPS_UPDATE_RATE_LIMITED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REQUEST_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SLIPPAGE_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STAKE_TOO_LOW\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGIST_NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGY_PAUSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_ALREADY_ACTIVE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_ALREADY_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_NOT_ACTIVE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_EXPECTED_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_OUTPUT_AMOUNT\",\"inputs\":[]}]",
}

// SuperVaultStrategyABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperVaultStrategyMetaData.ABI instead.
var SuperVaultStrategyABI = SuperVaultStrategyMetaData.ABI

// SuperVaultStrategy is an auto generated Go binding around an Ethereum contract.
type SuperVaultStrategy struct {
	SuperVaultStrategyCaller     // Read-only binding to the contract
	SuperVaultStrategyTransactor // Write-only binding to the contract
	SuperVaultStrategyFilterer   // Log filterer for contract events
}

// SuperVaultStrategyCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperVaultStrategyCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultStrategyTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperVaultStrategyTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultStrategyFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperVaultStrategyFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultStrategySession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperVaultStrategySession struct {
	Contract     *SuperVaultStrategy // Generic contract binding to set the session for
	CallOpts     bind.CallOpts       // Call options to use throughout this session
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// SuperVaultStrategyCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperVaultStrategyCallerSession struct {
	Contract *SuperVaultStrategyCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts             // Call options to use throughout this session
}

// SuperVaultStrategyTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperVaultStrategyTransactorSession struct {
	Contract     *SuperVaultStrategyTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// SuperVaultStrategyRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperVaultStrategyRaw struct {
	Contract *SuperVaultStrategy // Generic contract binding to access the raw methods on
}

// SuperVaultStrategyCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperVaultStrategyCallerRaw struct {
	Contract *SuperVaultStrategyCaller // Generic read-only contract binding to access the raw methods on
}

// SuperVaultStrategyTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperVaultStrategyTransactorRaw struct {
	Contract *SuperVaultStrategyTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperVaultStrategy creates a new instance of SuperVaultStrategy, bound to a specific deployed contract.
func NewSuperVaultStrategy(address common.Address, backend bind.ContractBackend) (*SuperVaultStrategy, error) {
	contract, err := bindSuperVaultStrategy(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategy{SuperVaultStrategyCaller: SuperVaultStrategyCaller{contract: contract}, SuperVaultStrategyTransactor: SuperVaultStrategyTransactor{contract: contract}, SuperVaultStrategyFilterer: SuperVaultStrategyFilterer{contract: contract}}, nil
}

// NewSuperVaultStrategyCaller creates a new read-only instance of SuperVaultStrategy, bound to a specific deployed contract.
func NewSuperVaultStrategyCaller(address common.Address, caller bind.ContractCaller) (*SuperVaultStrategyCaller, error) {
	contract, err := bindSuperVaultStrategy(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyCaller{contract: contract}, nil
}

// NewSuperVaultStrategyTransactor creates a new write-only instance of SuperVaultStrategy, bound to a specific deployed contract.
func NewSuperVaultStrategyTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperVaultStrategyTransactor, error) {
	contract, err := bindSuperVaultStrategy(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyTransactor{contract: contract}, nil
}

// NewSuperVaultStrategyFilterer creates a new log filterer instance of SuperVaultStrategy, bound to a specific deployed contract.
func NewSuperVaultStrategyFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperVaultStrategyFilterer, error) {
	contract, err := bindSuperVaultStrategy(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyFilterer{contract: contract}, nil
}

// bindSuperVaultStrategy binds a generic wrapper to an already deployed contract.
func bindSuperVaultStrategy(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperVaultStrategyMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultStrategy *SuperVaultStrategyRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultStrategy.Contract.SuperVaultStrategyCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultStrategy *SuperVaultStrategyRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.SuperVaultStrategyTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultStrategy *SuperVaultStrategyRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.SuperVaultStrategyTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultStrategy *SuperVaultStrategyCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultStrategy.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultStrategy *SuperVaultStrategyTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultStrategy *SuperVaultStrategyTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.contract.Transact(opts, method, params...)
}

// PRECISION is a free data retrieval call binding the contract method 0xaaf5eb68.
//
// Solidity: function PRECISION() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) PRECISION(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "PRECISION")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PRECISION is a free data retrieval call binding the contract method 0xaaf5eb68.
//
// Solidity: function PRECISION() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategySession) PRECISION() (*big.Int, error) {
	return _SuperVaultStrategy.Contract.PRECISION(&_SuperVaultStrategy.CallOpts)
}

// PRECISION is a free data retrieval call binding the contract method 0xaaf5eb68.
//
// Solidity: function PRECISION() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) PRECISION() (*big.Int, error) {
	return _SuperVaultStrategy.Contract.PRECISION(&_SuperVaultStrategy.CallOpts)
}

// ClaimableWithdraw is a free data retrieval call binding the contract method 0xdc697818.
//
// Solidity: function claimableWithdraw(address controller) view returns(uint256 claimableAssets)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) ClaimableWithdraw(opts *bind.CallOpts, controller common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "claimableWithdraw", controller)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ClaimableWithdraw is a free data retrieval call binding the contract method 0xdc697818.
//
// Solidity: function claimableWithdraw(address controller) view returns(uint256 claimableAssets)
func (_SuperVaultStrategy *SuperVaultStrategySession) ClaimableWithdraw(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.ClaimableWithdraw(&_SuperVaultStrategy.CallOpts, controller)
}

// ClaimableWithdraw is a free data retrieval call binding the contract method 0xdc697818.
//
// Solidity: function claimableWithdraw(address controller) view returns(uint256 claimableAssets)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) ClaimableWithdraw(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.ClaimableWithdraw(&_SuperVaultStrategy.CallOpts, controller)
}

// EmergencyWithdrawable is a free data retrieval call binding the contract method 0x3e9d39ab.
//
// Solidity: function emergencyWithdrawable() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) EmergencyWithdrawable(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "emergencyWithdrawable")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// EmergencyWithdrawable is a free data retrieval call binding the contract method 0x3e9d39ab.
//
// Solidity: function emergencyWithdrawable() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategySession) EmergencyWithdrawable() (bool, error) {
	return _SuperVaultStrategy.Contract.EmergencyWithdrawable(&_SuperVaultStrategy.CallOpts)
}

// EmergencyWithdrawable is a free data retrieval call binding the contract method 0x3e9d39ab.
//
// Solidity: function emergencyWithdrawable() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) EmergencyWithdrawable() (bool, error) {
	return _SuperVaultStrategy.Contract.EmergencyWithdrawable(&_SuperVaultStrategy.CallOpts)
}

// EmergencyWithdrawableEffectiveTime is a free data retrieval call binding the contract method 0x56bd1148.
//
// Solidity: function emergencyWithdrawableEffectiveTime() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) EmergencyWithdrawableEffectiveTime(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "emergencyWithdrawableEffectiveTime")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// EmergencyWithdrawableEffectiveTime is a free data retrieval call binding the contract method 0x56bd1148.
//
// Solidity: function emergencyWithdrawableEffectiveTime() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategySession) EmergencyWithdrawableEffectiveTime() (*big.Int, error) {
	return _SuperVaultStrategy.Contract.EmergencyWithdrawableEffectiveTime(&_SuperVaultStrategy.CallOpts)
}

// EmergencyWithdrawableEffectiveTime is a free data retrieval call binding the contract method 0x56bd1148.
//
// Solidity: function emergencyWithdrawableEffectiveTime() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) EmergencyWithdrawableEffectiveTime() (*big.Int, error) {
	return _SuperVaultStrategy.Contract.EmergencyWithdrawableEffectiveTime(&_SuperVaultStrategy.CallOpts)
}

// GetAverageWithdrawPrice is a free data retrieval call binding the contract method 0xcd773844.
//
// Solidity: function getAverageWithdrawPrice(address controller) view returns(uint256 averageWithdrawPrice)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetAverageWithdrawPrice(opts *bind.CallOpts, controller common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getAverageWithdrawPrice", controller)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAverageWithdrawPrice is a free data retrieval call binding the contract method 0xcd773844.
//
// Solidity: function getAverageWithdrawPrice(address controller) view returns(uint256 averageWithdrawPrice)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetAverageWithdrawPrice(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetAverageWithdrawPrice(&_SuperVaultStrategy.CallOpts, controller)
}

// GetAverageWithdrawPrice is a free data retrieval call binding the contract method 0xcd773844.
//
// Solidity: function getAverageWithdrawPrice(address controller) view returns(uint256 averageWithdrawPrice)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetAverageWithdrawPrice(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetAverageWithdrawPrice(&_SuperVaultStrategy.CallOpts, controller)
}

// GetConfigInfo is a free data retrieval call binding the contract method 0x78a1bf05.
//
// Solidity: function getConfigInfo() view returns((uint256,address) feeConfig_)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetConfigInfo(opts *bind.CallOpts) (ISuperVaultStrategyFeeConfig, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getConfigInfo")

	if err != nil {
		return *new(ISuperVaultStrategyFeeConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(ISuperVaultStrategyFeeConfig)).(*ISuperVaultStrategyFeeConfig)

	return out0, err

}

// GetConfigInfo is a free data retrieval call binding the contract method 0x78a1bf05.
//
// Solidity: function getConfigInfo() view returns((uint256,address) feeConfig_)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetConfigInfo() (ISuperVaultStrategyFeeConfig, error) {
	return _SuperVaultStrategy.Contract.GetConfigInfo(&_SuperVaultStrategy.CallOpts)
}

// GetConfigInfo is a free data retrieval call binding the contract method 0x78a1bf05.
//
// Solidity: function getConfigInfo() view returns((uint256,address) feeConfig_)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetConfigInfo() (ISuperVaultStrategyFeeConfig, error) {
	return _SuperVaultStrategy.Contract.GetConfigInfo(&_SuperVaultStrategy.CallOpts)
}

// GetStoredPPS is a free data retrieval call binding the contract method 0x2653517d.
//
// Solidity: function getStoredPPS() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetStoredPPS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getStoredPPS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetStoredPPS is a free data retrieval call binding the contract method 0x2653517d.
//
// Solidity: function getStoredPPS() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetStoredPPS() (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetStoredPPS(&_SuperVaultStrategy.CallOpts)
}

// GetStoredPPS is a free data retrieval call binding the contract method 0x2653517d.
//
// Solidity: function getStoredPPS() view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetStoredPPS() (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetStoredPPS(&_SuperVaultStrategy.CallOpts)
}

// GetVaultInfo is a free data retrieval call binding the contract method 0x7f98aa71.
//
// Solidity: function getVaultInfo() view returns(address vault_, address asset_, uint8 vaultDecimals_)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetVaultInfo(opts *bind.CallOpts) (struct {
	Vault         common.Address
	Asset         common.Address
	VaultDecimals uint8
}, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getVaultInfo")

	outstruct := new(struct {
		Vault         common.Address
		Asset         common.Address
		VaultDecimals uint8
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Vault = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.Asset = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.VaultDecimals = *abi.ConvertType(out[2], new(uint8)).(*uint8)

	return *outstruct, err

}

// GetVaultInfo is a free data retrieval call binding the contract method 0x7f98aa71.
//
// Solidity: function getVaultInfo() view returns(address vault_, address asset_, uint8 vaultDecimals_)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetVaultInfo() (struct {
	Vault         common.Address
	Asset         common.Address
	VaultDecimals uint8
}, error) {
	return _SuperVaultStrategy.Contract.GetVaultInfo(&_SuperVaultStrategy.CallOpts)
}

// GetVaultInfo is a free data retrieval call binding the contract method 0x7f98aa71.
//
// Solidity: function getVaultInfo() view returns(address vault_, address asset_, uint8 vaultDecimals_)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetVaultInfo() (struct {
	Vault         common.Address
	Asset         common.Address
	VaultDecimals uint8
}, error) {
	return _SuperVaultStrategy.Contract.GetVaultInfo(&_SuperVaultStrategy.CallOpts)
}

// GetYieldSource is a free data retrieval call binding the contract method 0x6bccefbd.
//
// Solidity: function getYieldSource(address source) view returns((address,bool))
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetYieldSource(opts *bind.CallOpts, source common.Address) (ISuperVaultStrategyYieldSource, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getYieldSource", source)

	if err != nil {
		return *new(ISuperVaultStrategyYieldSource), err
	}

	out0 := *abi.ConvertType(out[0], new(ISuperVaultStrategyYieldSource)).(*ISuperVaultStrategyYieldSource)

	return out0, err

}

// GetYieldSource is a free data retrieval call binding the contract method 0x6bccefbd.
//
// Solidity: function getYieldSource(address source) view returns((address,bool))
func (_SuperVaultStrategy *SuperVaultStrategySession) GetYieldSource(source common.Address) (ISuperVaultStrategyYieldSource, error) {
	return _SuperVaultStrategy.Contract.GetYieldSource(&_SuperVaultStrategy.CallOpts, source)
}

// GetYieldSource is a free data retrieval call binding the contract method 0x6bccefbd.
//
// Solidity: function getYieldSource(address source) view returns((address,bool))
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetYieldSource(source common.Address) (ISuperVaultStrategyYieldSource, error) {
	return _SuperVaultStrategy.Contract.GetYieldSource(&_SuperVaultStrategy.CallOpts, source)
}

// GetYieldSourcesList is a free data retrieval call binding the contract method 0x7b26e709.
//
// Solidity: function getYieldSourcesList() view returns((address,address,bool)[])
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetYieldSourcesList(opts *bind.CallOpts) ([]ISuperVaultStrategyYieldSourceInfo, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getYieldSourcesList")

	if err != nil {
		return *new([]ISuperVaultStrategyYieldSourceInfo), err
	}

	out0 := *abi.ConvertType(out[0], new([]ISuperVaultStrategyYieldSourceInfo)).(*[]ISuperVaultStrategyYieldSourceInfo)

	return out0, err

}

// GetYieldSourcesList is a free data retrieval call binding the contract method 0x7b26e709.
//
// Solidity: function getYieldSourcesList() view returns((address,address,bool)[])
func (_SuperVaultStrategy *SuperVaultStrategySession) GetYieldSourcesList() ([]ISuperVaultStrategyYieldSourceInfo, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourcesList(&_SuperVaultStrategy.CallOpts)
}

// GetYieldSourcesList is a free data retrieval call binding the contract method 0x7b26e709.
//
// Solidity: function getYieldSourcesList() view returns((address,address,bool)[])
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetYieldSourcesList() ([]ISuperVaultStrategyYieldSourceInfo, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourcesList(&_SuperVaultStrategy.CallOpts)
}

// IsInitialized is a free data retrieval call binding the contract method 0x392e53cd.
//
// Solidity: function isInitialized() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) IsInitialized(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "isInitialized")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0x392e53cd.
//
// Solidity: function isInitialized() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategySession) IsInitialized() (bool, error) {
	return _SuperVaultStrategy.Contract.IsInitialized(&_SuperVaultStrategy.CallOpts)
}

// IsInitialized is a free data retrieval call binding the contract method 0x392e53cd.
//
// Solidity: function isInitialized() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) IsInitialized() (bool, error) {
	return _SuperVaultStrategy.Contract.IsInitialized(&_SuperVaultStrategy.CallOpts)
}

// PendingRedeemRequest is a free data retrieval call binding the contract method 0x53dc1dd3.
//
// Solidity: function pendingRedeemRequest(address controller) view returns(uint256 pendingShares)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) PendingRedeemRequest(opts *bind.CallOpts, controller common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "pendingRedeemRequest", controller)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingRedeemRequest is a free data retrieval call binding the contract method 0x53dc1dd3.
//
// Solidity: function pendingRedeemRequest(address controller) view returns(uint256 pendingShares)
func (_SuperVaultStrategy *SuperVaultStrategySession) PendingRedeemRequest(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.PendingRedeemRequest(&_SuperVaultStrategy.CallOpts, controller)
}

// PendingRedeemRequest is a free data retrieval call binding the contract method 0x53dc1dd3.
//
// Solidity: function pendingRedeemRequest(address controller) view returns(uint256 pendingShares)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) PendingRedeemRequest(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.PendingRedeemRequest(&_SuperVaultStrategy.CallOpts, controller)
}

// PreviewPerformanceFee is a free data retrieval call binding the contract method 0xa660de9f.
//
// Solidity: function previewPerformanceFee(address controller, uint256 sharesToRedeem) view returns(uint256 totalFee, uint256 superformFee, uint256 recipientFee)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) PreviewPerformanceFee(opts *bind.CallOpts, controller common.Address, sharesToRedeem *big.Int) (struct {
	TotalFee     *big.Int
	SuperformFee *big.Int
	RecipientFee *big.Int
}, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "previewPerformanceFee", controller, sharesToRedeem)

	outstruct := new(struct {
		TotalFee     *big.Int
		SuperformFee *big.Int
		RecipientFee *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.TotalFee = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.SuperformFee = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.RecipientFee = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// PreviewPerformanceFee is a free data retrieval call binding the contract method 0xa660de9f.
//
// Solidity: function previewPerformanceFee(address controller, uint256 sharesToRedeem) view returns(uint256 totalFee, uint256 superformFee, uint256 recipientFee)
func (_SuperVaultStrategy *SuperVaultStrategySession) PreviewPerformanceFee(controller common.Address, sharesToRedeem *big.Int) (struct {
	TotalFee     *big.Int
	SuperformFee *big.Int
	RecipientFee *big.Int
}, error) {
	return _SuperVaultStrategy.Contract.PreviewPerformanceFee(&_SuperVaultStrategy.CallOpts, controller, sharesToRedeem)
}

// PreviewPerformanceFee is a free data retrieval call binding the contract method 0xa660de9f.
//
// Solidity: function previewPerformanceFee(address controller, uint256 sharesToRedeem) view returns(uint256 totalFee, uint256 superformFee, uint256 recipientFee)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) PreviewPerformanceFee(controller common.Address, sharesToRedeem *big.Int) (struct {
	TotalFee     *big.Int
	SuperformFee *big.Int
	RecipientFee *big.Int
}, error) {
	return _SuperVaultStrategy.Contract.PreviewPerformanceFee(&_SuperVaultStrategy.CallOpts, controller, sharesToRedeem)
}

// ProposedEmergencyWithdrawable is a free data retrieval call binding the contract method 0x1ac69304.
//
// Solidity: function proposedEmergencyWithdrawable() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) ProposedEmergencyWithdrawable(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "proposedEmergencyWithdrawable")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ProposedEmergencyWithdrawable is a free data retrieval call binding the contract method 0x1ac69304.
//
// Solidity: function proposedEmergencyWithdrawable() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategySession) ProposedEmergencyWithdrawable() (bool, error) {
	return _SuperVaultStrategy.Contract.ProposedEmergencyWithdrawable(&_SuperVaultStrategy.CallOpts)
}

// ProposedEmergencyWithdrawable is a free data retrieval call binding the contract method 0x1ac69304.
//
// Solidity: function proposedEmergencyWithdrawable() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) ProposedEmergencyWithdrawable() (bool, error) {
	return _SuperVaultStrategy.Contract.ProposedEmergencyWithdrawable(&_SuperVaultStrategy.CallOpts)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x2f82b89a.
//
// Solidity: function executeHooks((address[],bytes[],uint256[],bytes32[][],bytes32[][]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ExecuteHooks(opts *bind.TransactOpts, args ISuperVaultStrategyExecuteArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "executeHooks", args)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x2f82b89a.
//
// Solidity: function executeHooks((address[],bytes[],uint256[],bytes32[][],bytes32[][]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ExecuteHooks(args ISuperVaultStrategyExecuteArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ExecuteHooks(&_SuperVaultStrategy.TransactOpts, args)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x2f82b89a.
//
// Solidity: function executeHooks((address[],bytes[],uint256[],bytes32[][],bytes32[][]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ExecuteHooks(args ISuperVaultStrategyExecuteArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ExecuteHooks(&_SuperVaultStrategy.TransactOpts, args)
}

// ExecuteVaultFeeConfigUpdate is a paid mutator transaction binding the contract method 0x1aa7d751.
//
// Solidity: function executeVaultFeeConfigUpdate() returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ExecuteVaultFeeConfigUpdate(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "executeVaultFeeConfigUpdate")
}

// ExecuteVaultFeeConfigUpdate is a paid mutator transaction binding the contract method 0x1aa7d751.
//
// Solidity: function executeVaultFeeConfigUpdate() returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ExecuteVaultFeeConfigUpdate() (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ExecuteVaultFeeConfigUpdate(&_SuperVaultStrategy.TransactOpts)
}

// ExecuteVaultFeeConfigUpdate is a paid mutator transaction binding the contract method 0x1aa7d751.
//
// Solidity: function executeVaultFeeConfigUpdate() returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ExecuteVaultFeeConfigUpdate() (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ExecuteVaultFeeConfigUpdate(&_SuperVaultStrategy.TransactOpts)
}

// FulfillRedeemRequests is a paid mutator transaction binding the contract method 0x1140092c.
//
// Solidity: function fulfillRedeemRequests((address[],address[],bytes[],uint256[],bytes32[][],bytes32[][]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) FulfillRedeemRequests(opts *bind.TransactOpts, args ISuperVaultStrategyFulfillArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "fulfillRedeemRequests", args)
}

// FulfillRedeemRequests is a paid mutator transaction binding the contract method 0x1140092c.
//
// Solidity: function fulfillRedeemRequests((address[],address[],bytes[],uint256[],bytes32[][],bytes32[][]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) FulfillRedeemRequests(args ISuperVaultStrategyFulfillArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.FulfillRedeemRequests(&_SuperVaultStrategy.TransactOpts, args)
}

// FulfillRedeemRequests is a paid mutator transaction binding the contract method 0x1140092c.
//
// Solidity: function fulfillRedeemRequests((address[],address[],bytes[],uint256[],bytes32[][],bytes32[][]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) FulfillRedeemRequests(args ISuperVaultStrategyFulfillArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.FulfillRedeemRequests(&_SuperVaultStrategy.TransactOpts, args)
}

// HandleOperation is a paid mutator transaction binding the contract method 0xe2036753.
//
// Solidity: function handleOperation(address controller, uint256 assets, uint256 shares, uint8 operation) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) HandleOperation(opts *bind.TransactOpts, controller common.Address, assets *big.Int, shares *big.Int, operation uint8) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "handleOperation", controller, assets, shares, operation)
}

// HandleOperation is a paid mutator transaction binding the contract method 0xe2036753.
//
// Solidity: function handleOperation(address controller, uint256 assets, uint256 shares, uint8 operation) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) HandleOperation(controller common.Address, assets *big.Int, shares *big.Int, operation uint8) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.HandleOperation(&_SuperVaultStrategy.TransactOpts, controller, assets, shares, operation)
}

// HandleOperation is a paid mutator transaction binding the contract method 0xe2036753.
//
// Solidity: function handleOperation(address controller, uint256 assets, uint256 shares, uint8 operation) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) HandleOperation(controller common.Address, assets *big.Int, shares *big.Int, operation uint8) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.HandleOperation(&_SuperVaultStrategy.TransactOpts, controller, assets, shares, operation)
}

// Initialize is a paid mutator transaction binding the contract method 0x61525ad8.
//
// Solidity: function initialize(address vault_, address superGovernor_, (uint256,address) feeConfig_) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) Initialize(opts *bind.TransactOpts, vault_ common.Address, superGovernor_ common.Address, feeConfig_ ISuperVaultStrategyFeeConfig) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "initialize", vault_, superGovernor_, feeConfig_)
}

// Initialize is a paid mutator transaction binding the contract method 0x61525ad8.
//
// Solidity: function initialize(address vault_, address superGovernor_, (uint256,address) feeConfig_) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) Initialize(vault_ common.Address, superGovernor_ common.Address, feeConfig_ ISuperVaultStrategyFeeConfig) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Initialize(&_SuperVaultStrategy.TransactOpts, vault_, superGovernor_, feeConfig_)
}

// Initialize is a paid mutator transaction binding the contract method 0x61525ad8.
//
// Solidity: function initialize(address vault_, address superGovernor_, (uint256,address) feeConfig_) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) Initialize(vault_ common.Address, superGovernor_ common.Address, feeConfig_ ISuperVaultStrategyFeeConfig) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Initialize(&_SuperVaultStrategy.TransactOpts, vault_, superGovernor_, feeConfig_)
}

// ManageEmergencyWithdraw is a paid mutator transaction binding the contract method 0xf4b3ea58.
//
// Solidity: function manageEmergencyWithdraw(uint8 action, address recipient, uint256 amount) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ManageEmergencyWithdraw(opts *bind.TransactOpts, action uint8, recipient common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "manageEmergencyWithdraw", action, recipient, amount)
}

// ManageEmergencyWithdraw is a paid mutator transaction binding the contract method 0xf4b3ea58.
//
// Solidity: function manageEmergencyWithdraw(uint8 action, address recipient, uint256 amount) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ManageEmergencyWithdraw(action uint8, recipient common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageEmergencyWithdraw(&_SuperVaultStrategy.TransactOpts, action, recipient, amount)
}

// ManageEmergencyWithdraw is a paid mutator transaction binding the contract method 0xf4b3ea58.
//
// Solidity: function manageEmergencyWithdraw(uint8 action, address recipient, uint256 amount) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ManageEmergencyWithdraw(action uint8, recipient common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageEmergencyWithdraw(&_SuperVaultStrategy.TransactOpts, action, recipient, amount)
}

// ManageYieldSource is a paid mutator transaction binding the contract method 0x2528f691.
//
// Solidity: function manageYieldSource(address source, address oracle, uint8 actionType, bool activate) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ManageYieldSource(opts *bind.TransactOpts, source common.Address, oracle common.Address, actionType uint8, activate bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "manageYieldSource", source, oracle, actionType, activate)
}

// ManageYieldSource is a paid mutator transaction binding the contract method 0x2528f691.
//
// Solidity: function manageYieldSource(address source, address oracle, uint8 actionType, bool activate) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ManageYieldSource(source common.Address, oracle common.Address, actionType uint8, activate bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageYieldSource(&_SuperVaultStrategy.TransactOpts, source, oracle, actionType, activate)
}

// ManageYieldSource is a paid mutator transaction binding the contract method 0x2528f691.
//
// Solidity: function manageYieldSource(address source, address oracle, uint8 actionType, bool activate) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ManageYieldSource(source common.Address, oracle common.Address, actionType uint8, activate bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageYieldSource(&_SuperVaultStrategy.TransactOpts, source, oracle, actionType, activate)
}

// ManageYieldSources is a paid mutator transaction binding the contract method 0xa8e34b93.
//
// Solidity: function manageYieldSources(address[] sources, address[] oracles, uint8[] actionTypes, bool[] activates) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ManageYieldSources(opts *bind.TransactOpts, sources []common.Address, oracles []common.Address, actionTypes []uint8, activates []bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "manageYieldSources", sources, oracles, actionTypes, activates)
}

// ManageYieldSources is a paid mutator transaction binding the contract method 0xa8e34b93.
//
// Solidity: function manageYieldSources(address[] sources, address[] oracles, uint8[] actionTypes, bool[] activates) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ManageYieldSources(sources []common.Address, oracles []common.Address, actionTypes []uint8, activates []bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageYieldSources(&_SuperVaultStrategy.TransactOpts, sources, oracles, actionTypes, activates)
}

// ManageYieldSources is a paid mutator transaction binding the contract method 0xa8e34b93.
//
// Solidity: function manageYieldSources(address[] sources, address[] oracles, uint8[] actionTypes, bool[] activates) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ManageYieldSources(sources []common.Address, oracles []common.Address, actionTypes []uint8, activates []bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageYieldSources(&_SuperVaultStrategy.TransactOpts, sources, oracles, actionTypes, activates)
}

// ProposeVaultFeeConfigUpdate is a paid mutator transaction binding the contract method 0x563ceec3.
//
// Solidity: function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ProposeVaultFeeConfigUpdate(opts *bind.TransactOpts, performanceFeeBps *big.Int, recipient common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "proposeVaultFeeConfigUpdate", performanceFeeBps, recipient)
}

// ProposeVaultFeeConfigUpdate is a paid mutator transaction binding the contract method 0x563ceec3.
//
// Solidity: function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ProposeVaultFeeConfigUpdate(performanceFeeBps *big.Int, recipient common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ProposeVaultFeeConfigUpdate(&_SuperVaultStrategy.TransactOpts, performanceFeeBps, recipient)
}

// ProposeVaultFeeConfigUpdate is a paid mutator transaction binding the contract method 0x563ceec3.
//
// Solidity: function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ProposeVaultFeeConfigUpdate(performanceFeeBps *big.Int, recipient common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ProposeVaultFeeConfigUpdate(&_SuperVaultStrategy.TransactOpts, performanceFeeBps, recipient)
}

// UpdateMaxPPSSlippage is a paid mutator transaction binding the contract method 0x545fe28a.
//
// Solidity: function updateMaxPPSSlippage(uint256 maxSlippageBps) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) UpdateMaxPPSSlippage(opts *bind.TransactOpts, maxSlippageBps *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "updateMaxPPSSlippage", maxSlippageBps)
}

// UpdateMaxPPSSlippage is a paid mutator transaction binding the contract method 0x545fe28a.
//
// Solidity: function updateMaxPPSSlippage(uint256 maxSlippageBps) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) UpdateMaxPPSSlippage(maxSlippageBps *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.UpdateMaxPPSSlippage(&_SuperVaultStrategy.TransactOpts, maxSlippageBps)
}

// UpdateMaxPPSSlippage is a paid mutator transaction binding the contract method 0x545fe28a.
//
// Solidity: function updateMaxPPSSlippage(uint256 maxSlippageBps) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) UpdateMaxPPSSlippage(maxSlippageBps *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.UpdateMaxPPSSlippage(&_SuperVaultStrategy.TransactOpts, maxSlippageBps)
}

// SuperVaultStrategyDepositHandledIterator is returned from FilterDepositHandled and is used to iterate over the raw logs and unpacked data for DepositHandled events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyDepositHandledIterator struct {
	Event *SuperVaultStrategyDepositHandled // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyDepositHandledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyDepositHandled)
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
		it.Event = new(SuperVaultStrategyDepositHandled)
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
func (it *SuperVaultStrategyDepositHandledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyDepositHandledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyDepositHandled represents a DepositHandled event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyDepositHandled struct {
	Controller common.Address
	Assets     *big.Int
	Shares     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterDepositHandled is a free log retrieval operation binding the contract event 0xa7a45ea372219103bc7d0bb545ac15937334185abf185241b18414600ed19110.
//
// Solidity: event DepositHandled(address indexed controller, uint256 assets, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterDepositHandled(opts *bind.FilterOpts, controller []common.Address) (*SuperVaultStrategyDepositHandledIterator, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "DepositHandled", controllerRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyDepositHandledIterator{contract: _SuperVaultStrategy.contract, event: "DepositHandled", logs: logs, sub: sub}, nil
}

// WatchDepositHandled is a free log subscription operation binding the contract event 0xa7a45ea372219103bc7d0bb545ac15937334185abf185241b18414600ed19110.
//
// Solidity: event DepositHandled(address indexed controller, uint256 assets, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchDepositHandled(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyDepositHandled, controller []common.Address) (event.Subscription, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "DepositHandled", controllerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyDepositHandled)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "DepositHandled", log); err != nil {
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

// ParseDepositHandled is a log parse operation binding the contract event 0xa7a45ea372219103bc7d0bb545ac15937334185abf185241b18414600ed19110.
//
// Solidity: event DepositHandled(address indexed controller, uint256 assets, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseDepositHandled(log types.Log) (*SuperVaultStrategyDepositHandled, error) {
	event := new(SuperVaultStrategyDepositHandled)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "DepositHandled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyEmergencyWithdrawableProposedIterator is returned from FilterEmergencyWithdrawableProposed and is used to iterate over the raw logs and unpacked data for EmergencyWithdrawableProposed events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyEmergencyWithdrawableProposedIterator struct {
	Event *SuperVaultStrategyEmergencyWithdrawableProposed // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyEmergencyWithdrawableProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyEmergencyWithdrawableProposed)
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
		it.Event = new(SuperVaultStrategyEmergencyWithdrawableProposed)
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
func (it *SuperVaultStrategyEmergencyWithdrawableProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyEmergencyWithdrawableProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyEmergencyWithdrawableProposed represents a EmergencyWithdrawableProposed event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyEmergencyWithdrawableProposed struct {
	NewWithdrawable bool
	EffectiveTime   *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterEmergencyWithdrawableProposed is a free log retrieval operation binding the contract event 0xbc62dd7af2eb8726f42cc4e918aa6def7d921717520ada8d161a1c4343465330.
//
// Solidity: event EmergencyWithdrawableProposed(bool newWithdrawable, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterEmergencyWithdrawableProposed(opts *bind.FilterOpts) (*SuperVaultStrategyEmergencyWithdrawableProposedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "EmergencyWithdrawableProposed")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyEmergencyWithdrawableProposedIterator{contract: _SuperVaultStrategy.contract, event: "EmergencyWithdrawableProposed", logs: logs, sub: sub}, nil
}

// WatchEmergencyWithdrawableProposed is a free log subscription operation binding the contract event 0xbc62dd7af2eb8726f42cc4e918aa6def7d921717520ada8d161a1c4343465330.
//
// Solidity: event EmergencyWithdrawableProposed(bool newWithdrawable, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchEmergencyWithdrawableProposed(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyEmergencyWithdrawableProposed) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "EmergencyWithdrawableProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyEmergencyWithdrawableProposed)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "EmergencyWithdrawableProposed", log); err != nil {
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

// ParseEmergencyWithdrawableProposed is a log parse operation binding the contract event 0xbc62dd7af2eb8726f42cc4e918aa6def7d921717520ada8d161a1c4343465330.
//
// Solidity: event EmergencyWithdrawableProposed(bool newWithdrawable, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseEmergencyWithdrawableProposed(log types.Log) (*SuperVaultStrategyEmergencyWithdrawableProposed, error) {
	event := new(SuperVaultStrategyEmergencyWithdrawableProposed)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "EmergencyWithdrawableProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyEmergencyWithdrawableUpdatedIterator is returned from FilterEmergencyWithdrawableUpdated and is used to iterate over the raw logs and unpacked data for EmergencyWithdrawableUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyEmergencyWithdrawableUpdatedIterator struct {
	Event *SuperVaultStrategyEmergencyWithdrawableUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyEmergencyWithdrawableUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyEmergencyWithdrawableUpdated)
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
		it.Event = new(SuperVaultStrategyEmergencyWithdrawableUpdated)
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
func (it *SuperVaultStrategyEmergencyWithdrawableUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyEmergencyWithdrawableUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyEmergencyWithdrawableUpdated represents a EmergencyWithdrawableUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyEmergencyWithdrawableUpdated struct {
	Withdrawable bool
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterEmergencyWithdrawableUpdated is a free log retrieval operation binding the contract event 0xe87478340fab7d5135af4c3a430eee25d6f3d97e0039b5b7b133db4106857b79.
//
// Solidity: event EmergencyWithdrawableUpdated(bool withdrawable)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterEmergencyWithdrawableUpdated(opts *bind.FilterOpts) (*SuperVaultStrategyEmergencyWithdrawableUpdatedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "EmergencyWithdrawableUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyEmergencyWithdrawableUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "EmergencyWithdrawableUpdated", logs: logs, sub: sub}, nil
}

// WatchEmergencyWithdrawableUpdated is a free log subscription operation binding the contract event 0xe87478340fab7d5135af4c3a430eee25d6f3d97e0039b5b7b133db4106857b79.
//
// Solidity: event EmergencyWithdrawableUpdated(bool withdrawable)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchEmergencyWithdrawableUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyEmergencyWithdrawableUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "EmergencyWithdrawableUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyEmergencyWithdrawableUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "EmergencyWithdrawableUpdated", log); err != nil {
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

// ParseEmergencyWithdrawableUpdated is a log parse operation binding the contract event 0xe87478340fab7d5135af4c3a430eee25d6f3d97e0039b5b7b133db4106857b79.
//
// Solidity: event EmergencyWithdrawableUpdated(bool withdrawable)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseEmergencyWithdrawableUpdated(log types.Log) (*SuperVaultStrategyEmergencyWithdrawableUpdated, error) {
	event := new(SuperVaultStrategyEmergencyWithdrawableUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "EmergencyWithdrawableUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyEmergencyWithdrawalIterator is returned from FilterEmergencyWithdrawal and is used to iterate over the raw logs and unpacked data for EmergencyWithdrawal events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyEmergencyWithdrawalIterator struct {
	Event *SuperVaultStrategyEmergencyWithdrawal // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyEmergencyWithdrawalIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyEmergencyWithdrawal)
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
		it.Event = new(SuperVaultStrategyEmergencyWithdrawal)
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
func (it *SuperVaultStrategyEmergencyWithdrawalIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyEmergencyWithdrawalIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyEmergencyWithdrawal represents a EmergencyWithdrawal event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyEmergencyWithdrawal struct {
	Recipient common.Address
	Assets    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterEmergencyWithdrawal is a free log retrieval operation binding the contract event 0x23d6711a1d031134a36921253c75aa59e967d38e369ac625992824315e204f20.
//
// Solidity: event EmergencyWithdrawal(address indexed recipient, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterEmergencyWithdrawal(opts *bind.FilterOpts, recipient []common.Address) (*SuperVaultStrategyEmergencyWithdrawalIterator, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "EmergencyWithdrawal", recipientRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyEmergencyWithdrawalIterator{contract: _SuperVaultStrategy.contract, event: "EmergencyWithdrawal", logs: logs, sub: sub}, nil
}

// WatchEmergencyWithdrawal is a free log subscription operation binding the contract event 0x23d6711a1d031134a36921253c75aa59e967d38e369ac625992824315e204f20.
//
// Solidity: event EmergencyWithdrawal(address indexed recipient, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchEmergencyWithdrawal(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyEmergencyWithdrawal, recipient []common.Address) (event.Subscription, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "EmergencyWithdrawal", recipientRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyEmergencyWithdrawal)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "EmergencyWithdrawal", log); err != nil {
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

// ParseEmergencyWithdrawal is a log parse operation binding the contract event 0x23d6711a1d031134a36921253c75aa59e967d38e369ac625992824315e204f20.
//
// Solidity: event EmergencyWithdrawal(address indexed recipient, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseEmergencyWithdrawal(log types.Log) (*SuperVaultStrategyEmergencyWithdrawal, error) {
	event := new(SuperVaultStrategyEmergencyWithdrawal)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "EmergencyWithdrawal", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyFeePaidIterator is returned from FilterFeePaid and is used to iterate over the raw logs and unpacked data for FeePaid events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyFeePaidIterator struct {
	Event *SuperVaultStrategyFeePaid // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyFeePaidIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyFeePaid)
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
		it.Event = new(SuperVaultStrategyFeePaid)
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
func (it *SuperVaultStrategyFeePaidIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyFeePaidIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyFeePaid represents a FeePaid event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyFeePaid struct {
	Recipient         common.Address
	Amount            *big.Int
	PerformanceFeeBps *big.Int
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterFeePaid is a free log retrieval operation binding the contract event 0xf3816d9cce3442fbfe3e4d36ad047b3362efdc9f2e283e77b0ecd768a0a01ef2.
//
// Solidity: event FeePaid(address indexed recipient, uint256 amount, uint256 performanceFeeBps)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterFeePaid(opts *bind.FilterOpts, recipient []common.Address) (*SuperVaultStrategyFeePaidIterator, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "FeePaid", recipientRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyFeePaidIterator{contract: _SuperVaultStrategy.contract, event: "FeePaid", logs: logs, sub: sub}, nil
}

// WatchFeePaid is a free log subscription operation binding the contract event 0xf3816d9cce3442fbfe3e4d36ad047b3362efdc9f2e283e77b0ecd768a0a01ef2.
//
// Solidity: event FeePaid(address indexed recipient, uint256 amount, uint256 performanceFeeBps)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchFeePaid(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyFeePaid, recipient []common.Address) (event.Subscription, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "FeePaid", recipientRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyFeePaid)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "FeePaid", log); err != nil {
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

// ParseFeePaid is a log parse operation binding the contract event 0xf3816d9cce3442fbfe3e4d36ad047b3362efdc9f2e283e77b0ecd768a0a01ef2.
//
// Solidity: event FeePaid(address indexed recipient, uint256 amount, uint256 performanceFeeBps)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseFeePaid(log types.Log) (*SuperVaultStrategyFeePaid, error) {
	event := new(SuperVaultStrategyFeePaid)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "FeePaid", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyFulfillHookExecutedIterator is returned from FilterFulfillHookExecuted and is used to iterate over the raw logs and unpacked data for FulfillHookExecuted events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyFulfillHookExecutedIterator struct {
	Event *SuperVaultStrategyFulfillHookExecuted // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyFulfillHookExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyFulfillHookExecuted)
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
		it.Event = new(SuperVaultStrategyFulfillHookExecuted)
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
func (it *SuperVaultStrategyFulfillHookExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyFulfillHookExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyFulfillHookExecuted represents a FulfillHookExecuted event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyFulfillHookExecuted struct {
	Hook                common.Address
	TargetedYieldSource common.Address
	HookCalldata        []byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterFulfillHookExecuted is a free log retrieval operation binding the contract event 0x8965eeca9fa7abfe57ce06ca140a412809309fe05703f910e28d53e9e8ec8ba1.
//
// Solidity: event FulfillHookExecuted(address indexed hook, address indexed targetedYieldSource, bytes hookCalldata)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterFulfillHookExecuted(opts *bind.FilterOpts, hook []common.Address, targetedYieldSource []common.Address) (*SuperVaultStrategyFulfillHookExecutedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}
	var targetedYieldSourceRule []interface{}
	for _, targetedYieldSourceItem := range targetedYieldSource {
		targetedYieldSourceRule = append(targetedYieldSourceRule, targetedYieldSourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "FulfillHookExecuted", hookRule, targetedYieldSourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyFulfillHookExecutedIterator{contract: _SuperVaultStrategy.contract, event: "FulfillHookExecuted", logs: logs, sub: sub}, nil
}

// WatchFulfillHookExecuted is a free log subscription operation binding the contract event 0x8965eeca9fa7abfe57ce06ca140a412809309fe05703f910e28d53e9e8ec8ba1.
//
// Solidity: event FulfillHookExecuted(address indexed hook, address indexed targetedYieldSource, bytes hookCalldata)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchFulfillHookExecuted(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyFulfillHookExecuted, hook []common.Address, targetedYieldSource []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}
	var targetedYieldSourceRule []interface{}
	for _, targetedYieldSourceItem := range targetedYieldSource {
		targetedYieldSourceRule = append(targetedYieldSourceRule, targetedYieldSourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "FulfillHookExecuted", hookRule, targetedYieldSourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyFulfillHookExecuted)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "FulfillHookExecuted", log); err != nil {
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

// ParseFulfillHookExecuted is a log parse operation binding the contract event 0x8965eeca9fa7abfe57ce06ca140a412809309fe05703f910e28d53e9e8ec8ba1.
//
// Solidity: event FulfillHookExecuted(address indexed hook, address indexed targetedYieldSource, bytes hookCalldata)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseFulfillHookExecuted(log types.Log) (*SuperVaultStrategyFulfillHookExecuted, error) {
	event := new(SuperVaultStrategyFulfillHookExecuted)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "FulfillHookExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyHookExecutedIterator is returned from FilterHookExecuted and is used to iterate over the raw logs and unpacked data for HookExecuted events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHookExecutedIterator struct {
	Event *SuperVaultStrategyHookExecuted // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyHookExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyHookExecuted)
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
		it.Event = new(SuperVaultStrategyHookExecuted)
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
func (it *SuperVaultStrategyHookExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyHookExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyHookExecuted represents a HookExecuted event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHookExecuted struct {
	Hook                common.Address
	PrevHook            common.Address
	TargetedYieldSource common.Address
	UsePrevHookAmount   bool
	HookCalldata        []byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterHookExecuted is a free log retrieval operation binding the contract event 0xedec66be61a678e975773689d9e1b08597890550d0a45c11e6e4014a7a67c713.
//
// Solidity: event HookExecuted(address indexed hook, address indexed prevHook, address indexed targetedYieldSource, bool usePrevHookAmount, bytes hookCalldata)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterHookExecuted(opts *bind.FilterOpts, hook []common.Address, prevHook []common.Address, targetedYieldSource []common.Address) (*SuperVaultStrategyHookExecutedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}
	var prevHookRule []interface{}
	for _, prevHookItem := range prevHook {
		prevHookRule = append(prevHookRule, prevHookItem)
	}
	var targetedYieldSourceRule []interface{}
	for _, targetedYieldSourceItem := range targetedYieldSource {
		targetedYieldSourceRule = append(targetedYieldSourceRule, targetedYieldSourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "HookExecuted", hookRule, prevHookRule, targetedYieldSourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyHookExecutedIterator{contract: _SuperVaultStrategy.contract, event: "HookExecuted", logs: logs, sub: sub}, nil
}

// WatchHookExecuted is a free log subscription operation binding the contract event 0xedec66be61a678e975773689d9e1b08597890550d0a45c11e6e4014a7a67c713.
//
// Solidity: event HookExecuted(address indexed hook, address indexed prevHook, address indexed targetedYieldSource, bool usePrevHookAmount, bytes hookCalldata)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchHookExecuted(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyHookExecuted, hook []common.Address, prevHook []common.Address, targetedYieldSource []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}
	var prevHookRule []interface{}
	for _, prevHookItem := range prevHook {
		prevHookRule = append(prevHookRule, prevHookItem)
	}
	var targetedYieldSourceRule []interface{}
	for _, targetedYieldSourceItem := range targetedYieldSource {
		targetedYieldSourceRule = append(targetedYieldSourceRule, targetedYieldSourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "HookExecuted", hookRule, prevHookRule, targetedYieldSourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyHookExecuted)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "HookExecuted", log); err != nil {
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

// ParseHookExecuted is a log parse operation binding the contract event 0xedec66be61a678e975773689d9e1b08597890550d0a45c11e6e4014a7a67c713.
//
// Solidity: event HookExecuted(address indexed hook, address indexed prevHook, address indexed targetedYieldSource, bool usePrevHookAmount, bytes hookCalldata)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseHookExecuted(log types.Log) (*SuperVaultStrategyHookExecuted, error) {
	event := new(SuperVaultStrategyHookExecuted)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "HookExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyHookRootProposedIterator is returned from FilterHookRootProposed and is used to iterate over the raw logs and unpacked data for HookRootProposed events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHookRootProposedIterator struct {
	Event *SuperVaultStrategyHookRootProposed // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyHookRootProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyHookRootProposed)
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
		it.Event = new(SuperVaultStrategyHookRootProposed)
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
func (it *SuperVaultStrategyHookRootProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyHookRootProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyHookRootProposed represents a HookRootProposed event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHookRootProposed struct {
	ProposedRoot  [32]byte
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterHookRootProposed is a free log retrieval operation binding the contract event 0x00f61e01330fc1f30df248beda57fe37643d5362e056a9b99a9cfd927cc1d074.
//
// Solidity: event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterHookRootProposed(opts *bind.FilterOpts) (*SuperVaultStrategyHookRootProposedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "HookRootProposed")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyHookRootProposedIterator{contract: _SuperVaultStrategy.contract, event: "HookRootProposed", logs: logs, sub: sub}, nil
}

// WatchHookRootProposed is a free log subscription operation binding the contract event 0x00f61e01330fc1f30df248beda57fe37643d5362e056a9b99a9cfd927cc1d074.
//
// Solidity: event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchHookRootProposed(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyHookRootProposed) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "HookRootProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyHookRootProposed)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "HookRootProposed", log); err != nil {
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

// ParseHookRootProposed is a log parse operation binding the contract event 0x00f61e01330fc1f30df248beda57fe37643d5362e056a9b99a9cfd927cc1d074.
//
// Solidity: event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseHookRootProposed(log types.Log) (*SuperVaultStrategyHookRootProposed, error) {
	event := new(SuperVaultStrategyHookRootProposed)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "HookRootProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyHookRootUpdatedIterator is returned from FilterHookRootUpdated and is used to iterate over the raw logs and unpacked data for HookRootUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHookRootUpdatedIterator struct {
	Event *SuperVaultStrategyHookRootUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyHookRootUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyHookRootUpdated)
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
		it.Event = new(SuperVaultStrategyHookRootUpdated)
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
func (it *SuperVaultStrategyHookRootUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyHookRootUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyHookRootUpdated represents a HookRootUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHookRootUpdated struct {
	NewRoot [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterHookRootUpdated is a free log retrieval operation binding the contract event 0xeac06fcc31dca2b84f8838f6463e8d3be2249718907e6d951e49a26b37ce3bc3.
//
// Solidity: event HookRootUpdated(bytes32 newRoot)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterHookRootUpdated(opts *bind.FilterOpts) (*SuperVaultStrategyHookRootUpdatedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "HookRootUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyHookRootUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "HookRootUpdated", logs: logs, sub: sub}, nil
}

// WatchHookRootUpdated is a free log subscription operation binding the contract event 0xeac06fcc31dca2b84f8838f6463e8d3be2249718907e6d951e49a26b37ce3bc3.
//
// Solidity: event HookRootUpdated(bytes32 newRoot)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchHookRootUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyHookRootUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "HookRootUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyHookRootUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "HookRootUpdated", log); err != nil {
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

// ParseHookRootUpdated is a log parse operation binding the contract event 0xeac06fcc31dca2b84f8838f6463e8d3be2249718907e6d951e49a26b37ce3bc3.
//
// Solidity: event HookRootUpdated(bytes32 newRoot)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseHookRootUpdated(log types.Log) (*SuperVaultStrategyHookRootUpdated, error) {
	event := new(SuperVaultStrategyHookRootUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "HookRootUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyHooksExecutedIterator is returned from FilterHooksExecuted and is used to iterate over the raw logs and unpacked data for HooksExecuted events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHooksExecutedIterator struct {
	Event *SuperVaultStrategyHooksExecuted // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyHooksExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyHooksExecuted)
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
		it.Event = new(SuperVaultStrategyHooksExecuted)
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
func (it *SuperVaultStrategyHooksExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyHooksExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyHooksExecuted represents a HooksExecuted event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyHooksExecuted struct {
	Hooks []common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterHooksExecuted is a free log retrieval operation binding the contract event 0xff9e16ffdb4688c2ca0a0c2405ef9a7237ef140b3830a164e6a28b69c9895ddc.
//
// Solidity: event HooksExecuted(address[] hooks)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterHooksExecuted(opts *bind.FilterOpts) (*SuperVaultStrategyHooksExecutedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "HooksExecuted")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyHooksExecutedIterator{contract: _SuperVaultStrategy.contract, event: "HooksExecuted", logs: logs, sub: sub}, nil
}

// WatchHooksExecuted is a free log subscription operation binding the contract event 0xff9e16ffdb4688c2ca0a0c2405ef9a7237ef140b3830a164e6a28b69c9895ddc.
//
// Solidity: event HooksExecuted(address[] hooks)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchHooksExecuted(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyHooksExecuted) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "HooksExecuted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyHooksExecuted)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "HooksExecuted", log); err != nil {
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

// ParseHooksExecuted is a log parse operation binding the contract event 0xff9e16ffdb4688c2ca0a0c2405ef9a7237ef140b3830a164e6a28b69c9895ddc.
//
// Solidity: event HooksExecuted(address[] hooks)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseHooksExecuted(log types.Log) (*SuperVaultStrategyHooksExecuted, error) {
	event := new(SuperVaultStrategyHooksExecuted)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "HooksExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyInitializedIterator struct {
	Event *SuperVaultStrategyInitialized // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyInitialized)
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
		it.Event = new(SuperVaultStrategyInitialized)
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
func (it *SuperVaultStrategyInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyInitialized represents a Initialized event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyInitialized struct {
	Vault         common.Address
	SuperGovernor common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x3cd5ec01b1ae7cfec6ca1863e2cd6aa25d6d1702825803ff2b7cc95010fffdc2.
//
// Solidity: event Initialized(address indexed vault, address indexed superGovernor)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterInitialized(opts *bind.FilterOpts, vault []common.Address, superGovernor []common.Address) (*SuperVaultStrategyInitializedIterator, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var superGovernorRule []interface{}
	for _, superGovernorItem := range superGovernor {
		superGovernorRule = append(superGovernorRule, superGovernorItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "Initialized", vaultRule, superGovernorRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyInitializedIterator{contract: _SuperVaultStrategy.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x3cd5ec01b1ae7cfec6ca1863e2cd6aa25d6d1702825803ff2b7cc95010fffdc2.
//
// Solidity: event Initialized(address indexed vault, address indexed superGovernor)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyInitialized, vault []common.Address, superGovernor []common.Address) (event.Subscription, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var superGovernorRule []interface{}
	for _, superGovernorItem := range superGovernor {
		superGovernorRule = append(superGovernorRule, superGovernorItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "Initialized", vaultRule, superGovernorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyInitialized)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "Initialized", log); err != nil {
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

// ParseInitialized is a log parse operation binding the contract event 0x3cd5ec01b1ae7cfec6ca1863e2cd6aa25d6d1702825803ff2b7cc95010fffdc2.
//
// Solidity: event Initialized(address indexed vault, address indexed superGovernor)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseInitialized(log types.Log) (*SuperVaultStrategyInitialized, error) {
	event := new(SuperVaultStrategyInitialized)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyMaxPPSSlippageUpdatedIterator is returned from FilterMaxPPSSlippageUpdated and is used to iterate over the raw logs and unpacked data for MaxPPSSlippageUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyMaxPPSSlippageUpdatedIterator struct {
	Event *SuperVaultStrategyMaxPPSSlippageUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyMaxPPSSlippageUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyMaxPPSSlippageUpdated)
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
		it.Event = new(SuperVaultStrategyMaxPPSSlippageUpdated)
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
func (it *SuperVaultStrategyMaxPPSSlippageUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyMaxPPSSlippageUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyMaxPPSSlippageUpdated represents a MaxPPSSlippageUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyMaxPPSSlippageUpdated struct {
	MaxSlippageBps *big.Int
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterMaxPPSSlippageUpdated is a free log retrieval operation binding the contract event 0x601e6af9a1eaa6a1c282472f960e4f70d707620a2d5320eb83176b21fbb7af59.
//
// Solidity: event MaxPPSSlippageUpdated(uint256 maxSlippageBps)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterMaxPPSSlippageUpdated(opts *bind.FilterOpts) (*SuperVaultStrategyMaxPPSSlippageUpdatedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "MaxPPSSlippageUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyMaxPPSSlippageUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "MaxPPSSlippageUpdated", logs: logs, sub: sub}, nil
}

// WatchMaxPPSSlippageUpdated is a free log subscription operation binding the contract event 0x601e6af9a1eaa6a1c282472f960e4f70d707620a2d5320eb83176b21fbb7af59.
//
// Solidity: event MaxPPSSlippageUpdated(uint256 maxSlippageBps)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchMaxPPSSlippageUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyMaxPPSSlippageUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "MaxPPSSlippageUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyMaxPPSSlippageUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "MaxPPSSlippageUpdated", log); err != nil {
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

// ParseMaxPPSSlippageUpdated is a log parse operation binding the contract event 0x601e6af9a1eaa6a1c282472f960e4f70d707620a2d5320eb83176b21fbb7af59.
//
// Solidity: event MaxPPSSlippageUpdated(uint256 maxSlippageBps)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseMaxPPSSlippageUpdated(log types.Log) (*SuperVaultStrategyMaxPPSSlippageUpdated, error) {
	event := new(SuperVaultStrategyMaxPPSSlippageUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "MaxPPSSlippageUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyPPSUpdatedIterator is returned from FilterPPSUpdated and is used to iterate over the raw logs and unpacked data for PPSUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyPPSUpdatedIterator struct {
	Event *SuperVaultStrategyPPSUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyPPSUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyPPSUpdated)
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
		it.Event = new(SuperVaultStrategyPPSUpdated)
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
func (it *SuperVaultStrategyPPSUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyPPSUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyPPSUpdated represents a PPSUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyPPSUpdated struct {
	NewPPS           *big.Int
	CalculationBlock *big.Int
	Raw              types.Log // Blockchain specific contextual infos
}

// FilterPPSUpdated is a free log retrieval operation binding the contract event 0xb6cc0c2ff0c9234f0af39df37dc4a66ff11533ec5936b359e86bb1f63a5f9b0e.
//
// Solidity: event PPSUpdated(uint256 newPPS, uint256 calculationBlock)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterPPSUpdated(opts *bind.FilterOpts) (*SuperVaultStrategyPPSUpdatedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "PPSUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyPPSUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "PPSUpdated", logs: logs, sub: sub}, nil
}

// WatchPPSUpdated is a free log subscription operation binding the contract event 0xb6cc0c2ff0c9234f0af39df37dc4a66ff11533ec5936b359e86bb1f63a5f9b0e.
//
// Solidity: event PPSUpdated(uint256 newPPS, uint256 calculationBlock)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchPPSUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyPPSUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "PPSUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyPPSUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "PPSUpdated", log); err != nil {
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

// ParsePPSUpdated is a log parse operation binding the contract event 0xb6cc0c2ff0c9234f0af39df37dc4a66ff11533ec5936b359e86bb1f63a5f9b0e.
//
// Solidity: event PPSUpdated(uint256 newPPS, uint256 calculationBlock)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParsePPSUpdated(log types.Log) (*SuperVaultStrategyPPSUpdated, error) {
	event := new(SuperVaultStrategyPPSUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "PPSUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyRedeemRequestCanceledIterator is returned from FilterRedeemRequestCanceled and is used to iterate over the raw logs and unpacked data for RedeemRequestCanceled events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestCanceledIterator struct {
	Event *SuperVaultStrategyRedeemRequestCanceled // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyRedeemRequestCanceledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyRedeemRequestCanceled)
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
		it.Event = new(SuperVaultStrategyRedeemRequestCanceled)
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
func (it *SuperVaultStrategyRedeemRequestCanceledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyRedeemRequestCanceledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyRedeemRequestCanceled represents a RedeemRequestCanceled event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestCanceled struct {
	Controller common.Address
	Shares     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterRedeemRequestCanceled is a free log retrieval operation binding the contract event 0x95c79fa73e29b5366d4d76636d7cee6df5062a878e67ddfaa9685f3a4b0ccc93.
//
// Solidity: event RedeemRequestCanceled(address indexed controller, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterRedeemRequestCanceled(opts *bind.FilterOpts, controller []common.Address) (*SuperVaultStrategyRedeemRequestCanceledIterator, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "RedeemRequestCanceled", controllerRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyRedeemRequestCanceledIterator{contract: _SuperVaultStrategy.contract, event: "RedeemRequestCanceled", logs: logs, sub: sub}, nil
}

// WatchRedeemRequestCanceled is a free log subscription operation binding the contract event 0x95c79fa73e29b5366d4d76636d7cee6df5062a878e67ddfaa9685f3a4b0ccc93.
//
// Solidity: event RedeemRequestCanceled(address indexed controller, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchRedeemRequestCanceled(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyRedeemRequestCanceled, controller []common.Address) (event.Subscription, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "RedeemRequestCanceled", controllerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyRedeemRequestCanceled)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestCanceled", log); err != nil {
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

// ParseRedeemRequestCanceled is a log parse operation binding the contract event 0x95c79fa73e29b5366d4d76636d7cee6df5062a878e67ddfaa9685f3a4b0ccc93.
//
// Solidity: event RedeemRequestCanceled(address indexed controller, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseRedeemRequestCanceled(log types.Log) (*SuperVaultStrategyRedeemRequestCanceled, error) {
	event := new(SuperVaultStrategyRedeemRequestCanceled)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestCanceled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyRedeemRequestFulfilledIterator is returned from FilterRedeemRequestFulfilled and is used to iterate over the raw logs and unpacked data for RedeemRequestFulfilled events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestFulfilledIterator struct {
	Event *SuperVaultStrategyRedeemRequestFulfilled // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyRedeemRequestFulfilledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyRedeemRequestFulfilled)
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
		it.Event = new(SuperVaultStrategyRedeemRequestFulfilled)
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
func (it *SuperVaultStrategyRedeemRequestFulfilledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyRedeemRequestFulfilledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyRedeemRequestFulfilled represents a RedeemRequestFulfilled event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestFulfilled struct {
	Controller common.Address
	Receiver   common.Address
	Assets     *big.Int
	Shares     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterRedeemRequestFulfilled is a free log retrieval operation binding the contract event 0x24111f527e6debb0efcfd4c847fc0ae4d8858cdfc72cc2fce0e757a3fce414f7.
//
// Solidity: event RedeemRequestFulfilled(address indexed controller, address indexed receiver, uint256 assets, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterRedeemRequestFulfilled(opts *bind.FilterOpts, controller []common.Address, receiver []common.Address) (*SuperVaultStrategyRedeemRequestFulfilledIterator, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}
	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "RedeemRequestFulfilled", controllerRule, receiverRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyRedeemRequestFulfilledIterator{contract: _SuperVaultStrategy.contract, event: "RedeemRequestFulfilled", logs: logs, sub: sub}, nil
}

// WatchRedeemRequestFulfilled is a free log subscription operation binding the contract event 0x24111f527e6debb0efcfd4c847fc0ae4d8858cdfc72cc2fce0e757a3fce414f7.
//
// Solidity: event RedeemRequestFulfilled(address indexed controller, address indexed receiver, uint256 assets, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchRedeemRequestFulfilled(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyRedeemRequestFulfilled, controller []common.Address, receiver []common.Address) (event.Subscription, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}
	var receiverRule []interface{}
	for _, receiverItem := range receiver {
		receiverRule = append(receiverRule, receiverItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "RedeemRequestFulfilled", controllerRule, receiverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyRedeemRequestFulfilled)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestFulfilled", log); err != nil {
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

// ParseRedeemRequestFulfilled is a log parse operation binding the contract event 0x24111f527e6debb0efcfd4c847fc0ae4d8858cdfc72cc2fce0e757a3fce414f7.
//
// Solidity: event RedeemRequestFulfilled(address indexed controller, address indexed receiver, uint256 assets, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseRedeemRequestFulfilled(log types.Log) (*SuperVaultStrategyRedeemRequestFulfilled, error) {
	event := new(SuperVaultStrategyRedeemRequestFulfilled)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestFulfilled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyRedeemRequestPlacedIterator is returned from FilterRedeemRequestPlaced and is used to iterate over the raw logs and unpacked data for RedeemRequestPlaced events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestPlacedIterator struct {
	Event *SuperVaultStrategyRedeemRequestPlaced // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyRedeemRequestPlacedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyRedeemRequestPlaced)
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
		it.Event = new(SuperVaultStrategyRedeemRequestPlaced)
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
func (it *SuperVaultStrategyRedeemRequestPlacedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyRedeemRequestPlacedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyRedeemRequestPlaced represents a RedeemRequestPlaced event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestPlaced struct {
	Controller common.Address
	Owner      common.Address
	Shares     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterRedeemRequestPlaced is a free log retrieval operation binding the contract event 0xbeb06d4f35e676c2ef7181fbfd7bf2499fe739db0a96517ae96c40ebaf2f5c6b.
//
// Solidity: event RedeemRequestPlaced(address indexed controller, address indexed owner, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterRedeemRequestPlaced(opts *bind.FilterOpts, controller []common.Address, owner []common.Address) (*SuperVaultStrategyRedeemRequestPlacedIterator, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "RedeemRequestPlaced", controllerRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyRedeemRequestPlacedIterator{contract: _SuperVaultStrategy.contract, event: "RedeemRequestPlaced", logs: logs, sub: sub}, nil
}

// WatchRedeemRequestPlaced is a free log subscription operation binding the contract event 0xbeb06d4f35e676c2ef7181fbfd7bf2499fe739db0a96517ae96c40ebaf2f5c6b.
//
// Solidity: event RedeemRequestPlaced(address indexed controller, address indexed owner, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchRedeemRequestPlaced(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyRedeemRequestPlaced, controller []common.Address, owner []common.Address) (event.Subscription, error) {

	var controllerRule []interface{}
	for _, controllerItem := range controller {
		controllerRule = append(controllerRule, controllerItem)
	}
	var ownerRule []interface{}
	for _, ownerItem := range owner {
		ownerRule = append(ownerRule, ownerItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "RedeemRequestPlaced", controllerRule, ownerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyRedeemRequestPlaced)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestPlaced", log); err != nil {
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

// ParseRedeemRequestPlaced is a log parse operation binding the contract event 0xbeb06d4f35e676c2ef7181fbfd7bf2499fe739db0a96517ae96c40ebaf2f5c6b.
//
// Solidity: event RedeemRequestPlaced(address indexed controller, address indexed owner, uint256 shares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseRedeemRequestPlaced(log types.Log) (*SuperVaultStrategyRedeemRequestPlaced, error) {
	event := new(SuperVaultStrategyRedeemRequestPlaced)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestPlaced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyRedeemRequestsFulfilledIterator is returned from FilterRedeemRequestsFulfilled and is used to iterate over the raw logs and unpacked data for RedeemRequestsFulfilled events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestsFulfilledIterator struct {
	Event *SuperVaultStrategyRedeemRequestsFulfilled // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyRedeemRequestsFulfilledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyRedeemRequestsFulfilled)
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
		it.Event = new(SuperVaultStrategyRedeemRequestsFulfilled)
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
func (it *SuperVaultStrategyRedeemRequestsFulfilledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyRedeemRequestsFulfilledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyRedeemRequestsFulfilled represents a RedeemRequestsFulfilled event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyRedeemRequestsFulfilled struct {
	Hooks           []common.Address
	Controllers     []common.Address
	ProcessedShares *big.Int
	CurrentPPS      *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterRedeemRequestsFulfilled is a free log retrieval operation binding the contract event 0xb60c22109df38dfaf6625c7de9afef9f213602f043bfa783be1c0ef783ed843e.
//
// Solidity: event RedeemRequestsFulfilled(address[] hooks, address[] controllers, uint256 processedShares, uint256 currentPPS)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterRedeemRequestsFulfilled(opts *bind.FilterOpts) (*SuperVaultStrategyRedeemRequestsFulfilledIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "RedeemRequestsFulfilled")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyRedeemRequestsFulfilledIterator{contract: _SuperVaultStrategy.contract, event: "RedeemRequestsFulfilled", logs: logs, sub: sub}, nil
}

// WatchRedeemRequestsFulfilled is a free log subscription operation binding the contract event 0xb60c22109df38dfaf6625c7de9afef9f213602f043bfa783be1c0ef783ed843e.
//
// Solidity: event RedeemRequestsFulfilled(address[] hooks, address[] controllers, uint256 processedShares, uint256 currentPPS)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchRedeemRequestsFulfilled(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyRedeemRequestsFulfilled) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "RedeemRequestsFulfilled")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyRedeemRequestsFulfilled)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestsFulfilled", log); err != nil {
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

// ParseRedeemRequestsFulfilled is a log parse operation binding the contract event 0xb60c22109df38dfaf6625c7de9afef9f213602f043bfa783be1c0ef783ed843e.
//
// Solidity: event RedeemRequestsFulfilled(address[] hooks, address[] controllers, uint256 processedShares, uint256 currentPPS)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseRedeemRequestsFulfilled(log types.Log) (*SuperVaultStrategyRedeemRequestsFulfilled, error) {
	event := new(SuperVaultStrategyRedeemRequestsFulfilled)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "RedeemRequestsFulfilled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyVaultFeeConfigProposedIterator is returned from FilterVaultFeeConfigProposed and is used to iterate over the raw logs and unpacked data for VaultFeeConfigProposed events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyVaultFeeConfigProposedIterator struct {
	Event *SuperVaultStrategyVaultFeeConfigProposed // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyVaultFeeConfigProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyVaultFeeConfigProposed)
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
		it.Event = new(SuperVaultStrategyVaultFeeConfigProposed)
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
func (it *SuperVaultStrategyVaultFeeConfigProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyVaultFeeConfigProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyVaultFeeConfigProposed represents a VaultFeeConfigProposed event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyVaultFeeConfigProposed struct {
	PerformanceFeeBps *big.Int
	Recipient         common.Address
	EffectiveTime     *big.Int
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterVaultFeeConfigProposed is a free log retrieval operation binding the contract event 0x5188b8658798521b4281d88afed6d6c2655463f96a25f198a6b07647060e5714.
//
// Solidity: event VaultFeeConfigProposed(uint256 performanceFeeBps, address indexed recipient, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterVaultFeeConfigProposed(opts *bind.FilterOpts, recipient []common.Address) (*SuperVaultStrategyVaultFeeConfigProposedIterator, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "VaultFeeConfigProposed", recipientRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyVaultFeeConfigProposedIterator{contract: _SuperVaultStrategy.contract, event: "VaultFeeConfigProposed", logs: logs, sub: sub}, nil
}

// WatchVaultFeeConfigProposed is a free log subscription operation binding the contract event 0x5188b8658798521b4281d88afed6d6c2655463f96a25f198a6b07647060e5714.
//
// Solidity: event VaultFeeConfigProposed(uint256 performanceFeeBps, address indexed recipient, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchVaultFeeConfigProposed(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyVaultFeeConfigProposed, recipient []common.Address) (event.Subscription, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "VaultFeeConfigProposed", recipientRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyVaultFeeConfigProposed)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "VaultFeeConfigProposed", log); err != nil {
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

// ParseVaultFeeConfigProposed is a log parse operation binding the contract event 0x5188b8658798521b4281d88afed6d6c2655463f96a25f198a6b07647060e5714.
//
// Solidity: event VaultFeeConfigProposed(uint256 performanceFeeBps, address indexed recipient, uint256 effectiveTime)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseVaultFeeConfigProposed(log types.Log) (*SuperVaultStrategyVaultFeeConfigProposed, error) {
	event := new(SuperVaultStrategyVaultFeeConfigProposed)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "VaultFeeConfigProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyVaultFeeConfigUpdatedIterator is returned from FilterVaultFeeConfigUpdated and is used to iterate over the raw logs and unpacked data for VaultFeeConfigUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyVaultFeeConfigUpdatedIterator struct {
	Event *SuperVaultStrategyVaultFeeConfigUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyVaultFeeConfigUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyVaultFeeConfigUpdated)
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
		it.Event = new(SuperVaultStrategyVaultFeeConfigUpdated)
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
func (it *SuperVaultStrategyVaultFeeConfigUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyVaultFeeConfigUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyVaultFeeConfigUpdated represents a VaultFeeConfigUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyVaultFeeConfigUpdated struct {
	PerformanceFeeBps *big.Int
	Recipient         common.Address
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterVaultFeeConfigUpdated is a free log retrieval operation binding the contract event 0x7ce40d3f17d02d50cdcb69904857ed5b20f515978cb42662a4714140cb2a2518.
//
// Solidity: event VaultFeeConfigUpdated(uint256 performanceFeeBps, address indexed recipient)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterVaultFeeConfigUpdated(opts *bind.FilterOpts, recipient []common.Address) (*SuperVaultStrategyVaultFeeConfigUpdatedIterator, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "VaultFeeConfigUpdated", recipientRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyVaultFeeConfigUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "VaultFeeConfigUpdated", logs: logs, sub: sub}, nil
}

// WatchVaultFeeConfigUpdated is a free log subscription operation binding the contract event 0x7ce40d3f17d02d50cdcb69904857ed5b20f515978cb42662a4714140cb2a2518.
//
// Solidity: event VaultFeeConfigUpdated(uint256 performanceFeeBps, address indexed recipient)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchVaultFeeConfigUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyVaultFeeConfigUpdated, recipient []common.Address) (event.Subscription, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "VaultFeeConfigUpdated", recipientRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyVaultFeeConfigUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "VaultFeeConfigUpdated", log); err != nil {
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

// ParseVaultFeeConfigUpdated is a log parse operation binding the contract event 0x7ce40d3f17d02d50cdcb69904857ed5b20f515978cb42662a4714140cb2a2518.
//
// Solidity: event VaultFeeConfigUpdated(uint256 performanceFeeBps, address indexed recipient)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseVaultFeeConfigUpdated(log types.Log) (*SuperVaultStrategyVaultFeeConfigUpdated, error) {
	event := new(SuperVaultStrategyVaultFeeConfigUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "VaultFeeConfigUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyYieldSourceAddedIterator is returned from FilterYieldSourceAdded and is used to iterate over the raw logs and unpacked data for YieldSourceAdded events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceAddedIterator struct {
	Event *SuperVaultStrategyYieldSourceAdded // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyYieldSourceAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyYieldSourceAdded)
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
		it.Event = new(SuperVaultStrategyYieldSourceAdded)
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
func (it *SuperVaultStrategyYieldSourceAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyYieldSourceAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyYieldSourceAdded represents a YieldSourceAdded event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceAdded struct {
	Source common.Address
	Oracle common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceAdded is a free log retrieval operation binding the contract event 0xe707395e33aba2b86eeb8427d34294bf318cfbc202805d3452f1f9a753bb77bc.
//
// Solidity: event YieldSourceAdded(address indexed source, address indexed oracle)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterYieldSourceAdded(opts *bind.FilterOpts, source []common.Address, oracle []common.Address) (*SuperVaultStrategyYieldSourceAddedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}
	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "YieldSourceAdded", sourceRule, oracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyYieldSourceAddedIterator{contract: _SuperVaultStrategy.contract, event: "YieldSourceAdded", logs: logs, sub: sub}, nil
}

// WatchYieldSourceAdded is a free log subscription operation binding the contract event 0xe707395e33aba2b86eeb8427d34294bf318cfbc202805d3452f1f9a753bb77bc.
//
// Solidity: event YieldSourceAdded(address indexed source, address indexed oracle)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchYieldSourceAdded(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyYieldSourceAdded, source []common.Address, oracle []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}
	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "YieldSourceAdded", sourceRule, oracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyYieldSourceAdded)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceAdded", log); err != nil {
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

// ParseYieldSourceAdded is a log parse operation binding the contract event 0xe707395e33aba2b86eeb8427d34294bf318cfbc202805d3452f1f9a753bb77bc.
//
// Solidity: event YieldSourceAdded(address indexed source, address indexed oracle)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseYieldSourceAdded(log types.Log) (*SuperVaultStrategyYieldSourceAdded, error) {
	event := new(SuperVaultStrategyYieldSourceAdded)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyYieldSourceDeactivatedIterator is returned from FilterYieldSourceDeactivated and is used to iterate over the raw logs and unpacked data for YieldSourceDeactivated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceDeactivatedIterator struct {
	Event *SuperVaultStrategyYieldSourceDeactivated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyYieldSourceDeactivatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyYieldSourceDeactivated)
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
		it.Event = new(SuperVaultStrategyYieldSourceDeactivated)
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
func (it *SuperVaultStrategyYieldSourceDeactivatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyYieldSourceDeactivatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyYieldSourceDeactivated represents a YieldSourceDeactivated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceDeactivated struct {
	Source common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceDeactivated is a free log retrieval operation binding the contract event 0xec4b3f6e63c2971d30ae8cc3bb93a9b7081745191aca753648c6050495ebdcbf.
//
// Solidity: event YieldSourceDeactivated(address indexed source)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterYieldSourceDeactivated(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyYieldSourceDeactivatedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "YieldSourceDeactivated", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyYieldSourceDeactivatedIterator{contract: _SuperVaultStrategy.contract, event: "YieldSourceDeactivated", logs: logs, sub: sub}, nil
}

// WatchYieldSourceDeactivated is a free log subscription operation binding the contract event 0xec4b3f6e63c2971d30ae8cc3bb93a9b7081745191aca753648c6050495ebdcbf.
//
// Solidity: event YieldSourceDeactivated(address indexed source)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchYieldSourceDeactivated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyYieldSourceDeactivated, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "YieldSourceDeactivated", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyYieldSourceDeactivated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceDeactivated", log); err != nil {
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

// ParseYieldSourceDeactivated is a log parse operation binding the contract event 0xec4b3f6e63c2971d30ae8cc3bb93a9b7081745191aca753648c6050495ebdcbf.
//
// Solidity: event YieldSourceDeactivated(address indexed source)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseYieldSourceDeactivated(log types.Log) (*SuperVaultStrategyYieldSourceDeactivated, error) {
	event := new(SuperVaultStrategyYieldSourceDeactivated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceDeactivated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyYieldSourceOracleUpdatedIterator is returned from FilterYieldSourceOracleUpdated and is used to iterate over the raw logs and unpacked data for YieldSourceOracleUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceOracleUpdatedIterator struct {
	Event *SuperVaultStrategyYieldSourceOracleUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyYieldSourceOracleUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyYieldSourceOracleUpdated)
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
		it.Event = new(SuperVaultStrategyYieldSourceOracleUpdated)
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
func (it *SuperVaultStrategyYieldSourceOracleUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyYieldSourceOracleUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyYieldSourceOracleUpdated represents a YieldSourceOracleUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceOracleUpdated struct {
	Source    common.Address
	OldOracle common.Address
	NewOracle common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceOracleUpdated is a free log retrieval operation binding the contract event 0x850afc8bf4c49f8b6f53abfe029a2997d0a83103e3ad01b1e95e7ffb6470be6d.
//
// Solidity: event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterYieldSourceOracleUpdated(opts *bind.FilterOpts, source []common.Address, oldOracle []common.Address, newOracle []common.Address) (*SuperVaultStrategyYieldSourceOracleUpdatedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}
	var oldOracleRule []interface{}
	for _, oldOracleItem := range oldOracle {
		oldOracleRule = append(oldOracleRule, oldOracleItem)
	}
	var newOracleRule []interface{}
	for _, newOracleItem := range newOracle {
		newOracleRule = append(newOracleRule, newOracleItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "YieldSourceOracleUpdated", sourceRule, oldOracleRule, newOracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyYieldSourceOracleUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "YieldSourceOracleUpdated", logs: logs, sub: sub}, nil
}

// WatchYieldSourceOracleUpdated is a free log subscription operation binding the contract event 0x850afc8bf4c49f8b6f53abfe029a2997d0a83103e3ad01b1e95e7ffb6470be6d.
//
// Solidity: event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchYieldSourceOracleUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyYieldSourceOracleUpdated, source []common.Address, oldOracle []common.Address, newOracle []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}
	var oldOracleRule []interface{}
	for _, oldOracleItem := range oldOracle {
		oldOracleRule = append(oldOracleRule, oldOracleItem)
	}
	var newOracleRule []interface{}
	for _, newOracleItem := range newOracle {
		newOracleRule = append(newOracleRule, newOracleItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "YieldSourceOracleUpdated", sourceRule, oldOracleRule, newOracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyYieldSourceOracleUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceOracleUpdated", log); err != nil {
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

// ParseYieldSourceOracleUpdated is a log parse operation binding the contract event 0x850afc8bf4c49f8b6f53abfe029a2997d0a83103e3ad01b1e95e7ffb6470be6d.
//
// Solidity: event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseYieldSourceOracleUpdated(log types.Log) (*SuperVaultStrategyYieldSourceOracleUpdated, error) {
	event := new(SuperVaultStrategyYieldSourceOracleUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceOracleUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyYieldSourceReactivatedIterator is returned from FilterYieldSourceReactivated and is used to iterate over the raw logs and unpacked data for YieldSourceReactivated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceReactivatedIterator struct {
	Event *SuperVaultStrategyYieldSourceReactivated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyYieldSourceReactivatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyYieldSourceReactivated)
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
		it.Event = new(SuperVaultStrategyYieldSourceReactivated)
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
func (it *SuperVaultStrategyYieldSourceReactivatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyYieldSourceReactivatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyYieldSourceReactivated represents a YieldSourceReactivated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceReactivated struct {
	Source common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceReactivated is a free log retrieval operation binding the contract event 0x908c3d9bb2b8258fb2635aa91f2f8093b6b6108863474c59c8449592d07adde0.
//
// Solidity: event YieldSourceReactivated(address indexed source)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterYieldSourceReactivated(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyYieldSourceReactivatedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "YieldSourceReactivated", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyYieldSourceReactivatedIterator{contract: _SuperVaultStrategy.contract, event: "YieldSourceReactivated", logs: logs, sub: sub}, nil
}

// WatchYieldSourceReactivated is a free log subscription operation binding the contract event 0x908c3d9bb2b8258fb2635aa91f2f8093b6b6108863474c59c8449592d07adde0.
//
// Solidity: event YieldSourceReactivated(address indexed source)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchYieldSourceReactivated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyYieldSourceReactivated, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "YieldSourceReactivated", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyYieldSourceReactivated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceReactivated", log); err != nil {
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

// ParseYieldSourceReactivated is a log parse operation binding the contract event 0x908c3d9bb2b8258fb2635aa91f2f8093b6b6108863474c59c8449592d07adde0.
//
// Solidity: event YieldSourceReactivated(address indexed source)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseYieldSourceReactivated(log types.Log) (*SuperVaultStrategyYieldSourceReactivated, error) {
	event := new(SuperVaultStrategyYieldSourceReactivated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceReactivated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
