// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperVaultAggregator

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

// ISuperVaultAggregatorBatchForwardPPSArgs is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultAggregatorBatchForwardPPSArgs struct {
	Strategies      []common.Address
	Ppss            []*big.Int
	PpsStdevs       []*big.Int
	ValidatorSets   []*big.Int
	TotalValidators []*big.Int
	Timestamps      []*big.Int
}

// ISuperVaultAggregatorForwardPPSArgs is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultAggregatorForwardPPSArgs struct {
	Strategy        common.Address
	IsExempt        bool
	Pps             *big.Int
	PpsStdev        *big.Int
	ValidatorSet    *big.Int
	TotalValidators *big.Int
	Timestamp       *big.Int
	UpkeepCost      *big.Int
}

// ISuperVaultAggregatorVaultCreationParams is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultAggregatorVaultCreationParams struct {
	Asset             common.Address
	Name              string
	Symbol            string
	MainStrategist    common.Address
	MinUpdateInterval *big.Int
	MaxStaleness      *big.Int
	FeeConfig         ISuperVaultStrategyFeeConfig
}

// ISuperVaultStrategyFeeConfig is an auto generated low-level Go binding around an user-defined struct.
type ISuperVaultStrategyFeeConfig struct {
	PerformanceFeeBps *big.Int
	Recipient         common.Address
}

// SuperVaultAggregatorMetaData contains all meta data concerning the SuperVaultAggregator contract.
var SuperVaultAggregatorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superGovernor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"ESCROW_IMPLEMENTATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PPS_DECIMALS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"STRATEGY_IMPLEMENTATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_GOVERNOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperGovernor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"VAULT_IMPLEMENTATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"addAuthorizedCaller\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addSecondaryStrategist\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"batchForwardPPS\",\"inputs\":[{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultAggregator.BatchForwardPPSArgs\",\"components\":[{\"name\":\"strategies\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ppss\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"ppsStdevs\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"validatorSets\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"totalValidators\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"timestamps\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"changePrimaryStrategist\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newStrategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"createVault\",\"inputs\":[{\"name\":\"params\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultAggregator.VaultCreationParams\",\"components\":[{\"name\":\"asset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"mainStrategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"minUpdateInterval\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"maxStaleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"feeConfig\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultStrategy.FeeConfig\",\"components\":[{\"name\":\"performanceFeeBps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"superVault\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"escrow\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"depositUpkeep\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeChangePrimaryStrategist\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeGlobalHooksRootUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeStrategyHooksRootUpdate\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"forwardPPS\",\"inputs\":[{\"name\":\"updateAuthority\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structISuperVaultAggregator.ForwardPPSArgs\",\"components\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isExempt\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"pps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ppsStdev\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"validatorSet\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"totalValidators\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"upkeepCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getAllSuperVaultEscrows\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAllSuperVaultStrategies\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAllSuperVaults\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAuthorizedCallers\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"callers\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getGlobalHooksRoot\",\"inputs\":[],\"outputs\":[{\"name\":\"root\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastUpdateTimestamp\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getMainStrategist\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getMaxStaleness\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"staleness\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getMinUpdateInterval\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"interval\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPPS\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pps\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPPSVerificationThresholds\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"dispersionThreshold\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"deviationThreshold\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"mnThreshold\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPPSWithStdDev\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"pps\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ppsStdev\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposedGlobalHooksRoot\",\"inputs\":[],\"outputs\":[{\"name\":\"root\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposedStrategyHooksRoot\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"root\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getSecondaryStrategists\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStrategyHooksRoot\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"root\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getUpkeepBalance\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isAnyStrategist\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isGlobalHooksRootActive\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isGlobalHooksRootVetoed\",\"inputs\":[],\"outputs\":[{\"name\":\"vetoed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isMainStrategist\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isSecondaryStrategist\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isStrategyHooksRootVetoed\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"vetoed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isStrategyPaused\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isPaused\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeChangePrimaryStrategist\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newStrategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeGlobalHooksRoot\",\"inputs\":[{\"name\":\"newRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeStrategyHooksRoot\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeAuthorizedCaller\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeSecondaryStrategist\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setGlobalHooksRootVetoStatus\",\"inputs\":[{\"name\":\"vetoed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setStrategyHooksRootVetoStatus\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"vetoed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superVaultEscrows\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superVaultStrategies\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superVaults\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"updatePPSVerificationThresholds\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dispersionThreshold_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"deviationThreshold_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"mnThreshold_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateHook\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hookArgs\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"globalProof\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"strategyProof\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[{\"name\":\"isValid\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"validateHooks\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hooksArgs\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"globalProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"},{\"name\":\"strategyProofs\",\"type\":\"bytes32[][]\",\"internalType\":\"bytes32[][]\"}],\"outputs\":[{\"name\":\"validHooks\",\"type\":\"bool[]\",\"internalType\":\"bool[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"withdrawUpkeep\",\"inputs\":[{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AuthorizedCallerAdded\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"caller\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AuthorizedCallerRemoved\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"caller\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"GlobalHooksRootUpdateProposed\",\"inputs\":[{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"GlobalHooksRootUpdated\",\"inputs\":[{\"name\":\"oldRoot\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"GlobalHooksRootVetoStatusChanged\",\"inputs\":[{\"name\":\"vetoed\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"GlobalHooksRootVetoed\",\"inputs\":[{\"name\":\"guardian\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PPSUpdated\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"pps\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"ppsStdev\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"validatorSet\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"totalValidators\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PPSVerificationThresholdsUpdated\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"dispersionThreshold\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"deviationThreshold\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"mnThreshold\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PrimaryStrategistChangeProposed\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"proposer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newStrategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PrimaryStrategistChanged\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oldStrategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newStrategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PrimaryStrategistChangedToSuperform\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oldStrategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newStrategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SecondaryStrategistAdded\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SecondaryStrategistRemoved\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StaleUpdate\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"updateAuthority\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyCheckFailed\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"reason\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyHooksRootUpdateProposed\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"proposer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyHooksRootUpdated\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oldRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyHooksRootVetoStatusChanged\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"vetoed\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyHooksRootVetoed\",\"inputs\":[{\"name\":\"guardian\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyPaused\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategyUnpaused\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepCostUpdated\",\"inputs\":[{\"name\":\"oldCost\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"newCost\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepDeposited\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepSpent\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepWithdrawn\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultDeployed\",\"inputs\":[{\"name\":\"vault\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"escrow\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"asset\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"name\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"symbol\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CALLER_ALREADY_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CALLER_NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CANNOT_REMOVE_LAST_STRATEGIST\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FailedDeployment\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_VALIDATION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INDEX_OUT_OF_BOUNDS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_UPKEEP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_UPKEEP_BALANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ARRAY_LENGTH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InsufficientBalance\",\"inputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"needed\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"NOT_A_GUARDIAN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_GLOBAL_ROOT_CHANGE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_ROOT_UPDATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_STRATEGIST_CHANGE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ROOT_UPDATE_NOT_READY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGIST_ALREADY_EXISTS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGIST_CHANGE_NOT_READY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGIST_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TIMELOCK_NOT_EXPIRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED_CALLER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED_PPS_ORACLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNAUTHORIZED_UPDATE_AUTHORITY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNKNOWN_STRATEGY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UPDATE_TOO_FREQUENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UPDATE_TOO_STALE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_PAUSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ARRAY_LENGTH\",\"inputs\":[]}]",
}

// SuperVaultAggregatorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperVaultAggregatorMetaData.ABI instead.
var SuperVaultAggregatorABI = SuperVaultAggregatorMetaData.ABI

// SuperVaultAggregator is an auto generated Go binding around an Ethereum contract.
type SuperVaultAggregator struct {
	SuperVaultAggregatorCaller     // Read-only binding to the contract
	SuperVaultAggregatorTransactor // Write-only binding to the contract
	SuperVaultAggregatorFilterer   // Log filterer for contract events
}

// SuperVaultAggregatorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperVaultAggregatorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultAggregatorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperVaultAggregatorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultAggregatorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperVaultAggregatorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperVaultAggregatorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperVaultAggregatorSession struct {
	Contract     *SuperVaultAggregator // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// SuperVaultAggregatorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperVaultAggregatorCallerSession struct {
	Contract *SuperVaultAggregatorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// SuperVaultAggregatorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperVaultAggregatorTransactorSession struct {
	Contract     *SuperVaultAggregatorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// SuperVaultAggregatorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperVaultAggregatorRaw struct {
	Contract *SuperVaultAggregator // Generic contract binding to access the raw methods on
}

// SuperVaultAggregatorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperVaultAggregatorCallerRaw struct {
	Contract *SuperVaultAggregatorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperVaultAggregatorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperVaultAggregatorTransactorRaw struct {
	Contract *SuperVaultAggregatorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperVaultAggregator creates a new instance of SuperVaultAggregator, bound to a specific deployed contract.
func NewSuperVaultAggregator(address common.Address, backend bind.ContractBackend) (*SuperVaultAggregator, error) {
	contract, err := bindSuperVaultAggregator(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregator{SuperVaultAggregatorCaller: SuperVaultAggregatorCaller{contract: contract}, SuperVaultAggregatorTransactor: SuperVaultAggregatorTransactor{contract: contract}, SuperVaultAggregatorFilterer: SuperVaultAggregatorFilterer{contract: contract}}, nil
}

// NewSuperVaultAggregatorCaller creates a new read-only instance of SuperVaultAggregator, bound to a specific deployed contract.
func NewSuperVaultAggregatorCaller(address common.Address, caller bind.ContractCaller) (*SuperVaultAggregatorCaller, error) {
	contract, err := bindSuperVaultAggregator(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorCaller{contract: contract}, nil
}

// NewSuperVaultAggregatorTransactor creates a new write-only instance of SuperVaultAggregator, bound to a specific deployed contract.
func NewSuperVaultAggregatorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperVaultAggregatorTransactor, error) {
	contract, err := bindSuperVaultAggregator(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorTransactor{contract: contract}, nil
}

// NewSuperVaultAggregatorFilterer creates a new log filterer instance of SuperVaultAggregator, bound to a specific deployed contract.
func NewSuperVaultAggregatorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperVaultAggregatorFilterer, error) {
	contract, err := bindSuperVaultAggregator(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorFilterer{contract: contract}, nil
}

// bindSuperVaultAggregator binds a generic wrapper to an already deployed contract.
func bindSuperVaultAggregator(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperVaultAggregatorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultAggregator *SuperVaultAggregatorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultAggregator.Contract.SuperVaultAggregatorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultAggregator *SuperVaultAggregatorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.SuperVaultAggregatorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultAggregator *SuperVaultAggregatorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.SuperVaultAggregatorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperVaultAggregator *SuperVaultAggregatorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperVaultAggregator.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.contract.Transact(opts, method, params...)
}

// ESCROWIMPLEMENTATION is a free data retrieval call binding the contract method 0x1de18ae6.
//
// Solidity: function ESCROW_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) ESCROWIMPLEMENTATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "ESCROW_IMPLEMENTATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ESCROWIMPLEMENTATION is a free data retrieval call binding the contract method 0x1de18ae6.
//
// Solidity: function ESCROW_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ESCROWIMPLEMENTATION() (common.Address, error) {
	return _SuperVaultAggregator.Contract.ESCROWIMPLEMENTATION(&_SuperVaultAggregator.CallOpts)
}

// ESCROWIMPLEMENTATION is a free data retrieval call binding the contract method 0x1de18ae6.
//
// Solidity: function ESCROW_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) ESCROWIMPLEMENTATION() (common.Address, error) {
	return _SuperVaultAggregator.Contract.ESCROWIMPLEMENTATION(&_SuperVaultAggregator.CallOpts)
}

// PPSDECIMALS is a free data retrieval call binding the contract method 0x13b56ce7.
//
// Solidity: function PPS_DECIMALS() view returns(uint256)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) PPSDECIMALS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "PPS_DECIMALS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PPSDECIMALS is a free data retrieval call binding the contract method 0x13b56ce7.
//
// Solidity: function PPS_DECIMALS() view returns(uint256)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) PPSDECIMALS() (*big.Int, error) {
	return _SuperVaultAggregator.Contract.PPSDECIMALS(&_SuperVaultAggregator.CallOpts)
}

// PPSDECIMALS is a free data retrieval call binding the contract method 0x13b56ce7.
//
// Solidity: function PPS_DECIMALS() view returns(uint256)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) PPSDECIMALS() (*big.Int, error) {
	return _SuperVaultAggregator.Contract.PPSDECIMALS(&_SuperVaultAggregator.CallOpts)
}

// STRATEGYIMPLEMENTATION is a free data retrieval call binding the contract method 0xf301061d.
//
// Solidity: function STRATEGY_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) STRATEGYIMPLEMENTATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "STRATEGY_IMPLEMENTATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// STRATEGYIMPLEMENTATION is a free data retrieval call binding the contract method 0xf301061d.
//
// Solidity: function STRATEGY_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) STRATEGYIMPLEMENTATION() (common.Address, error) {
	return _SuperVaultAggregator.Contract.STRATEGYIMPLEMENTATION(&_SuperVaultAggregator.CallOpts)
}

// STRATEGYIMPLEMENTATION is a free data retrieval call binding the contract method 0xf301061d.
//
// Solidity: function STRATEGY_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) STRATEGYIMPLEMENTATION() (common.Address, error) {
	return _SuperVaultAggregator.Contract.STRATEGYIMPLEMENTATION(&_SuperVaultAggregator.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) SUPERGOVERNOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "SUPER_GOVERNOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperVaultAggregator.Contract.SUPERGOVERNOR(&_SuperVaultAggregator.CallOpts)
}

// SUPERGOVERNOR is a free data retrieval call binding the contract method 0x39c7d246.
//
// Solidity: function SUPER_GOVERNOR() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) SUPERGOVERNOR() (common.Address, error) {
	return _SuperVaultAggregator.Contract.SUPERGOVERNOR(&_SuperVaultAggregator.CallOpts)
}

// VAULTIMPLEMENTATION is a free data retrieval call binding the contract method 0x1f9b5aaf.
//
// Solidity: function VAULT_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) VAULTIMPLEMENTATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "VAULT_IMPLEMENTATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// VAULTIMPLEMENTATION is a free data retrieval call binding the contract method 0x1f9b5aaf.
//
// Solidity: function VAULT_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) VAULTIMPLEMENTATION() (common.Address, error) {
	return _SuperVaultAggregator.Contract.VAULTIMPLEMENTATION(&_SuperVaultAggregator.CallOpts)
}

// VAULTIMPLEMENTATION is a free data retrieval call binding the contract method 0x1f9b5aaf.
//
// Solidity: function VAULT_IMPLEMENTATION() view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) VAULTIMPLEMENTATION() (common.Address, error) {
	return _SuperVaultAggregator.Contract.VAULTIMPLEMENTATION(&_SuperVaultAggregator.CallOpts)
}

// GetAllSuperVaultEscrows is a free data retrieval call binding the contract method 0x154fd23f.
//
// Solidity: function getAllSuperVaultEscrows() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetAllSuperVaultEscrows(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getAllSuperVaultEscrows")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetAllSuperVaultEscrows is a free data retrieval call binding the contract method 0x154fd23f.
//
// Solidity: function getAllSuperVaultEscrows() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetAllSuperVaultEscrows() ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAllSuperVaultEscrows(&_SuperVaultAggregator.CallOpts)
}

// GetAllSuperVaultEscrows is a free data retrieval call binding the contract method 0x154fd23f.
//
// Solidity: function getAllSuperVaultEscrows() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetAllSuperVaultEscrows() ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAllSuperVaultEscrows(&_SuperVaultAggregator.CallOpts)
}

// GetAllSuperVaultStrategies is a free data retrieval call binding the contract method 0x8e9615c9.
//
// Solidity: function getAllSuperVaultStrategies() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetAllSuperVaultStrategies(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getAllSuperVaultStrategies")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetAllSuperVaultStrategies is a free data retrieval call binding the contract method 0x8e9615c9.
//
// Solidity: function getAllSuperVaultStrategies() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetAllSuperVaultStrategies() ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAllSuperVaultStrategies(&_SuperVaultAggregator.CallOpts)
}

// GetAllSuperVaultStrategies is a free data retrieval call binding the contract method 0x8e9615c9.
//
// Solidity: function getAllSuperVaultStrategies() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetAllSuperVaultStrategies() ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAllSuperVaultStrategies(&_SuperVaultAggregator.CallOpts)
}

// GetAllSuperVaults is a free data retrieval call binding the contract method 0xa5256bf2.
//
// Solidity: function getAllSuperVaults() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetAllSuperVaults(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getAllSuperVaults")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetAllSuperVaults is a free data retrieval call binding the contract method 0xa5256bf2.
//
// Solidity: function getAllSuperVaults() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetAllSuperVaults() ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAllSuperVaults(&_SuperVaultAggregator.CallOpts)
}

// GetAllSuperVaults is a free data retrieval call binding the contract method 0xa5256bf2.
//
// Solidity: function getAllSuperVaults() view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetAllSuperVaults() ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAllSuperVaults(&_SuperVaultAggregator.CallOpts)
}

// GetAuthorizedCallers is a free data retrieval call binding the contract method 0xceb18ce4.
//
// Solidity: function getAuthorizedCallers(address strategy) view returns(address[] callers)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetAuthorizedCallers(opts *bind.CallOpts, strategy common.Address) ([]common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getAuthorizedCallers", strategy)

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetAuthorizedCallers is a free data retrieval call binding the contract method 0xceb18ce4.
//
// Solidity: function getAuthorizedCallers(address strategy) view returns(address[] callers)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetAuthorizedCallers(strategy common.Address) ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAuthorizedCallers(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetAuthorizedCallers is a free data retrieval call binding the contract method 0xceb18ce4.
//
// Solidity: function getAuthorizedCallers(address strategy) view returns(address[] callers)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetAuthorizedCallers(strategy common.Address) ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetAuthorizedCallers(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetGlobalHooksRoot is a free data retrieval call binding the contract method 0x2a90a055.
//
// Solidity: function getGlobalHooksRoot() view returns(bytes32 root)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetGlobalHooksRoot(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getGlobalHooksRoot")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetGlobalHooksRoot is a free data retrieval call binding the contract method 0x2a90a055.
//
// Solidity: function getGlobalHooksRoot() view returns(bytes32 root)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetGlobalHooksRoot() ([32]byte, error) {
	return _SuperVaultAggregator.Contract.GetGlobalHooksRoot(&_SuperVaultAggregator.CallOpts)
}

// GetGlobalHooksRoot is a free data retrieval call binding the contract method 0x2a90a055.
//
// Solidity: function getGlobalHooksRoot() view returns(bytes32 root)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetGlobalHooksRoot() ([32]byte, error) {
	return _SuperVaultAggregator.Contract.GetGlobalHooksRoot(&_SuperVaultAggregator.CallOpts)
}

// GetLastUpdateTimestamp is a free data retrieval call binding the contract method 0x1a351d62.
//
// Solidity: function getLastUpdateTimestamp(address strategy) view returns(uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetLastUpdateTimestamp(opts *bind.CallOpts, strategy common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getLastUpdateTimestamp", strategy)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetLastUpdateTimestamp is a free data retrieval call binding the contract method 0x1a351d62.
//
// Solidity: function getLastUpdateTimestamp(address strategy) view returns(uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetLastUpdateTimestamp(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetLastUpdateTimestamp(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetLastUpdateTimestamp is a free data retrieval call binding the contract method 0x1a351d62.
//
// Solidity: function getLastUpdateTimestamp(address strategy) view returns(uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetLastUpdateTimestamp(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetLastUpdateTimestamp(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetMainStrategist is a free data retrieval call binding the contract method 0x457c1641.
//
// Solidity: function getMainStrategist(address strategy) view returns(address strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetMainStrategist(opts *bind.CallOpts, strategy common.Address) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getMainStrategist", strategy)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetMainStrategist is a free data retrieval call binding the contract method 0x457c1641.
//
// Solidity: function getMainStrategist(address strategy) view returns(address strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetMainStrategist(strategy common.Address) (common.Address, error) {
	return _SuperVaultAggregator.Contract.GetMainStrategist(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetMainStrategist is a free data retrieval call binding the contract method 0x457c1641.
//
// Solidity: function getMainStrategist(address strategy) view returns(address strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetMainStrategist(strategy common.Address) (common.Address, error) {
	return _SuperVaultAggregator.Contract.GetMainStrategist(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetMaxStaleness is a free data retrieval call binding the contract method 0xc25b784f.
//
// Solidity: function getMaxStaleness(address strategy) view returns(uint256 staleness)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetMaxStaleness(opts *bind.CallOpts, strategy common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getMaxStaleness", strategy)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetMaxStaleness is a free data retrieval call binding the contract method 0xc25b784f.
//
// Solidity: function getMaxStaleness(address strategy) view returns(uint256 staleness)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetMaxStaleness(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetMaxStaleness(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetMaxStaleness is a free data retrieval call binding the contract method 0xc25b784f.
//
// Solidity: function getMaxStaleness(address strategy) view returns(uint256 staleness)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetMaxStaleness(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetMaxStaleness(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetMinUpdateInterval is a free data retrieval call binding the contract method 0x3ab973a3.
//
// Solidity: function getMinUpdateInterval(address strategy) view returns(uint256 interval)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetMinUpdateInterval(opts *bind.CallOpts, strategy common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getMinUpdateInterval", strategy)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetMinUpdateInterval is a free data retrieval call binding the contract method 0x3ab973a3.
//
// Solidity: function getMinUpdateInterval(address strategy) view returns(uint256 interval)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetMinUpdateInterval(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetMinUpdateInterval(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetMinUpdateInterval is a free data retrieval call binding the contract method 0x3ab973a3.
//
// Solidity: function getMinUpdateInterval(address strategy) view returns(uint256 interval)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetMinUpdateInterval(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetMinUpdateInterval(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetPPS is a free data retrieval call binding the contract method 0xbef02b8c.
//
// Solidity: function getPPS(address strategy) view returns(uint256 pps)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetPPS(opts *bind.CallOpts, strategy common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getPPS", strategy)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPPS is a free data retrieval call binding the contract method 0xbef02b8c.
//
// Solidity: function getPPS(address strategy) view returns(uint256 pps)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetPPS(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetPPS(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetPPS is a free data retrieval call binding the contract method 0xbef02b8c.
//
// Solidity: function getPPS(address strategy) view returns(uint256 pps)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetPPS(strategy common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetPPS(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetPPSVerificationThresholds is a free data retrieval call binding the contract method 0x322ae311.
//
// Solidity: function getPPSVerificationThresholds(address strategy) view returns(uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetPPSVerificationThresholds(opts *bind.CallOpts, strategy common.Address) (struct {
	DispersionThreshold *big.Int
	DeviationThreshold  *big.Int
	MnThreshold         *big.Int
}, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getPPSVerificationThresholds", strategy)

	outstruct := new(struct {
		DispersionThreshold *big.Int
		DeviationThreshold  *big.Int
		MnThreshold         *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.DispersionThreshold = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.DeviationThreshold = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.MnThreshold = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetPPSVerificationThresholds is a free data retrieval call binding the contract method 0x322ae311.
//
// Solidity: function getPPSVerificationThresholds(address strategy) view returns(uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetPPSVerificationThresholds(strategy common.Address) (struct {
	DispersionThreshold *big.Int
	DeviationThreshold  *big.Int
	MnThreshold         *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetPPSVerificationThresholds(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetPPSVerificationThresholds is a free data retrieval call binding the contract method 0x322ae311.
//
// Solidity: function getPPSVerificationThresholds(address strategy) view returns(uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetPPSVerificationThresholds(strategy common.Address) (struct {
	DispersionThreshold *big.Int
	DeviationThreshold  *big.Int
	MnThreshold         *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetPPSVerificationThresholds(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetPPSWithStdDev is a free data retrieval call binding the contract method 0x2e79802f.
//
// Solidity: function getPPSWithStdDev(address strategy) view returns(uint256 pps, uint256 ppsStdev)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetPPSWithStdDev(opts *bind.CallOpts, strategy common.Address) (struct {
	Pps      *big.Int
	PpsStdev *big.Int
}, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getPPSWithStdDev", strategy)

	outstruct := new(struct {
		Pps      *big.Int
		PpsStdev *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Pps = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.PpsStdev = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetPPSWithStdDev is a free data retrieval call binding the contract method 0x2e79802f.
//
// Solidity: function getPPSWithStdDev(address strategy) view returns(uint256 pps, uint256 ppsStdev)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetPPSWithStdDev(strategy common.Address) (struct {
	Pps      *big.Int
	PpsStdev *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetPPSWithStdDev(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetPPSWithStdDev is a free data retrieval call binding the contract method 0x2e79802f.
//
// Solidity: function getPPSWithStdDev(address strategy) view returns(uint256 pps, uint256 ppsStdev)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetPPSWithStdDev(strategy common.Address) (struct {
	Pps      *big.Int
	PpsStdev *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetPPSWithStdDev(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetProposedGlobalHooksRoot is a free data retrieval call binding the contract method 0x9ab4e37b.
//
// Solidity: function getProposedGlobalHooksRoot() view returns(bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetProposedGlobalHooksRoot(opts *bind.CallOpts) (struct {
	Root          [32]byte
	EffectiveTime *big.Int
}, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getProposedGlobalHooksRoot")

	outstruct := new(struct {
		Root          [32]byte
		EffectiveTime *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Root = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.EffectiveTime = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetProposedGlobalHooksRoot is a free data retrieval call binding the contract method 0x9ab4e37b.
//
// Solidity: function getProposedGlobalHooksRoot() view returns(bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetProposedGlobalHooksRoot() (struct {
	Root          [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetProposedGlobalHooksRoot(&_SuperVaultAggregator.CallOpts)
}

// GetProposedGlobalHooksRoot is a free data retrieval call binding the contract method 0x9ab4e37b.
//
// Solidity: function getProposedGlobalHooksRoot() view returns(bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetProposedGlobalHooksRoot() (struct {
	Root          [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetProposedGlobalHooksRoot(&_SuperVaultAggregator.CallOpts)
}

// GetProposedStrategyHooksRoot is a free data retrieval call binding the contract method 0x2b4bb841.
//
// Solidity: function getProposedStrategyHooksRoot(address strategy) view returns(bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetProposedStrategyHooksRoot(opts *bind.CallOpts, strategy common.Address) (struct {
	Root          [32]byte
	EffectiveTime *big.Int
}, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getProposedStrategyHooksRoot", strategy)

	outstruct := new(struct {
		Root          [32]byte
		EffectiveTime *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Root = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.EffectiveTime = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetProposedStrategyHooksRoot is a free data retrieval call binding the contract method 0x2b4bb841.
//
// Solidity: function getProposedStrategyHooksRoot(address strategy) view returns(bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetProposedStrategyHooksRoot(strategy common.Address) (struct {
	Root          [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetProposedStrategyHooksRoot(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetProposedStrategyHooksRoot is a free data retrieval call binding the contract method 0x2b4bb841.
//
// Solidity: function getProposedStrategyHooksRoot(address strategy) view returns(bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetProposedStrategyHooksRoot(strategy common.Address) (struct {
	Root          [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperVaultAggregator.Contract.GetProposedStrategyHooksRoot(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetSecondaryStrategists is a free data retrieval call binding the contract method 0x0edd65cc.
//
// Solidity: function getSecondaryStrategists(address strategy) view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetSecondaryStrategists(opts *bind.CallOpts, strategy common.Address) ([]common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getSecondaryStrategists", strategy)

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetSecondaryStrategists is a free data retrieval call binding the contract method 0x0edd65cc.
//
// Solidity: function getSecondaryStrategists(address strategy) view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetSecondaryStrategists(strategy common.Address) ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetSecondaryStrategists(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetSecondaryStrategists is a free data retrieval call binding the contract method 0x0edd65cc.
//
// Solidity: function getSecondaryStrategists(address strategy) view returns(address[])
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetSecondaryStrategists(strategy common.Address) ([]common.Address, error) {
	return _SuperVaultAggregator.Contract.GetSecondaryStrategists(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetStrategyHooksRoot is a free data retrieval call binding the contract method 0xc99d2c89.
//
// Solidity: function getStrategyHooksRoot(address strategy) view returns(bytes32 root)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetStrategyHooksRoot(opts *bind.CallOpts, strategy common.Address) ([32]byte, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getStrategyHooksRoot", strategy)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetStrategyHooksRoot is a free data retrieval call binding the contract method 0xc99d2c89.
//
// Solidity: function getStrategyHooksRoot(address strategy) view returns(bytes32 root)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetStrategyHooksRoot(strategy common.Address) ([32]byte, error) {
	return _SuperVaultAggregator.Contract.GetStrategyHooksRoot(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetStrategyHooksRoot is a free data retrieval call binding the contract method 0xc99d2c89.
//
// Solidity: function getStrategyHooksRoot(address strategy) view returns(bytes32 root)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetStrategyHooksRoot(strategy common.Address) ([32]byte, error) {
	return _SuperVaultAggregator.Contract.GetStrategyHooksRoot(&_SuperVaultAggregator.CallOpts, strategy)
}

// GetUpkeepBalance is a free data retrieval call binding the contract method 0x1aef3510.
//
// Solidity: function getUpkeepBalance(address strategist) view returns(uint256 balance)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) GetUpkeepBalance(opts *bind.CallOpts, strategist common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "getUpkeepBalance", strategist)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetUpkeepBalance is a free data retrieval call binding the contract method 0x1aef3510.
//
// Solidity: function getUpkeepBalance(address strategist) view returns(uint256 balance)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) GetUpkeepBalance(strategist common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetUpkeepBalance(&_SuperVaultAggregator.CallOpts, strategist)
}

// GetUpkeepBalance is a free data retrieval call binding the contract method 0x1aef3510.
//
// Solidity: function getUpkeepBalance(address strategist) view returns(uint256 balance)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) GetUpkeepBalance(strategist common.Address) (*big.Int, error) {
	return _SuperVaultAggregator.Contract.GetUpkeepBalance(&_SuperVaultAggregator.CallOpts, strategist)
}

// IsAnyStrategist is a free data retrieval call binding the contract method 0x76de118f.
//
// Solidity: function isAnyStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) IsAnyStrategist(opts *bind.CallOpts, strategist common.Address, strategy common.Address) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "isAnyStrategist", strategist, strategy)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsAnyStrategist is a free data retrieval call binding the contract method 0x76de118f.
//
// Solidity: function isAnyStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) IsAnyStrategist(strategist common.Address, strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsAnyStrategist(&_SuperVaultAggregator.CallOpts, strategist, strategy)
}

// IsAnyStrategist is a free data retrieval call binding the contract method 0x76de118f.
//
// Solidity: function isAnyStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) IsAnyStrategist(strategist common.Address, strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsAnyStrategist(&_SuperVaultAggregator.CallOpts, strategist, strategy)
}

// IsGlobalHooksRootActive is a free data retrieval call binding the contract method 0x28f36ff0.
//
// Solidity: function isGlobalHooksRootActive() view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) IsGlobalHooksRootActive(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "isGlobalHooksRootActive")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsGlobalHooksRootActive is a free data retrieval call binding the contract method 0x28f36ff0.
//
// Solidity: function isGlobalHooksRootActive() view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) IsGlobalHooksRootActive() (bool, error) {
	return _SuperVaultAggregator.Contract.IsGlobalHooksRootActive(&_SuperVaultAggregator.CallOpts)
}

// IsGlobalHooksRootActive is a free data retrieval call binding the contract method 0x28f36ff0.
//
// Solidity: function isGlobalHooksRootActive() view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) IsGlobalHooksRootActive() (bool, error) {
	return _SuperVaultAggregator.Contract.IsGlobalHooksRootActive(&_SuperVaultAggregator.CallOpts)
}

// IsGlobalHooksRootVetoed is a free data retrieval call binding the contract method 0x81ed8df4.
//
// Solidity: function isGlobalHooksRootVetoed() view returns(bool vetoed)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) IsGlobalHooksRootVetoed(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "isGlobalHooksRootVetoed")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsGlobalHooksRootVetoed is a free data retrieval call binding the contract method 0x81ed8df4.
//
// Solidity: function isGlobalHooksRootVetoed() view returns(bool vetoed)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) IsGlobalHooksRootVetoed() (bool, error) {
	return _SuperVaultAggregator.Contract.IsGlobalHooksRootVetoed(&_SuperVaultAggregator.CallOpts)
}

// IsGlobalHooksRootVetoed is a free data retrieval call binding the contract method 0x81ed8df4.
//
// Solidity: function isGlobalHooksRootVetoed() view returns(bool vetoed)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) IsGlobalHooksRootVetoed() (bool, error) {
	return _SuperVaultAggregator.Contract.IsGlobalHooksRootVetoed(&_SuperVaultAggregator.CallOpts)
}

// IsMainStrategist is a free data retrieval call binding the contract method 0xd2c806e5.
//
// Solidity: function isMainStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) IsMainStrategist(opts *bind.CallOpts, strategist common.Address, strategy common.Address) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "isMainStrategist", strategist, strategy)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMainStrategist is a free data retrieval call binding the contract method 0xd2c806e5.
//
// Solidity: function isMainStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) IsMainStrategist(strategist common.Address, strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsMainStrategist(&_SuperVaultAggregator.CallOpts, strategist, strategy)
}

// IsMainStrategist is a free data retrieval call binding the contract method 0xd2c806e5.
//
// Solidity: function isMainStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) IsMainStrategist(strategist common.Address, strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsMainStrategist(&_SuperVaultAggregator.CallOpts, strategist, strategy)
}

// IsSecondaryStrategist is a free data retrieval call binding the contract method 0x247c2867.
//
// Solidity: function isSecondaryStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) IsSecondaryStrategist(opts *bind.CallOpts, strategist common.Address, strategy common.Address) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "isSecondaryStrategist", strategist, strategy)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsSecondaryStrategist is a free data retrieval call binding the contract method 0x247c2867.
//
// Solidity: function isSecondaryStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) IsSecondaryStrategist(strategist common.Address, strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsSecondaryStrategist(&_SuperVaultAggregator.CallOpts, strategist, strategy)
}

// IsSecondaryStrategist is a free data retrieval call binding the contract method 0x247c2867.
//
// Solidity: function isSecondaryStrategist(address strategist, address strategy) view returns(bool)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) IsSecondaryStrategist(strategist common.Address, strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsSecondaryStrategist(&_SuperVaultAggregator.CallOpts, strategist, strategy)
}

// IsStrategyHooksRootVetoed is a free data retrieval call binding the contract method 0xa8485b73.
//
// Solidity: function isStrategyHooksRootVetoed(address strategy) view returns(bool vetoed)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) IsStrategyHooksRootVetoed(opts *bind.CallOpts, strategy common.Address) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "isStrategyHooksRootVetoed", strategy)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsStrategyHooksRootVetoed is a free data retrieval call binding the contract method 0xa8485b73.
//
// Solidity: function isStrategyHooksRootVetoed(address strategy) view returns(bool vetoed)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) IsStrategyHooksRootVetoed(strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsStrategyHooksRootVetoed(&_SuperVaultAggregator.CallOpts, strategy)
}

// IsStrategyHooksRootVetoed is a free data retrieval call binding the contract method 0xa8485b73.
//
// Solidity: function isStrategyHooksRootVetoed(address strategy) view returns(bool vetoed)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) IsStrategyHooksRootVetoed(strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsStrategyHooksRootVetoed(&_SuperVaultAggregator.CallOpts, strategy)
}

// IsStrategyPaused is a free data retrieval call binding the contract method 0xc06a02e8.
//
// Solidity: function isStrategyPaused(address strategy) view returns(bool isPaused)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) IsStrategyPaused(opts *bind.CallOpts, strategy common.Address) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "isStrategyPaused", strategy)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsStrategyPaused is a free data retrieval call binding the contract method 0xc06a02e8.
//
// Solidity: function isStrategyPaused(address strategy) view returns(bool isPaused)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) IsStrategyPaused(strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsStrategyPaused(&_SuperVaultAggregator.CallOpts, strategy)
}

// IsStrategyPaused is a free data retrieval call binding the contract method 0xc06a02e8.
//
// Solidity: function isStrategyPaused(address strategy) view returns(bool isPaused)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) IsStrategyPaused(strategy common.Address) (bool, error) {
	return _SuperVaultAggregator.Contract.IsStrategyPaused(&_SuperVaultAggregator.CallOpts, strategy)
}

// SuperVaultEscrows is a free data retrieval call binding the contract method 0xbda262d7.
//
// Solidity: function superVaultEscrows(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) SuperVaultEscrows(opts *bind.CallOpts, index *big.Int) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "superVaultEscrows", index)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperVaultEscrows is a free data retrieval call binding the contract method 0xbda262d7.
//
// Solidity: function superVaultEscrows(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) SuperVaultEscrows(index *big.Int) (common.Address, error) {
	return _SuperVaultAggregator.Contract.SuperVaultEscrows(&_SuperVaultAggregator.CallOpts, index)
}

// SuperVaultEscrows is a free data retrieval call binding the contract method 0xbda262d7.
//
// Solidity: function superVaultEscrows(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) SuperVaultEscrows(index *big.Int) (common.Address, error) {
	return _SuperVaultAggregator.Contract.SuperVaultEscrows(&_SuperVaultAggregator.CallOpts, index)
}

// SuperVaultStrategies is a free data retrieval call binding the contract method 0x9dc0ad84.
//
// Solidity: function superVaultStrategies(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) SuperVaultStrategies(opts *bind.CallOpts, index *big.Int) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "superVaultStrategies", index)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperVaultStrategies is a free data retrieval call binding the contract method 0x9dc0ad84.
//
// Solidity: function superVaultStrategies(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) SuperVaultStrategies(index *big.Int) (common.Address, error) {
	return _SuperVaultAggregator.Contract.SuperVaultStrategies(&_SuperVaultAggregator.CallOpts, index)
}

// SuperVaultStrategies is a free data retrieval call binding the contract method 0x9dc0ad84.
//
// Solidity: function superVaultStrategies(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) SuperVaultStrategies(index *big.Int) (common.Address, error) {
	return _SuperVaultAggregator.Contract.SuperVaultStrategies(&_SuperVaultAggregator.CallOpts, index)
}

// SuperVaults is a free data retrieval call binding the contract method 0x44648c76.
//
// Solidity: function superVaults(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) SuperVaults(opts *bind.CallOpts, index *big.Int) (common.Address, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "superVaults", index)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperVaults is a free data retrieval call binding the contract method 0x44648c76.
//
// Solidity: function superVaults(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) SuperVaults(index *big.Int) (common.Address, error) {
	return _SuperVaultAggregator.Contract.SuperVaults(&_SuperVaultAggregator.CallOpts, index)
}

// SuperVaults is a free data retrieval call binding the contract method 0x44648c76.
//
// Solidity: function superVaults(uint256 index) view returns(address)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) SuperVaults(index *big.Int) (common.Address, error) {
	return _SuperVaultAggregator.Contract.SuperVaults(&_SuperVaultAggregator.CallOpts, index)
}

// ValidateHook is a free data retrieval call binding the contract method 0x480b11e7.
//
// Solidity: function validateHook(address strategy, bytes hookArgs, bytes32[] globalProof, bytes32[] strategyProof) view returns(bool isValid)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) ValidateHook(opts *bind.CallOpts, strategy common.Address, hookArgs []byte, globalProof [][32]byte, strategyProof [][32]byte) (bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "validateHook", strategy, hookArgs, globalProof, strategyProof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ValidateHook is a free data retrieval call binding the contract method 0x480b11e7.
//
// Solidity: function validateHook(address strategy, bytes hookArgs, bytes32[] globalProof, bytes32[] strategyProof) view returns(bool isValid)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ValidateHook(strategy common.Address, hookArgs []byte, globalProof [][32]byte, strategyProof [][32]byte) (bool, error) {
	return _SuperVaultAggregator.Contract.ValidateHook(&_SuperVaultAggregator.CallOpts, strategy, hookArgs, globalProof, strategyProof)
}

// ValidateHook is a free data retrieval call binding the contract method 0x480b11e7.
//
// Solidity: function validateHook(address strategy, bytes hookArgs, bytes32[] globalProof, bytes32[] strategyProof) view returns(bool isValid)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) ValidateHook(strategy common.Address, hookArgs []byte, globalProof [][32]byte, strategyProof [][32]byte) (bool, error) {
	return _SuperVaultAggregator.Contract.ValidateHook(&_SuperVaultAggregator.CallOpts, strategy, hookArgs, globalProof, strategyProof)
}

// ValidateHooks is a free data retrieval call binding the contract method 0x5e1d6d6c.
//
// Solidity: function validateHooks(address strategy, bytes[] hooksArgs, bytes32[][] globalProofs, bytes32[][] strategyProofs) view returns(bool[] validHooks)
func (_SuperVaultAggregator *SuperVaultAggregatorCaller) ValidateHooks(opts *bind.CallOpts, strategy common.Address, hooksArgs [][]byte, globalProofs [][][32]byte, strategyProofs [][][32]byte) ([]bool, error) {
	var out []interface{}
	err := _SuperVaultAggregator.contract.Call(opts, &out, "validateHooks", strategy, hooksArgs, globalProofs, strategyProofs)

	if err != nil {
		return *new([]bool), err
	}

	out0 := *abi.ConvertType(out[0], new([]bool)).(*[]bool)

	return out0, err

}

// ValidateHooks is a free data retrieval call binding the contract method 0x5e1d6d6c.
//
// Solidity: function validateHooks(address strategy, bytes[] hooksArgs, bytes32[][] globalProofs, bytes32[][] strategyProofs) view returns(bool[] validHooks)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ValidateHooks(strategy common.Address, hooksArgs [][]byte, globalProofs [][][32]byte, strategyProofs [][][32]byte) ([]bool, error) {
	return _SuperVaultAggregator.Contract.ValidateHooks(&_SuperVaultAggregator.CallOpts, strategy, hooksArgs, globalProofs, strategyProofs)
}

// ValidateHooks is a free data retrieval call binding the contract method 0x5e1d6d6c.
//
// Solidity: function validateHooks(address strategy, bytes[] hooksArgs, bytes32[][] globalProofs, bytes32[][] strategyProofs) view returns(bool[] validHooks)
func (_SuperVaultAggregator *SuperVaultAggregatorCallerSession) ValidateHooks(strategy common.Address, hooksArgs [][]byte, globalProofs [][][32]byte, strategyProofs [][][32]byte) ([]bool, error) {
	return _SuperVaultAggregator.Contract.ValidateHooks(&_SuperVaultAggregator.CallOpts, strategy, hooksArgs, globalProofs, strategyProofs)
}

// AddAuthorizedCaller is a paid mutator transaction binding the contract method 0x6a279bb6.
//
// Solidity: function addAuthorizedCaller(address strategy, address caller) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) AddAuthorizedCaller(opts *bind.TransactOpts, strategy common.Address, caller common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "addAuthorizedCaller", strategy, caller)
}

// AddAuthorizedCaller is a paid mutator transaction binding the contract method 0x6a279bb6.
//
// Solidity: function addAuthorizedCaller(address strategy, address caller) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) AddAuthorizedCaller(strategy common.Address, caller common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.AddAuthorizedCaller(&_SuperVaultAggregator.TransactOpts, strategy, caller)
}

// AddAuthorizedCaller is a paid mutator transaction binding the contract method 0x6a279bb6.
//
// Solidity: function addAuthorizedCaller(address strategy, address caller) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) AddAuthorizedCaller(strategy common.Address, caller common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.AddAuthorizedCaller(&_SuperVaultAggregator.TransactOpts, strategy, caller)
}

// AddSecondaryStrategist is a paid mutator transaction binding the contract method 0x29d0999d.
//
// Solidity: function addSecondaryStrategist(address strategy, address strategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) AddSecondaryStrategist(opts *bind.TransactOpts, strategy common.Address, strategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "addSecondaryStrategist", strategy, strategist)
}

// AddSecondaryStrategist is a paid mutator transaction binding the contract method 0x29d0999d.
//
// Solidity: function addSecondaryStrategist(address strategy, address strategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) AddSecondaryStrategist(strategy common.Address, strategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.AddSecondaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, strategist)
}

// AddSecondaryStrategist is a paid mutator transaction binding the contract method 0x29d0999d.
//
// Solidity: function addSecondaryStrategist(address strategy, address strategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) AddSecondaryStrategist(strategy common.Address, strategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.AddSecondaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, strategist)
}

// BatchForwardPPS is a paid mutator transaction binding the contract method 0x8e813db5.
//
// Solidity: function batchForwardPPS((address[],uint256[],uint256[],uint256[],uint256[],uint256[]) args) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) BatchForwardPPS(opts *bind.TransactOpts, args ISuperVaultAggregatorBatchForwardPPSArgs) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "batchForwardPPS", args)
}

// BatchForwardPPS is a paid mutator transaction binding the contract method 0x8e813db5.
//
// Solidity: function batchForwardPPS((address[],uint256[],uint256[],uint256[],uint256[],uint256[]) args) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) BatchForwardPPS(args ISuperVaultAggregatorBatchForwardPPSArgs) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.BatchForwardPPS(&_SuperVaultAggregator.TransactOpts, args)
}

// BatchForwardPPS is a paid mutator transaction binding the contract method 0x8e813db5.
//
// Solidity: function batchForwardPPS((address[],uint256[],uint256[],uint256[],uint256[],uint256[]) args) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) BatchForwardPPS(args ISuperVaultAggregatorBatchForwardPPSArgs) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.BatchForwardPPS(&_SuperVaultAggregator.TransactOpts, args)
}

// ChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x3c308f54.
//
// Solidity: function changePrimaryStrategist(address strategy, address newStrategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ChangePrimaryStrategist(opts *bind.TransactOpts, strategy common.Address, newStrategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "changePrimaryStrategist", strategy, newStrategist)
}

// ChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x3c308f54.
//
// Solidity: function changePrimaryStrategist(address strategy, address newStrategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ChangePrimaryStrategist(strategy common.Address, newStrategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ChangePrimaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, newStrategist)
}

// ChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x3c308f54.
//
// Solidity: function changePrimaryStrategist(address strategy, address newStrategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ChangePrimaryStrategist(strategy common.Address, newStrategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ChangePrimaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, newStrategist)
}

// CreateVault is a paid mutator transaction binding the contract method 0x08109456.
//
// Solidity: function createVault((address,string,string,address,uint256,uint256,(uint256,address)) params) returns(address superVault, address strategy, address escrow)
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) CreateVault(opts *bind.TransactOpts, params ISuperVaultAggregatorVaultCreationParams) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "createVault", params)
}

// CreateVault is a paid mutator transaction binding the contract method 0x08109456.
//
// Solidity: function createVault((address,string,string,address,uint256,uint256,(uint256,address)) params) returns(address superVault, address strategy, address escrow)
func (_SuperVaultAggregator *SuperVaultAggregatorSession) CreateVault(params ISuperVaultAggregatorVaultCreationParams) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.CreateVault(&_SuperVaultAggregator.TransactOpts, params)
}

// CreateVault is a paid mutator transaction binding the contract method 0x08109456.
//
// Solidity: function createVault((address,string,string,address,uint256,uint256,(uint256,address)) params) returns(address superVault, address strategy, address escrow)
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) CreateVault(params ISuperVaultAggregatorVaultCreationParams) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.CreateVault(&_SuperVaultAggregator.TransactOpts, params)
}

// DepositUpkeep is a paid mutator transaction binding the contract method 0x6fe79652.
//
// Solidity: function depositUpkeep(address strategist, uint256 amount) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) DepositUpkeep(opts *bind.TransactOpts, strategist common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "depositUpkeep", strategist, amount)
}

// DepositUpkeep is a paid mutator transaction binding the contract method 0x6fe79652.
//
// Solidity: function depositUpkeep(address strategist, uint256 amount) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) DepositUpkeep(strategist common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.DepositUpkeep(&_SuperVaultAggregator.TransactOpts, strategist, amount)
}

// DepositUpkeep is a paid mutator transaction binding the contract method 0x6fe79652.
//
// Solidity: function depositUpkeep(address strategist, uint256 amount) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) DepositUpkeep(strategist common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.DepositUpkeep(&_SuperVaultAggregator.TransactOpts, strategist, amount)
}

// ExecuteChangePrimaryStrategist is a paid mutator transaction binding the contract method 0xc5109cf4.
//
// Solidity: function executeChangePrimaryStrategist(address strategy) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ExecuteChangePrimaryStrategist(opts *bind.TransactOpts, strategy common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "executeChangePrimaryStrategist", strategy)
}

// ExecuteChangePrimaryStrategist is a paid mutator transaction binding the contract method 0xc5109cf4.
//
// Solidity: function executeChangePrimaryStrategist(address strategy) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ExecuteChangePrimaryStrategist(strategy common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ExecuteChangePrimaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy)
}

// ExecuteChangePrimaryStrategist is a paid mutator transaction binding the contract method 0xc5109cf4.
//
// Solidity: function executeChangePrimaryStrategist(address strategy) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ExecuteChangePrimaryStrategist(strategy common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ExecuteChangePrimaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy)
}

// ExecuteGlobalHooksRootUpdate is a paid mutator transaction binding the contract method 0x0a48d243.
//
// Solidity: function executeGlobalHooksRootUpdate() returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ExecuteGlobalHooksRootUpdate(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "executeGlobalHooksRootUpdate")
}

// ExecuteGlobalHooksRootUpdate is a paid mutator transaction binding the contract method 0x0a48d243.
//
// Solidity: function executeGlobalHooksRootUpdate() returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ExecuteGlobalHooksRootUpdate() (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ExecuteGlobalHooksRootUpdate(&_SuperVaultAggregator.TransactOpts)
}

// ExecuteGlobalHooksRootUpdate is a paid mutator transaction binding the contract method 0x0a48d243.
//
// Solidity: function executeGlobalHooksRootUpdate() returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ExecuteGlobalHooksRootUpdate() (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ExecuteGlobalHooksRootUpdate(&_SuperVaultAggregator.TransactOpts)
}

// ExecuteStrategyHooksRootUpdate is a paid mutator transaction binding the contract method 0x7825784b.
//
// Solidity: function executeStrategyHooksRootUpdate(address strategy) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ExecuteStrategyHooksRootUpdate(opts *bind.TransactOpts, strategy common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "executeStrategyHooksRootUpdate", strategy)
}

// ExecuteStrategyHooksRootUpdate is a paid mutator transaction binding the contract method 0x7825784b.
//
// Solidity: function executeStrategyHooksRootUpdate(address strategy) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ExecuteStrategyHooksRootUpdate(strategy common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ExecuteStrategyHooksRootUpdate(&_SuperVaultAggregator.TransactOpts, strategy)
}

// ExecuteStrategyHooksRootUpdate is a paid mutator transaction binding the contract method 0x7825784b.
//
// Solidity: function executeStrategyHooksRootUpdate(address strategy) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ExecuteStrategyHooksRootUpdate(strategy common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ExecuteStrategyHooksRootUpdate(&_SuperVaultAggregator.TransactOpts, strategy)
}

// ForwardPPS is a paid mutator transaction binding the contract method 0xa895a594.
//
// Solidity: function forwardPPS(address updateAuthority, (address,bool,uint256,uint256,uint256,uint256,uint256,uint256) args) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ForwardPPS(opts *bind.TransactOpts, updateAuthority common.Address, args ISuperVaultAggregatorForwardPPSArgs) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "forwardPPS", updateAuthority, args)
}

// ForwardPPS is a paid mutator transaction binding the contract method 0xa895a594.
//
// Solidity: function forwardPPS(address updateAuthority, (address,bool,uint256,uint256,uint256,uint256,uint256,uint256) args) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ForwardPPS(updateAuthority common.Address, args ISuperVaultAggregatorForwardPPSArgs) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ForwardPPS(&_SuperVaultAggregator.TransactOpts, updateAuthority, args)
}

// ForwardPPS is a paid mutator transaction binding the contract method 0xa895a594.
//
// Solidity: function forwardPPS(address updateAuthority, (address,bool,uint256,uint256,uint256,uint256,uint256,uint256) args) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ForwardPPS(updateAuthority common.Address, args ISuperVaultAggregatorForwardPPSArgs) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ForwardPPS(&_SuperVaultAggregator.TransactOpts, updateAuthority, args)
}

// ProposeChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x2a0f4c14.
//
// Solidity: function proposeChangePrimaryStrategist(address strategy, address newStrategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ProposeChangePrimaryStrategist(opts *bind.TransactOpts, strategy common.Address, newStrategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "proposeChangePrimaryStrategist", strategy, newStrategist)
}

// ProposeChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x2a0f4c14.
//
// Solidity: function proposeChangePrimaryStrategist(address strategy, address newStrategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ProposeChangePrimaryStrategist(strategy common.Address, newStrategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ProposeChangePrimaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, newStrategist)
}

// ProposeChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x2a0f4c14.
//
// Solidity: function proposeChangePrimaryStrategist(address strategy, address newStrategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ProposeChangePrimaryStrategist(strategy common.Address, newStrategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ProposeChangePrimaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, newStrategist)
}

// ProposeGlobalHooksRoot is a paid mutator transaction binding the contract method 0xb0e5173b.
//
// Solidity: function proposeGlobalHooksRoot(bytes32 newRoot) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ProposeGlobalHooksRoot(opts *bind.TransactOpts, newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "proposeGlobalHooksRoot", newRoot)
}

// ProposeGlobalHooksRoot is a paid mutator transaction binding the contract method 0xb0e5173b.
//
// Solidity: function proposeGlobalHooksRoot(bytes32 newRoot) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ProposeGlobalHooksRoot(newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ProposeGlobalHooksRoot(&_SuperVaultAggregator.TransactOpts, newRoot)
}

// ProposeGlobalHooksRoot is a paid mutator transaction binding the contract method 0xb0e5173b.
//
// Solidity: function proposeGlobalHooksRoot(bytes32 newRoot) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ProposeGlobalHooksRoot(newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ProposeGlobalHooksRoot(&_SuperVaultAggregator.TransactOpts, newRoot)
}

// ProposeStrategyHooksRoot is a paid mutator transaction binding the contract method 0x5e12b2db.
//
// Solidity: function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) ProposeStrategyHooksRoot(opts *bind.TransactOpts, strategy common.Address, newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "proposeStrategyHooksRoot", strategy, newRoot)
}

// ProposeStrategyHooksRoot is a paid mutator transaction binding the contract method 0x5e12b2db.
//
// Solidity: function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) ProposeStrategyHooksRoot(strategy common.Address, newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ProposeStrategyHooksRoot(&_SuperVaultAggregator.TransactOpts, strategy, newRoot)
}

// ProposeStrategyHooksRoot is a paid mutator transaction binding the contract method 0x5e12b2db.
//
// Solidity: function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) ProposeStrategyHooksRoot(strategy common.Address, newRoot [32]byte) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.ProposeStrategyHooksRoot(&_SuperVaultAggregator.TransactOpts, strategy, newRoot)
}

// RemoveAuthorizedCaller is a paid mutator transaction binding the contract method 0x4e179bce.
//
// Solidity: function removeAuthorizedCaller(address strategy, address caller) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) RemoveAuthorizedCaller(opts *bind.TransactOpts, strategy common.Address, caller common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "removeAuthorizedCaller", strategy, caller)
}

// RemoveAuthorizedCaller is a paid mutator transaction binding the contract method 0x4e179bce.
//
// Solidity: function removeAuthorizedCaller(address strategy, address caller) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) RemoveAuthorizedCaller(strategy common.Address, caller common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.RemoveAuthorizedCaller(&_SuperVaultAggregator.TransactOpts, strategy, caller)
}

// RemoveAuthorizedCaller is a paid mutator transaction binding the contract method 0x4e179bce.
//
// Solidity: function removeAuthorizedCaller(address strategy, address caller) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) RemoveAuthorizedCaller(strategy common.Address, caller common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.RemoveAuthorizedCaller(&_SuperVaultAggregator.TransactOpts, strategy, caller)
}

// RemoveSecondaryStrategist is a paid mutator transaction binding the contract method 0xe3a218fe.
//
// Solidity: function removeSecondaryStrategist(address strategy, address strategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) RemoveSecondaryStrategist(opts *bind.TransactOpts, strategy common.Address, strategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "removeSecondaryStrategist", strategy, strategist)
}

// RemoveSecondaryStrategist is a paid mutator transaction binding the contract method 0xe3a218fe.
//
// Solidity: function removeSecondaryStrategist(address strategy, address strategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) RemoveSecondaryStrategist(strategy common.Address, strategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.RemoveSecondaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, strategist)
}

// RemoveSecondaryStrategist is a paid mutator transaction binding the contract method 0xe3a218fe.
//
// Solidity: function removeSecondaryStrategist(address strategy, address strategist) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) RemoveSecondaryStrategist(strategy common.Address, strategist common.Address) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.RemoveSecondaryStrategist(&_SuperVaultAggregator.TransactOpts, strategy, strategist)
}

// SetGlobalHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xd5f3cd86.
//
// Solidity: function setGlobalHooksRootVetoStatus(bool vetoed) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) SetGlobalHooksRootVetoStatus(opts *bind.TransactOpts, vetoed bool) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "setGlobalHooksRootVetoStatus", vetoed)
}

// SetGlobalHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xd5f3cd86.
//
// Solidity: function setGlobalHooksRootVetoStatus(bool vetoed) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) SetGlobalHooksRootVetoStatus(vetoed bool) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.SetGlobalHooksRootVetoStatus(&_SuperVaultAggregator.TransactOpts, vetoed)
}

// SetGlobalHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xd5f3cd86.
//
// Solidity: function setGlobalHooksRootVetoStatus(bool vetoed) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) SetGlobalHooksRootVetoStatus(vetoed bool) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.SetGlobalHooksRootVetoStatus(&_SuperVaultAggregator.TransactOpts, vetoed)
}

// SetStrategyHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xf5297a47.
//
// Solidity: function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) SetStrategyHooksRootVetoStatus(opts *bind.TransactOpts, strategy common.Address, vetoed bool) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "setStrategyHooksRootVetoStatus", strategy, vetoed)
}

// SetStrategyHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xf5297a47.
//
// Solidity: function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) SetStrategyHooksRootVetoStatus(strategy common.Address, vetoed bool) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.SetStrategyHooksRootVetoStatus(&_SuperVaultAggregator.TransactOpts, strategy, vetoed)
}

// SetStrategyHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xf5297a47.
//
// Solidity: function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) SetStrategyHooksRootVetoStatus(strategy common.Address, vetoed bool) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.SetStrategyHooksRootVetoStatus(&_SuperVaultAggregator.TransactOpts, strategy, vetoed)
}

// UpdatePPSVerificationThresholds is a paid mutator transaction binding the contract method 0x473e031c.
//
// Solidity: function updatePPSVerificationThresholds(address strategy, uint256 dispersionThreshold_, uint256 deviationThreshold_, uint256 mnThreshold_) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) UpdatePPSVerificationThresholds(opts *bind.TransactOpts, strategy common.Address, dispersionThreshold_ *big.Int, deviationThreshold_ *big.Int, mnThreshold_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "updatePPSVerificationThresholds", strategy, dispersionThreshold_, deviationThreshold_, mnThreshold_)
}

// UpdatePPSVerificationThresholds is a paid mutator transaction binding the contract method 0x473e031c.
//
// Solidity: function updatePPSVerificationThresholds(address strategy, uint256 dispersionThreshold_, uint256 deviationThreshold_, uint256 mnThreshold_) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) UpdatePPSVerificationThresholds(strategy common.Address, dispersionThreshold_ *big.Int, deviationThreshold_ *big.Int, mnThreshold_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.UpdatePPSVerificationThresholds(&_SuperVaultAggregator.TransactOpts, strategy, dispersionThreshold_, deviationThreshold_, mnThreshold_)
}

// UpdatePPSVerificationThresholds is a paid mutator transaction binding the contract method 0x473e031c.
//
// Solidity: function updatePPSVerificationThresholds(address strategy, uint256 dispersionThreshold_, uint256 deviationThreshold_, uint256 mnThreshold_) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) UpdatePPSVerificationThresholds(strategy common.Address, dispersionThreshold_ *big.Int, deviationThreshold_ *big.Int, mnThreshold_ *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.UpdatePPSVerificationThresholds(&_SuperVaultAggregator.TransactOpts, strategy, dispersionThreshold_, deviationThreshold_, mnThreshold_)
}

// WithdrawUpkeep is a paid mutator transaction binding the contract method 0x4b0b8aa6.
//
// Solidity: function withdrawUpkeep(uint256 amount) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactor) WithdrawUpkeep(opts *bind.TransactOpts, amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.contract.Transact(opts, "withdrawUpkeep", amount)
}

// WithdrawUpkeep is a paid mutator transaction binding the contract method 0x4b0b8aa6.
//
// Solidity: function withdrawUpkeep(uint256 amount) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorSession) WithdrawUpkeep(amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.WithdrawUpkeep(&_SuperVaultAggregator.TransactOpts, amount)
}

// WithdrawUpkeep is a paid mutator transaction binding the contract method 0x4b0b8aa6.
//
// Solidity: function withdrawUpkeep(uint256 amount) returns()
func (_SuperVaultAggregator *SuperVaultAggregatorTransactorSession) WithdrawUpkeep(amount *big.Int) (*types.Transaction, error) {
	return _SuperVaultAggregator.Contract.WithdrawUpkeep(&_SuperVaultAggregator.TransactOpts, amount)
}

// SuperVaultAggregatorAuthorizedCallerAddedIterator is returned from FilterAuthorizedCallerAdded and is used to iterate over the raw logs and unpacked data for AuthorizedCallerAdded events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorAuthorizedCallerAddedIterator struct {
	Event *SuperVaultAggregatorAuthorizedCallerAdded // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorAuthorizedCallerAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorAuthorizedCallerAdded)
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
		it.Event = new(SuperVaultAggregatorAuthorizedCallerAdded)
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
func (it *SuperVaultAggregatorAuthorizedCallerAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorAuthorizedCallerAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorAuthorizedCallerAdded represents a AuthorizedCallerAdded event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorAuthorizedCallerAdded struct {
	Strategy common.Address
	Caller   common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterAuthorizedCallerAdded is a free log retrieval operation binding the contract event 0xde6b6315e31236a6504cb4a4fa3ccc32947e648ce1f188687e0711f55ec418b0.
//
// Solidity: event AuthorizedCallerAdded(address indexed strategy, address indexed caller)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterAuthorizedCallerAdded(opts *bind.FilterOpts, strategy []common.Address, caller []common.Address) (*SuperVaultAggregatorAuthorizedCallerAddedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var callerRule []interface{}
	for _, callerItem := range caller {
		callerRule = append(callerRule, callerItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "AuthorizedCallerAdded", strategyRule, callerRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorAuthorizedCallerAddedIterator{contract: _SuperVaultAggregator.contract, event: "AuthorizedCallerAdded", logs: logs, sub: sub}, nil
}

// WatchAuthorizedCallerAdded is a free log subscription operation binding the contract event 0xde6b6315e31236a6504cb4a4fa3ccc32947e648ce1f188687e0711f55ec418b0.
//
// Solidity: event AuthorizedCallerAdded(address indexed strategy, address indexed caller)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchAuthorizedCallerAdded(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorAuthorizedCallerAdded, strategy []common.Address, caller []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var callerRule []interface{}
	for _, callerItem := range caller {
		callerRule = append(callerRule, callerItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "AuthorizedCallerAdded", strategyRule, callerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorAuthorizedCallerAdded)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "AuthorizedCallerAdded", log); err != nil {
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

// ParseAuthorizedCallerAdded is a log parse operation binding the contract event 0xde6b6315e31236a6504cb4a4fa3ccc32947e648ce1f188687e0711f55ec418b0.
//
// Solidity: event AuthorizedCallerAdded(address indexed strategy, address indexed caller)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseAuthorizedCallerAdded(log types.Log) (*SuperVaultAggregatorAuthorizedCallerAdded, error) {
	event := new(SuperVaultAggregatorAuthorizedCallerAdded)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "AuthorizedCallerAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorAuthorizedCallerRemovedIterator is returned from FilterAuthorizedCallerRemoved and is used to iterate over the raw logs and unpacked data for AuthorizedCallerRemoved events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorAuthorizedCallerRemovedIterator struct {
	Event *SuperVaultAggregatorAuthorizedCallerRemoved // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorAuthorizedCallerRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorAuthorizedCallerRemoved)
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
		it.Event = new(SuperVaultAggregatorAuthorizedCallerRemoved)
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
func (it *SuperVaultAggregatorAuthorizedCallerRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorAuthorizedCallerRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorAuthorizedCallerRemoved represents a AuthorizedCallerRemoved event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorAuthorizedCallerRemoved struct {
	Strategy common.Address
	Caller   common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterAuthorizedCallerRemoved is a free log retrieval operation binding the contract event 0xd175903e18897b59f1dec5589010cd32eb1cb6d795239d0d79159089bfd4f52a.
//
// Solidity: event AuthorizedCallerRemoved(address indexed strategy, address indexed caller)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterAuthorizedCallerRemoved(opts *bind.FilterOpts, strategy []common.Address, caller []common.Address) (*SuperVaultAggregatorAuthorizedCallerRemovedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var callerRule []interface{}
	for _, callerItem := range caller {
		callerRule = append(callerRule, callerItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "AuthorizedCallerRemoved", strategyRule, callerRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorAuthorizedCallerRemovedIterator{contract: _SuperVaultAggregator.contract, event: "AuthorizedCallerRemoved", logs: logs, sub: sub}, nil
}

// WatchAuthorizedCallerRemoved is a free log subscription operation binding the contract event 0xd175903e18897b59f1dec5589010cd32eb1cb6d795239d0d79159089bfd4f52a.
//
// Solidity: event AuthorizedCallerRemoved(address indexed strategy, address indexed caller)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchAuthorizedCallerRemoved(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorAuthorizedCallerRemoved, strategy []common.Address, caller []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var callerRule []interface{}
	for _, callerItem := range caller {
		callerRule = append(callerRule, callerItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "AuthorizedCallerRemoved", strategyRule, callerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorAuthorizedCallerRemoved)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "AuthorizedCallerRemoved", log); err != nil {
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

// ParseAuthorizedCallerRemoved is a log parse operation binding the contract event 0xd175903e18897b59f1dec5589010cd32eb1cb6d795239d0d79159089bfd4f52a.
//
// Solidity: event AuthorizedCallerRemoved(address indexed strategy, address indexed caller)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseAuthorizedCallerRemoved(log types.Log) (*SuperVaultAggregatorAuthorizedCallerRemoved, error) {
	event := new(SuperVaultAggregatorAuthorizedCallerRemoved)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "AuthorizedCallerRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorGlobalHooksRootUpdateProposedIterator is returned from FilterGlobalHooksRootUpdateProposed and is used to iterate over the raw logs and unpacked data for GlobalHooksRootUpdateProposed events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootUpdateProposedIterator struct {
	Event *SuperVaultAggregatorGlobalHooksRootUpdateProposed // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorGlobalHooksRootUpdateProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorGlobalHooksRootUpdateProposed)
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
		it.Event = new(SuperVaultAggregatorGlobalHooksRootUpdateProposed)
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
func (it *SuperVaultAggregatorGlobalHooksRootUpdateProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorGlobalHooksRootUpdateProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorGlobalHooksRootUpdateProposed represents a GlobalHooksRootUpdateProposed event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootUpdateProposed struct {
	Root          [32]byte
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterGlobalHooksRootUpdateProposed is a free log retrieval operation binding the contract event 0x71e72baaa2bffcb51d34de71bba7ea258c9c5667a86e69b1c684f0e1ecb4f395.
//
// Solidity: event GlobalHooksRootUpdateProposed(bytes32 indexed root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterGlobalHooksRootUpdateProposed(opts *bind.FilterOpts, root [][32]byte) (*SuperVaultAggregatorGlobalHooksRootUpdateProposedIterator, error) {

	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "GlobalHooksRootUpdateProposed", rootRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorGlobalHooksRootUpdateProposedIterator{contract: _SuperVaultAggregator.contract, event: "GlobalHooksRootUpdateProposed", logs: logs, sub: sub}, nil
}

// WatchGlobalHooksRootUpdateProposed is a free log subscription operation binding the contract event 0x71e72baaa2bffcb51d34de71bba7ea258c9c5667a86e69b1c684f0e1ecb4f395.
//
// Solidity: event GlobalHooksRootUpdateProposed(bytes32 indexed root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchGlobalHooksRootUpdateProposed(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorGlobalHooksRootUpdateProposed, root [][32]byte) (event.Subscription, error) {

	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "GlobalHooksRootUpdateProposed", rootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorGlobalHooksRootUpdateProposed)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootUpdateProposed", log); err != nil {
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

// ParseGlobalHooksRootUpdateProposed is a log parse operation binding the contract event 0x71e72baaa2bffcb51d34de71bba7ea258c9c5667a86e69b1c684f0e1ecb4f395.
//
// Solidity: event GlobalHooksRootUpdateProposed(bytes32 indexed root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseGlobalHooksRootUpdateProposed(log types.Log) (*SuperVaultAggregatorGlobalHooksRootUpdateProposed, error) {
	event := new(SuperVaultAggregatorGlobalHooksRootUpdateProposed)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootUpdateProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorGlobalHooksRootUpdatedIterator is returned from FilterGlobalHooksRootUpdated and is used to iterate over the raw logs and unpacked data for GlobalHooksRootUpdated events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootUpdatedIterator struct {
	Event *SuperVaultAggregatorGlobalHooksRootUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorGlobalHooksRootUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorGlobalHooksRootUpdated)
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
		it.Event = new(SuperVaultAggregatorGlobalHooksRootUpdated)
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
func (it *SuperVaultAggregatorGlobalHooksRootUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorGlobalHooksRootUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorGlobalHooksRootUpdated represents a GlobalHooksRootUpdated event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootUpdated struct {
	OldRoot [32]byte
	NewRoot [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterGlobalHooksRootUpdated is a free log retrieval operation binding the contract event 0x0360da73fad480d9a31212f8337d4a576e6b9749d68fc663acf171bb07f950ba.
//
// Solidity: event GlobalHooksRootUpdated(bytes32 indexed oldRoot, bytes32 newRoot)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterGlobalHooksRootUpdated(opts *bind.FilterOpts, oldRoot [][32]byte) (*SuperVaultAggregatorGlobalHooksRootUpdatedIterator, error) {

	var oldRootRule []interface{}
	for _, oldRootItem := range oldRoot {
		oldRootRule = append(oldRootRule, oldRootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "GlobalHooksRootUpdated", oldRootRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorGlobalHooksRootUpdatedIterator{contract: _SuperVaultAggregator.contract, event: "GlobalHooksRootUpdated", logs: logs, sub: sub}, nil
}

// WatchGlobalHooksRootUpdated is a free log subscription operation binding the contract event 0x0360da73fad480d9a31212f8337d4a576e6b9749d68fc663acf171bb07f950ba.
//
// Solidity: event GlobalHooksRootUpdated(bytes32 indexed oldRoot, bytes32 newRoot)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchGlobalHooksRootUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorGlobalHooksRootUpdated, oldRoot [][32]byte) (event.Subscription, error) {

	var oldRootRule []interface{}
	for _, oldRootItem := range oldRoot {
		oldRootRule = append(oldRootRule, oldRootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "GlobalHooksRootUpdated", oldRootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorGlobalHooksRootUpdated)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootUpdated", log); err != nil {
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

// ParseGlobalHooksRootUpdated is a log parse operation binding the contract event 0x0360da73fad480d9a31212f8337d4a576e6b9749d68fc663acf171bb07f950ba.
//
// Solidity: event GlobalHooksRootUpdated(bytes32 indexed oldRoot, bytes32 newRoot)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseGlobalHooksRootUpdated(log types.Log) (*SuperVaultAggregatorGlobalHooksRootUpdated, error) {
	event := new(SuperVaultAggregatorGlobalHooksRootUpdated)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorGlobalHooksRootVetoStatusChangedIterator is returned from FilterGlobalHooksRootVetoStatusChanged and is used to iterate over the raw logs and unpacked data for GlobalHooksRootVetoStatusChanged events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootVetoStatusChangedIterator struct {
	Event *SuperVaultAggregatorGlobalHooksRootVetoStatusChanged // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorGlobalHooksRootVetoStatusChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorGlobalHooksRootVetoStatusChanged)
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
		it.Event = new(SuperVaultAggregatorGlobalHooksRootVetoStatusChanged)
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
func (it *SuperVaultAggregatorGlobalHooksRootVetoStatusChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorGlobalHooksRootVetoStatusChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorGlobalHooksRootVetoStatusChanged represents a GlobalHooksRootVetoStatusChanged event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootVetoStatusChanged struct {
	Vetoed bool
	Root   [32]byte
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterGlobalHooksRootVetoStatusChanged is a free log retrieval operation binding the contract event 0xd867c555762bc6e6e6c9f80aa6c8132ccc5909f83266bc4d24489c8aa10e5e8d.
//
// Solidity: event GlobalHooksRootVetoStatusChanged(bool vetoed, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterGlobalHooksRootVetoStatusChanged(opts *bind.FilterOpts, root [][32]byte) (*SuperVaultAggregatorGlobalHooksRootVetoStatusChangedIterator, error) {

	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "GlobalHooksRootVetoStatusChanged", rootRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorGlobalHooksRootVetoStatusChangedIterator{contract: _SuperVaultAggregator.contract, event: "GlobalHooksRootVetoStatusChanged", logs: logs, sub: sub}, nil
}

// WatchGlobalHooksRootVetoStatusChanged is a free log subscription operation binding the contract event 0xd867c555762bc6e6e6c9f80aa6c8132ccc5909f83266bc4d24489c8aa10e5e8d.
//
// Solidity: event GlobalHooksRootVetoStatusChanged(bool vetoed, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchGlobalHooksRootVetoStatusChanged(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorGlobalHooksRootVetoStatusChanged, root [][32]byte) (event.Subscription, error) {

	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "GlobalHooksRootVetoStatusChanged", rootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorGlobalHooksRootVetoStatusChanged)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootVetoStatusChanged", log); err != nil {
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

// ParseGlobalHooksRootVetoStatusChanged is a log parse operation binding the contract event 0xd867c555762bc6e6e6c9f80aa6c8132ccc5909f83266bc4d24489c8aa10e5e8d.
//
// Solidity: event GlobalHooksRootVetoStatusChanged(bool vetoed, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseGlobalHooksRootVetoStatusChanged(log types.Log) (*SuperVaultAggregatorGlobalHooksRootVetoStatusChanged, error) {
	event := new(SuperVaultAggregatorGlobalHooksRootVetoStatusChanged)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootVetoStatusChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorGlobalHooksRootVetoedIterator is returned from FilterGlobalHooksRootVetoed and is used to iterate over the raw logs and unpacked data for GlobalHooksRootVetoed events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootVetoedIterator struct {
	Event *SuperVaultAggregatorGlobalHooksRootVetoed // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorGlobalHooksRootVetoedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorGlobalHooksRootVetoed)
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
		it.Event = new(SuperVaultAggregatorGlobalHooksRootVetoed)
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
func (it *SuperVaultAggregatorGlobalHooksRootVetoedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorGlobalHooksRootVetoedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorGlobalHooksRootVetoed represents a GlobalHooksRootVetoed event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorGlobalHooksRootVetoed struct {
	Guardian common.Address
	Root     [32]byte
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterGlobalHooksRootVetoed is a free log retrieval operation binding the contract event 0x26c1ad46cb7f3649d1025e06bdbe8fc101891e84299550e6e28b5b5c62e09ec3.
//
// Solidity: event GlobalHooksRootVetoed(address indexed guardian, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterGlobalHooksRootVetoed(opts *bind.FilterOpts, guardian []common.Address, root [][32]byte) (*SuperVaultAggregatorGlobalHooksRootVetoedIterator, error) {

	var guardianRule []interface{}
	for _, guardianItem := range guardian {
		guardianRule = append(guardianRule, guardianItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "GlobalHooksRootVetoed", guardianRule, rootRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorGlobalHooksRootVetoedIterator{contract: _SuperVaultAggregator.contract, event: "GlobalHooksRootVetoed", logs: logs, sub: sub}, nil
}

// WatchGlobalHooksRootVetoed is a free log subscription operation binding the contract event 0x26c1ad46cb7f3649d1025e06bdbe8fc101891e84299550e6e28b5b5c62e09ec3.
//
// Solidity: event GlobalHooksRootVetoed(address indexed guardian, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchGlobalHooksRootVetoed(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorGlobalHooksRootVetoed, guardian []common.Address, root [][32]byte) (event.Subscription, error) {

	var guardianRule []interface{}
	for _, guardianItem := range guardian {
		guardianRule = append(guardianRule, guardianItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "GlobalHooksRootVetoed", guardianRule, rootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorGlobalHooksRootVetoed)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootVetoed", log); err != nil {
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

// ParseGlobalHooksRootVetoed is a log parse operation binding the contract event 0x26c1ad46cb7f3649d1025e06bdbe8fc101891e84299550e6e28b5b5c62e09ec3.
//
// Solidity: event GlobalHooksRootVetoed(address indexed guardian, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseGlobalHooksRootVetoed(log types.Log) (*SuperVaultAggregatorGlobalHooksRootVetoed, error) {
	event := new(SuperVaultAggregatorGlobalHooksRootVetoed)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "GlobalHooksRootVetoed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorPPSUpdatedIterator is returned from FilterPPSUpdated and is used to iterate over the raw logs and unpacked data for PPSUpdated events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPPSUpdatedIterator struct {
	Event *SuperVaultAggregatorPPSUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorPPSUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorPPSUpdated)
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
		it.Event = new(SuperVaultAggregatorPPSUpdated)
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
func (it *SuperVaultAggregatorPPSUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorPPSUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorPPSUpdated represents a PPSUpdated event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPPSUpdated struct {
	Strategy        common.Address
	Pps             *big.Int
	PpsStdev        *big.Int
	ValidatorSet    *big.Int
	TotalValidators *big.Int
	Timestamp       *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterPPSUpdated is a free log retrieval operation binding the contract event 0xd9c8c2dea3061ff41ebdd1d1b16209a1d11761d3b4709874c68172c2d23dadcf.
//
// Solidity: event PPSUpdated(address indexed strategy, uint256 pps, uint256 ppsStdev, uint256 validatorSet, uint256 totalValidators, uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterPPSUpdated(opts *bind.FilterOpts, strategy []common.Address) (*SuperVaultAggregatorPPSUpdatedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "PPSUpdated", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorPPSUpdatedIterator{contract: _SuperVaultAggregator.contract, event: "PPSUpdated", logs: logs, sub: sub}, nil
}

// WatchPPSUpdated is a free log subscription operation binding the contract event 0xd9c8c2dea3061ff41ebdd1d1b16209a1d11761d3b4709874c68172c2d23dadcf.
//
// Solidity: event PPSUpdated(address indexed strategy, uint256 pps, uint256 ppsStdev, uint256 validatorSet, uint256 totalValidators, uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchPPSUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorPPSUpdated, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "PPSUpdated", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorPPSUpdated)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "PPSUpdated", log); err != nil {
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

// ParsePPSUpdated is a log parse operation binding the contract event 0xd9c8c2dea3061ff41ebdd1d1b16209a1d11761d3b4709874c68172c2d23dadcf.
//
// Solidity: event PPSUpdated(address indexed strategy, uint256 pps, uint256 ppsStdev, uint256 validatorSet, uint256 totalValidators, uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParsePPSUpdated(log types.Log) (*SuperVaultAggregatorPPSUpdated, error) {
	event := new(SuperVaultAggregatorPPSUpdated)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "PPSUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorPPSVerificationThresholdsUpdatedIterator is returned from FilterPPSVerificationThresholdsUpdated and is used to iterate over the raw logs and unpacked data for PPSVerificationThresholdsUpdated events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPPSVerificationThresholdsUpdatedIterator struct {
	Event *SuperVaultAggregatorPPSVerificationThresholdsUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorPPSVerificationThresholdsUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorPPSVerificationThresholdsUpdated)
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
		it.Event = new(SuperVaultAggregatorPPSVerificationThresholdsUpdated)
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
func (it *SuperVaultAggregatorPPSVerificationThresholdsUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorPPSVerificationThresholdsUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorPPSVerificationThresholdsUpdated represents a PPSVerificationThresholdsUpdated event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPPSVerificationThresholdsUpdated struct {
	Strategy            common.Address
	DispersionThreshold *big.Int
	DeviationThreshold  *big.Int
	MnThreshold         *big.Int
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterPPSVerificationThresholdsUpdated is a free log retrieval operation binding the contract event 0x74bc5feac9403f697b1540399145c807469b19844f79f96c5b544c9c0d90124f.
//
// Solidity: event PPSVerificationThresholdsUpdated(address indexed strategy, uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterPPSVerificationThresholdsUpdated(opts *bind.FilterOpts, strategy []common.Address) (*SuperVaultAggregatorPPSVerificationThresholdsUpdatedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "PPSVerificationThresholdsUpdated", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorPPSVerificationThresholdsUpdatedIterator{contract: _SuperVaultAggregator.contract, event: "PPSVerificationThresholdsUpdated", logs: logs, sub: sub}, nil
}

// WatchPPSVerificationThresholdsUpdated is a free log subscription operation binding the contract event 0x74bc5feac9403f697b1540399145c807469b19844f79f96c5b544c9c0d90124f.
//
// Solidity: event PPSVerificationThresholdsUpdated(address indexed strategy, uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchPPSVerificationThresholdsUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorPPSVerificationThresholdsUpdated, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "PPSVerificationThresholdsUpdated", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorPPSVerificationThresholdsUpdated)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "PPSVerificationThresholdsUpdated", log); err != nil {
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

// ParsePPSVerificationThresholdsUpdated is a log parse operation binding the contract event 0x74bc5feac9403f697b1540399145c807469b19844f79f96c5b544c9c0d90124f.
//
// Solidity: event PPSVerificationThresholdsUpdated(address indexed strategy, uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParsePPSVerificationThresholdsUpdated(log types.Log) (*SuperVaultAggregatorPPSVerificationThresholdsUpdated, error) {
	event := new(SuperVaultAggregatorPPSVerificationThresholdsUpdated)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "PPSVerificationThresholdsUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorPrimaryStrategistChangeProposedIterator is returned from FilterPrimaryStrategistChangeProposed and is used to iterate over the raw logs and unpacked data for PrimaryStrategistChangeProposed events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPrimaryStrategistChangeProposedIterator struct {
	Event *SuperVaultAggregatorPrimaryStrategistChangeProposed // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorPrimaryStrategistChangeProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorPrimaryStrategistChangeProposed)
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
		it.Event = new(SuperVaultAggregatorPrimaryStrategistChangeProposed)
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
func (it *SuperVaultAggregatorPrimaryStrategistChangeProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorPrimaryStrategistChangeProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorPrimaryStrategistChangeProposed represents a PrimaryStrategistChangeProposed event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPrimaryStrategistChangeProposed struct {
	Strategy      common.Address
	Proposer      common.Address
	NewStrategist common.Address
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterPrimaryStrategistChangeProposed is a free log retrieval operation binding the contract event 0x142f0213eba92660be9bd12fa93e492e21f9f0a023bd218949b3464f9e21a285.
//
// Solidity: event PrimaryStrategistChangeProposed(address indexed strategy, address indexed proposer, address indexed newStrategist, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterPrimaryStrategistChangeProposed(opts *bind.FilterOpts, strategy []common.Address, proposer []common.Address, newStrategist []common.Address) (*SuperVaultAggregatorPrimaryStrategistChangeProposedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}
	var newStrategistRule []interface{}
	for _, newStrategistItem := range newStrategist {
		newStrategistRule = append(newStrategistRule, newStrategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "PrimaryStrategistChangeProposed", strategyRule, proposerRule, newStrategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorPrimaryStrategistChangeProposedIterator{contract: _SuperVaultAggregator.contract, event: "PrimaryStrategistChangeProposed", logs: logs, sub: sub}, nil
}

// WatchPrimaryStrategistChangeProposed is a free log subscription operation binding the contract event 0x142f0213eba92660be9bd12fa93e492e21f9f0a023bd218949b3464f9e21a285.
//
// Solidity: event PrimaryStrategistChangeProposed(address indexed strategy, address indexed proposer, address indexed newStrategist, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchPrimaryStrategistChangeProposed(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorPrimaryStrategistChangeProposed, strategy []common.Address, proposer []common.Address, newStrategist []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}
	var newStrategistRule []interface{}
	for _, newStrategistItem := range newStrategist {
		newStrategistRule = append(newStrategistRule, newStrategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "PrimaryStrategistChangeProposed", strategyRule, proposerRule, newStrategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorPrimaryStrategistChangeProposed)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "PrimaryStrategistChangeProposed", log); err != nil {
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

// ParsePrimaryStrategistChangeProposed is a log parse operation binding the contract event 0x142f0213eba92660be9bd12fa93e492e21f9f0a023bd218949b3464f9e21a285.
//
// Solidity: event PrimaryStrategistChangeProposed(address indexed strategy, address indexed proposer, address indexed newStrategist, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParsePrimaryStrategistChangeProposed(log types.Log) (*SuperVaultAggregatorPrimaryStrategistChangeProposed, error) {
	event := new(SuperVaultAggregatorPrimaryStrategistChangeProposed)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "PrimaryStrategistChangeProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorPrimaryStrategistChangedIterator is returned from FilterPrimaryStrategistChanged and is used to iterate over the raw logs and unpacked data for PrimaryStrategistChanged events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPrimaryStrategistChangedIterator struct {
	Event *SuperVaultAggregatorPrimaryStrategistChanged // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorPrimaryStrategistChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorPrimaryStrategistChanged)
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
		it.Event = new(SuperVaultAggregatorPrimaryStrategistChanged)
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
func (it *SuperVaultAggregatorPrimaryStrategistChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorPrimaryStrategistChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorPrimaryStrategistChanged represents a PrimaryStrategistChanged event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPrimaryStrategistChanged struct {
	Strategy      common.Address
	OldStrategist common.Address
	NewStrategist common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterPrimaryStrategistChanged is a free log retrieval operation binding the contract event 0x652015667737ca0d02cff5aa5159731ac509a4b0f37a81ea6274132720fa989e.
//
// Solidity: event PrimaryStrategistChanged(address indexed strategy, address indexed oldStrategist, address indexed newStrategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterPrimaryStrategistChanged(opts *bind.FilterOpts, strategy []common.Address, oldStrategist []common.Address, newStrategist []common.Address) (*SuperVaultAggregatorPrimaryStrategistChangedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var oldStrategistRule []interface{}
	for _, oldStrategistItem := range oldStrategist {
		oldStrategistRule = append(oldStrategistRule, oldStrategistItem)
	}
	var newStrategistRule []interface{}
	for _, newStrategistItem := range newStrategist {
		newStrategistRule = append(newStrategistRule, newStrategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "PrimaryStrategistChanged", strategyRule, oldStrategistRule, newStrategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorPrimaryStrategistChangedIterator{contract: _SuperVaultAggregator.contract, event: "PrimaryStrategistChanged", logs: logs, sub: sub}, nil
}

// WatchPrimaryStrategistChanged is a free log subscription operation binding the contract event 0x652015667737ca0d02cff5aa5159731ac509a4b0f37a81ea6274132720fa989e.
//
// Solidity: event PrimaryStrategistChanged(address indexed strategy, address indexed oldStrategist, address indexed newStrategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchPrimaryStrategistChanged(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorPrimaryStrategistChanged, strategy []common.Address, oldStrategist []common.Address, newStrategist []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var oldStrategistRule []interface{}
	for _, oldStrategistItem := range oldStrategist {
		oldStrategistRule = append(oldStrategistRule, oldStrategistItem)
	}
	var newStrategistRule []interface{}
	for _, newStrategistItem := range newStrategist {
		newStrategistRule = append(newStrategistRule, newStrategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "PrimaryStrategistChanged", strategyRule, oldStrategistRule, newStrategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorPrimaryStrategistChanged)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "PrimaryStrategistChanged", log); err != nil {
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

// ParsePrimaryStrategistChanged is a log parse operation binding the contract event 0x652015667737ca0d02cff5aa5159731ac509a4b0f37a81ea6274132720fa989e.
//
// Solidity: event PrimaryStrategistChanged(address indexed strategy, address indexed oldStrategist, address indexed newStrategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParsePrimaryStrategistChanged(log types.Log) (*SuperVaultAggregatorPrimaryStrategistChanged, error) {
	event := new(SuperVaultAggregatorPrimaryStrategistChanged)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "PrimaryStrategistChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorPrimaryStrategistChangedToSuperformIterator is returned from FilterPrimaryStrategistChangedToSuperform and is used to iterate over the raw logs and unpacked data for PrimaryStrategistChangedToSuperform events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPrimaryStrategistChangedToSuperformIterator struct {
	Event *SuperVaultAggregatorPrimaryStrategistChangedToSuperform // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorPrimaryStrategistChangedToSuperformIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorPrimaryStrategistChangedToSuperform)
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
		it.Event = new(SuperVaultAggregatorPrimaryStrategistChangedToSuperform)
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
func (it *SuperVaultAggregatorPrimaryStrategistChangedToSuperformIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorPrimaryStrategistChangedToSuperformIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorPrimaryStrategistChangedToSuperform represents a PrimaryStrategistChangedToSuperform event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorPrimaryStrategistChangedToSuperform struct {
	Strategy      common.Address
	OldStrategist common.Address
	NewStrategist common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterPrimaryStrategistChangedToSuperform is a free log retrieval operation binding the contract event 0x3ac9f650c48cf2cf7a7b640c3f616280609b770849551e28b1d18a14c3de9491.
//
// Solidity: event PrimaryStrategistChangedToSuperform(address indexed strategy, address indexed oldStrategist, address indexed newStrategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterPrimaryStrategistChangedToSuperform(opts *bind.FilterOpts, strategy []common.Address, oldStrategist []common.Address, newStrategist []common.Address) (*SuperVaultAggregatorPrimaryStrategistChangedToSuperformIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var oldStrategistRule []interface{}
	for _, oldStrategistItem := range oldStrategist {
		oldStrategistRule = append(oldStrategistRule, oldStrategistItem)
	}
	var newStrategistRule []interface{}
	for _, newStrategistItem := range newStrategist {
		newStrategistRule = append(newStrategistRule, newStrategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "PrimaryStrategistChangedToSuperform", strategyRule, oldStrategistRule, newStrategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorPrimaryStrategistChangedToSuperformIterator{contract: _SuperVaultAggregator.contract, event: "PrimaryStrategistChangedToSuperform", logs: logs, sub: sub}, nil
}

// WatchPrimaryStrategistChangedToSuperform is a free log subscription operation binding the contract event 0x3ac9f650c48cf2cf7a7b640c3f616280609b770849551e28b1d18a14c3de9491.
//
// Solidity: event PrimaryStrategistChangedToSuperform(address indexed strategy, address indexed oldStrategist, address indexed newStrategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchPrimaryStrategistChangedToSuperform(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorPrimaryStrategistChangedToSuperform, strategy []common.Address, oldStrategist []common.Address, newStrategist []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var oldStrategistRule []interface{}
	for _, oldStrategistItem := range oldStrategist {
		oldStrategistRule = append(oldStrategistRule, oldStrategistItem)
	}
	var newStrategistRule []interface{}
	for _, newStrategistItem := range newStrategist {
		newStrategistRule = append(newStrategistRule, newStrategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "PrimaryStrategistChangedToSuperform", strategyRule, oldStrategistRule, newStrategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorPrimaryStrategistChangedToSuperform)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "PrimaryStrategistChangedToSuperform", log); err != nil {
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

// ParsePrimaryStrategistChangedToSuperform is a log parse operation binding the contract event 0x3ac9f650c48cf2cf7a7b640c3f616280609b770849551e28b1d18a14c3de9491.
//
// Solidity: event PrimaryStrategistChangedToSuperform(address indexed strategy, address indexed oldStrategist, address indexed newStrategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParsePrimaryStrategistChangedToSuperform(log types.Log) (*SuperVaultAggregatorPrimaryStrategistChangedToSuperform, error) {
	event := new(SuperVaultAggregatorPrimaryStrategistChangedToSuperform)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "PrimaryStrategistChangedToSuperform", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorSecondaryStrategistAddedIterator is returned from FilterSecondaryStrategistAdded and is used to iterate over the raw logs and unpacked data for SecondaryStrategistAdded events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorSecondaryStrategistAddedIterator struct {
	Event *SuperVaultAggregatorSecondaryStrategistAdded // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorSecondaryStrategistAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorSecondaryStrategistAdded)
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
		it.Event = new(SuperVaultAggregatorSecondaryStrategistAdded)
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
func (it *SuperVaultAggregatorSecondaryStrategistAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorSecondaryStrategistAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorSecondaryStrategistAdded represents a SecondaryStrategistAdded event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorSecondaryStrategistAdded struct {
	Strategy   common.Address
	Strategist common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSecondaryStrategistAdded is a free log retrieval operation binding the contract event 0x6f564e73e0f2deb5e3f099e22cc84afde763cc801d86bdbeaefa989e0d45b342.
//
// Solidity: event SecondaryStrategistAdded(address indexed strategy, address indexed strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterSecondaryStrategistAdded(opts *bind.FilterOpts, strategy []common.Address, strategist []common.Address) (*SuperVaultAggregatorSecondaryStrategistAddedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "SecondaryStrategistAdded", strategyRule, strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorSecondaryStrategistAddedIterator{contract: _SuperVaultAggregator.contract, event: "SecondaryStrategistAdded", logs: logs, sub: sub}, nil
}

// WatchSecondaryStrategistAdded is a free log subscription operation binding the contract event 0x6f564e73e0f2deb5e3f099e22cc84afde763cc801d86bdbeaefa989e0d45b342.
//
// Solidity: event SecondaryStrategistAdded(address indexed strategy, address indexed strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchSecondaryStrategistAdded(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorSecondaryStrategistAdded, strategy []common.Address, strategist []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "SecondaryStrategistAdded", strategyRule, strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorSecondaryStrategistAdded)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "SecondaryStrategistAdded", log); err != nil {
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

// ParseSecondaryStrategistAdded is a log parse operation binding the contract event 0x6f564e73e0f2deb5e3f099e22cc84afde763cc801d86bdbeaefa989e0d45b342.
//
// Solidity: event SecondaryStrategistAdded(address indexed strategy, address indexed strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseSecondaryStrategistAdded(log types.Log) (*SuperVaultAggregatorSecondaryStrategistAdded, error) {
	event := new(SuperVaultAggregatorSecondaryStrategistAdded)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "SecondaryStrategistAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorSecondaryStrategistRemovedIterator is returned from FilterSecondaryStrategistRemoved and is used to iterate over the raw logs and unpacked data for SecondaryStrategistRemoved events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorSecondaryStrategistRemovedIterator struct {
	Event *SuperVaultAggregatorSecondaryStrategistRemoved // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorSecondaryStrategistRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorSecondaryStrategistRemoved)
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
		it.Event = new(SuperVaultAggregatorSecondaryStrategistRemoved)
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
func (it *SuperVaultAggregatorSecondaryStrategistRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorSecondaryStrategistRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorSecondaryStrategistRemoved represents a SecondaryStrategistRemoved event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorSecondaryStrategistRemoved struct {
	Strategy   common.Address
	Strategist common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSecondaryStrategistRemoved is a free log retrieval operation binding the contract event 0x1752e353c5989bc3c9593594df568802b688caa3df9ecd95dbeab0393b3dff94.
//
// Solidity: event SecondaryStrategistRemoved(address indexed strategy, address indexed strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterSecondaryStrategistRemoved(opts *bind.FilterOpts, strategy []common.Address, strategist []common.Address) (*SuperVaultAggregatorSecondaryStrategistRemovedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "SecondaryStrategistRemoved", strategyRule, strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorSecondaryStrategistRemovedIterator{contract: _SuperVaultAggregator.contract, event: "SecondaryStrategistRemoved", logs: logs, sub: sub}, nil
}

// WatchSecondaryStrategistRemoved is a free log subscription operation binding the contract event 0x1752e353c5989bc3c9593594df568802b688caa3df9ecd95dbeab0393b3dff94.
//
// Solidity: event SecondaryStrategistRemoved(address indexed strategy, address indexed strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchSecondaryStrategistRemoved(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorSecondaryStrategistRemoved, strategy []common.Address, strategist []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "SecondaryStrategistRemoved", strategyRule, strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorSecondaryStrategistRemoved)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "SecondaryStrategistRemoved", log); err != nil {
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

// ParseSecondaryStrategistRemoved is a log parse operation binding the contract event 0x1752e353c5989bc3c9593594df568802b688caa3df9ecd95dbeab0393b3dff94.
//
// Solidity: event SecondaryStrategistRemoved(address indexed strategy, address indexed strategist)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseSecondaryStrategistRemoved(log types.Log) (*SuperVaultAggregatorSecondaryStrategistRemoved, error) {
	event := new(SuperVaultAggregatorSecondaryStrategistRemoved)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "SecondaryStrategistRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStaleUpdateIterator is returned from FilterStaleUpdate and is used to iterate over the raw logs and unpacked data for StaleUpdate events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStaleUpdateIterator struct {
	Event *SuperVaultAggregatorStaleUpdate // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStaleUpdateIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStaleUpdate)
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
		it.Event = new(SuperVaultAggregatorStaleUpdate)
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
func (it *SuperVaultAggregatorStaleUpdateIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStaleUpdateIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStaleUpdate represents a StaleUpdate event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStaleUpdate struct {
	Strategy        common.Address
	UpdateAuthority common.Address
	Timestamp       *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterStaleUpdate is a free log retrieval operation binding the contract event 0x5413368ef0fd371d352762fd42f794381bdd66d2b2c3860549bc61f12f6ab2ba.
//
// Solidity: event StaleUpdate(address indexed strategy, address indexed updateAuthority, uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStaleUpdate(opts *bind.FilterOpts, strategy []common.Address, updateAuthority []common.Address) (*SuperVaultAggregatorStaleUpdateIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var updateAuthorityRule []interface{}
	for _, updateAuthorityItem := range updateAuthority {
		updateAuthorityRule = append(updateAuthorityRule, updateAuthorityItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StaleUpdate", strategyRule, updateAuthorityRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStaleUpdateIterator{contract: _SuperVaultAggregator.contract, event: "StaleUpdate", logs: logs, sub: sub}, nil
}

// WatchStaleUpdate is a free log subscription operation binding the contract event 0x5413368ef0fd371d352762fd42f794381bdd66d2b2c3860549bc61f12f6ab2ba.
//
// Solidity: event StaleUpdate(address indexed strategy, address indexed updateAuthority, uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStaleUpdate(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStaleUpdate, strategy []common.Address, updateAuthority []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var updateAuthorityRule []interface{}
	for _, updateAuthorityItem := range updateAuthority {
		updateAuthorityRule = append(updateAuthorityRule, updateAuthorityItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StaleUpdate", strategyRule, updateAuthorityRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStaleUpdate)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StaleUpdate", log); err != nil {
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

// ParseStaleUpdate is a log parse operation binding the contract event 0x5413368ef0fd371d352762fd42f794381bdd66d2b2c3860549bc61f12f6ab2ba.
//
// Solidity: event StaleUpdate(address indexed strategy, address indexed updateAuthority, uint256 timestamp)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStaleUpdate(log types.Log) (*SuperVaultAggregatorStaleUpdate, error) {
	event := new(SuperVaultAggregatorStaleUpdate)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StaleUpdate", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStrategyCheckFailedIterator is returned from FilterStrategyCheckFailed and is used to iterate over the raw logs and unpacked data for StrategyCheckFailed events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyCheckFailedIterator struct {
	Event *SuperVaultAggregatorStrategyCheckFailed // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStrategyCheckFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStrategyCheckFailed)
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
		it.Event = new(SuperVaultAggregatorStrategyCheckFailed)
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
func (it *SuperVaultAggregatorStrategyCheckFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStrategyCheckFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStrategyCheckFailed represents a StrategyCheckFailed event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyCheckFailed struct {
	Strategy common.Address
	Reason   string
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyCheckFailed is a free log retrieval operation binding the contract event 0xe364669b114d8ecba48ed1742526a04c78dd506cd3af6beb910f6622a928cbdb.
//
// Solidity: event StrategyCheckFailed(address indexed strategy, string reason)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStrategyCheckFailed(opts *bind.FilterOpts, strategy []common.Address) (*SuperVaultAggregatorStrategyCheckFailedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StrategyCheckFailed", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStrategyCheckFailedIterator{contract: _SuperVaultAggregator.contract, event: "StrategyCheckFailed", logs: logs, sub: sub}, nil
}

// WatchStrategyCheckFailed is a free log subscription operation binding the contract event 0xe364669b114d8ecba48ed1742526a04c78dd506cd3af6beb910f6622a928cbdb.
//
// Solidity: event StrategyCheckFailed(address indexed strategy, string reason)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStrategyCheckFailed(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStrategyCheckFailed, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StrategyCheckFailed", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStrategyCheckFailed)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyCheckFailed", log); err != nil {
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

// ParseStrategyCheckFailed is a log parse operation binding the contract event 0xe364669b114d8ecba48ed1742526a04c78dd506cd3af6beb910f6622a928cbdb.
//
// Solidity: event StrategyCheckFailed(address indexed strategy, string reason)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStrategyCheckFailed(log types.Log) (*SuperVaultAggregatorStrategyCheckFailed, error) {
	event := new(SuperVaultAggregatorStrategyCheckFailed)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyCheckFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStrategyHooksRootUpdateProposedIterator is returned from FilterStrategyHooksRootUpdateProposed and is used to iterate over the raw logs and unpacked data for StrategyHooksRootUpdateProposed events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootUpdateProposedIterator struct {
	Event *SuperVaultAggregatorStrategyHooksRootUpdateProposed // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStrategyHooksRootUpdateProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStrategyHooksRootUpdateProposed)
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
		it.Event = new(SuperVaultAggregatorStrategyHooksRootUpdateProposed)
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
func (it *SuperVaultAggregatorStrategyHooksRootUpdateProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStrategyHooksRootUpdateProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStrategyHooksRootUpdateProposed represents a StrategyHooksRootUpdateProposed event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootUpdateProposed struct {
	Strategy      common.Address
	Proposer      common.Address
	Root          [32]byte
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterStrategyHooksRootUpdateProposed is a free log retrieval operation binding the contract event 0x3c67f914ba911b08519fae976b442675afa7d36b96bab1276ca2ab142c1b1714.
//
// Solidity: event StrategyHooksRootUpdateProposed(address indexed strategy, address indexed proposer, bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStrategyHooksRootUpdateProposed(opts *bind.FilterOpts, strategy []common.Address, proposer []common.Address) (*SuperVaultAggregatorStrategyHooksRootUpdateProposedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StrategyHooksRootUpdateProposed", strategyRule, proposerRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStrategyHooksRootUpdateProposedIterator{contract: _SuperVaultAggregator.contract, event: "StrategyHooksRootUpdateProposed", logs: logs, sub: sub}, nil
}

// WatchStrategyHooksRootUpdateProposed is a free log subscription operation binding the contract event 0x3c67f914ba911b08519fae976b442675afa7d36b96bab1276ca2ab142c1b1714.
//
// Solidity: event StrategyHooksRootUpdateProposed(address indexed strategy, address indexed proposer, bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStrategyHooksRootUpdateProposed(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStrategyHooksRootUpdateProposed, strategy []common.Address, proposer []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StrategyHooksRootUpdateProposed", strategyRule, proposerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStrategyHooksRootUpdateProposed)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootUpdateProposed", log); err != nil {
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

// ParseStrategyHooksRootUpdateProposed is a log parse operation binding the contract event 0x3c67f914ba911b08519fae976b442675afa7d36b96bab1276ca2ab142c1b1714.
//
// Solidity: event StrategyHooksRootUpdateProposed(address indexed strategy, address indexed proposer, bytes32 root, uint256 effectiveTime)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStrategyHooksRootUpdateProposed(log types.Log) (*SuperVaultAggregatorStrategyHooksRootUpdateProposed, error) {
	event := new(SuperVaultAggregatorStrategyHooksRootUpdateProposed)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootUpdateProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStrategyHooksRootUpdatedIterator is returned from FilterStrategyHooksRootUpdated and is used to iterate over the raw logs and unpacked data for StrategyHooksRootUpdated events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootUpdatedIterator struct {
	Event *SuperVaultAggregatorStrategyHooksRootUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStrategyHooksRootUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStrategyHooksRootUpdated)
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
		it.Event = new(SuperVaultAggregatorStrategyHooksRootUpdated)
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
func (it *SuperVaultAggregatorStrategyHooksRootUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStrategyHooksRootUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStrategyHooksRootUpdated represents a StrategyHooksRootUpdated event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootUpdated struct {
	Strategy common.Address
	OldRoot  [32]byte
	NewRoot  [32]byte
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyHooksRootUpdated is a free log retrieval operation binding the contract event 0x50db1dc8f2cc634e637edbe632acec34656994c29a699c817c89e8de694035f6.
//
// Solidity: event StrategyHooksRootUpdated(address indexed strategy, bytes32 oldRoot, bytes32 newRoot)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStrategyHooksRootUpdated(opts *bind.FilterOpts, strategy []common.Address) (*SuperVaultAggregatorStrategyHooksRootUpdatedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StrategyHooksRootUpdated", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStrategyHooksRootUpdatedIterator{contract: _SuperVaultAggregator.contract, event: "StrategyHooksRootUpdated", logs: logs, sub: sub}, nil
}

// WatchStrategyHooksRootUpdated is a free log subscription operation binding the contract event 0x50db1dc8f2cc634e637edbe632acec34656994c29a699c817c89e8de694035f6.
//
// Solidity: event StrategyHooksRootUpdated(address indexed strategy, bytes32 oldRoot, bytes32 newRoot)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStrategyHooksRootUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStrategyHooksRootUpdated, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StrategyHooksRootUpdated", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStrategyHooksRootUpdated)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootUpdated", log); err != nil {
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

// ParseStrategyHooksRootUpdated is a log parse operation binding the contract event 0x50db1dc8f2cc634e637edbe632acec34656994c29a699c817c89e8de694035f6.
//
// Solidity: event StrategyHooksRootUpdated(address indexed strategy, bytes32 oldRoot, bytes32 newRoot)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStrategyHooksRootUpdated(log types.Log) (*SuperVaultAggregatorStrategyHooksRootUpdated, error) {
	event := new(SuperVaultAggregatorStrategyHooksRootUpdated)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStrategyHooksRootVetoStatusChangedIterator is returned from FilterStrategyHooksRootVetoStatusChanged and is used to iterate over the raw logs and unpacked data for StrategyHooksRootVetoStatusChanged events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootVetoStatusChangedIterator struct {
	Event *SuperVaultAggregatorStrategyHooksRootVetoStatusChanged // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStrategyHooksRootVetoStatusChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStrategyHooksRootVetoStatusChanged)
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
		it.Event = new(SuperVaultAggregatorStrategyHooksRootVetoStatusChanged)
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
func (it *SuperVaultAggregatorStrategyHooksRootVetoStatusChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStrategyHooksRootVetoStatusChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStrategyHooksRootVetoStatusChanged represents a StrategyHooksRootVetoStatusChanged event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootVetoStatusChanged struct {
	Strategy common.Address
	Vetoed   bool
	Root     [32]byte
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyHooksRootVetoStatusChanged is a free log retrieval operation binding the contract event 0x927440ad59e90a7b01af1effd4191955ea9e6ef812fc415e7f8e71eadbc5bc35.
//
// Solidity: event StrategyHooksRootVetoStatusChanged(address indexed strategy, bool vetoed, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStrategyHooksRootVetoStatusChanged(opts *bind.FilterOpts, strategy []common.Address, root [][32]byte) (*SuperVaultAggregatorStrategyHooksRootVetoStatusChangedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StrategyHooksRootVetoStatusChanged", strategyRule, rootRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStrategyHooksRootVetoStatusChangedIterator{contract: _SuperVaultAggregator.contract, event: "StrategyHooksRootVetoStatusChanged", logs: logs, sub: sub}, nil
}

// WatchStrategyHooksRootVetoStatusChanged is a free log subscription operation binding the contract event 0x927440ad59e90a7b01af1effd4191955ea9e6ef812fc415e7f8e71eadbc5bc35.
//
// Solidity: event StrategyHooksRootVetoStatusChanged(address indexed strategy, bool vetoed, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStrategyHooksRootVetoStatusChanged(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStrategyHooksRootVetoStatusChanged, strategy []common.Address, root [][32]byte) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StrategyHooksRootVetoStatusChanged", strategyRule, rootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStrategyHooksRootVetoStatusChanged)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootVetoStatusChanged", log); err != nil {
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

// ParseStrategyHooksRootVetoStatusChanged is a log parse operation binding the contract event 0x927440ad59e90a7b01af1effd4191955ea9e6ef812fc415e7f8e71eadbc5bc35.
//
// Solidity: event StrategyHooksRootVetoStatusChanged(address indexed strategy, bool vetoed, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStrategyHooksRootVetoStatusChanged(log types.Log) (*SuperVaultAggregatorStrategyHooksRootVetoStatusChanged, error) {
	event := new(SuperVaultAggregatorStrategyHooksRootVetoStatusChanged)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootVetoStatusChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStrategyHooksRootVetoedIterator is returned from FilterStrategyHooksRootVetoed and is used to iterate over the raw logs and unpacked data for StrategyHooksRootVetoed events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootVetoedIterator struct {
	Event *SuperVaultAggregatorStrategyHooksRootVetoed // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStrategyHooksRootVetoedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStrategyHooksRootVetoed)
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
		it.Event = new(SuperVaultAggregatorStrategyHooksRootVetoed)
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
func (it *SuperVaultAggregatorStrategyHooksRootVetoedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStrategyHooksRootVetoedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStrategyHooksRootVetoed represents a StrategyHooksRootVetoed event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyHooksRootVetoed struct {
	Guardian common.Address
	Strategy common.Address
	Root     [32]byte
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyHooksRootVetoed is a free log retrieval operation binding the contract event 0x13fb75f412cd7275ea6c0c59de6d99dd291eddab76417824e0edc385e5d75561.
//
// Solidity: event StrategyHooksRootVetoed(address indexed guardian, address indexed strategy, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStrategyHooksRootVetoed(opts *bind.FilterOpts, guardian []common.Address, strategy []common.Address, root [][32]byte) (*SuperVaultAggregatorStrategyHooksRootVetoedIterator, error) {

	var guardianRule []interface{}
	for _, guardianItem := range guardian {
		guardianRule = append(guardianRule, guardianItem)
	}
	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StrategyHooksRootVetoed", guardianRule, strategyRule, rootRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStrategyHooksRootVetoedIterator{contract: _SuperVaultAggregator.contract, event: "StrategyHooksRootVetoed", logs: logs, sub: sub}, nil
}

// WatchStrategyHooksRootVetoed is a free log subscription operation binding the contract event 0x13fb75f412cd7275ea6c0c59de6d99dd291eddab76417824e0edc385e5d75561.
//
// Solidity: event StrategyHooksRootVetoed(address indexed guardian, address indexed strategy, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStrategyHooksRootVetoed(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStrategyHooksRootVetoed, guardian []common.Address, strategy []common.Address, root [][32]byte) (event.Subscription, error) {

	var guardianRule []interface{}
	for _, guardianItem := range guardian {
		guardianRule = append(guardianRule, guardianItem)
	}
	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StrategyHooksRootVetoed", guardianRule, strategyRule, rootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStrategyHooksRootVetoed)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootVetoed", log); err != nil {
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

// ParseStrategyHooksRootVetoed is a log parse operation binding the contract event 0x13fb75f412cd7275ea6c0c59de6d99dd291eddab76417824e0edc385e5d75561.
//
// Solidity: event StrategyHooksRootVetoed(address indexed guardian, address indexed strategy, bytes32 indexed root)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStrategyHooksRootVetoed(log types.Log) (*SuperVaultAggregatorStrategyHooksRootVetoed, error) {
	event := new(SuperVaultAggregatorStrategyHooksRootVetoed)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyHooksRootVetoed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStrategyPausedIterator is returned from FilterStrategyPaused and is used to iterate over the raw logs and unpacked data for StrategyPaused events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyPausedIterator struct {
	Event *SuperVaultAggregatorStrategyPaused // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStrategyPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStrategyPaused)
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
		it.Event = new(SuperVaultAggregatorStrategyPaused)
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
func (it *SuperVaultAggregatorStrategyPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStrategyPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStrategyPaused represents a StrategyPaused event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyPaused struct {
	Strategy common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyPaused is a free log retrieval operation binding the contract event 0xc2897a3765ea6cd9ed9ce463d3bc9c9cf968f21f8664b62684e1254d3b0f9ee5.
//
// Solidity: event StrategyPaused(address indexed strategy)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStrategyPaused(opts *bind.FilterOpts, strategy []common.Address) (*SuperVaultAggregatorStrategyPausedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StrategyPaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStrategyPausedIterator{contract: _SuperVaultAggregator.contract, event: "StrategyPaused", logs: logs, sub: sub}, nil
}

// WatchStrategyPaused is a free log subscription operation binding the contract event 0xc2897a3765ea6cd9ed9ce463d3bc9c9cf968f21f8664b62684e1254d3b0f9ee5.
//
// Solidity: event StrategyPaused(address indexed strategy)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStrategyPaused(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStrategyPaused, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StrategyPaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStrategyPaused)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyPaused", log); err != nil {
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
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStrategyPaused(log types.Log) (*SuperVaultAggregatorStrategyPaused, error) {
	event := new(SuperVaultAggregatorStrategyPaused)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyPaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorStrategyUnpausedIterator is returned from FilterStrategyUnpaused and is used to iterate over the raw logs and unpacked data for StrategyUnpaused events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyUnpausedIterator struct {
	Event *SuperVaultAggregatorStrategyUnpaused // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorStrategyUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorStrategyUnpaused)
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
		it.Event = new(SuperVaultAggregatorStrategyUnpaused)
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
func (it *SuperVaultAggregatorStrategyUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorStrategyUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorStrategyUnpaused represents a StrategyUnpaused event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorStrategyUnpaused struct {
	Strategy common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterStrategyUnpaused is a free log retrieval operation binding the contract event 0x9de75c520457842eb5fe159114348bf5358100a1acaf1bcb5052f64f347503df.
//
// Solidity: event StrategyUnpaused(address indexed strategy)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterStrategyUnpaused(opts *bind.FilterOpts, strategy []common.Address) (*SuperVaultAggregatorStrategyUnpausedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "StrategyUnpaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorStrategyUnpausedIterator{contract: _SuperVaultAggregator.contract, event: "StrategyUnpaused", logs: logs, sub: sub}, nil
}

// WatchStrategyUnpaused is a free log subscription operation binding the contract event 0x9de75c520457842eb5fe159114348bf5358100a1acaf1bcb5052f64f347503df.
//
// Solidity: event StrategyUnpaused(address indexed strategy)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchStrategyUnpaused(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorStrategyUnpaused, strategy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "StrategyUnpaused", strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorStrategyUnpaused)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyUnpaused", log); err != nil {
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
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseStrategyUnpaused(log types.Log) (*SuperVaultAggregatorStrategyUnpaused, error) {
	event := new(SuperVaultAggregatorStrategyUnpaused)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "StrategyUnpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorUpkeepCostUpdatedIterator is returned from FilterUpkeepCostUpdated and is used to iterate over the raw logs and unpacked data for UpkeepCostUpdated events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepCostUpdatedIterator struct {
	Event *SuperVaultAggregatorUpkeepCostUpdated // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorUpkeepCostUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorUpkeepCostUpdated)
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
		it.Event = new(SuperVaultAggregatorUpkeepCostUpdated)
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
func (it *SuperVaultAggregatorUpkeepCostUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorUpkeepCostUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorUpkeepCostUpdated represents a UpkeepCostUpdated event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepCostUpdated struct {
	OldCost *big.Int
	NewCost *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUpkeepCostUpdated is a free log retrieval operation binding the contract event 0x39bca166dfce33a0df0f6a53e61159a307a9cf65e4c4982a9d025df35b60e746.
//
// Solidity: event UpkeepCostUpdated(uint256 oldCost, uint256 newCost)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterUpkeepCostUpdated(opts *bind.FilterOpts) (*SuperVaultAggregatorUpkeepCostUpdatedIterator, error) {

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "UpkeepCostUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorUpkeepCostUpdatedIterator{contract: _SuperVaultAggregator.contract, event: "UpkeepCostUpdated", logs: logs, sub: sub}, nil
}

// WatchUpkeepCostUpdated is a free log subscription operation binding the contract event 0x39bca166dfce33a0df0f6a53e61159a307a9cf65e4c4982a9d025df35b60e746.
//
// Solidity: event UpkeepCostUpdated(uint256 oldCost, uint256 newCost)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchUpkeepCostUpdated(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorUpkeepCostUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "UpkeepCostUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorUpkeepCostUpdated)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepCostUpdated", log); err != nil {
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

// ParseUpkeepCostUpdated is a log parse operation binding the contract event 0x39bca166dfce33a0df0f6a53e61159a307a9cf65e4c4982a9d025df35b60e746.
//
// Solidity: event UpkeepCostUpdated(uint256 oldCost, uint256 newCost)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseUpkeepCostUpdated(log types.Log) (*SuperVaultAggregatorUpkeepCostUpdated, error) {
	event := new(SuperVaultAggregatorUpkeepCostUpdated)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepCostUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorUpkeepDepositedIterator is returned from FilterUpkeepDeposited and is used to iterate over the raw logs and unpacked data for UpkeepDeposited events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepDepositedIterator struct {
	Event *SuperVaultAggregatorUpkeepDeposited // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorUpkeepDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorUpkeepDeposited)
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
		it.Event = new(SuperVaultAggregatorUpkeepDeposited)
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
func (it *SuperVaultAggregatorUpkeepDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorUpkeepDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorUpkeepDeposited represents a UpkeepDeposited event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepDeposited struct {
	Strategist common.Address
	Amount     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterUpkeepDeposited is a free log retrieval operation binding the contract event 0xf0616af70d35af23c32610a6397a036a898c088ade99b972a26dc56e54798865.
//
// Solidity: event UpkeepDeposited(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterUpkeepDeposited(opts *bind.FilterOpts, strategist []common.Address) (*SuperVaultAggregatorUpkeepDepositedIterator, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "UpkeepDeposited", strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorUpkeepDepositedIterator{contract: _SuperVaultAggregator.contract, event: "UpkeepDeposited", logs: logs, sub: sub}, nil
}

// WatchUpkeepDeposited is a free log subscription operation binding the contract event 0xf0616af70d35af23c32610a6397a036a898c088ade99b972a26dc56e54798865.
//
// Solidity: event UpkeepDeposited(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchUpkeepDeposited(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorUpkeepDeposited, strategist []common.Address) (event.Subscription, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "UpkeepDeposited", strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorUpkeepDeposited)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepDeposited", log); err != nil {
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

// ParseUpkeepDeposited is a log parse operation binding the contract event 0xf0616af70d35af23c32610a6397a036a898c088ade99b972a26dc56e54798865.
//
// Solidity: event UpkeepDeposited(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseUpkeepDeposited(log types.Log) (*SuperVaultAggregatorUpkeepDeposited, error) {
	event := new(SuperVaultAggregatorUpkeepDeposited)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorUpkeepSpentIterator is returned from FilterUpkeepSpent and is used to iterate over the raw logs and unpacked data for UpkeepSpent events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepSpentIterator struct {
	Event *SuperVaultAggregatorUpkeepSpent // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorUpkeepSpentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorUpkeepSpent)
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
		it.Event = new(SuperVaultAggregatorUpkeepSpent)
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
func (it *SuperVaultAggregatorUpkeepSpentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorUpkeepSpentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorUpkeepSpent represents a UpkeepSpent event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepSpent struct {
	Strategist common.Address
	Amount     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterUpkeepSpent is a free log retrieval operation binding the contract event 0x15c92f373007d64c3ac31aa659df53e4a3340021ce36bdc35691470b05c6aa21.
//
// Solidity: event UpkeepSpent(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterUpkeepSpent(opts *bind.FilterOpts, strategist []common.Address) (*SuperVaultAggregatorUpkeepSpentIterator, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "UpkeepSpent", strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorUpkeepSpentIterator{contract: _SuperVaultAggregator.contract, event: "UpkeepSpent", logs: logs, sub: sub}, nil
}

// WatchUpkeepSpent is a free log subscription operation binding the contract event 0x15c92f373007d64c3ac31aa659df53e4a3340021ce36bdc35691470b05c6aa21.
//
// Solidity: event UpkeepSpent(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchUpkeepSpent(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorUpkeepSpent, strategist []common.Address) (event.Subscription, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "UpkeepSpent", strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorUpkeepSpent)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepSpent", log); err != nil {
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

// ParseUpkeepSpent is a log parse operation binding the contract event 0x15c92f373007d64c3ac31aa659df53e4a3340021ce36bdc35691470b05c6aa21.
//
// Solidity: event UpkeepSpent(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseUpkeepSpent(log types.Log) (*SuperVaultAggregatorUpkeepSpent, error) {
	event := new(SuperVaultAggregatorUpkeepSpent)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepSpent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorUpkeepWithdrawnIterator is returned from FilterUpkeepWithdrawn and is used to iterate over the raw logs and unpacked data for UpkeepWithdrawn events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepWithdrawnIterator struct {
	Event *SuperVaultAggregatorUpkeepWithdrawn // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorUpkeepWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorUpkeepWithdrawn)
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
		it.Event = new(SuperVaultAggregatorUpkeepWithdrawn)
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
func (it *SuperVaultAggregatorUpkeepWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorUpkeepWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorUpkeepWithdrawn represents a UpkeepWithdrawn event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorUpkeepWithdrawn struct {
	Strategist common.Address
	Amount     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterUpkeepWithdrawn is a free log retrieval operation binding the contract event 0x4a588cb81e6e407560dfbf48e566f684e0b6b791bd8ced912e4f9c58aa99e3d2.
//
// Solidity: event UpkeepWithdrawn(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterUpkeepWithdrawn(opts *bind.FilterOpts, strategist []common.Address) (*SuperVaultAggregatorUpkeepWithdrawnIterator, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "UpkeepWithdrawn", strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorUpkeepWithdrawnIterator{contract: _SuperVaultAggregator.contract, event: "UpkeepWithdrawn", logs: logs, sub: sub}, nil
}

// WatchUpkeepWithdrawn is a free log subscription operation binding the contract event 0x4a588cb81e6e407560dfbf48e566f684e0b6b791bd8ced912e4f9c58aa99e3d2.
//
// Solidity: event UpkeepWithdrawn(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchUpkeepWithdrawn(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorUpkeepWithdrawn, strategist []common.Address) (event.Subscription, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "UpkeepWithdrawn", strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorUpkeepWithdrawn)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepWithdrawn", log); err != nil {
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

// ParseUpkeepWithdrawn is a log parse operation binding the contract event 0x4a588cb81e6e407560dfbf48e566f684e0b6b791bd8ced912e4f9c58aa99e3d2.
//
// Solidity: event UpkeepWithdrawn(address indexed strategist, uint256 amount)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseUpkeepWithdrawn(log types.Log) (*SuperVaultAggregatorUpkeepWithdrawn, error) {
	event := new(SuperVaultAggregatorUpkeepWithdrawn)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "UpkeepWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperVaultAggregatorVaultDeployedIterator is returned from FilterVaultDeployed and is used to iterate over the raw logs and unpacked data for VaultDeployed events raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorVaultDeployedIterator struct {
	Event *SuperVaultAggregatorVaultDeployed // Event containing the contract specifics and raw log

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
func (it *SuperVaultAggregatorVaultDeployedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperVaultAggregatorVaultDeployed)
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
		it.Event = new(SuperVaultAggregatorVaultDeployed)
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
func (it *SuperVaultAggregatorVaultDeployedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperVaultAggregatorVaultDeployedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperVaultAggregatorVaultDeployed represents a VaultDeployed event raised by the SuperVaultAggregator contract.
type SuperVaultAggregatorVaultDeployed struct {
	Vault    common.Address
	Strategy common.Address
	Escrow   common.Address
	Asset    common.Address
	Name     string
	Symbol   string
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterVaultDeployed is a free log retrieval operation binding the contract event 0x4e0ec6694e967b226634747e76e28b7f488cb081ae303528e527f8d4430e62f9.
//
// Solidity: event VaultDeployed(address indexed vault, address indexed strategy, address escrow, address asset, string name, string symbol)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) FilterVaultDeployed(opts *bind.FilterOpts, vault []common.Address, strategy []common.Address) (*SuperVaultAggregatorVaultDeployedIterator, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.FilterLogs(opts, "VaultDeployed", vaultRule, strategyRule)
	if err != nil {
		return nil, err
	}
	return &SuperVaultAggregatorVaultDeployedIterator{contract: _SuperVaultAggregator.contract, event: "VaultDeployed", logs: logs, sub: sub}, nil
}

// WatchVaultDeployed is a free log subscription operation binding the contract event 0x4e0ec6694e967b226634747e76e28b7f488cb081ae303528e527f8d4430e62f9.
//
// Solidity: event VaultDeployed(address indexed vault, address indexed strategy, address escrow, address asset, string name, string symbol)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) WatchVaultDeployed(opts *bind.WatchOpts, sink chan<- *SuperVaultAggregatorVaultDeployed, vault []common.Address, strategy []common.Address) (event.Subscription, error) {

	var vaultRule []interface{}
	for _, vaultItem := range vault {
		vaultRule = append(vaultRule, vaultItem)
	}
	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}

	logs, sub, err := _SuperVaultAggregator.contract.WatchLogs(opts, "VaultDeployed", vaultRule, strategyRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperVaultAggregatorVaultDeployed)
				if err := _SuperVaultAggregator.contract.UnpackLog(event, "VaultDeployed", log); err != nil {
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

// ParseVaultDeployed is a log parse operation binding the contract event 0x4e0ec6694e967b226634747e76e28b7f488cb081ae303528e527f8d4430e62f9.
//
// Solidity: event VaultDeployed(address indexed vault, address indexed strategy, address escrow, address asset, string name, string symbol)
func (_SuperVaultAggregator *SuperVaultAggregatorFilterer) ParseVaultDeployed(log types.Log) (*SuperVaultAggregatorVaultDeployed, error) {
	event := new(SuperVaultAggregatorVaultDeployed)
	if err := _SuperVaultAggregator.contract.UnpackLog(event, "VaultDeployed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
