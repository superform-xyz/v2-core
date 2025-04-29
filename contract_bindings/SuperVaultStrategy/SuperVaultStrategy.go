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
	Users                     []common.Address
	Hooks                     []common.Address
	HookCalldata              [][]byte
	HookProofs                [][][32]byte
	ExpectedAssetsOrSharesOut []*big.Int
}

// ISuperVaultStrategyFeeConfig is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyFeeConfig struct {
	PerformanceFeeBps *big.Int
	Recipient         common.Address
}

// ISuperVaultStrategyYieldSource is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyYieldSource struct {
	Oracle   common.Address
	IsActive bool
}

// ISuperVaultStrategyYieldSourceTVL is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyYieldSourceTVL struct {
	Source common.Address
	Tvl    *big.Int
}

// SuperVaultStrategyMetaData contains all meta data concerning the SuperVaultStrategy contract.
var SuperVaultStrategyMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"addresses\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"roleAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claimedTokens\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"emergencyWithdrawable\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"emergencyWithdrawableEffectiveTime\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"executeHooks\",\"inputs\":[{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.ExecuteArgs\",\"components\":[{\"name\":\"users\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"hooks\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"hookCalldata\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"hookProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"},{\"name\":\"expectedAssetsOrSharesOut\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeVaultFeeConfigUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getConfigInfo\",\"inputs\":[],\"outputs\":[{\"name\":\"superVaultCap_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"feeConfig_\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.FeeConfig\",\"components\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getHookInfo\",\"inputs\":[],\"outputs\":[{\"name\":\"hookRoot_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposedHookRoot_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"hookRootEffectiveTime_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getSuperVaultState\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"stateType\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getVaultInfo\",\"inputs\":[],\"outputs\":[{\"name\":\"vault_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"asset_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"vaultDecimals_\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYieldSource\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.YieldSource\",\"components\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isActive\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYieldSourceAssetsInTransitInflows\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYieldSourceSharesInTransitOutflows\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getYieldSourcesList\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleOperation\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"operation\",\"type\":\"uint8\",\"internalType\":\"enumISuperVaultStrategy.Operation\"}],\"outputs\":[{\"name\":\"assetsOrSharesOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":[{\"name\":\"vault_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"manager_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategist_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"emergencyAdmin_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"peripheryRegistry_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superVaultCap_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isHookAllowed\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proof\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"manageEmergencyWithdraw\",\"inputs\":[{\"name\":\"action\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"manageYieldSource\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actionType\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"activate\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"isAsync\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"matchRequests\",\"inputs\":[{\"name\":\"redeemUsers\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"depositUsers\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingDepositRequest\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pendingAssets\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingRedeemRequest\",\"inputs\":[{\"name\":\"controller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pendingShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeOrExecuteHookRoot\",\"inputs\":[{\"name\":\"newRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeVaultFeeConfigUpdate\",\"inputs\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposedEmergencyWithdrawable\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"setAddress\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"totalAssets\",\"inputs\":[],\"outputs\":[{\"name\":\"totalAssets_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"sourceTVLs\",\"type\":\"tuple[]\",\"internalType\":\"structISuperVaultStrategy.YieldSourceTVL[]\",\"components\":[{\"name\":\"source\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"updateSuperVaultCap\",\"inputs\":[{\"name\":\"superVaultCap_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AsyncYieldSourceInflowFulfillmentProcessed\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AsyncYieldSourceOutflowFulfillmentProcessed\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EmergencyWithdrawableProposed\",\"inputs\":[{\"name\":\"newWithdrawable\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EmergencyWithdrawableUpdated\",\"inputs\":[{\"name\":\"withdrawable\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EmergencyWithdrawal\",\"inputs\":[{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutionCompleted\",\"inputs\":[{\"name\":\"hooks\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"isFulfillment\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"usersProcessed\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"processedShares\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeeConfigUpdated\",\"inputs\":[{\"name\":\"feeBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeePaid\",\"inputs\":[{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"bps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookRootProposed\",\"inputs\":[{\"name\":\"proposedRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookRootUpdated\",\"inputs\":[{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HooksExecuted\",\"inputs\":[{\"name\":\"hooks\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"manager\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"emergencyAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"superVaultCap\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperVaultCapUpdated\",\"inputs\":[{\"name\":\"superVaultCap\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultFeeConfigProposed\",\"inputs\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultFeeConfigUpdated\",\"inputs\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceAdded\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceDeactivated\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceInflowFulfillmentProcessed\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceOracleUpdated\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oldOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceOutflowFulfillmentProcessed\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"assets\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"YieldSourceReactivated\",\"inputs\":[{\"name\":\"source\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ACTION_TYPE_DISALLOWED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ASYNC_REQUEST_BLOCKING\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CANNOT_CHANGE_TOTAL_ASSETS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CLAIMING_MORE_THAN_IN_TRANSIT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DEPOSIT_FAILURE_INVALID_TARGET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EnforcedPause\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ExpectedPause\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FULFILMENT_TYPE_UNSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INCOMPLETE_DEPOSIT_MATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_FUNDS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_SHARES\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_AMOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ASSET_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ASSET_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BALANCE_CHANGE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CANCELATION_TYPE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CONTROLLER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_DEPOSIT_FILL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_EMERGENCY_ADMIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_EMERGENCY_WITHDRAWAL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FULFILMENT_TYPE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_HOOK\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_HOOK_ROOT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_HOOK_TYPE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MAX_ALLOCATION_RATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ORACLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PERFORMANCE_FEE_BPS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PERIPHERY_REGISTRY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_REDEEM_FILL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_STRATEGIST\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SUPER_VAULT_CAP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_TIMESTAMP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_VAULT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_VAULT_CAP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_VAULT_THRESHOLD\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LIMIT_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MINIMUM_OUTPUT_AMOUNT_ASSETS_OR_SHARES_NOT_MET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MINIMUM_PREVIOUS_HOOK_OUT_AMOUNT_NOT_MET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_VALID_OUTFLOW_REQUEST\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OPERATION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REDEEMED_MORE_THAN_REQUESTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REQUEST_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESIZED_ARRAY_LENGTH_ERROR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SUPER_VAULT_CAP_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"VAULT_THRESHOLD_EXCEEDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_ALREADY_ACTIVE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_ALREADY_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_NOT_ACTIVE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"YIELD_SOURCE_ORACLE_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_EXPECTED_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_OUTPUT_AMOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_SHARES_FULFILLED\",\"inputs\":[]}]",
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

// Addresses is a free data retrieval call binding the contract method 0x699f200f.
//
// Solidity: function addresses(bytes32 role) view returns(address roleAddress)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) Addresses(opts *bind.CallOpts, role [32]byte) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "addresses", role)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Addresses is a free data retrieval call binding the contract method 0x699f200f.
//
// Solidity: function addresses(bytes32 role) view returns(address roleAddress)
func (_SuperVaultStrategy *SuperVaultStrategySession) Addresses(role [32]byte) (common.Address, error) {
	return _SuperVaultStrategy.Contract.Addresses(&_SuperVaultStrategy.CallOpts, role)
}

// Addresses is a free data retrieval call binding the contract method 0x699f200f.
//
// Solidity: function addresses(bytes32 role) view returns(address roleAddress)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) Addresses(role [32]byte) (common.Address, error) {
	return _SuperVaultStrategy.Contract.Addresses(&_SuperVaultStrategy.CallOpts, role)
}

// ClaimedTokens is a free data retrieval call binding the contract method 0xa960c65f.
//
// Solidity: function claimedTokens(address token) view returns(uint256 amount)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) ClaimedTokens(opts *bind.CallOpts, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "claimedTokens", token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ClaimedTokens is a free data retrieval call binding the contract method 0xa960c65f.
//
// Solidity: function claimedTokens(address token) view returns(uint256 amount)
func (_SuperVaultStrategy *SuperVaultStrategySession) ClaimedTokens(token common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.ClaimedTokens(&_SuperVaultStrategy.CallOpts, token)
}

// ClaimedTokens is a free data retrieval call binding the contract method 0xa960c65f.
//
// Solidity: function claimedTokens(address token) view returns(uint256 amount)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) ClaimedTokens(token common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.ClaimedTokens(&_SuperVaultStrategy.CallOpts, token)
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

// GetConfigInfo is a free data retrieval call binding the contract method 0x78a1bf05.
//
// Solidity: function getConfigInfo() view returns(uint256 superVaultCap_, (uint256,address) feeConfig_)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetConfigInfo(opts *bind.CallOpts) (struct {
	SuperVaultCap *big.Int
	FeeConfig     ISuperVaultStrategyFeeConfig
}, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getConfigInfo")

	outstruct := new(struct {
		SuperVaultCap *big.Int
		FeeConfig     ISuperVaultStrategyFeeConfig
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.SuperVaultCap = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.FeeConfig = *abi.ConvertType(out[1], new(ISuperVaultStrategyFeeConfig)).(*ISuperVaultStrategyFeeConfig)

	return *outstruct, err

}

// GetConfigInfo is a free data retrieval call binding the contract method 0x78a1bf05.
//
// Solidity: function getConfigInfo() view returns(uint256 superVaultCap_, (uint256,address) feeConfig_)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetConfigInfo() (struct {
	SuperVaultCap *big.Int
	FeeConfig     ISuperVaultStrategyFeeConfig
}, error) {
	return _SuperVaultStrategy.Contract.GetConfigInfo(&_SuperVaultStrategy.CallOpts)
}

// GetConfigInfo is a free data retrieval call binding the contract method 0x78a1bf05.
//
// Solidity: function getConfigInfo() view returns(uint256 superVaultCap_, (uint256,address) feeConfig_)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetConfigInfo() (struct {
	SuperVaultCap *big.Int
	FeeConfig     ISuperVaultStrategyFeeConfig
}, error) {
	return _SuperVaultStrategy.Contract.GetConfigInfo(&_SuperVaultStrategy.CallOpts)
}

// GetHookInfo is a free data retrieval call binding the contract method 0x650fb029.
//
// Solidity: function getHookInfo() view returns(bytes32 hookRoot_, bytes32 proposedHookRoot_, uint256 hookRootEffectiveTime_)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetHookInfo(opts *bind.CallOpts) (struct {
	HookRoot              [32]byte
	ProposedHookRoot      [32]byte
	HookRootEffectiveTime *big.Int
}, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getHookInfo")

	outstruct := new(struct {
		HookRoot              [32]byte
		ProposedHookRoot      [32]byte
		HookRootEffectiveTime *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.HookRoot = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.ProposedHookRoot = *abi.ConvertType(out[1], new([32]byte)).(*[32]byte)
	outstruct.HookRootEffectiveTime = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetHookInfo is a free data retrieval call binding the contract method 0x650fb029.
//
// Solidity: function getHookInfo() view returns(bytes32 hookRoot_, bytes32 proposedHookRoot_, uint256 hookRootEffectiveTime_)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetHookInfo() (struct {
	HookRoot              [32]byte
	ProposedHookRoot      [32]byte
	HookRootEffectiveTime *big.Int
}, error) {
	return _SuperVaultStrategy.Contract.GetHookInfo(&_SuperVaultStrategy.CallOpts)
}

// GetHookInfo is a free data retrieval call binding the contract method 0x650fb029.
//
// Solidity: function getHookInfo() view returns(bytes32 hookRoot_, bytes32 proposedHookRoot_, uint256 hookRootEffectiveTime_)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetHookInfo() (struct {
	HookRoot              [32]byte
	ProposedHookRoot      [32]byte
	HookRootEffectiveTime *big.Int
}, error) {
	return _SuperVaultStrategy.Contract.GetHookInfo(&_SuperVaultStrategy.CallOpts)
}

// GetSuperVaultState is a free data retrieval call binding the contract method 0xcf8a6ea9.
//
// Solidity: function getSuperVaultState(address owner, uint8 stateType) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetSuperVaultState(opts *bind.CallOpts, owner common.Address, stateType uint8) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getSuperVaultState", owner, stateType)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetSuperVaultState is a free data retrieval call binding the contract method 0xcf8a6ea9.
//
// Solidity: function getSuperVaultState(address owner, uint8 stateType) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetSuperVaultState(owner common.Address, stateType uint8) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetSuperVaultState(&_SuperVaultStrategy.CallOpts, owner, stateType)
}

// GetSuperVaultState is a free data retrieval call binding the contract method 0xcf8a6ea9.
//
// Solidity: function getSuperVaultState(address owner, uint8 stateType) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetSuperVaultState(owner common.Address, stateType uint8) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetSuperVaultState(&_SuperVaultStrategy.CallOpts, owner, stateType)
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

// GetYieldSourceAssetsInTransitInflows is a free data retrieval call binding the contract method 0x4a5abce1.
//
// Solidity: function getYieldSourceAssetsInTransitInflows(address source) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetYieldSourceAssetsInTransitInflows(opts *bind.CallOpts, source common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getYieldSourceAssetsInTransitInflows", source)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetYieldSourceAssetsInTransitInflows is a free data retrieval call binding the contract method 0x4a5abce1.
//
// Solidity: function getYieldSourceAssetsInTransitInflows(address source) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetYieldSourceAssetsInTransitInflows(source common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourceAssetsInTransitInflows(&_SuperVaultStrategy.CallOpts, source)
}

// GetYieldSourceAssetsInTransitInflows is a free data retrieval call binding the contract method 0x4a5abce1.
//
// Solidity: function getYieldSourceAssetsInTransitInflows(address source) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetYieldSourceAssetsInTransitInflows(source common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourceAssetsInTransitInflows(&_SuperVaultStrategy.CallOpts, source)
}

// GetYieldSourceSharesInTransitOutflows is a free data retrieval call binding the contract method 0x10793bdb.
//
// Solidity: function getYieldSourceSharesInTransitOutflows(address source) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetYieldSourceSharesInTransitOutflows(opts *bind.CallOpts, source common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getYieldSourceSharesInTransitOutflows", source)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetYieldSourceSharesInTransitOutflows is a free data retrieval call binding the contract method 0x10793bdb.
//
// Solidity: function getYieldSourceSharesInTransitOutflows(address source) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategySession) GetYieldSourceSharesInTransitOutflows(source common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourceSharesInTransitOutflows(&_SuperVaultStrategy.CallOpts, source)
}

// GetYieldSourceSharesInTransitOutflows is a free data retrieval call binding the contract method 0x10793bdb.
//
// Solidity: function getYieldSourceSharesInTransitOutflows(address source) view returns(uint256)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetYieldSourceSharesInTransitOutflows(source common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourceSharesInTransitOutflows(&_SuperVaultStrategy.CallOpts, source)
}

// GetYieldSourcesList is a free data retrieval call binding the contract method 0x7b26e709.
//
// Solidity: function getYieldSourcesList() view returns(address[])
func (_SuperVaultStrategy *SuperVaultStrategyCaller) GetYieldSourcesList(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "getYieldSourcesList")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetYieldSourcesList is a free data retrieval call binding the contract method 0x7b26e709.
//
// Solidity: function getYieldSourcesList() view returns(address[])
func (_SuperVaultStrategy *SuperVaultStrategySession) GetYieldSourcesList() ([]common.Address, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourcesList(&_SuperVaultStrategy.CallOpts)
}

// GetYieldSourcesList is a free data retrieval call binding the contract method 0x7b26e709.
//
// Solidity: function getYieldSourcesList() view returns(address[])
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) GetYieldSourcesList() ([]common.Address, error) {
	return _SuperVaultStrategy.Contract.GetYieldSourcesList(&_SuperVaultStrategy.CallOpts)
}

// IsHookAllowed is a free data retrieval call binding the contract method 0x0a8cd26c.
//
// Solidity: function isHookAllowed(address hook, bytes32[] proof) view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) IsHookAllowed(opts *bind.CallOpts, hook common.Address, proof [][32]byte) (bool, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "isHookAllowed", hook, proof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsHookAllowed is a free data retrieval call binding the contract method 0x0a8cd26c.
//
// Solidity: function isHookAllowed(address hook, bytes32[] proof) view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategySession) IsHookAllowed(hook common.Address, proof [][32]byte) (bool, error) {
	return _SuperVaultStrategy.Contract.IsHookAllowed(&_SuperVaultStrategy.CallOpts, hook, proof)
}

// IsHookAllowed is a free data retrieval call binding the contract method 0x0a8cd26c.
//
// Solidity: function isHookAllowed(address hook, bytes32[] proof) view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) IsHookAllowed(hook common.Address, proof [][32]byte) (bool, error) {
	return _SuperVaultStrategy.Contract.IsHookAllowed(&_SuperVaultStrategy.CallOpts, hook, proof)
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

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategySession) Paused() (bool, error) {
	return _SuperVaultStrategy.Contract.Paused(&_SuperVaultStrategy.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) Paused() (bool, error) {
	return _SuperVaultStrategy.Contract.Paused(&_SuperVaultStrategy.CallOpts)
}

// PendingDepositRequest is a free data retrieval call binding the contract method 0xc3702989.
//
// Solidity: function pendingDepositRequest(address controller) view returns(uint256 pendingAssets)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) PendingDepositRequest(opts *bind.CallOpts, controller common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "pendingDepositRequest", controller)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PendingDepositRequest is a free data retrieval call binding the contract method 0xc3702989.
//
// Solidity: function pendingDepositRequest(address controller) view returns(uint256 pendingAssets)
func (_SuperVaultStrategy *SuperVaultStrategySession) PendingDepositRequest(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.PendingDepositRequest(&_SuperVaultStrategy.CallOpts, controller)
}

// PendingDepositRequest is a free data retrieval call binding the contract method 0xc3702989.
//
// Solidity: function pendingDepositRequest(address controller) view returns(uint256 pendingAssets)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) PendingDepositRequest(controller common.Address) (*big.Int, error) {
	return _SuperVaultStrategy.Contract.PendingDepositRequest(&_SuperVaultStrategy.CallOpts, controller)
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

// TotalAssets is a free data retrieval call binding the contract method 0x01e1d114.
//
// Solidity: function totalAssets() view returns(uint256 totalAssets_, (address,uint256)[] sourceTVLs)
func (_SuperVaultStrategy *SuperVaultStrategyCaller) TotalAssets(opts *bind.CallOpts) (struct {
	TotalAssets *big.Int
	SourceTVLs  []ISuperVaultStrategyYieldSourceTVL
}, error) {
	var out []interface{}
	err := _SuperVaultStrategy.contract.Call(opts, &out, "totalAssets")

	outstruct := new(struct {
		TotalAssets *big.Int
		SourceTVLs  []ISuperVaultStrategyYieldSourceTVL
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.TotalAssets = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.SourceTVLs = *abi.ConvertType(out[1], new([]ISuperVaultStrategyYieldSourceTVL)).(*[]ISuperVaultStrategyYieldSourceTVL)

	return *outstruct, err

}

// TotalAssets is a free data retrieval call binding the contract method 0x01e1d114.
//
// Solidity: function totalAssets() view returns(uint256 totalAssets_, (address,uint256)[] sourceTVLs)
func (_SuperVaultStrategy *SuperVaultStrategySession) TotalAssets() (struct {
	TotalAssets *big.Int
	SourceTVLs  []ISuperVaultStrategyYieldSourceTVL
}, error) {
	return _SuperVaultStrategy.Contract.TotalAssets(&_SuperVaultStrategy.CallOpts)
}

// TotalAssets is a free data retrieval call binding the contract method 0x01e1d114.
//
// Solidity: function totalAssets() view returns(uint256 totalAssets_, (address,uint256)[] sourceTVLs)
func (_SuperVaultStrategy *SuperVaultStrategyCallerSession) TotalAssets() (struct {
	TotalAssets *big.Int
	SourceTVLs  []ISuperVaultStrategyYieldSourceTVL
}, error) {
	return _SuperVaultStrategy.Contract.TotalAssets(&_SuperVaultStrategy.CallOpts)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x03425748.
//
// Solidity: function executeHooks((address[],address[],bytes[],bytes32[][],uint256[]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ExecuteHooks(opts *bind.TransactOpts, args ISuperVaultStrategyExecuteArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "executeHooks", args)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x03425748.
//
// Solidity: function executeHooks((address[],address[],bytes[],bytes32[][],uint256[]) args) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ExecuteHooks(args ISuperVaultStrategyExecuteArgs) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ExecuteHooks(&_SuperVaultStrategy.TransactOpts, args)
}

// ExecuteHooks is a paid mutator transaction binding the contract method 0x03425748.
//
// Solidity: function executeHooks((address[],address[],bytes[],bytes32[][],uint256[]) args) returns()
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

// HandleOperation is a paid mutator transaction binding the contract method 0x165329ff.
//
// Solidity: function handleOperation(address controller, uint256 amount, uint8 operation) returns(uint256 assetsOrSharesOut)
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) HandleOperation(opts *bind.TransactOpts, controller common.Address, amount *big.Int, operation uint8) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "handleOperation", controller, amount, operation)
}

// HandleOperation is a paid mutator transaction binding the contract method 0x165329ff.
//
// Solidity: function handleOperation(address controller, uint256 amount, uint8 operation) returns(uint256 assetsOrSharesOut)
func (_SuperVaultStrategy *SuperVaultStrategySession) HandleOperation(controller common.Address, amount *big.Int, operation uint8) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.HandleOperation(&_SuperVaultStrategy.TransactOpts, controller, amount, operation)
}

// HandleOperation is a paid mutator transaction binding the contract method 0x165329ff.
//
// Solidity: function handleOperation(address controller, uint256 amount, uint8 operation) returns(uint256 assetsOrSharesOut)
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) HandleOperation(controller common.Address, amount *big.Int, operation uint8) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.HandleOperation(&_SuperVaultStrategy.TransactOpts, controller, amount, operation)
}

// Initialize is a paid mutator transaction binding the contract method 0x95b6ef0c.
//
// Solidity: function initialize(address vault_, address manager_, address strategist_, address emergencyAdmin_, address peripheryRegistry_, uint256 superVaultCap_) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) Initialize(opts *bind.TransactOpts, vault_ common.Address, manager_ common.Address, strategist_ common.Address, emergencyAdmin_ common.Address, peripheryRegistry_ common.Address, superVaultCap_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "initialize", vault_, manager_, strategist_, emergencyAdmin_, peripheryRegistry_, superVaultCap_)
}

// Initialize is a paid mutator transaction binding the contract method 0x95b6ef0c.
//
// Solidity: function initialize(address vault_, address manager_, address strategist_, address emergencyAdmin_, address peripheryRegistry_, uint256 superVaultCap_) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) Initialize(vault_ common.Address, manager_ common.Address, strategist_ common.Address, emergencyAdmin_ common.Address, peripheryRegistry_ common.Address, superVaultCap_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Initialize(&_SuperVaultStrategy.TransactOpts, vault_, manager_, strategist_, emergencyAdmin_, peripheryRegistry_, superVaultCap_)
}

// Initialize is a paid mutator transaction binding the contract method 0x95b6ef0c.
//
// Solidity: function initialize(address vault_, address manager_, address strategist_, address emergencyAdmin_, address peripheryRegistry_, uint256 superVaultCap_) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) Initialize(vault_ common.Address, manager_ common.Address, strategist_ common.Address, emergencyAdmin_ common.Address, peripheryRegistry_ common.Address, superVaultCap_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Initialize(&_SuperVaultStrategy.TransactOpts, vault_, manager_, strategist_, emergencyAdmin_, peripheryRegistry_, superVaultCap_)
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

// ManageYieldSource is a paid mutator transaction binding the contract method 0x162fb691.
//
// Solidity: function manageYieldSource(address source, address oracle, uint8 actionType, bool activate, bool isAsync) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ManageYieldSource(opts *bind.TransactOpts, source common.Address, oracle common.Address, actionType uint8, activate bool, isAsync bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "manageYieldSource", source, oracle, actionType, activate, isAsync)
}

// ManageYieldSource is a paid mutator transaction binding the contract method 0x162fb691.
//
// Solidity: function manageYieldSource(address source, address oracle, uint8 actionType, bool activate, bool isAsync) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ManageYieldSource(source common.Address, oracle common.Address, actionType uint8, activate bool, isAsync bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageYieldSource(&_SuperVaultStrategy.TransactOpts, source, oracle, actionType, activate, isAsync)
}

// ManageYieldSource is a paid mutator transaction binding the contract method 0x162fb691.
//
// Solidity: function manageYieldSource(address source, address oracle, uint8 actionType, bool activate, bool isAsync) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ManageYieldSource(source common.Address, oracle common.Address, actionType uint8, activate bool, isAsync bool) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ManageYieldSource(&_SuperVaultStrategy.TransactOpts, source, oracle, actionType, activate, isAsync)
}

// MatchRequests is a paid mutator transaction binding the contract method 0x4bb4a4fa.
//
// Solidity: function matchRequests(address[] redeemUsers, address[] depositUsers) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) MatchRequests(opts *bind.TransactOpts, redeemUsers []common.Address, depositUsers []common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "matchRequests", redeemUsers, depositUsers)
}

// MatchRequests is a paid mutator transaction binding the contract method 0x4bb4a4fa.
//
// Solidity: function matchRequests(address[] redeemUsers, address[] depositUsers) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) MatchRequests(redeemUsers []common.Address, depositUsers []common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.MatchRequests(&_SuperVaultStrategy.TransactOpts, redeemUsers, depositUsers)
}

// MatchRequests is a paid mutator transaction binding the contract method 0x4bb4a4fa.
//
// Solidity: function matchRequests(address[] redeemUsers, address[] depositUsers) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) MatchRequests(redeemUsers []common.Address, depositUsers []common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.MatchRequests(&_SuperVaultStrategy.TransactOpts, redeemUsers, depositUsers)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) Pause() (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Pause(&_SuperVaultStrategy.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) Pause() (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Pause(&_SuperVaultStrategy.TransactOpts)
}

// ProposeOrExecuteHookRoot is a paid mutator transaction binding the contract method 0xa1649678.
//
// Solidity: function proposeOrExecuteHookRoot(bytes32 newRoot) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) ProposeOrExecuteHookRoot(opts *bind.TransactOpts, newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "proposeOrExecuteHookRoot", newRoot)
}

// ProposeOrExecuteHookRoot is a paid mutator transaction binding the contract method 0xa1649678.
//
// Solidity: function proposeOrExecuteHookRoot(bytes32 newRoot) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) ProposeOrExecuteHookRoot(newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ProposeOrExecuteHookRoot(&_SuperVaultStrategy.TransactOpts, newRoot)
}

// ProposeOrExecuteHookRoot is a paid mutator transaction binding the contract method 0xa1649678.
//
// Solidity: function proposeOrExecuteHookRoot(bytes32 newRoot) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) ProposeOrExecuteHookRoot(newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.ProposeOrExecuteHookRoot(&_SuperVaultStrategy.TransactOpts, newRoot)
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

// SetAddress is a paid mutator transaction binding the contract method 0xca446dd9.
//
// Solidity: function setAddress(bytes32 role, address account) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) SetAddress(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "setAddress", role, account)
}

// SetAddress is a paid mutator transaction binding the contract method 0xca446dd9.
//
// Solidity: function setAddress(bytes32 role, address account) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) SetAddress(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.SetAddress(&_SuperVaultStrategy.TransactOpts, role, account)
}

// SetAddress is a paid mutator transaction binding the contract method 0xca446dd9.
//
// Solidity: function setAddress(bytes32 role, address account) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) SetAddress(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.SetAddress(&_SuperVaultStrategy.TransactOpts, role, account)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) Unpause() (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Unpause(&_SuperVaultStrategy.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) Unpause() (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.Unpause(&_SuperVaultStrategy.TransactOpts)
}

// UpdateSuperVaultCap is a paid mutator transaction binding the contract method 0x2bb0e253.
//
// Solidity: function updateSuperVaultCap(uint256 superVaultCap_) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactor) UpdateSuperVaultCap(opts *bind.TransactOpts, superVaultCap_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.contract.Transact(opts, "updateSuperVaultCap", superVaultCap_)
}

// UpdateSuperVaultCap is a paid mutator transaction binding the contract method 0x2bb0e253.
//
// Solidity: function updateSuperVaultCap(uint256 superVaultCap_) returns()
func (_SuperVaultStrategy *SuperVaultStrategySession) UpdateSuperVaultCap(superVaultCap_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.UpdateSuperVaultCap(&_SuperVaultStrategy.TransactOpts, superVaultCap_)
}

// UpdateSuperVaultCap is a paid mutator transaction binding the contract method 0x2bb0e253.
//
// Solidity: function updateSuperVaultCap(uint256 superVaultCap_) returns()
func (_SuperVaultStrategy *SuperVaultStrategyTransactorSession) UpdateSuperVaultCap(superVaultCap_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultStrategy.Contract.UpdateSuperVaultCap(&_SuperVaultStrategy.TransactOpts, superVaultCap_)
}

// SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedIterator is returned from FilterAsyncYieldSourceInflowFulfillmentProcessed and is used to iterate over the raw logs and unpacked data for AsyncYieldSourceInflowFulfillmentProcessed events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedIterator struct {
	Event *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed)
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
		it.Event = new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed)
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
func (it *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed represents a AsyncYieldSourceInflowFulfillmentProcessed event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed struct {
	Source common.Address
	Assets *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterAsyncYieldSourceInflowFulfillmentProcessed is a free log retrieval operation binding the contract event 0x097ee89902a07bbcea1711381c46d7e547aa590fe492f93b88272d6734ef70a3.
//
// Solidity: event AsyncYieldSourceInflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterAsyncYieldSourceInflowFulfillmentProcessed(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "AsyncYieldSourceInflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedIterator{contract: _SuperVaultStrategy.contract, event: "AsyncYieldSourceInflowFulfillmentProcessed", logs: logs, sub: sub}, nil
}

// WatchAsyncYieldSourceInflowFulfillmentProcessed is a free log subscription operation binding the contract event 0x097ee89902a07bbcea1711381c46d7e547aa590fe492f93b88272d6734ef70a3.
//
// Solidity: event AsyncYieldSourceInflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchAsyncYieldSourceInflowFulfillmentProcessed(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "AsyncYieldSourceInflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceInflowFulfillmentProcessed", log); err != nil {
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

// ParseAsyncYieldSourceInflowFulfillmentProcessed is a log parse operation binding the contract event 0x097ee89902a07bbcea1711381c46d7e547aa590fe492f93b88272d6734ef70a3.
//
// Solidity: event AsyncYieldSourceInflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseAsyncYieldSourceInflowFulfillmentProcessed(log types.Log) (*SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed, error) {
	event := new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessed)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceInflowFulfillmentProcessed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOutIterator is returned from FilterAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut and is used to iterate over the raw logs and unpacked data for AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOutIterator struct {
	Event *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOutIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut)
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
		it.Event = new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut)
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
func (it *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOutIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOutIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut represents a AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut struct {
	Source common.Address
	Assets *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut is a free log retrieval operation binding the contract event 0x75363f690c3bec01cf9532514b503c9b421a299cd62bd5103fd30e4e9a409650.
//
// Solidity: event AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOutIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOutIterator{contract: _SuperVaultStrategy.contract, event: "AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut", logs: logs, sub: sub}, nil
}

// WatchAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut is a free log subscription operation binding the contract event 0x75363f690c3bec01cf9532514b503c9b421a299cd62bd5103fd30e4e9a409650.
//
// Solidity: event AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut", log); err != nil {
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

// ParseAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut is a log parse operation binding the contract event 0x75363f690c3bec01cf9532514b503c9b421a299cd62bd5103fd30e4e9a409650.
//
// Solidity: event AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut(log types.Log) (*SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut, error) {
	event := new(SuperVaultStrategyAsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceInflowFulfillmentProcessedExcessSharesOut", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedIterator is returned from FilterAsyncYieldSourceOutflowFulfillmentProcessed and is used to iterate over the raw logs and unpacked data for AsyncYieldSourceOutflowFulfillmentProcessed events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedIterator struct {
	Event *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed)
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
		it.Event = new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed)
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
func (it *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed represents a AsyncYieldSourceOutflowFulfillmentProcessed event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed struct {
	Source common.Address
	Assets *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterAsyncYieldSourceOutflowFulfillmentProcessed is a free log retrieval operation binding the contract event 0xb03e54d42036393c901088d8f7e8914434fdea9c4e4bfbabcaf2789e1b1c76be.
//
// Solidity: event AsyncYieldSourceOutflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterAsyncYieldSourceOutflowFulfillmentProcessed(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "AsyncYieldSourceOutflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedIterator{contract: _SuperVaultStrategy.contract, event: "AsyncYieldSourceOutflowFulfillmentProcessed", logs: logs, sub: sub}, nil
}

// WatchAsyncYieldSourceOutflowFulfillmentProcessed is a free log subscription operation binding the contract event 0xb03e54d42036393c901088d8f7e8914434fdea9c4e4bfbabcaf2789e1b1c76be.
//
// Solidity: event AsyncYieldSourceOutflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchAsyncYieldSourceOutflowFulfillmentProcessed(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "AsyncYieldSourceOutflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceOutflowFulfillmentProcessed", log); err != nil {
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

// ParseAsyncYieldSourceOutflowFulfillmentProcessed is a log parse operation binding the contract event 0xb03e54d42036393c901088d8f7e8914434fdea9c4e4bfbabcaf2789e1b1c76be.
//
// Solidity: event AsyncYieldSourceOutflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseAsyncYieldSourceOutflowFulfillmentProcessed(log types.Log) (*SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed, error) {
	event := new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessed)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceOutflowFulfillmentProcessed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOutIterator is returned from FilterAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut and is used to iterate over the raw logs and unpacked data for AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOutIterator struct {
	Event *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOutIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut)
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
		it.Event = new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut)
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
func (it *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOutIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOutIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut represents a AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut struct {
	Source common.Address
	Assets *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut is a free log retrieval operation binding the contract event 0xbd26d323cd7c3458d5cf5bf2fc36956c4809fb7554ba55f13e201008b8ba6a41.
//
// Solidity: event AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOutIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOutIterator{contract: _SuperVaultStrategy.contract, event: "AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut", logs: logs, sub: sub}, nil
}

// WatchAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut is a free log subscription operation binding the contract event 0xbd26d323cd7c3458d5cf5bf2fc36956c4809fb7554ba55f13e201008b8ba6a41.
//
// Solidity: event AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut", log); err != nil {
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

// ParseAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut is a log parse operation binding the contract event 0xbd26d323cd7c3458d5cf5bf2fc36956c4809fb7554ba55f13e201008b8ba6a41.
//
// Solidity: event AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut(log types.Log) (*SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut, error) {
	event := new(SuperVaultStrategyAsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "AsyncYieldSourceOutflowFulfillmentProcessedExcessAssetsOut", log); err != nil {
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

// SuperVaultStrategyExecutionCompletedIterator is returned from FilterExecutionCompleted and is used to iterate over the raw logs and unpacked data for ExecutionCompleted events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyExecutionCompletedIterator struct {
	Event *SuperVaultStrategyExecutionCompleted // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyExecutionCompletedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyExecutionCompleted)
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
		it.Event = new(SuperVaultStrategyExecutionCompleted)
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
func (it *SuperVaultStrategyExecutionCompletedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyExecutionCompletedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyExecutionCompleted represents a ExecutionCompleted event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyExecutionCompleted struct {
	Hooks           []common.Address
	IsFulfillment   bool
	UsersProcessed  *big.Int
	ProcessedShares *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterExecutionCompleted is a free log retrieval operation binding the contract event 0x2fa8a9095cfd1b99771cb3aa4eddfa7aacb563c30364df76aa5996d6019a004c.
//
// Solidity: event ExecutionCompleted(address[] hooks, bool isFulfillment, uint256 usersProcessed, uint256 processedShares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterExecutionCompleted(opts *bind.FilterOpts) (*SuperVaultStrategyExecutionCompletedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "ExecutionCompleted")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyExecutionCompletedIterator{contract: _SuperVaultStrategy.contract, event: "ExecutionCompleted", logs: logs, sub: sub}, nil
}

// WatchExecutionCompleted is a free log subscription operation binding the contract event 0x2fa8a9095cfd1b99771cb3aa4eddfa7aacb563c30364df76aa5996d6019a004c.
//
// Solidity: event ExecutionCompleted(address[] hooks, bool isFulfillment, uint256 usersProcessed, uint256 processedShares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchExecutionCompleted(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyExecutionCompleted) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "ExecutionCompleted")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyExecutionCompleted)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "ExecutionCompleted", log); err != nil {
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

// ParseExecutionCompleted is a log parse operation binding the contract event 0x2fa8a9095cfd1b99771cb3aa4eddfa7aacb563c30364df76aa5996d6019a004c.
//
// Solidity: event ExecutionCompleted(address[] hooks, bool isFulfillment, uint256 usersProcessed, uint256 processedShares)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseExecutionCompleted(log types.Log) (*SuperVaultStrategyExecutionCompleted, error) {
	event := new(SuperVaultStrategyExecutionCompleted)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "ExecutionCompleted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyFeeConfigUpdatedIterator is returned from FilterFeeConfigUpdated and is used to iterate over the raw logs and unpacked data for FeeConfigUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyFeeConfigUpdatedIterator struct {
	Event *SuperVaultStrategyFeeConfigUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyFeeConfigUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyFeeConfigUpdated)
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
		it.Event = new(SuperVaultStrategyFeeConfigUpdated)
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
func (it *SuperVaultStrategyFeeConfigUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyFeeConfigUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyFeeConfigUpdated represents a FeeConfigUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyFeeConfigUpdated struct {
	FeeBps    *big.Int
	Recipient common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterFeeConfigUpdated is a free log retrieval operation binding the contract event 0xe125ae54d7ba2b06e6f44852861516acb2dd2692cf41fb127fa03252f15b334e.
//
// Solidity: event FeeConfigUpdated(uint256 feeBps, address indexed recipient)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterFeeConfigUpdated(opts *bind.FilterOpts, recipient []common.Address) (*SuperVaultStrategyFeeConfigUpdatedIterator, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "FeeConfigUpdated", recipientRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyFeeConfigUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "FeeConfigUpdated", logs: logs, sub: sub}, nil
}

// WatchFeeConfigUpdated is a free log subscription operation binding the contract event 0xe125ae54d7ba2b06e6f44852861516acb2dd2692cf41fb127fa03252f15b334e.
//
// Solidity: event FeeConfigUpdated(uint256 feeBps, address indexed recipient)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchFeeConfigUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyFeeConfigUpdated, recipient []common.Address) (event.Subscription, error) {

	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "FeeConfigUpdated", recipientRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyFeeConfigUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "FeeConfigUpdated", log); err != nil {
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

// ParseFeeConfigUpdated is a log parse operation binding the contract event 0xe125ae54d7ba2b06e6f44852861516acb2dd2692cf41fb127fa03252f15b334e.
//
// Solidity: event FeeConfigUpdated(uint256 feeBps, address indexed recipient)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseFeeConfigUpdated(log types.Log) (*SuperVaultStrategyFeeConfigUpdated, error) {
	event := new(SuperVaultStrategyFeeConfigUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "FeeConfigUpdated", log); err != nil {
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
	Recipient common.Address
	Assets    *big.Int
	Bps       *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterFeePaid is a free log retrieval operation binding the contract event 0xf3816d9cce3442fbfe3e4d36ad047b3362efdc9f2e283e77b0ecd768a0a01ef2.
//
// Solidity: event FeePaid(address indexed recipient, uint256 assets, uint256 bps)
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
// Solidity: event FeePaid(address indexed recipient, uint256 assets, uint256 bps)
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
// Solidity: event FeePaid(address indexed recipient, uint256 assets, uint256 bps)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseFeePaid(log types.Log) (*SuperVaultStrategyFeePaid, error) {
	event := new(SuperVaultStrategyFeePaid)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "FeePaid", log); err != nil {
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
	Vault          common.Address
	Manager        common.Address
	Strategist     common.Address
	EmergencyAdmin common.Address
	SuperVaultCap  *big.Int
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0xb9bf2986b44bc4d312da1451b923a8676446e697dc0d76abe92d41a005207713.
//
// Solidity: event Initialized(address indexed vault, address indexed manager, address indexed strategist, address emergencyAdmin, uint256 superVaultCap)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterInitialized(opts *bind.FilterOpts, vault []common.Address, manager []common.Address, strategist []common.Address) (*SuperVaultStrategyInitializedIterator, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var managerRule []interface{}
	for _, managerItem := range manager {
		managerRule = append(managerRule, managerItem)
	}
	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "Initialized", vaultRule, managerRule, strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyInitializedIterator{contract: _SuperVaultStrategy.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0xb9bf2986b44bc4d312da1451b923a8676446e697dc0d76abe92d41a005207713.
//
// Solidity: event Initialized(address indexed vault, address indexed manager, address indexed strategist, address emergencyAdmin, uint256 superVaultCap)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyInitialized, vault []common.Address, manager []common.Address, strategist []common.Address) (event.Subscription, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var managerRule []interface{}
	for _, managerItem := range manager {
		managerRule = append(managerRule, managerItem)
	}
	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "Initialized", vaultRule, managerRule, strategistRule)
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

// ParseInitialized is a log parse operation binding the contract event 0xb9bf2986b44bc4d312da1451b923a8676446e697dc0d76abe92d41a005207713.
//
// Solidity: event Initialized(address indexed vault, address indexed manager, address indexed strategist, address emergencyAdmin, uint256 superVaultCap)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseInitialized(log types.Log) (*SuperVaultStrategyInitialized, error) {
	event := new(SuperVaultStrategyInitialized)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyPausedIterator struct {
	Event *SuperVaultStrategyPaused // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyPaused)
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
		it.Event = new(SuperVaultStrategyPaused)
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
func (it *SuperVaultStrategyPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyPaused represents a Paused event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterPaused(opts *bind.FilterOpts) (*SuperVaultStrategyPausedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyPausedIterator{contract: _SuperVaultStrategy.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyPaused) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyPaused)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "Paused", log); err != nil {
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

// ParsePaused is a log parse operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParsePaused(log types.Log) (*SuperVaultStrategyPaused, error) {
	event := new(SuperVaultStrategyPaused)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategySuperVaultCapUpdatedIterator is returned from FilterSuperVaultCapUpdated and is used to iterate over the raw logs and unpacked data for SuperVaultCapUpdated events raised by the SuperVaultStrategy contract.
type SuperVaultStrategySuperVaultCapUpdatedIterator struct {
	Event *SuperVaultStrategySuperVaultCapUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategySuperVaultCapUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategySuperVaultCapUpdated)
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
		it.Event = new(SuperVaultStrategySuperVaultCapUpdated)
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
func (it *SuperVaultStrategySuperVaultCapUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategySuperVaultCapUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategySuperVaultCapUpdated represents a SuperVaultCapUpdated event raised by the SuperVaultStrategy contract.
type SuperVaultStrategySuperVaultCapUpdated struct {
	SuperVaultCap *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterSuperVaultCapUpdated is a free log retrieval operation binding the contract event 0x2b3deb0c59064ab2c93dc8db35e806828ecd039562bc7a65451f752d2046c2a0.
//
// Solidity: event SuperVaultCapUpdated(uint256 superVaultCap)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterSuperVaultCapUpdated(opts *bind.FilterOpts) (*SuperVaultStrategySuperVaultCapUpdatedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "SuperVaultCapUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategySuperVaultCapUpdatedIterator{contract: _SuperVaultStrategy.contract, event: "SuperVaultCapUpdated", logs: logs, sub: sub}, nil
}

// WatchSuperVaultCapUpdated is a free log subscription operation binding the contract event 0x2b3deb0c59064ab2c93dc8db35e806828ecd039562bc7a65451f752d2046c2a0.
//
// Solidity: event SuperVaultCapUpdated(uint256 superVaultCap)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchSuperVaultCapUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategySuperVaultCapUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "SuperVaultCapUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategySuperVaultCapUpdated)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "SuperVaultCapUpdated", log); err != nil {
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

// ParseSuperVaultCapUpdated is a log parse operation binding the contract event 0x2b3deb0c59064ab2c93dc8db35e806828ecd039562bc7a65451f752d2046c2a0.
//
// Solidity: event SuperVaultCapUpdated(uint256 superVaultCap)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseSuperVaultCapUpdated(log types.Log) (*SuperVaultStrategySuperVaultCapUpdated, error) {
	event := new(SuperVaultStrategySuperVaultCapUpdated)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "SuperVaultCapUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultStrategyUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyUnpausedIterator struct {
	Event *SuperVaultStrategyUnpaused // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyUnpaused)
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
		it.Event = new(SuperVaultStrategyUnpaused)
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
func (it *SuperVaultStrategyUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyUnpaused represents a Unpaused event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterUnpaused(opts *bind.FilterOpts) (*SuperVaultStrategyUnpausedIterator, error) {

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyUnpausedIterator{contract: _SuperVaultStrategy.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyUnpaused) (event.Subscription, error) {

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyUnpaused)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "Unpaused", log); err != nil {
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

// ParseUnpaused is a log parse operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseUnpaused(log types.Log) (*SuperVaultStrategyUnpaused, error) {
	event := new(SuperVaultStrategyUnpaused)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "Unpaused", log); err != nil {
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

// SuperVaultStrategyYieldSourceInflowFulfillmentProcessedIterator is returned from FilterYieldSourceInflowFulfillmentProcessed and is used to iterate over the raw logs and unpacked data for YieldSourceInflowFulfillmentProcessed events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceInflowFulfillmentProcessedIterator struct {
	Event *SuperVaultStrategyYieldSourceInflowFulfillmentProcessed // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyYieldSourceInflowFulfillmentProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyYieldSourceInflowFulfillmentProcessed)
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
		it.Event = new(SuperVaultStrategyYieldSourceInflowFulfillmentProcessed)
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
func (it *SuperVaultStrategyYieldSourceInflowFulfillmentProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyYieldSourceInflowFulfillmentProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyYieldSourceInflowFulfillmentProcessed represents a YieldSourceInflowFulfillmentProcessed event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceInflowFulfillmentProcessed struct {
	Source common.Address
	Assets *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceInflowFulfillmentProcessed is a free log retrieval operation binding the contract event 0x2544eb80ba191928b329105f173d4b4619f3340a3d4d01f14925def998128e57.
//
// Solidity: event YieldSourceInflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterYieldSourceInflowFulfillmentProcessed(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyYieldSourceInflowFulfillmentProcessedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "YieldSourceInflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyYieldSourceInflowFulfillmentProcessedIterator{contract: _SuperVaultStrategy.contract, event: "YieldSourceInflowFulfillmentProcessed", logs: logs, sub: sub}, nil
}

// WatchYieldSourceInflowFulfillmentProcessed is a free log subscription operation binding the contract event 0x2544eb80ba191928b329105f173d4b4619f3340a3d4d01f14925def998128e57.
//
// Solidity: event YieldSourceInflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchYieldSourceInflowFulfillmentProcessed(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyYieldSourceInflowFulfillmentProcessed, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "YieldSourceInflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyYieldSourceInflowFulfillmentProcessed)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceInflowFulfillmentProcessed", log); err != nil {
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

// ParseYieldSourceInflowFulfillmentProcessed is a log parse operation binding the contract event 0x2544eb80ba191928b329105f173d4b4619f3340a3d4d01f14925def998128e57.
//
// Solidity: event YieldSourceInflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseYieldSourceInflowFulfillmentProcessed(log types.Log) (*SuperVaultStrategyYieldSourceInflowFulfillmentProcessed, error) {
	event := new(SuperVaultStrategyYieldSourceInflowFulfillmentProcessed)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceInflowFulfillmentProcessed", log); err != nil {
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

// SuperVaultStrategyYieldSourceOutflowFulfillmentProcessedIterator is returned from FilterYieldSourceOutflowFulfillmentProcessed and is used to iterate over the raw logs and unpacked data for YieldSourceOutflowFulfillmentProcessed events raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceOutflowFulfillmentProcessedIterator struct {
	Event *SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed // Event containing the contract specifics and raw log

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
func (it *SuperVaultStrategyYieldSourceOutflowFulfillmentProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed)
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
		it.Event = new(SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed)
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
func (it *SuperVaultStrategyYieldSourceOutflowFulfillmentProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultStrategyYieldSourceOutflowFulfillmentProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed represents a YieldSourceOutflowFulfillmentProcessed event raised by the SuperVaultStrategy contract.
type SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed struct {
	Source common.Address
	Assets *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterYieldSourceOutflowFulfillmentProcessed is a free log retrieval operation binding the contract event 0xc29771abfe922fe31214775793a74f7fe76938290013da1f03f9924f84ea9eb5.
//
// Solidity: event YieldSourceOutflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) FilterYieldSourceOutflowFulfillmentProcessed(opts *bind.FilterOpts, source []common.Address) (*SuperVaultStrategyYieldSourceOutflowFulfillmentProcessedIterator, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.FilterLogs(opts, "YieldSourceOutflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultStrategyYieldSourceOutflowFulfillmentProcessedIterator{contract: _SuperVaultStrategy.contract, event: "YieldSourceOutflowFulfillmentProcessed", logs: logs, sub: sub}, nil
}

// WatchYieldSourceOutflowFulfillmentProcessed is a free log subscription operation binding the contract event 0xc29771abfe922fe31214775793a74f7fe76938290013da1f03f9924f84ea9eb5.
//
// Solidity: event YieldSourceOutflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) WatchYieldSourceOutflowFulfillmentProcessed(opts *bind.WatchOpts, sink chan<- *SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed, source []common.Address) (event.Subscription, error) {

	var sourceRule []interface{}
	for _, sourceItem := range source {
		sourceRule = append(sourceRule, sourceItem)
	}

	logs, sub, err := _SuperVaultStrategy.contract.WatchLogs(opts, "YieldSourceOutflowFulfillmentProcessed", sourceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed)
				if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceOutflowFulfillmentProcessed", log); err != nil {
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

// ParseYieldSourceOutflowFulfillmentProcessed is a log parse operation binding the contract event 0xc29771abfe922fe31214775793a74f7fe76938290013da1f03f9924f84ea9eb5.
//
// Solidity: event YieldSourceOutflowFulfillmentProcessed(address indexed source, uint256 assets)
func (_SuperVaultStrategy *SuperVaultStrategyFilterer) ParseYieldSourceOutflowFulfillmentProcessed(log types.Log) (*SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed, error) {
	event := new(SuperVaultStrategyYieldSourceOutflowFulfillmentProcessed)
	if err := _SuperVaultStrategy.contract.UnpackLog(event, "YieldSourceOutflowFulfillmentProcessed", log); err != nil {
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
