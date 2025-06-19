// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperGovernor

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

// SuperGovernorMetaData contains all meta data concerning the SuperGovernor contract.
var SuperGovernorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superGovernor\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"governor\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"bankManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"treasury_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"prover_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"BANK_MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BANK_MANAGER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"DEFAULT_ADMIN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ECDSAPPSORACLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GOVERNOR_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"GUARDIAN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"SUP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_ASSET_FACTORY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"SUPER_BANK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_GOVERNOR_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"SUPER_ORACLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_VAULT_AGGREGATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TREASURY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"UP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"VAULT_BANK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"addExecutor\",\"inputs\":[{\"name\":\"executor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addICCToWhitelist\",\"inputs\":[{\"name\":\"icc\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addRelayer\",\"inputs\":[{\"name\":\"relayer_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addSuperformStrategist\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addValidator\",\"inputs\":[{\"name\":\"validator\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addVaultBank\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"vaultBank\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"batchSetEmergencyPrices\",\"inputs\":[{\"name\":\"tokens_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"prices_\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"batchSetOracleUptimeFeed\",\"inputs\":[{\"name\":\"dataOracles_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"uptimeOracles_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"gracePeriods_\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"changeHooksRootUpdateTimelock\",\"inputs\":[{\"name\":\"newTimelock_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"changePrimaryStrategist\",\"inputs\":[{\"name\":\"strategy_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newStrategist_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeActivePPSOracleChange\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeAddIncentiveTokens\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeFeeUpdate\",\"inputs\":[{\"name\":\"feeType\",\"type\":\"uint8\",\"internalType\":\"enumFeeType\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeRemoveIncentiveTokens\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeSuperBankHookMerkleRootUpdate\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeUpkeepCostPerUpdateChange\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeUpkeepPaymentsChange\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeVaultBankHookMerkleRootUpdate\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"freezeStrategistTakeover\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getActivePPSOracle\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAddress\",\"inputs\":[{\"name\":\"key\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAllSuperformStrategists\",\"inputs\":[],\"outputs\":[{\"name\":\"strategists\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getFee\",\"inputs\":[{\"name\":\"feeType\",\"type\":\"uint8\",\"internalType\":\"enumFeeType\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPPSOracleQuorum\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposedActivePPSOracle\",\"inputs\":[],\"outputs\":[{\"name\":\"proposedOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposedSuperBankHookMerkleRoot\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"proposedRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposedUpkeepCostPerUpdate\",\"inputs\":[],\"outputs\":[{\"name\":\"proposedCost\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposedUpkeepPaymentsStatus\",\"inputs\":[],\"outputs\":[{\"name\":\"enabled\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposedVaultBankHookMerkleRoot\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"proposedRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRegisteredFulfillRequestsHooks\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRegisteredHooks\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRoleAdmin\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStrategistsPaginated\",\"inputs\":[{\"name\":\"cursor\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"limit\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"chunkOfStrategists\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"next\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getSuperBankHookMerkleRoot\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getSuperformStrategistsCount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getUpkeepCostPerUpdate\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getValidators\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getVaultBank\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getVaultBankHookMerkleRoot\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"grantRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"hasRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isActivePPSOracle\",\"inputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isExecutor\",\"inputs\":[{\"name\":\"executor\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isFulfillRequestsHookRegistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isGuardian\",\"inputs\":[{\"name\":\"guardian\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isHookRegistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isRelayer\",\"inputs\":[{\"name\":\"relayer\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isStrategistTakeoverFrozen\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isSuperformStrategist\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isSuperform\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isUpkeepPaymentsEnabled\",\"inputs\":[],\"outputs\":[{\"name\":\"enabled\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidator\",\"inputs\":[{\"name\":\"validator\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isWhitelistedIncentiveToken\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeActivePPSOracle\",\"inputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeAddIncentiveTokens\",\"inputs\":[{\"name\":\"tokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeFee\",\"inputs\":[{\"name\":\"feeType\",\"type\":\"uint8\",\"internalType\":\"enumFeeType\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeGlobalHooksRoot\",\"inputs\":[{\"name\":\"newRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeRemoveIncentiveTokens\",\"inputs\":[{\"name\":\"tokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeSuperBankHookMerkleRoot\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeUpkeepCostPerUpdate\",\"inputs\":[{\"name\":\"newCost_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeUpkeepPaymentsChange\",\"inputs\":[{\"name\":\"enabled\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeVaultBankHookMerkleRoot\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"queueOracleProviderRemoval\",\"inputs\":[{\"name\":\"providers_\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"queueOracleUpdate\",\"inputs\":[{\"name\":\"bases_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"quotes_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"providers_\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"feeds_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"registerHook\",\"inputs\":[{\"name\":\"hook_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isFulfillRequestsHook_\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeExecutor\",\"inputs\":[{\"name\":\"executor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeICCFromWhitelist\",\"inputs\":[{\"name\":\"icc\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeRelayer\",\"inputs\":[{\"name\":\"relayer_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeSuperformStrategist\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeValidator\",\"inputs\":[{\"name\":\"validator\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"callerConfirmation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"revokeRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setActivePPSOracle\",\"inputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setAddress\",\"inputs\":[{\"name\":\"key\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"value\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setEmergencyPrice\",\"inputs\":[{\"name\":\"token_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"price_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setGlobalHooksRootVetoStatus\",\"inputs\":[{\"name\":\"vetoed_\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setOracleFeedMaxStaleness\",\"inputs\":[{\"name\":\"feed_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newMaxStaleness_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setOracleFeedMaxStalenessBatch\",\"inputs\":[{\"name\":\"feeds_\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"newMaxStalenessList_\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setOracleMaxStaleness\",\"inputs\":[{\"name\":\"newMaxStaleness_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setPPSOracleQuorum\",\"inputs\":[{\"name\":\"quorum\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setProver\",\"inputs\":[{\"name\":\"prover_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setStrategyHooksRootVetoStatus\",\"inputs\":[{\"name\":\"strategy_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"vetoed_\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setSuperAssetManager\",\"inputs\":[{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_superAssetManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"supportsInterface\",\"inputs\":[{\"name\":\"interfaceId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"unregisterHook\",\"inputs\":[{\"name\":\"hook_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isFulfillRequestsHook_\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"ActivePPSOracleChanged\",\"inputs\":[{\"name\":\"oldOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ActivePPSOracleProposed\",\"inputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ActivePPSOracleSet\",\"inputs\":[{\"name\":\"oracle\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AddressSet\",\"inputs\":[{\"name\":\"key\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"value\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutorAdded\",\"inputs\":[{\"name\":\"executor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ExecutorRemoved\",\"inputs\":[{\"name\":\"executor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeeProposed\",\"inputs\":[{\"name\":\"feeType\",\"type\":\"uint8\",\"indexed\":true,\"internalType\":\"enumFeeType\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeeUpdated\",\"inputs\":[{\"name\":\"feeType\",\"type\":\"uint8\",\"indexed\":true,\"internalType\":\"enumFeeType\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FulfillRequestsHookRegistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FulfillRequestsHookUnregistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookApproved\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookRemoved\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PPSOracleQuorumUpdated\",\"inputs\":[{\"name\":\"quorum\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProverSet\",\"inputs\":[{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RelayerAdded\",\"inputs\":[{\"name\":\"relayer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RelayerRemoved\",\"inputs\":[{\"name\":\"relayer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RevenueShareUpdated\",\"inputs\":[{\"name\":\"share\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleAdminChanged\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"previousAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleGranted\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleRevoked\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategistAdded\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategistRemoved\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StrategistTakeoversFrozen\",\"inputs\":[],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperBankHookMerkleRootProposed\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperBankHookMerkleRootUpdated\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperformStrategistAdded\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperformStrategistRemoved\",\"inputs\":[{\"name\":\"strategist\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepCostPerUpdateChanged\",\"inputs\":[{\"name\":\"newCost\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepCostPerUpdateProposed\",\"inputs\":[{\"name\":\"newCost\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepPaymentsChangeProposed\",\"inputs\":[{\"name\":\"enabled\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UpkeepPaymentsChanged\",\"inputs\":[{\"name\":\"enabled\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ValidatorAdded\",\"inputs\":[{\"name\":\"validator\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ValidatorRemoved\",\"inputs\":[{\"name\":\"validator\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultBankAddressAdded\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"indexed\":true,\"internalType\":\"uint64\"},{\"name\":\"vaultBank\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultBankHookMerkleRootProposed\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"VaultBankHookMerkleRootUpdated\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WhitelistedIncentiveTokensAdded\",\"inputs\":[{\"name\":\"tokens\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WhitelistedIncentiveTokensProposed\",\"inputs\":[{\"name\":\"tokens\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WhitelistedIncentiveTokensRemoved\",\"inputs\":[{\"name\":\"tokens\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"AccessControlBadConfirmation\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AccessControlUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"neededRole\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"CONTRACT_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CONTRACT_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EXECUTOR_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EXECUTOR_NOT_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FULFILL_REQUESTS_HOOK_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FULFILL_REQUESTS_HOOK_NOT_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_ALREADY_APPROVED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_NOT_APPROVED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_QUORUM\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_REVENUE_SHARE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_TIMESTAMP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MUST_USE_TIMELOCK_FOR_CHANGE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_PROPOSED_INCENTIVE_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_WHITELISTED_INCENTIVE_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_ACTIVE_PPS_ORACLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PENDING_CHANGE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PROPOSED_FEE\",\"inputs\":[{\"name\":\"feeType\",\"type\":\"uint8\",\"internalType\":\"enumFeeType\"}]},{\"type\":\"error\",\"name\":\"NO_PROPOSED_MERKLE_ROOT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PROPOSED_PPS_ORACLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_PROPOSED_UPKEEP_COST\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ONLY_GOVERNOR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RELAYER_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RELAYER_NOT_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGIST_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGIST_NOT_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STRATEGIST_TAKEOVERS_FROZEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TIMELOCK_NOT_EXPIRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TOKEN_ALREADY_WHITELISTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VALIDATOR_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VALIDATOR_NOT_REGISTERED\",\"inputs\":[]}]",
}

// SuperGovernorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperGovernorMetaData.ABI instead.
var SuperGovernorABI = SuperGovernorMetaData.ABI

// SuperGovernor is an auto generated Go binding around an Ethereum contract.
type SuperGovernor struct {
	SuperGovernorCaller     // Read-only binding to the contract
	SuperGovernorTransactor // Write-only binding to the contract
	SuperGovernorFilterer   // Log filterer for contract events
}

// SuperGovernorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperGovernorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperGovernorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperGovernorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperGovernorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperGovernorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperGovernorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperGovernorSession struct {
	Contract     *SuperGovernor    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperGovernorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperGovernorCallerSession struct {
	Contract *SuperGovernorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// SuperGovernorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperGovernorTransactorSession struct {
	Contract     *SuperGovernorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SuperGovernorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperGovernorRaw struct {
	Contract *SuperGovernor // Generic contract binding to access the raw methods on
}

// SuperGovernorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperGovernorCallerRaw struct {
	Contract *SuperGovernorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperGovernorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperGovernorTransactorRaw struct {
	Contract *SuperGovernorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperGovernor creates a new instance of SuperGovernor, bound to a specific deployed contract.
func NewSuperGovernor(address common.Address, backend bind.ContractBackend) (*SuperGovernor, error) {
	contract, err := bindSuperGovernor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperGovernor{SuperGovernorCaller: SuperGovernorCaller{contract: contract}, SuperGovernorTransactor: SuperGovernorTransactor{contract: contract}, SuperGovernorFilterer: SuperGovernorFilterer{contract: contract}}, nil
}

// NewSuperGovernorCaller creates a new read-only instance of SuperGovernor, bound to a specific deployed contract.
func NewSuperGovernorCaller(address common.Address, caller bind.ContractCaller) (*SuperGovernorCaller, error) {
	contract, err := bindSuperGovernor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorCaller{contract: contract}, nil
}

// NewSuperGovernorTransactor creates a new write-only instance of SuperGovernor, bound to a specific deployed contract.
func NewSuperGovernorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperGovernorTransactor, error) {
	contract, err := bindSuperGovernor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorTransactor{contract: contract}, nil
}

// NewSuperGovernorFilterer creates a new log filterer instance of SuperGovernor, bound to a specific deployed contract.
func NewSuperGovernorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperGovernorFilterer, error) {
	contract, err := bindSuperGovernor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorFilterer{contract: contract}, nil
}

// bindSuperGovernor binds a generic wrapper to an already deployed contract.
func bindSuperGovernor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperGovernorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperGovernor *SuperGovernorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperGovernor.Contract.SuperGovernorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperGovernor *SuperGovernorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SuperGovernorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperGovernor *SuperGovernorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SuperGovernorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperGovernor *SuperGovernorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperGovernor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperGovernor *SuperGovernorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperGovernor *SuperGovernorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperGovernor.Contract.contract.Transact(opts, method, params...)
}

// BANKMANAGER is a free data retrieval call binding the contract method 0x67e21123.
//
// Solidity: function BANK_MANAGER() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) BANKMANAGER(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "BANK_MANAGER")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// BANKMANAGER is a free data retrieval call binding the contract method 0x67e21123.
//
// Solidity: function BANK_MANAGER() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) BANKMANAGER() ([32]byte, error) {
	return _SuperGovernor.Contract.BANKMANAGER(&_SuperGovernor.CallOpts)
}

// BANKMANAGER is a free data retrieval call binding the contract method 0x67e21123.
//
// Solidity: function BANK_MANAGER() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) BANKMANAGER() ([32]byte, error) {
	return _SuperGovernor.Contract.BANKMANAGER(&_SuperGovernor.CallOpts)
}

// BANKMANAGERROLE is a free data retrieval call binding the contract method 0xf2157052.
//
// Solidity: function BANK_MANAGER_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) BANKMANAGERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "BANK_MANAGER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// BANKMANAGERROLE is a free data retrieval call binding the contract method 0xf2157052.
//
// Solidity: function BANK_MANAGER_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) BANKMANAGERROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.BANKMANAGERROLE(&_SuperGovernor.CallOpts)
}

// BANKMANAGERROLE is a free data retrieval call binding the contract method 0xf2157052.
//
// Solidity: function BANK_MANAGER_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) BANKMANAGERROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.BANKMANAGERROLE(&_SuperGovernor.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) DEFAULTADMINROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "DEFAULT_ADMIN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.DEFAULTADMINROLE(&_SuperGovernor.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.DEFAULTADMINROLE(&_SuperGovernor.CallOpts)
}

// ECDSAPPSORACLE is a free data retrieval call binding the contract method 0xffdb5200.
//
// Solidity: function ECDSAPPSORACLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) ECDSAPPSORACLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "ECDSAPPSORACLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ECDSAPPSORACLE is a free data retrieval call binding the contract method 0xffdb5200.
//
// Solidity: function ECDSAPPSORACLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) ECDSAPPSORACLE() ([32]byte, error) {
	return _SuperGovernor.Contract.ECDSAPPSORACLE(&_SuperGovernor.CallOpts)
}

// ECDSAPPSORACLE is a free data retrieval call binding the contract method 0xffdb5200.
//
// Solidity: function ECDSAPPSORACLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) ECDSAPPSORACLE() ([32]byte, error) {
	return _SuperGovernor.Contract.ECDSAPPSORACLE(&_SuperGovernor.CallOpts)
}

// GOVERNORROLE is a free data retrieval call binding the contract method 0xccc57490.
//
// Solidity: function GOVERNOR_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) GOVERNORROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "GOVERNOR_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GOVERNORROLE is a free data retrieval call binding the contract method 0xccc57490.
//
// Solidity: function GOVERNOR_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) GOVERNORROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.GOVERNORROLE(&_SuperGovernor.CallOpts)
}

// GOVERNORROLE is a free data retrieval call binding the contract method 0xccc57490.
//
// Solidity: function GOVERNOR_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) GOVERNORROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.GOVERNORROLE(&_SuperGovernor.CallOpts)
}

// GUARDIANROLE is a free data retrieval call binding the contract method 0x24ea54f4.
//
// Solidity: function GUARDIAN_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) GUARDIANROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "GUARDIAN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GUARDIANROLE is a free data retrieval call binding the contract method 0x24ea54f4.
//
// Solidity: function GUARDIAN_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) GUARDIANROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.GUARDIANROLE(&_SuperGovernor.CallOpts)
}

// GUARDIANROLE is a free data retrieval call binding the contract method 0x24ea54f4.
//
// Solidity: function GUARDIAN_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) GUARDIANROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.GUARDIANROLE(&_SuperGovernor.CallOpts)
}

// SUP is a free data retrieval call binding the contract method 0x95c0bf69.
//
// Solidity: function SUP() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) SUP(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "SUP")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SUP is a free data retrieval call binding the contract method 0x95c0bf69.
//
// Solidity: function SUP() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) SUP() ([32]byte, error) {
	return _SuperGovernor.Contract.SUP(&_SuperGovernor.CallOpts)
}

// SUP is a free data retrieval call binding the contract method 0x95c0bf69.
//
// Solidity: function SUP() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) SUP() ([32]byte, error) {
	return _SuperGovernor.Contract.SUP(&_SuperGovernor.CallOpts)
}

// SUPERASSETFACTORY is a free data retrieval call binding the contract method 0xec63a694.
//
// Solidity: function SUPER_ASSET_FACTORY() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) SUPERASSETFACTORY(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "SUPER_ASSET_FACTORY")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SUPERASSETFACTORY is a free data retrieval call binding the contract method 0xec63a694.
//
// Solidity: function SUPER_ASSET_FACTORY() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) SUPERASSETFACTORY() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERASSETFACTORY(&_SuperGovernor.CallOpts)
}

// SUPERASSETFACTORY is a free data retrieval call binding the contract method 0xec63a694.
//
// Solidity: function SUPER_ASSET_FACTORY() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) SUPERASSETFACTORY() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERASSETFACTORY(&_SuperGovernor.CallOpts)
}

// SUPERBANK is a free data retrieval call binding the contract method 0x6f2140c1.
//
// Solidity: function SUPER_BANK() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) SUPERBANK(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "SUPER_BANK")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SUPERBANK is a free data retrieval call binding the contract method 0x6f2140c1.
//
// Solidity: function SUPER_BANK() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) SUPERBANK() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERBANK(&_SuperGovernor.CallOpts)
}

// SUPERBANK is a free data retrieval call binding the contract method 0x6f2140c1.
//
// Solidity: function SUPER_BANK() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) SUPERBANK() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERBANK(&_SuperGovernor.CallOpts)
}

// SUPERGOVERNORROLE is a free data retrieval call binding the contract method 0xec45ad53.
//
// Solidity: function SUPER_GOVERNOR_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) SUPERGOVERNORROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "SUPER_GOVERNOR_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SUPERGOVERNORROLE is a free data retrieval call binding the contract method 0xec45ad53.
//
// Solidity: function SUPER_GOVERNOR_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) SUPERGOVERNORROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERGOVERNORROLE(&_SuperGovernor.CallOpts)
}

// SUPERGOVERNORROLE is a free data retrieval call binding the contract method 0xec45ad53.
//
// Solidity: function SUPER_GOVERNOR_ROLE() pure returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) SUPERGOVERNORROLE() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERGOVERNORROLE(&_SuperGovernor.CallOpts)
}

// SUPERORACLE is a free data retrieval call binding the contract method 0x90d4a56d.
//
// Solidity: function SUPER_ORACLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) SUPERORACLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "SUPER_ORACLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SUPERORACLE is a free data retrieval call binding the contract method 0x90d4a56d.
//
// Solidity: function SUPER_ORACLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) SUPERORACLE() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERORACLE(&_SuperGovernor.CallOpts)
}

// SUPERORACLE is a free data retrieval call binding the contract method 0x90d4a56d.
//
// Solidity: function SUPER_ORACLE() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) SUPERORACLE() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERORACLE(&_SuperGovernor.CallOpts)
}

// SUPERVAULTAGGREGATOR is a free data retrieval call binding the contract method 0xc9838819.
//
// Solidity: function SUPER_VAULT_AGGREGATOR() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) SUPERVAULTAGGREGATOR(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "SUPER_VAULT_AGGREGATOR")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SUPERVAULTAGGREGATOR is a free data retrieval call binding the contract method 0xc9838819.
//
// Solidity: function SUPER_VAULT_AGGREGATOR() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) SUPERVAULTAGGREGATOR() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERVAULTAGGREGATOR(&_SuperGovernor.CallOpts)
}

// SUPERVAULTAGGREGATOR is a free data retrieval call binding the contract method 0xc9838819.
//
// Solidity: function SUPER_VAULT_AGGREGATOR() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) SUPERVAULTAGGREGATOR() ([32]byte, error) {
	return _SuperGovernor.Contract.SUPERVAULTAGGREGATOR(&_SuperGovernor.CallOpts)
}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) TREASURY(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "TREASURY")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) TREASURY() ([32]byte, error) {
	return _SuperGovernor.Contract.TREASURY(&_SuperGovernor.CallOpts)
}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) TREASURY() ([32]byte, error) {
	return _SuperGovernor.Contract.TREASURY(&_SuperGovernor.CallOpts)
}

// UP is a free data retrieval call binding the contract method 0x24f4ec51.
//
// Solidity: function UP() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) UP(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "UP")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// UP is a free data retrieval call binding the contract method 0x24f4ec51.
//
// Solidity: function UP() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) UP() ([32]byte, error) {
	return _SuperGovernor.Contract.UP(&_SuperGovernor.CallOpts)
}

// UP is a free data retrieval call binding the contract method 0x24f4ec51.
//
// Solidity: function UP() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) UP() ([32]byte, error) {
	return _SuperGovernor.Contract.UP(&_SuperGovernor.CallOpts)
}

// VAULTBANK is a free data retrieval call binding the contract method 0x39e0739e.
//
// Solidity: function VAULT_BANK() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) VAULTBANK(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "VAULT_BANK")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// VAULTBANK is a free data retrieval call binding the contract method 0x39e0739e.
//
// Solidity: function VAULT_BANK() view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) VAULTBANK() ([32]byte, error) {
	return _SuperGovernor.Contract.VAULTBANK(&_SuperGovernor.CallOpts)
}

// VAULTBANK is a free data retrieval call binding the contract method 0x39e0739e.
//
// Solidity: function VAULT_BANK() view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) VAULTBANK() ([32]byte, error) {
	return _SuperGovernor.Contract.VAULTBANK(&_SuperGovernor.CallOpts)
}

// GetActivePPSOracle is a free data retrieval call binding the contract method 0x275f0f2b.
//
// Solidity: function getActivePPSOracle() view returns(address)
func (_SuperGovernor *SuperGovernorCaller) GetActivePPSOracle(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getActivePPSOracle")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetActivePPSOracle is a free data retrieval call binding the contract method 0x275f0f2b.
//
// Solidity: function getActivePPSOracle() view returns(address)
func (_SuperGovernor *SuperGovernorSession) GetActivePPSOracle() (common.Address, error) {
	return _SuperGovernor.Contract.GetActivePPSOracle(&_SuperGovernor.CallOpts)
}

// GetActivePPSOracle is a free data retrieval call binding the contract method 0x275f0f2b.
//
// Solidity: function getActivePPSOracle() view returns(address)
func (_SuperGovernor *SuperGovernorCallerSession) GetActivePPSOracle() (common.Address, error) {
	return _SuperGovernor.Contract.GetActivePPSOracle(&_SuperGovernor.CallOpts)
}

// GetAddress is a free data retrieval call binding the contract method 0x21f8a721.
//
// Solidity: function getAddress(bytes32 key) view returns(address)
func (_SuperGovernor *SuperGovernorCaller) GetAddress(opts *bind.CallOpts, key [32]byte) (common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getAddress", key)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAddress is a free data retrieval call binding the contract method 0x21f8a721.
//
// Solidity: function getAddress(bytes32 key) view returns(address)
func (_SuperGovernor *SuperGovernorSession) GetAddress(key [32]byte) (common.Address, error) {
	return _SuperGovernor.Contract.GetAddress(&_SuperGovernor.CallOpts, key)
}

// GetAddress is a free data retrieval call binding the contract method 0x21f8a721.
//
// Solidity: function getAddress(bytes32 key) view returns(address)
func (_SuperGovernor *SuperGovernorCallerSession) GetAddress(key [32]byte) (common.Address, error) {
	return _SuperGovernor.Contract.GetAddress(&_SuperGovernor.CallOpts, key)
}

// GetAllSuperformStrategists is a free data retrieval call binding the contract method 0x94bc40c2.
//
// Solidity: function getAllSuperformStrategists() view returns(address[] strategists)
func (_SuperGovernor *SuperGovernorCaller) GetAllSuperformStrategists(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getAllSuperformStrategists")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetAllSuperformStrategists is a free data retrieval call binding the contract method 0x94bc40c2.
//
// Solidity: function getAllSuperformStrategists() view returns(address[] strategists)
func (_SuperGovernor *SuperGovernorSession) GetAllSuperformStrategists() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetAllSuperformStrategists(&_SuperGovernor.CallOpts)
}

// GetAllSuperformStrategists is a free data retrieval call binding the contract method 0x94bc40c2.
//
// Solidity: function getAllSuperformStrategists() view returns(address[] strategists)
func (_SuperGovernor *SuperGovernorCallerSession) GetAllSuperformStrategists() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetAllSuperformStrategists(&_SuperGovernor.CallOpts)
}

// GetFee is a free data retrieval call binding the contract method 0x083132c4.
//
// Solidity: function getFee(uint8 feeType) view returns(uint256)
func (_SuperGovernor *SuperGovernorCaller) GetFee(opts *bind.CallOpts, feeType uint8) (*big.Int, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getFee", feeType)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetFee is a free data retrieval call binding the contract method 0x083132c4.
//
// Solidity: function getFee(uint8 feeType) view returns(uint256)
func (_SuperGovernor *SuperGovernorSession) GetFee(feeType uint8) (*big.Int, error) {
	return _SuperGovernor.Contract.GetFee(&_SuperGovernor.CallOpts, feeType)
}

// GetFee is a free data retrieval call binding the contract method 0x083132c4.
//
// Solidity: function getFee(uint8 feeType) view returns(uint256)
func (_SuperGovernor *SuperGovernorCallerSession) GetFee(feeType uint8) (*big.Int, error) {
	return _SuperGovernor.Contract.GetFee(&_SuperGovernor.CallOpts, feeType)
}

// GetPPSOracleQuorum is a free data retrieval call binding the contract method 0xdf6aaf96.
//
// Solidity: function getPPSOracleQuorum() view returns(uint256)
func (_SuperGovernor *SuperGovernorCaller) GetPPSOracleQuorum(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getPPSOracleQuorum")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPPSOracleQuorum is a free data retrieval call binding the contract method 0xdf6aaf96.
//
// Solidity: function getPPSOracleQuorum() view returns(uint256)
func (_SuperGovernor *SuperGovernorSession) GetPPSOracleQuorum() (*big.Int, error) {
	return _SuperGovernor.Contract.GetPPSOracleQuorum(&_SuperGovernor.CallOpts)
}

// GetPPSOracleQuorum is a free data retrieval call binding the contract method 0xdf6aaf96.
//
// Solidity: function getPPSOracleQuorum() view returns(uint256)
func (_SuperGovernor *SuperGovernorCallerSession) GetPPSOracleQuorum() (*big.Int, error) {
	return _SuperGovernor.Contract.GetPPSOracleQuorum(&_SuperGovernor.CallOpts)
}

// GetProposedActivePPSOracle is a free data retrieval call binding the contract method 0xa86ed388.
//
// Solidity: function getProposedActivePPSOracle() view returns(address proposedOracle, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCaller) GetProposedActivePPSOracle(opts *bind.CallOpts) (struct {
	ProposedOracle common.Address
	EffectiveTime  *big.Int
}, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getProposedActivePPSOracle")

	outstruct := new(struct {
		ProposedOracle common.Address
		EffectiveTime  *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ProposedOracle = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.EffectiveTime = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetProposedActivePPSOracle is a free data retrieval call binding the contract method 0xa86ed388.
//
// Solidity: function getProposedActivePPSOracle() view returns(address proposedOracle, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorSession) GetProposedActivePPSOracle() (struct {
	ProposedOracle common.Address
	EffectiveTime  *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedActivePPSOracle(&_SuperGovernor.CallOpts)
}

// GetProposedActivePPSOracle is a free data retrieval call binding the contract method 0xa86ed388.
//
// Solidity: function getProposedActivePPSOracle() view returns(address proposedOracle, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCallerSession) GetProposedActivePPSOracle() (struct {
	ProposedOracle common.Address
	EffectiveTime  *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedActivePPSOracle(&_SuperGovernor.CallOpts)
}

// GetProposedSuperBankHookMerkleRoot is a free data retrieval call binding the contract method 0x43844de6.
//
// Solidity: function getProposedSuperBankHookMerkleRoot(address hook) view returns(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCaller) GetProposedSuperBankHookMerkleRoot(opts *bind.CallOpts, hook common.Address) (struct {
	ProposedRoot  [32]byte
	EffectiveTime *big.Int
}, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getProposedSuperBankHookMerkleRoot", hook)

	outstruct := new(struct {
		ProposedRoot  [32]byte
		EffectiveTime *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ProposedRoot = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.EffectiveTime = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetProposedSuperBankHookMerkleRoot is a free data retrieval call binding the contract method 0x43844de6.
//
// Solidity: function getProposedSuperBankHookMerkleRoot(address hook) view returns(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorSession) GetProposedSuperBankHookMerkleRoot(hook common.Address) (struct {
	ProposedRoot  [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedSuperBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// GetProposedSuperBankHookMerkleRoot is a free data retrieval call binding the contract method 0x43844de6.
//
// Solidity: function getProposedSuperBankHookMerkleRoot(address hook) view returns(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCallerSession) GetProposedSuperBankHookMerkleRoot(hook common.Address) (struct {
	ProposedRoot  [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedSuperBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// GetProposedUpkeepCostPerUpdate is a free data retrieval call binding the contract method 0x8be48ce6.
//
// Solidity: function getProposedUpkeepCostPerUpdate() view returns(uint256 proposedCost, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCaller) GetProposedUpkeepCostPerUpdate(opts *bind.CallOpts) (struct {
	ProposedCost  *big.Int
	EffectiveTime *big.Int
}, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getProposedUpkeepCostPerUpdate")

	outstruct := new(struct {
		ProposedCost  *big.Int
		EffectiveTime *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ProposedCost = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.EffectiveTime = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetProposedUpkeepCostPerUpdate is a free data retrieval call binding the contract method 0x8be48ce6.
//
// Solidity: function getProposedUpkeepCostPerUpdate() view returns(uint256 proposedCost, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorSession) GetProposedUpkeepCostPerUpdate() (struct {
	ProposedCost  *big.Int
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedUpkeepCostPerUpdate(&_SuperGovernor.CallOpts)
}

// GetProposedUpkeepCostPerUpdate is a free data retrieval call binding the contract method 0x8be48ce6.
//
// Solidity: function getProposedUpkeepCostPerUpdate() view returns(uint256 proposedCost, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCallerSession) GetProposedUpkeepCostPerUpdate() (struct {
	ProposedCost  *big.Int
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedUpkeepCostPerUpdate(&_SuperGovernor.CallOpts)
}

// GetProposedUpkeepPaymentsStatus is a free data retrieval call binding the contract method 0x57b8b13d.
//
// Solidity: function getProposedUpkeepPaymentsStatus() view returns(bool enabled, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCaller) GetProposedUpkeepPaymentsStatus(opts *bind.CallOpts) (struct {
	Enabled       bool
	EffectiveTime *big.Int
}, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getProposedUpkeepPaymentsStatus")

	outstruct := new(struct {
		Enabled       bool
		EffectiveTime *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Enabled = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.EffectiveTime = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetProposedUpkeepPaymentsStatus is a free data retrieval call binding the contract method 0x57b8b13d.
//
// Solidity: function getProposedUpkeepPaymentsStatus() view returns(bool enabled, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorSession) GetProposedUpkeepPaymentsStatus() (struct {
	Enabled       bool
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedUpkeepPaymentsStatus(&_SuperGovernor.CallOpts)
}

// GetProposedUpkeepPaymentsStatus is a free data retrieval call binding the contract method 0x57b8b13d.
//
// Solidity: function getProposedUpkeepPaymentsStatus() view returns(bool enabled, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCallerSession) GetProposedUpkeepPaymentsStatus() (struct {
	Enabled       bool
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedUpkeepPaymentsStatus(&_SuperGovernor.CallOpts)
}

// GetProposedVaultBankHookMerkleRoot is a free data retrieval call binding the contract method 0xf7536506.
//
// Solidity: function getProposedVaultBankHookMerkleRoot(address hook) view returns(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCaller) GetProposedVaultBankHookMerkleRoot(opts *bind.CallOpts, hook common.Address) (struct {
	ProposedRoot  [32]byte
	EffectiveTime *big.Int
}, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getProposedVaultBankHookMerkleRoot", hook)

	outstruct := new(struct {
		ProposedRoot  [32]byte
		EffectiveTime *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ProposedRoot = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.EffectiveTime = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetProposedVaultBankHookMerkleRoot is a free data retrieval call binding the contract method 0xf7536506.
//
// Solidity: function getProposedVaultBankHookMerkleRoot(address hook) view returns(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorSession) GetProposedVaultBankHookMerkleRoot(hook common.Address) (struct {
	ProposedRoot  [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedVaultBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// GetProposedVaultBankHookMerkleRoot is a free data retrieval call binding the contract method 0xf7536506.
//
// Solidity: function getProposedVaultBankHookMerkleRoot(address hook) view returns(bytes32 proposedRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorCallerSession) GetProposedVaultBankHookMerkleRoot(hook common.Address) (struct {
	ProposedRoot  [32]byte
	EffectiveTime *big.Int
}, error) {
	return _SuperGovernor.Contract.GetProposedVaultBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// GetProver is a free data retrieval call binding the contract method 0xf9a83be7.
//
// Solidity: function getProver() view returns(address)
func (_SuperGovernor *SuperGovernorCaller) GetProver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getProver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetProver is a free data retrieval call binding the contract method 0xf9a83be7.
//
// Solidity: function getProver() view returns(address)
func (_SuperGovernor *SuperGovernorSession) GetProver() (common.Address, error) {
	return _SuperGovernor.Contract.GetProver(&_SuperGovernor.CallOpts)
}

// GetProver is a free data retrieval call binding the contract method 0xf9a83be7.
//
// Solidity: function getProver() view returns(address)
func (_SuperGovernor *SuperGovernorCallerSession) GetProver() (common.Address, error) {
	return _SuperGovernor.Contract.GetProver(&_SuperGovernor.CallOpts)
}

// GetRegisteredFulfillRequestsHooks is a free data retrieval call binding the contract method 0x046c7418.
//
// Solidity: function getRegisteredFulfillRequestsHooks() view returns(address[])
func (_SuperGovernor *SuperGovernorCaller) GetRegisteredFulfillRequestsHooks(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getRegisteredFulfillRequestsHooks")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetRegisteredFulfillRequestsHooks is a free data retrieval call binding the contract method 0x046c7418.
//
// Solidity: function getRegisteredFulfillRequestsHooks() view returns(address[])
func (_SuperGovernor *SuperGovernorSession) GetRegisteredFulfillRequestsHooks() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetRegisteredFulfillRequestsHooks(&_SuperGovernor.CallOpts)
}

// GetRegisteredFulfillRequestsHooks is a free data retrieval call binding the contract method 0x046c7418.
//
// Solidity: function getRegisteredFulfillRequestsHooks() view returns(address[])
func (_SuperGovernor *SuperGovernorCallerSession) GetRegisteredFulfillRequestsHooks() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetRegisteredFulfillRequestsHooks(&_SuperGovernor.CallOpts)
}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_SuperGovernor *SuperGovernorCaller) GetRegisteredHooks(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getRegisteredHooks")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_SuperGovernor *SuperGovernorSession) GetRegisteredHooks() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetRegisteredHooks(&_SuperGovernor.CallOpts)
}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_SuperGovernor *SuperGovernorCallerSession) GetRegisteredHooks() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetRegisteredHooks(&_SuperGovernor.CallOpts)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) GetRoleAdmin(opts *bind.CallOpts, role [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getRoleAdmin", role)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperGovernor.Contract.GetRoleAdmin(&_SuperGovernor.CallOpts, role)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _SuperGovernor.Contract.GetRoleAdmin(&_SuperGovernor.CallOpts, role)
}

// GetStrategistsPaginated is a free data retrieval call binding the contract method 0x703714ca.
//
// Solidity: function getStrategistsPaginated(uint256 cursor, uint256 limit) view returns(address[] chunkOfStrategists, uint256 next)
func (_SuperGovernor *SuperGovernorCaller) GetStrategistsPaginated(opts *bind.CallOpts, cursor *big.Int, limit *big.Int) (struct {
	ChunkOfStrategists []common.Address
	Next               *big.Int
}, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getStrategistsPaginated", cursor, limit)

	outstruct := new(struct {
		ChunkOfStrategists []common.Address
		Next               *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ChunkOfStrategists = *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)
	outstruct.Next = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetStrategistsPaginated is a free data retrieval call binding the contract method 0x703714ca.
//
// Solidity: function getStrategistsPaginated(uint256 cursor, uint256 limit) view returns(address[] chunkOfStrategists, uint256 next)
func (_SuperGovernor *SuperGovernorSession) GetStrategistsPaginated(cursor *big.Int, limit *big.Int) (struct {
	ChunkOfStrategists []common.Address
	Next               *big.Int
}, error) {
	return _SuperGovernor.Contract.GetStrategistsPaginated(&_SuperGovernor.CallOpts, cursor, limit)
}

// GetStrategistsPaginated is a free data retrieval call binding the contract method 0x703714ca.
//
// Solidity: function getStrategistsPaginated(uint256 cursor, uint256 limit) view returns(address[] chunkOfStrategists, uint256 next)
func (_SuperGovernor *SuperGovernorCallerSession) GetStrategistsPaginated(cursor *big.Int, limit *big.Int) (struct {
	ChunkOfStrategists []common.Address
	Next               *big.Int
}, error) {
	return _SuperGovernor.Contract.GetStrategistsPaginated(&_SuperGovernor.CallOpts, cursor, limit)
}

// GetSuperBankHookMerkleRoot is a free data retrieval call binding the contract method 0xf43526f4.
//
// Solidity: function getSuperBankHookMerkleRoot(address hook) view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) GetSuperBankHookMerkleRoot(opts *bind.CallOpts, hook common.Address) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getSuperBankHookMerkleRoot", hook)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetSuperBankHookMerkleRoot is a free data retrieval call binding the contract method 0xf43526f4.
//
// Solidity: function getSuperBankHookMerkleRoot(address hook) view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) GetSuperBankHookMerkleRoot(hook common.Address) ([32]byte, error) {
	return _SuperGovernor.Contract.GetSuperBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// GetSuperBankHookMerkleRoot is a free data retrieval call binding the contract method 0xf43526f4.
//
// Solidity: function getSuperBankHookMerkleRoot(address hook) view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) GetSuperBankHookMerkleRoot(hook common.Address) ([32]byte, error) {
	return _SuperGovernor.Contract.GetSuperBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// GetSuperformStrategistsCount is a free data retrieval call binding the contract method 0x0129e699.
//
// Solidity: function getSuperformStrategistsCount() view returns(uint256)
func (_SuperGovernor *SuperGovernorCaller) GetSuperformStrategistsCount(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getSuperformStrategistsCount")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetSuperformStrategistsCount is a free data retrieval call binding the contract method 0x0129e699.
//
// Solidity: function getSuperformStrategistsCount() view returns(uint256)
func (_SuperGovernor *SuperGovernorSession) GetSuperformStrategistsCount() (*big.Int, error) {
	return _SuperGovernor.Contract.GetSuperformStrategistsCount(&_SuperGovernor.CallOpts)
}

// GetSuperformStrategistsCount is a free data retrieval call binding the contract method 0x0129e699.
//
// Solidity: function getSuperformStrategistsCount() view returns(uint256)
func (_SuperGovernor *SuperGovernorCallerSession) GetSuperformStrategistsCount() (*big.Int, error) {
	return _SuperGovernor.Contract.GetSuperformStrategistsCount(&_SuperGovernor.CallOpts)
}

// GetUpkeepCostPerUpdate is a free data retrieval call binding the contract method 0xb4e111ca.
//
// Solidity: function getUpkeepCostPerUpdate() view returns(uint256)
func (_SuperGovernor *SuperGovernorCaller) GetUpkeepCostPerUpdate(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getUpkeepCostPerUpdate")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetUpkeepCostPerUpdate is a free data retrieval call binding the contract method 0xb4e111ca.
//
// Solidity: function getUpkeepCostPerUpdate() view returns(uint256)
func (_SuperGovernor *SuperGovernorSession) GetUpkeepCostPerUpdate() (*big.Int, error) {
	return _SuperGovernor.Contract.GetUpkeepCostPerUpdate(&_SuperGovernor.CallOpts)
}

// GetUpkeepCostPerUpdate is a free data retrieval call binding the contract method 0xb4e111ca.
//
// Solidity: function getUpkeepCostPerUpdate() view returns(uint256)
func (_SuperGovernor *SuperGovernorCallerSession) GetUpkeepCostPerUpdate() (*big.Int, error) {
	return _SuperGovernor.Contract.GetUpkeepCostPerUpdate(&_SuperGovernor.CallOpts)
}

// GetValidators is a free data retrieval call binding the contract method 0xb7ab4db5.
//
// Solidity: function getValidators() view returns(address[])
func (_SuperGovernor *SuperGovernorCaller) GetValidators(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getValidators")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetValidators is a free data retrieval call binding the contract method 0xb7ab4db5.
//
// Solidity: function getValidators() view returns(address[])
func (_SuperGovernor *SuperGovernorSession) GetValidators() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetValidators(&_SuperGovernor.CallOpts)
}

// GetValidators is a free data retrieval call binding the contract method 0xb7ab4db5.
//
// Solidity: function getValidators() view returns(address[])
func (_SuperGovernor *SuperGovernorCallerSession) GetValidators() ([]common.Address, error) {
	return _SuperGovernor.Contract.GetValidators(&_SuperGovernor.CallOpts)
}

// GetVaultBank is a free data retrieval call binding the contract method 0x3e099f30.
//
// Solidity: function getVaultBank(uint64 chainId) view returns(address)
func (_SuperGovernor *SuperGovernorCaller) GetVaultBank(opts *bind.CallOpts, chainId uint64) (common.Address, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getVaultBank", chainId)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetVaultBank is a free data retrieval call binding the contract method 0x3e099f30.
//
// Solidity: function getVaultBank(uint64 chainId) view returns(address)
func (_SuperGovernor *SuperGovernorSession) GetVaultBank(chainId uint64) (common.Address, error) {
	return _SuperGovernor.Contract.GetVaultBank(&_SuperGovernor.CallOpts, chainId)
}

// GetVaultBank is a free data retrieval call binding the contract method 0x3e099f30.
//
// Solidity: function getVaultBank(uint64 chainId) view returns(address)
func (_SuperGovernor *SuperGovernorCallerSession) GetVaultBank(chainId uint64) (common.Address, error) {
	return _SuperGovernor.Contract.GetVaultBank(&_SuperGovernor.CallOpts, chainId)
}

// GetVaultBankHookMerkleRoot is a free data retrieval call binding the contract method 0xdfebb1c2.
//
// Solidity: function getVaultBankHookMerkleRoot(address hook) view returns(bytes32)
func (_SuperGovernor *SuperGovernorCaller) GetVaultBankHookMerkleRoot(opts *bind.CallOpts, hook common.Address) ([32]byte, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "getVaultBankHookMerkleRoot", hook)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetVaultBankHookMerkleRoot is a free data retrieval call binding the contract method 0xdfebb1c2.
//
// Solidity: function getVaultBankHookMerkleRoot(address hook) view returns(bytes32)
func (_SuperGovernor *SuperGovernorSession) GetVaultBankHookMerkleRoot(hook common.Address) ([32]byte, error) {
	return _SuperGovernor.Contract.GetVaultBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// GetVaultBankHookMerkleRoot is a free data retrieval call binding the contract method 0xdfebb1c2.
//
// Solidity: function getVaultBankHookMerkleRoot(address hook) view returns(bytes32)
func (_SuperGovernor *SuperGovernorCallerSession) GetVaultBankHookMerkleRoot(hook common.Address) ([32]byte, error) {
	return _SuperGovernor.Contract.GetVaultBankHookMerkleRoot(&_SuperGovernor.CallOpts, hook)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) HasRole(opts *bind.CallOpts, role [32]byte, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "hasRole", role, account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperGovernor.Contract.HasRole(&_SuperGovernor.CallOpts, role, account)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _SuperGovernor.Contract.HasRole(&_SuperGovernor.CallOpts, role, account)
}

// IsActivePPSOracle is a free data retrieval call binding the contract method 0xfd6f0fc2.
//
// Solidity: function isActivePPSOracle(address oracle) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsActivePPSOracle(opts *bind.CallOpts, oracle common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isActivePPSOracle", oracle)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsActivePPSOracle is a free data retrieval call binding the contract method 0xfd6f0fc2.
//
// Solidity: function isActivePPSOracle(address oracle) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsActivePPSOracle(oracle common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsActivePPSOracle(&_SuperGovernor.CallOpts, oracle)
}

// IsActivePPSOracle is a free data retrieval call binding the contract method 0xfd6f0fc2.
//
// Solidity: function isActivePPSOracle(address oracle) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsActivePPSOracle(oracle common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsActivePPSOracle(&_SuperGovernor.CallOpts, oracle)
}

// IsExecutor is a free data retrieval call binding the contract method 0xdebfda30.
//
// Solidity: function isExecutor(address executor) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsExecutor(opts *bind.CallOpts, executor common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isExecutor", executor)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsExecutor is a free data retrieval call binding the contract method 0xdebfda30.
//
// Solidity: function isExecutor(address executor) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsExecutor(executor common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsExecutor(&_SuperGovernor.CallOpts, executor)
}

// IsExecutor is a free data retrieval call binding the contract method 0xdebfda30.
//
// Solidity: function isExecutor(address executor) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsExecutor(executor common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsExecutor(&_SuperGovernor.CallOpts, executor)
}

// IsFulfillRequestsHookRegistered is a free data retrieval call binding the contract method 0x7d3e649e.
//
// Solidity: function isFulfillRequestsHookRegistered(address hook) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsFulfillRequestsHookRegistered(opts *bind.CallOpts, hook common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isFulfillRequestsHookRegistered", hook)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsFulfillRequestsHookRegistered is a free data retrieval call binding the contract method 0x7d3e649e.
//
// Solidity: function isFulfillRequestsHookRegistered(address hook) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsFulfillRequestsHookRegistered(hook common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsFulfillRequestsHookRegistered(&_SuperGovernor.CallOpts, hook)
}

// IsFulfillRequestsHookRegistered is a free data retrieval call binding the contract method 0x7d3e649e.
//
// Solidity: function isFulfillRequestsHookRegistered(address hook) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsFulfillRequestsHookRegistered(hook common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsFulfillRequestsHookRegistered(&_SuperGovernor.CallOpts, hook)
}

// IsGuardian is a free data retrieval call binding the contract method 0x0c68ba21.
//
// Solidity: function isGuardian(address guardian) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsGuardian(opts *bind.CallOpts, guardian common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isGuardian", guardian)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsGuardian is a free data retrieval call binding the contract method 0x0c68ba21.
//
// Solidity: function isGuardian(address guardian) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsGuardian(guardian common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsGuardian(&_SuperGovernor.CallOpts, guardian)
}

// IsGuardian is a free data retrieval call binding the contract method 0x0c68ba21.
//
// Solidity: function isGuardian(address guardian) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsGuardian(guardian common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsGuardian(&_SuperGovernor.CallOpts, guardian)
}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address hook) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsHookRegistered(opts *bind.CallOpts, hook common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isHookRegistered", hook)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address hook) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsHookRegistered(hook common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsHookRegistered(&_SuperGovernor.CallOpts, hook)
}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address hook) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsHookRegistered(hook common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsHookRegistered(&_SuperGovernor.CallOpts, hook)
}

// IsRelayer is a free data retrieval call binding the contract method 0x541d5548.
//
// Solidity: function isRelayer(address relayer) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsRelayer(opts *bind.CallOpts, relayer common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isRelayer", relayer)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsRelayer is a free data retrieval call binding the contract method 0x541d5548.
//
// Solidity: function isRelayer(address relayer) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsRelayer(relayer common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsRelayer(&_SuperGovernor.CallOpts, relayer)
}

// IsRelayer is a free data retrieval call binding the contract method 0x541d5548.
//
// Solidity: function isRelayer(address relayer) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsRelayer(relayer common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsRelayer(&_SuperGovernor.CallOpts, relayer)
}

// IsStrategistTakeoverFrozen is a free data retrieval call binding the contract method 0x0e922b0b.
//
// Solidity: function isStrategistTakeoverFrozen() view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsStrategistTakeoverFrozen(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isStrategistTakeoverFrozen")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsStrategistTakeoverFrozen is a free data retrieval call binding the contract method 0x0e922b0b.
//
// Solidity: function isStrategistTakeoverFrozen() view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsStrategistTakeoverFrozen() (bool, error) {
	return _SuperGovernor.Contract.IsStrategistTakeoverFrozen(&_SuperGovernor.CallOpts)
}

// IsStrategistTakeoverFrozen is a free data retrieval call binding the contract method 0x0e922b0b.
//
// Solidity: function isStrategistTakeoverFrozen() view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsStrategistTakeoverFrozen() (bool, error) {
	return _SuperGovernor.Contract.IsStrategistTakeoverFrozen(&_SuperGovernor.CallOpts)
}

// IsSuperformStrategist is a free data retrieval call binding the contract method 0x72216c59.
//
// Solidity: function isSuperformStrategist(address strategist) view returns(bool isSuperform)
func (_SuperGovernor *SuperGovernorCaller) IsSuperformStrategist(opts *bind.CallOpts, strategist common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isSuperformStrategist", strategist)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsSuperformStrategist is a free data retrieval call binding the contract method 0x72216c59.
//
// Solidity: function isSuperformStrategist(address strategist) view returns(bool isSuperform)
func (_SuperGovernor *SuperGovernorSession) IsSuperformStrategist(strategist common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsSuperformStrategist(&_SuperGovernor.CallOpts, strategist)
}

// IsSuperformStrategist is a free data retrieval call binding the contract method 0x72216c59.
//
// Solidity: function isSuperformStrategist(address strategist) view returns(bool isSuperform)
func (_SuperGovernor *SuperGovernorCallerSession) IsSuperformStrategist(strategist common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsSuperformStrategist(&_SuperGovernor.CallOpts, strategist)
}

// IsUpkeepPaymentsEnabled is a free data retrieval call binding the contract method 0x3ef15059.
//
// Solidity: function isUpkeepPaymentsEnabled() view returns(bool enabled)
func (_SuperGovernor *SuperGovernorCaller) IsUpkeepPaymentsEnabled(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isUpkeepPaymentsEnabled")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsUpkeepPaymentsEnabled is a free data retrieval call binding the contract method 0x3ef15059.
//
// Solidity: function isUpkeepPaymentsEnabled() view returns(bool enabled)
func (_SuperGovernor *SuperGovernorSession) IsUpkeepPaymentsEnabled() (bool, error) {
	return _SuperGovernor.Contract.IsUpkeepPaymentsEnabled(&_SuperGovernor.CallOpts)
}

// IsUpkeepPaymentsEnabled is a free data retrieval call binding the contract method 0x3ef15059.
//
// Solidity: function isUpkeepPaymentsEnabled() view returns(bool enabled)
func (_SuperGovernor *SuperGovernorCallerSession) IsUpkeepPaymentsEnabled() (bool, error) {
	return _SuperGovernor.Contract.IsUpkeepPaymentsEnabled(&_SuperGovernor.CallOpts)
}

// IsValidator is a free data retrieval call binding the contract method 0xfacd743b.
//
// Solidity: function isValidator(address validator) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsValidator(opts *bind.CallOpts, validator common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isValidator", validator)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsValidator is a free data retrieval call binding the contract method 0xfacd743b.
//
// Solidity: function isValidator(address validator) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsValidator(validator common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsValidator(&_SuperGovernor.CallOpts, validator)
}

// IsValidator is a free data retrieval call binding the contract method 0xfacd743b.
//
// Solidity: function isValidator(address validator) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsValidator(validator common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsValidator(&_SuperGovernor.CallOpts, validator)
}

// IsWhitelistedIncentiveToken is a free data retrieval call binding the contract method 0x7045af80.
//
// Solidity: function isWhitelistedIncentiveToken(address token) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) IsWhitelistedIncentiveToken(opts *bind.CallOpts, token common.Address) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "isWhitelistedIncentiveToken", token)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsWhitelistedIncentiveToken is a free data retrieval call binding the contract method 0x7045af80.
//
// Solidity: function isWhitelistedIncentiveToken(address token) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) IsWhitelistedIncentiveToken(token common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsWhitelistedIncentiveToken(&_SuperGovernor.CallOpts, token)
}

// IsWhitelistedIncentiveToken is a free data retrieval call binding the contract method 0x7045af80.
//
// Solidity: function isWhitelistedIncentiveToken(address token) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) IsWhitelistedIncentiveToken(token common.Address) (bool, error) {
	return _SuperGovernor.Contract.IsWhitelistedIncentiveToken(&_SuperGovernor.CallOpts, token)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperGovernor *SuperGovernorCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _SuperGovernor.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperGovernor *SuperGovernorSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperGovernor.Contract.SupportsInterface(&_SuperGovernor.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_SuperGovernor *SuperGovernorCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _SuperGovernor.Contract.SupportsInterface(&_SuperGovernor.CallOpts, interfaceId)
}

// AddExecutor is a paid mutator transaction binding the contract method 0x1f5a0bbe.
//
// Solidity: function addExecutor(address executor_) returns()
func (_SuperGovernor *SuperGovernorTransactor) AddExecutor(opts *bind.TransactOpts, executor_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "addExecutor", executor_)
}

// AddExecutor is a paid mutator transaction binding the contract method 0x1f5a0bbe.
//
// Solidity: function addExecutor(address executor_) returns()
func (_SuperGovernor *SuperGovernorSession) AddExecutor(executor_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddExecutor(&_SuperGovernor.TransactOpts, executor_)
}

// AddExecutor is a paid mutator transaction binding the contract method 0x1f5a0bbe.
//
// Solidity: function addExecutor(address executor_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) AddExecutor(executor_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddExecutor(&_SuperGovernor.TransactOpts, executor_)
}

// AddICCToWhitelist is a paid mutator transaction binding the contract method 0xd070909e.
//
// Solidity: function addICCToWhitelist(address icc) returns()
func (_SuperGovernor *SuperGovernorTransactor) AddICCToWhitelist(opts *bind.TransactOpts, icc common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "addICCToWhitelist", icc)
}

// AddICCToWhitelist is a paid mutator transaction binding the contract method 0xd070909e.
//
// Solidity: function addICCToWhitelist(address icc) returns()
func (_SuperGovernor *SuperGovernorSession) AddICCToWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddICCToWhitelist(&_SuperGovernor.TransactOpts, icc)
}

// AddICCToWhitelist is a paid mutator transaction binding the contract method 0xd070909e.
//
// Solidity: function addICCToWhitelist(address icc) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) AddICCToWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddICCToWhitelist(&_SuperGovernor.TransactOpts, icc)
}

// AddRelayer is a paid mutator transaction binding the contract method 0xdd39f00d.
//
// Solidity: function addRelayer(address relayer_) returns()
func (_SuperGovernor *SuperGovernorTransactor) AddRelayer(opts *bind.TransactOpts, relayer_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "addRelayer", relayer_)
}

// AddRelayer is a paid mutator transaction binding the contract method 0xdd39f00d.
//
// Solidity: function addRelayer(address relayer_) returns()
func (_SuperGovernor *SuperGovernorSession) AddRelayer(relayer_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddRelayer(&_SuperGovernor.TransactOpts, relayer_)
}

// AddRelayer is a paid mutator transaction binding the contract method 0xdd39f00d.
//
// Solidity: function addRelayer(address relayer_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) AddRelayer(relayer_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddRelayer(&_SuperGovernor.TransactOpts, relayer_)
}

// AddSuperformStrategist is a paid mutator transaction binding the contract method 0x36819a97.
//
// Solidity: function addSuperformStrategist(address strategist) returns()
func (_SuperGovernor *SuperGovernorTransactor) AddSuperformStrategist(opts *bind.TransactOpts, strategist common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "addSuperformStrategist", strategist)
}

// AddSuperformStrategist is a paid mutator transaction binding the contract method 0x36819a97.
//
// Solidity: function addSuperformStrategist(address strategist) returns()
func (_SuperGovernor *SuperGovernorSession) AddSuperformStrategist(strategist common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddSuperformStrategist(&_SuperGovernor.TransactOpts, strategist)
}

// AddSuperformStrategist is a paid mutator transaction binding the contract method 0x36819a97.
//
// Solidity: function addSuperformStrategist(address strategist) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) AddSuperformStrategist(strategist common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddSuperformStrategist(&_SuperGovernor.TransactOpts, strategist)
}

// AddValidator is a paid mutator transaction binding the contract method 0x4d238c8e.
//
// Solidity: function addValidator(address validator) returns()
func (_SuperGovernor *SuperGovernorTransactor) AddValidator(opts *bind.TransactOpts, validator common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "addValidator", validator)
}

// AddValidator is a paid mutator transaction binding the contract method 0x4d238c8e.
//
// Solidity: function addValidator(address validator) returns()
func (_SuperGovernor *SuperGovernorSession) AddValidator(validator common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddValidator(&_SuperGovernor.TransactOpts, validator)
}

// AddValidator is a paid mutator transaction binding the contract method 0x4d238c8e.
//
// Solidity: function addValidator(address validator) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) AddValidator(validator common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddValidator(&_SuperGovernor.TransactOpts, validator)
}

// AddVaultBank is a paid mutator transaction binding the contract method 0xbecbf729.
//
// Solidity: function addVaultBank(uint64 chainId, address vaultBank) returns()
func (_SuperGovernor *SuperGovernorTransactor) AddVaultBank(opts *bind.TransactOpts, chainId uint64, vaultBank common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "addVaultBank", chainId, vaultBank)
}

// AddVaultBank is a paid mutator transaction binding the contract method 0xbecbf729.
//
// Solidity: function addVaultBank(uint64 chainId, address vaultBank) returns()
func (_SuperGovernor *SuperGovernorSession) AddVaultBank(chainId uint64, vaultBank common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddVaultBank(&_SuperGovernor.TransactOpts, chainId, vaultBank)
}

// AddVaultBank is a paid mutator transaction binding the contract method 0xbecbf729.
//
// Solidity: function addVaultBank(uint64 chainId, address vaultBank) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) AddVaultBank(chainId uint64, vaultBank common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.AddVaultBank(&_SuperGovernor.TransactOpts, chainId, vaultBank)
}

// BatchSetEmergencyPrices is a paid mutator transaction binding the contract method 0x00f1131f.
//
// Solidity: function batchSetEmergencyPrices(address[] tokens_, uint256[] prices_) returns()
func (_SuperGovernor *SuperGovernorTransactor) BatchSetEmergencyPrices(opts *bind.TransactOpts, tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "batchSetEmergencyPrices", tokens_, prices_)
}

// BatchSetEmergencyPrices is a paid mutator transaction binding the contract method 0x00f1131f.
//
// Solidity: function batchSetEmergencyPrices(address[] tokens_, uint256[] prices_) returns()
func (_SuperGovernor *SuperGovernorSession) BatchSetEmergencyPrices(tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.BatchSetEmergencyPrices(&_SuperGovernor.TransactOpts, tokens_, prices_)
}

// BatchSetEmergencyPrices is a paid mutator transaction binding the contract method 0x00f1131f.
//
// Solidity: function batchSetEmergencyPrices(address[] tokens_, uint256[] prices_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) BatchSetEmergencyPrices(tokens_ []common.Address, prices_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.BatchSetEmergencyPrices(&_SuperGovernor.TransactOpts, tokens_, prices_)
}

// BatchSetOracleUptimeFeed is a paid mutator transaction binding the contract method 0x52ad8b00.
//
// Solidity: function batchSetOracleUptimeFeed(address[] dataOracles_, address[] uptimeOracles_, uint256[] gracePeriods_) returns()
func (_SuperGovernor *SuperGovernorTransactor) BatchSetOracleUptimeFeed(opts *bind.TransactOpts, dataOracles_ []common.Address, uptimeOracles_ []common.Address, gracePeriods_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "batchSetOracleUptimeFeed", dataOracles_, uptimeOracles_, gracePeriods_)
}

// BatchSetOracleUptimeFeed is a paid mutator transaction binding the contract method 0x52ad8b00.
//
// Solidity: function batchSetOracleUptimeFeed(address[] dataOracles_, address[] uptimeOracles_, uint256[] gracePeriods_) returns()
func (_SuperGovernor *SuperGovernorSession) BatchSetOracleUptimeFeed(dataOracles_ []common.Address, uptimeOracles_ []common.Address, gracePeriods_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.BatchSetOracleUptimeFeed(&_SuperGovernor.TransactOpts, dataOracles_, uptimeOracles_, gracePeriods_)
}

// BatchSetOracleUptimeFeed is a paid mutator transaction binding the contract method 0x52ad8b00.
//
// Solidity: function batchSetOracleUptimeFeed(address[] dataOracles_, address[] uptimeOracles_, uint256[] gracePeriods_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) BatchSetOracleUptimeFeed(dataOracles_ []common.Address, uptimeOracles_ []common.Address, gracePeriods_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.BatchSetOracleUptimeFeed(&_SuperGovernor.TransactOpts, dataOracles_, uptimeOracles_, gracePeriods_)
}

// ChangeHooksRootUpdateTimelock is a paid mutator transaction binding the contract method 0x9649933b.
//
// Solidity: function changeHooksRootUpdateTimelock(uint256 newTimelock_) returns()
func (_SuperGovernor *SuperGovernorTransactor) ChangeHooksRootUpdateTimelock(opts *bind.TransactOpts, newTimelock_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "changeHooksRootUpdateTimelock", newTimelock_)
}

// ChangeHooksRootUpdateTimelock is a paid mutator transaction binding the contract method 0x9649933b.
//
// Solidity: function changeHooksRootUpdateTimelock(uint256 newTimelock_) returns()
func (_SuperGovernor *SuperGovernorSession) ChangeHooksRootUpdateTimelock(newTimelock_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ChangeHooksRootUpdateTimelock(&_SuperGovernor.TransactOpts, newTimelock_)
}

// ChangeHooksRootUpdateTimelock is a paid mutator transaction binding the contract method 0x9649933b.
//
// Solidity: function changeHooksRootUpdateTimelock(uint256 newTimelock_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ChangeHooksRootUpdateTimelock(newTimelock_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ChangeHooksRootUpdateTimelock(&_SuperGovernor.TransactOpts, newTimelock_)
}

// ChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x3c308f54.
//
// Solidity: function changePrimaryStrategist(address strategy_, address newStrategist_) returns()
func (_SuperGovernor *SuperGovernorTransactor) ChangePrimaryStrategist(opts *bind.TransactOpts, strategy_ common.Address, newStrategist_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "changePrimaryStrategist", strategy_, newStrategist_)
}

// ChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x3c308f54.
//
// Solidity: function changePrimaryStrategist(address strategy_, address newStrategist_) returns()
func (_SuperGovernor *SuperGovernorSession) ChangePrimaryStrategist(strategy_ common.Address, newStrategist_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ChangePrimaryStrategist(&_SuperGovernor.TransactOpts, strategy_, newStrategist_)
}

// ChangePrimaryStrategist is a paid mutator transaction binding the contract method 0x3c308f54.
//
// Solidity: function changePrimaryStrategist(address strategy_, address newStrategist_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ChangePrimaryStrategist(strategy_ common.Address, newStrategist_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ChangePrimaryStrategist(&_SuperGovernor.TransactOpts, strategy_, newStrategist_)
}

// ExecuteActivePPSOracleChange is a paid mutator transaction binding the contract method 0xf1031b4e.
//
// Solidity: function executeActivePPSOracleChange() returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteActivePPSOracleChange(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeActivePPSOracleChange")
}

// ExecuteActivePPSOracleChange is a paid mutator transaction binding the contract method 0xf1031b4e.
//
// Solidity: function executeActivePPSOracleChange() returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteActivePPSOracleChange() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteActivePPSOracleChange(&_SuperGovernor.TransactOpts)
}

// ExecuteActivePPSOracleChange is a paid mutator transaction binding the contract method 0xf1031b4e.
//
// Solidity: function executeActivePPSOracleChange() returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteActivePPSOracleChange() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteActivePPSOracleChange(&_SuperGovernor.TransactOpts)
}

// ExecuteAddIncentiveTokens is a paid mutator transaction binding the contract method 0xe5cc7970.
//
// Solidity: function executeAddIncentiveTokens() returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteAddIncentiveTokens(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeAddIncentiveTokens")
}

// ExecuteAddIncentiveTokens is a paid mutator transaction binding the contract method 0xe5cc7970.
//
// Solidity: function executeAddIncentiveTokens() returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteAddIncentiveTokens() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteAddIncentiveTokens(&_SuperGovernor.TransactOpts)
}

// ExecuteAddIncentiveTokens is a paid mutator transaction binding the contract method 0xe5cc7970.
//
// Solidity: function executeAddIncentiveTokens() returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteAddIncentiveTokens() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteAddIncentiveTokens(&_SuperGovernor.TransactOpts)
}

// ExecuteFeeUpdate is a paid mutator transaction binding the contract method 0x365d6bf3.
//
// Solidity: function executeFeeUpdate(uint8 feeType) returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteFeeUpdate(opts *bind.TransactOpts, feeType uint8) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeFeeUpdate", feeType)
}

// ExecuteFeeUpdate is a paid mutator transaction binding the contract method 0x365d6bf3.
//
// Solidity: function executeFeeUpdate(uint8 feeType) returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteFeeUpdate(feeType uint8) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteFeeUpdate(&_SuperGovernor.TransactOpts, feeType)
}

// ExecuteFeeUpdate is a paid mutator transaction binding the contract method 0x365d6bf3.
//
// Solidity: function executeFeeUpdate(uint8 feeType) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteFeeUpdate(feeType uint8) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteFeeUpdate(&_SuperGovernor.TransactOpts, feeType)
}

// ExecuteRemoveIncentiveTokens is a paid mutator transaction binding the contract method 0xdc972801.
//
// Solidity: function executeRemoveIncentiveTokens() returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteRemoveIncentiveTokens(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeRemoveIncentiveTokens")
}

// ExecuteRemoveIncentiveTokens is a paid mutator transaction binding the contract method 0xdc972801.
//
// Solidity: function executeRemoveIncentiveTokens() returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteRemoveIncentiveTokens() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteRemoveIncentiveTokens(&_SuperGovernor.TransactOpts)
}

// ExecuteRemoveIncentiveTokens is a paid mutator transaction binding the contract method 0xdc972801.
//
// Solidity: function executeRemoveIncentiveTokens() returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteRemoveIncentiveTokens() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteRemoveIncentiveTokens(&_SuperGovernor.TransactOpts)
}

// ExecuteSuperBankHookMerkleRootUpdate is a paid mutator transaction binding the contract method 0x290c49a1.
//
// Solidity: function executeSuperBankHookMerkleRootUpdate(address hook) returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteSuperBankHookMerkleRootUpdate(opts *bind.TransactOpts, hook common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeSuperBankHookMerkleRootUpdate", hook)
}

// ExecuteSuperBankHookMerkleRootUpdate is a paid mutator transaction binding the contract method 0x290c49a1.
//
// Solidity: function executeSuperBankHookMerkleRootUpdate(address hook) returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteSuperBankHookMerkleRootUpdate(hook common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteSuperBankHookMerkleRootUpdate(&_SuperGovernor.TransactOpts, hook)
}

// ExecuteSuperBankHookMerkleRootUpdate is a paid mutator transaction binding the contract method 0x290c49a1.
//
// Solidity: function executeSuperBankHookMerkleRootUpdate(address hook) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteSuperBankHookMerkleRootUpdate(hook common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteSuperBankHookMerkleRootUpdate(&_SuperGovernor.TransactOpts, hook)
}

// ExecuteUpkeepCostPerUpdateChange is a paid mutator transaction binding the contract method 0x045b4bdf.
//
// Solidity: function executeUpkeepCostPerUpdateChange() returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteUpkeepCostPerUpdateChange(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeUpkeepCostPerUpdateChange")
}

// ExecuteUpkeepCostPerUpdateChange is a paid mutator transaction binding the contract method 0x045b4bdf.
//
// Solidity: function executeUpkeepCostPerUpdateChange() returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteUpkeepCostPerUpdateChange() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteUpkeepCostPerUpdateChange(&_SuperGovernor.TransactOpts)
}

// ExecuteUpkeepCostPerUpdateChange is a paid mutator transaction binding the contract method 0x045b4bdf.
//
// Solidity: function executeUpkeepCostPerUpdateChange() returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteUpkeepCostPerUpdateChange() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteUpkeepCostPerUpdateChange(&_SuperGovernor.TransactOpts)
}

// ExecuteUpkeepPaymentsChange is a paid mutator transaction binding the contract method 0xecc3d967.
//
// Solidity: function executeUpkeepPaymentsChange() returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteUpkeepPaymentsChange(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeUpkeepPaymentsChange")
}

// ExecuteUpkeepPaymentsChange is a paid mutator transaction binding the contract method 0xecc3d967.
//
// Solidity: function executeUpkeepPaymentsChange() returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteUpkeepPaymentsChange() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteUpkeepPaymentsChange(&_SuperGovernor.TransactOpts)
}

// ExecuteUpkeepPaymentsChange is a paid mutator transaction binding the contract method 0xecc3d967.
//
// Solidity: function executeUpkeepPaymentsChange() returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteUpkeepPaymentsChange() (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteUpkeepPaymentsChange(&_SuperGovernor.TransactOpts)
}

// ExecuteVaultBankHookMerkleRootUpdate is a paid mutator transaction binding the contract method 0x1de73a40.
//
// Solidity: function executeVaultBankHookMerkleRootUpdate(address hook) returns()
func (_SuperGovernor *SuperGovernorTransactor) ExecuteVaultBankHookMerkleRootUpdate(opts *bind.TransactOpts, hook common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "executeVaultBankHookMerkleRootUpdate", hook)
}

// ExecuteVaultBankHookMerkleRootUpdate is a paid mutator transaction binding the contract method 0x1de73a40.
//
// Solidity: function executeVaultBankHookMerkleRootUpdate(address hook) returns()
func (_SuperGovernor *SuperGovernorSession) ExecuteVaultBankHookMerkleRootUpdate(hook common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteVaultBankHookMerkleRootUpdate(&_SuperGovernor.TransactOpts, hook)
}

// ExecuteVaultBankHookMerkleRootUpdate is a paid mutator transaction binding the contract method 0x1de73a40.
//
// Solidity: function executeVaultBankHookMerkleRootUpdate(address hook) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ExecuteVaultBankHookMerkleRootUpdate(hook common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ExecuteVaultBankHookMerkleRootUpdate(&_SuperGovernor.TransactOpts, hook)
}

// FreezeStrategistTakeover is a paid mutator transaction binding the contract method 0xf0a3f0ec.
//
// Solidity: function freezeStrategistTakeover() returns()
func (_SuperGovernor *SuperGovernorTransactor) FreezeStrategistTakeover(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "freezeStrategistTakeover")
}

// FreezeStrategistTakeover is a paid mutator transaction binding the contract method 0xf0a3f0ec.
//
// Solidity: function freezeStrategistTakeover() returns()
func (_SuperGovernor *SuperGovernorSession) FreezeStrategistTakeover() (*types.Transaction, error) {
	return _SuperGovernor.Contract.FreezeStrategistTakeover(&_SuperGovernor.TransactOpts)
}

// FreezeStrategistTakeover is a paid mutator transaction binding the contract method 0xf0a3f0ec.
//
// Solidity: function freezeStrategistTakeover() returns()
func (_SuperGovernor *SuperGovernorTransactorSession) FreezeStrategistTakeover() (*types.Transaction, error) {
	return _SuperGovernor.Contract.FreezeStrategistTakeover(&_SuperGovernor.TransactOpts)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperGovernor *SuperGovernorTransactor) GrantRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "grantRole", role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperGovernor *SuperGovernorSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.GrantRole(&_SuperGovernor.TransactOpts, role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.GrantRole(&_SuperGovernor.TransactOpts, role, account)
}

// ProposeActivePPSOracle is a paid mutator transaction binding the contract method 0x1551c6c0.
//
// Solidity: function proposeActivePPSOracle(address oracle) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeActivePPSOracle(opts *bind.TransactOpts, oracle common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeActivePPSOracle", oracle)
}

// ProposeActivePPSOracle is a paid mutator transaction binding the contract method 0x1551c6c0.
//
// Solidity: function proposeActivePPSOracle(address oracle) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeActivePPSOracle(oracle common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeActivePPSOracle(&_SuperGovernor.TransactOpts, oracle)
}

// ProposeActivePPSOracle is a paid mutator transaction binding the contract method 0x1551c6c0.
//
// Solidity: function proposeActivePPSOracle(address oracle) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeActivePPSOracle(oracle common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeActivePPSOracle(&_SuperGovernor.TransactOpts, oracle)
}

// ProposeAddIncentiveTokens is a paid mutator transaction binding the contract method 0x51597672.
//
// Solidity: function proposeAddIncentiveTokens(address[] tokens) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeAddIncentiveTokens(opts *bind.TransactOpts, tokens []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeAddIncentiveTokens", tokens)
}

// ProposeAddIncentiveTokens is a paid mutator transaction binding the contract method 0x51597672.
//
// Solidity: function proposeAddIncentiveTokens(address[] tokens) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeAddIncentiveTokens(tokens []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeAddIncentiveTokens(&_SuperGovernor.TransactOpts, tokens)
}

// ProposeAddIncentiveTokens is a paid mutator transaction binding the contract method 0x51597672.
//
// Solidity: function proposeAddIncentiveTokens(address[] tokens) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeAddIncentiveTokens(tokens []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeAddIncentiveTokens(&_SuperGovernor.TransactOpts, tokens)
}

// ProposeFee is a paid mutator transaction binding the contract method 0x022e38cf.
//
// Solidity: function proposeFee(uint8 feeType, uint256 value) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeFee(opts *bind.TransactOpts, feeType uint8, value *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeFee", feeType, value)
}

// ProposeFee is a paid mutator transaction binding the contract method 0x022e38cf.
//
// Solidity: function proposeFee(uint8 feeType, uint256 value) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeFee(feeType uint8, value *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeFee(&_SuperGovernor.TransactOpts, feeType, value)
}

// ProposeFee is a paid mutator transaction binding the contract method 0x022e38cf.
//
// Solidity: function proposeFee(uint8 feeType, uint256 value) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeFee(feeType uint8, value *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeFee(&_SuperGovernor.TransactOpts, feeType, value)
}

// ProposeGlobalHooksRoot is a paid mutator transaction binding the contract method 0xb0e5173b.
//
// Solidity: function proposeGlobalHooksRoot(bytes32 newRoot) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeGlobalHooksRoot(opts *bind.TransactOpts, newRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeGlobalHooksRoot", newRoot)
}

// ProposeGlobalHooksRoot is a paid mutator transaction binding the contract method 0xb0e5173b.
//
// Solidity: function proposeGlobalHooksRoot(bytes32 newRoot) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeGlobalHooksRoot(newRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeGlobalHooksRoot(&_SuperGovernor.TransactOpts, newRoot)
}

// ProposeGlobalHooksRoot is a paid mutator transaction binding the contract method 0xb0e5173b.
//
// Solidity: function proposeGlobalHooksRoot(bytes32 newRoot) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeGlobalHooksRoot(newRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeGlobalHooksRoot(&_SuperGovernor.TransactOpts, newRoot)
}

// ProposeRemoveIncentiveTokens is a paid mutator transaction binding the contract method 0xcb53603e.
//
// Solidity: function proposeRemoveIncentiveTokens(address[] tokens) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeRemoveIncentiveTokens(opts *bind.TransactOpts, tokens []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeRemoveIncentiveTokens", tokens)
}

// ProposeRemoveIncentiveTokens is a paid mutator transaction binding the contract method 0xcb53603e.
//
// Solidity: function proposeRemoveIncentiveTokens(address[] tokens) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeRemoveIncentiveTokens(tokens []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeRemoveIncentiveTokens(&_SuperGovernor.TransactOpts, tokens)
}

// ProposeRemoveIncentiveTokens is a paid mutator transaction binding the contract method 0xcb53603e.
//
// Solidity: function proposeRemoveIncentiveTokens(address[] tokens) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeRemoveIncentiveTokens(tokens []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeRemoveIncentiveTokens(&_SuperGovernor.TransactOpts, tokens)
}

// ProposeSuperBankHookMerkleRoot is a paid mutator transaction binding the contract method 0x5e46e8b9.
//
// Solidity: function proposeSuperBankHookMerkleRoot(address hook, bytes32 proposedRoot) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeSuperBankHookMerkleRoot(opts *bind.TransactOpts, hook common.Address, proposedRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeSuperBankHookMerkleRoot", hook, proposedRoot)
}

// ProposeSuperBankHookMerkleRoot is a paid mutator transaction binding the contract method 0x5e46e8b9.
//
// Solidity: function proposeSuperBankHookMerkleRoot(address hook, bytes32 proposedRoot) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeSuperBankHookMerkleRoot(hook common.Address, proposedRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeSuperBankHookMerkleRoot(&_SuperGovernor.TransactOpts, hook, proposedRoot)
}

// ProposeSuperBankHookMerkleRoot is a paid mutator transaction binding the contract method 0x5e46e8b9.
//
// Solidity: function proposeSuperBankHookMerkleRoot(address hook, bytes32 proposedRoot) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeSuperBankHookMerkleRoot(hook common.Address, proposedRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeSuperBankHookMerkleRoot(&_SuperGovernor.TransactOpts, hook, proposedRoot)
}

// ProposeUpkeepCostPerUpdate is a paid mutator transaction binding the contract method 0xd6a8bf3a.
//
// Solidity: function proposeUpkeepCostPerUpdate(uint256 newCost_) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeUpkeepCostPerUpdate(opts *bind.TransactOpts, newCost_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeUpkeepCostPerUpdate", newCost_)
}

// ProposeUpkeepCostPerUpdate is a paid mutator transaction binding the contract method 0xd6a8bf3a.
//
// Solidity: function proposeUpkeepCostPerUpdate(uint256 newCost_) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeUpkeepCostPerUpdate(newCost_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeUpkeepCostPerUpdate(&_SuperGovernor.TransactOpts, newCost_)
}

// ProposeUpkeepCostPerUpdate is a paid mutator transaction binding the contract method 0xd6a8bf3a.
//
// Solidity: function proposeUpkeepCostPerUpdate(uint256 newCost_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeUpkeepCostPerUpdate(newCost_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeUpkeepCostPerUpdate(&_SuperGovernor.TransactOpts, newCost_)
}

// ProposeUpkeepPaymentsChange is a paid mutator transaction binding the contract method 0x778f8a93.
//
// Solidity: function proposeUpkeepPaymentsChange(bool enabled) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeUpkeepPaymentsChange(opts *bind.TransactOpts, enabled bool) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeUpkeepPaymentsChange", enabled)
}

// ProposeUpkeepPaymentsChange is a paid mutator transaction binding the contract method 0x778f8a93.
//
// Solidity: function proposeUpkeepPaymentsChange(bool enabled) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeUpkeepPaymentsChange(enabled bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeUpkeepPaymentsChange(&_SuperGovernor.TransactOpts, enabled)
}

// ProposeUpkeepPaymentsChange is a paid mutator transaction binding the contract method 0x778f8a93.
//
// Solidity: function proposeUpkeepPaymentsChange(bool enabled) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeUpkeepPaymentsChange(enabled bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeUpkeepPaymentsChange(&_SuperGovernor.TransactOpts, enabled)
}

// ProposeVaultBankHookMerkleRoot is a paid mutator transaction binding the contract method 0xba96fb67.
//
// Solidity: function proposeVaultBankHookMerkleRoot(address hook, bytes32 proposedRoot) returns()
func (_SuperGovernor *SuperGovernorTransactor) ProposeVaultBankHookMerkleRoot(opts *bind.TransactOpts, hook common.Address, proposedRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "proposeVaultBankHookMerkleRoot", hook, proposedRoot)
}

// ProposeVaultBankHookMerkleRoot is a paid mutator transaction binding the contract method 0xba96fb67.
//
// Solidity: function proposeVaultBankHookMerkleRoot(address hook, bytes32 proposedRoot) returns()
func (_SuperGovernor *SuperGovernorSession) ProposeVaultBankHookMerkleRoot(hook common.Address, proposedRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeVaultBankHookMerkleRoot(&_SuperGovernor.TransactOpts, hook, proposedRoot)
}

// ProposeVaultBankHookMerkleRoot is a paid mutator transaction binding the contract method 0xba96fb67.
//
// Solidity: function proposeVaultBankHookMerkleRoot(address hook, bytes32 proposedRoot) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) ProposeVaultBankHookMerkleRoot(hook common.Address, proposedRoot [32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.ProposeVaultBankHookMerkleRoot(&_SuperGovernor.TransactOpts, hook, proposedRoot)
}

// QueueOracleProviderRemoval is a paid mutator transaction binding the contract method 0x6490305f.
//
// Solidity: function queueOracleProviderRemoval(bytes32[] providers_) returns()
func (_SuperGovernor *SuperGovernorTransactor) QueueOracleProviderRemoval(opts *bind.TransactOpts, providers_ [][32]byte) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "queueOracleProviderRemoval", providers_)
}

// QueueOracleProviderRemoval is a paid mutator transaction binding the contract method 0x6490305f.
//
// Solidity: function queueOracleProviderRemoval(bytes32[] providers_) returns()
func (_SuperGovernor *SuperGovernorSession) QueueOracleProviderRemoval(providers_ [][32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.QueueOracleProviderRemoval(&_SuperGovernor.TransactOpts, providers_)
}

// QueueOracleProviderRemoval is a paid mutator transaction binding the contract method 0x6490305f.
//
// Solidity: function queueOracleProviderRemoval(bytes32[] providers_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) QueueOracleProviderRemoval(providers_ [][32]byte) (*types.Transaction, error) {
	return _SuperGovernor.Contract.QueueOracleProviderRemoval(&_SuperGovernor.TransactOpts, providers_)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases_, address[] quotes_, bytes32[] providers_, address[] feeds_) returns()
func (_SuperGovernor *SuperGovernorTransactor) QueueOracleUpdate(opts *bind.TransactOpts, bases_ []common.Address, quotes_ []common.Address, providers_ [][32]byte, feeds_ []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "queueOracleUpdate", bases_, quotes_, providers_, feeds_)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases_, address[] quotes_, bytes32[] providers_, address[] feeds_) returns()
func (_SuperGovernor *SuperGovernorSession) QueueOracleUpdate(bases_ []common.Address, quotes_ []common.Address, providers_ [][32]byte, feeds_ []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.QueueOracleUpdate(&_SuperGovernor.TransactOpts, bases_, quotes_, providers_, feeds_)
}

// QueueOracleUpdate is a paid mutator transaction binding the contract method 0xba1f073c.
//
// Solidity: function queueOracleUpdate(address[] bases_, address[] quotes_, bytes32[] providers_, address[] feeds_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) QueueOracleUpdate(bases_ []common.Address, quotes_ []common.Address, providers_ [][32]byte, feeds_ []common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.QueueOracleUpdate(&_SuperGovernor.TransactOpts, bases_, quotes_, providers_, feeds_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x8481643b.
//
// Solidity: function registerHook(address hook_, bool isFulfillRequestsHook_) returns()
func (_SuperGovernor *SuperGovernorTransactor) RegisterHook(opts *bind.TransactOpts, hook_ common.Address, isFulfillRequestsHook_ bool) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "registerHook", hook_, isFulfillRequestsHook_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x8481643b.
//
// Solidity: function registerHook(address hook_, bool isFulfillRequestsHook_) returns()
func (_SuperGovernor *SuperGovernorSession) RegisterHook(hook_ common.Address, isFulfillRequestsHook_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RegisterHook(&_SuperGovernor.TransactOpts, hook_, isFulfillRequestsHook_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x8481643b.
//
// Solidity: function registerHook(address hook_, bool isFulfillRequestsHook_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RegisterHook(hook_ common.Address, isFulfillRequestsHook_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RegisterHook(&_SuperGovernor.TransactOpts, hook_, isFulfillRequestsHook_)
}

// RemoveExecutor is a paid mutator transaction binding the contract method 0x24788429.
//
// Solidity: function removeExecutor(address executor_) returns()
func (_SuperGovernor *SuperGovernorTransactor) RemoveExecutor(opts *bind.TransactOpts, executor_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "removeExecutor", executor_)
}

// RemoveExecutor is a paid mutator transaction binding the contract method 0x24788429.
//
// Solidity: function removeExecutor(address executor_) returns()
func (_SuperGovernor *SuperGovernorSession) RemoveExecutor(executor_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveExecutor(&_SuperGovernor.TransactOpts, executor_)
}

// RemoveExecutor is a paid mutator transaction binding the contract method 0x24788429.
//
// Solidity: function removeExecutor(address executor_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RemoveExecutor(executor_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveExecutor(&_SuperGovernor.TransactOpts, executor_)
}

// RemoveICCFromWhitelist is a paid mutator transaction binding the contract method 0x256b71a0.
//
// Solidity: function removeICCFromWhitelist(address icc) returns()
func (_SuperGovernor *SuperGovernorTransactor) RemoveICCFromWhitelist(opts *bind.TransactOpts, icc common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "removeICCFromWhitelist", icc)
}

// RemoveICCFromWhitelist is a paid mutator transaction binding the contract method 0x256b71a0.
//
// Solidity: function removeICCFromWhitelist(address icc) returns()
func (_SuperGovernor *SuperGovernorSession) RemoveICCFromWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveICCFromWhitelist(&_SuperGovernor.TransactOpts, icc)
}

// RemoveICCFromWhitelist is a paid mutator transaction binding the contract method 0x256b71a0.
//
// Solidity: function removeICCFromWhitelist(address icc) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RemoveICCFromWhitelist(icc common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveICCFromWhitelist(&_SuperGovernor.TransactOpts, icc)
}

// RemoveRelayer is a paid mutator transaction binding the contract method 0x60f0a5ac.
//
// Solidity: function removeRelayer(address relayer_) returns()
func (_SuperGovernor *SuperGovernorTransactor) RemoveRelayer(opts *bind.TransactOpts, relayer_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "removeRelayer", relayer_)
}

// RemoveRelayer is a paid mutator transaction binding the contract method 0x60f0a5ac.
//
// Solidity: function removeRelayer(address relayer_) returns()
func (_SuperGovernor *SuperGovernorSession) RemoveRelayer(relayer_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveRelayer(&_SuperGovernor.TransactOpts, relayer_)
}

// RemoveRelayer is a paid mutator transaction binding the contract method 0x60f0a5ac.
//
// Solidity: function removeRelayer(address relayer_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RemoveRelayer(relayer_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveRelayer(&_SuperGovernor.TransactOpts, relayer_)
}

// RemoveSuperformStrategist is a paid mutator transaction binding the contract method 0xd228a653.
//
// Solidity: function removeSuperformStrategist(address strategist) returns()
func (_SuperGovernor *SuperGovernorTransactor) RemoveSuperformStrategist(opts *bind.TransactOpts, strategist common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "removeSuperformStrategist", strategist)
}

// RemoveSuperformStrategist is a paid mutator transaction binding the contract method 0xd228a653.
//
// Solidity: function removeSuperformStrategist(address strategist) returns()
func (_SuperGovernor *SuperGovernorSession) RemoveSuperformStrategist(strategist common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveSuperformStrategist(&_SuperGovernor.TransactOpts, strategist)
}

// RemoveSuperformStrategist is a paid mutator transaction binding the contract method 0xd228a653.
//
// Solidity: function removeSuperformStrategist(address strategist) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RemoveSuperformStrategist(strategist common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveSuperformStrategist(&_SuperGovernor.TransactOpts, strategist)
}

// RemoveValidator is a paid mutator transaction binding the contract method 0x40a141ff.
//
// Solidity: function removeValidator(address validator) returns()
func (_SuperGovernor *SuperGovernorTransactor) RemoveValidator(opts *bind.TransactOpts, validator common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "removeValidator", validator)
}

// RemoveValidator is a paid mutator transaction binding the contract method 0x40a141ff.
//
// Solidity: function removeValidator(address validator) returns()
func (_SuperGovernor *SuperGovernorSession) RemoveValidator(validator common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveValidator(&_SuperGovernor.TransactOpts, validator)
}

// RemoveValidator is a paid mutator transaction binding the contract method 0x40a141ff.
//
// Solidity: function removeValidator(address validator) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RemoveValidator(validator common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RemoveValidator(&_SuperGovernor.TransactOpts, validator)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperGovernor *SuperGovernorTransactor) RenounceRole(opts *bind.TransactOpts, role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "renounceRole", role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperGovernor *SuperGovernorSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RenounceRole(&_SuperGovernor.TransactOpts, role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RenounceRole(&_SuperGovernor.TransactOpts, role, callerConfirmation)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperGovernor *SuperGovernorTransactor) RevokeRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "revokeRole", role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperGovernor *SuperGovernorSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RevokeRole(&_SuperGovernor.TransactOpts, role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.RevokeRole(&_SuperGovernor.TransactOpts, role, account)
}

// SetActivePPSOracle is a paid mutator transaction binding the contract method 0xf9525fb7.
//
// Solidity: function setActivePPSOracle(address oracle) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetActivePPSOracle(opts *bind.TransactOpts, oracle common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setActivePPSOracle", oracle)
}

// SetActivePPSOracle is a paid mutator transaction binding the contract method 0xf9525fb7.
//
// Solidity: function setActivePPSOracle(address oracle) returns()
func (_SuperGovernor *SuperGovernorSession) SetActivePPSOracle(oracle common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetActivePPSOracle(&_SuperGovernor.TransactOpts, oracle)
}

// SetActivePPSOracle is a paid mutator transaction binding the contract method 0xf9525fb7.
//
// Solidity: function setActivePPSOracle(address oracle) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetActivePPSOracle(oracle common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetActivePPSOracle(&_SuperGovernor.TransactOpts, oracle)
}

// SetAddress is a paid mutator transaction binding the contract method 0xca446dd9.
//
// Solidity: function setAddress(bytes32 key, address value) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetAddress(opts *bind.TransactOpts, key [32]byte, value common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setAddress", key, value)
}

// SetAddress is a paid mutator transaction binding the contract method 0xca446dd9.
//
// Solidity: function setAddress(bytes32 key, address value) returns()
func (_SuperGovernor *SuperGovernorSession) SetAddress(key [32]byte, value common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetAddress(&_SuperGovernor.TransactOpts, key, value)
}

// SetAddress is a paid mutator transaction binding the contract method 0xca446dd9.
//
// Solidity: function setAddress(bytes32 key, address value) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetAddress(key [32]byte, value common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetAddress(&_SuperGovernor.TransactOpts, key, value)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetEmergencyPrice(opts *bind.TransactOpts, token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setEmergencyPrice", token_, price_)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperGovernor *SuperGovernorSession) SetEmergencyPrice(token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetEmergencyPrice(&_SuperGovernor.TransactOpts, token_, price_)
}

// SetEmergencyPrice is a paid mutator transaction binding the contract method 0x7ee185c1.
//
// Solidity: function setEmergencyPrice(address token_, uint256 price_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetEmergencyPrice(token_ common.Address, price_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetEmergencyPrice(&_SuperGovernor.TransactOpts, token_, price_)
}

// SetGlobalHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xd5f3cd86.
//
// Solidity: function setGlobalHooksRootVetoStatus(bool vetoed_) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetGlobalHooksRootVetoStatus(opts *bind.TransactOpts, vetoed_ bool) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setGlobalHooksRootVetoStatus", vetoed_)
}

// SetGlobalHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xd5f3cd86.
//
// Solidity: function setGlobalHooksRootVetoStatus(bool vetoed_) returns()
func (_SuperGovernor *SuperGovernorSession) SetGlobalHooksRootVetoStatus(vetoed_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetGlobalHooksRootVetoStatus(&_SuperGovernor.TransactOpts, vetoed_)
}

// SetGlobalHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xd5f3cd86.
//
// Solidity: function setGlobalHooksRootVetoStatus(bool vetoed_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetGlobalHooksRootVetoStatus(vetoed_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetGlobalHooksRootVetoStatus(&_SuperGovernor.TransactOpts, vetoed_)
}

// SetOracleFeedMaxStaleness is a paid mutator transaction binding the contract method 0x17a79fa6.
//
// Solidity: function setOracleFeedMaxStaleness(address feed_, uint256 newMaxStaleness_) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetOracleFeedMaxStaleness(opts *bind.TransactOpts, feed_ common.Address, newMaxStaleness_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setOracleFeedMaxStaleness", feed_, newMaxStaleness_)
}

// SetOracleFeedMaxStaleness is a paid mutator transaction binding the contract method 0x17a79fa6.
//
// Solidity: function setOracleFeedMaxStaleness(address feed_, uint256 newMaxStaleness_) returns()
func (_SuperGovernor *SuperGovernorSession) SetOracleFeedMaxStaleness(feed_ common.Address, newMaxStaleness_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetOracleFeedMaxStaleness(&_SuperGovernor.TransactOpts, feed_, newMaxStaleness_)
}

// SetOracleFeedMaxStaleness is a paid mutator transaction binding the contract method 0x17a79fa6.
//
// Solidity: function setOracleFeedMaxStaleness(address feed_, uint256 newMaxStaleness_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetOracleFeedMaxStaleness(feed_ common.Address, newMaxStaleness_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetOracleFeedMaxStaleness(&_SuperGovernor.TransactOpts, feed_, newMaxStaleness_)
}

// SetOracleFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0x3fa9fe64.
//
// Solidity: function setOracleFeedMaxStalenessBatch(address[] feeds_, uint256[] newMaxStalenessList_) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetOracleFeedMaxStalenessBatch(opts *bind.TransactOpts, feeds_ []common.Address, newMaxStalenessList_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setOracleFeedMaxStalenessBatch", feeds_, newMaxStalenessList_)
}

// SetOracleFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0x3fa9fe64.
//
// Solidity: function setOracleFeedMaxStalenessBatch(address[] feeds_, uint256[] newMaxStalenessList_) returns()
func (_SuperGovernor *SuperGovernorSession) SetOracleFeedMaxStalenessBatch(feeds_ []common.Address, newMaxStalenessList_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetOracleFeedMaxStalenessBatch(&_SuperGovernor.TransactOpts, feeds_, newMaxStalenessList_)
}

// SetOracleFeedMaxStalenessBatch is a paid mutator transaction binding the contract method 0x3fa9fe64.
//
// Solidity: function setOracleFeedMaxStalenessBatch(address[] feeds_, uint256[] newMaxStalenessList_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetOracleFeedMaxStalenessBatch(feeds_ []common.Address, newMaxStalenessList_ []*big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetOracleFeedMaxStalenessBatch(&_SuperGovernor.TransactOpts, feeds_, newMaxStalenessList_)
}

// SetOracleMaxStaleness is a paid mutator transaction binding the contract method 0x324341ed.
//
// Solidity: function setOracleMaxStaleness(uint256 newMaxStaleness_) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetOracleMaxStaleness(opts *bind.TransactOpts, newMaxStaleness_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setOracleMaxStaleness", newMaxStaleness_)
}

// SetOracleMaxStaleness is a paid mutator transaction binding the contract method 0x324341ed.
//
// Solidity: function setOracleMaxStaleness(uint256 newMaxStaleness_) returns()
func (_SuperGovernor *SuperGovernorSession) SetOracleMaxStaleness(newMaxStaleness_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetOracleMaxStaleness(&_SuperGovernor.TransactOpts, newMaxStaleness_)
}

// SetOracleMaxStaleness is a paid mutator transaction binding the contract method 0x324341ed.
//
// Solidity: function setOracleMaxStaleness(uint256 newMaxStaleness_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetOracleMaxStaleness(newMaxStaleness_ *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetOracleMaxStaleness(&_SuperGovernor.TransactOpts, newMaxStaleness_)
}

// SetPPSOracleQuorum is a paid mutator transaction binding the contract method 0x52da1de3.
//
// Solidity: function setPPSOracleQuorum(uint256 quorum) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetPPSOracleQuorum(opts *bind.TransactOpts, quorum *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setPPSOracleQuorum", quorum)
}

// SetPPSOracleQuorum is a paid mutator transaction binding the contract method 0x52da1de3.
//
// Solidity: function setPPSOracleQuorum(uint256 quorum) returns()
func (_SuperGovernor *SuperGovernorSession) SetPPSOracleQuorum(quorum *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetPPSOracleQuorum(&_SuperGovernor.TransactOpts, quorum)
}

// SetPPSOracleQuorum is a paid mutator transaction binding the contract method 0x52da1de3.
//
// Solidity: function setPPSOracleQuorum(uint256 quorum) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetPPSOracleQuorum(quorum *big.Int) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetPPSOracleQuorum(&_SuperGovernor.TransactOpts, quorum)
}

// SetProver is a paid mutator transaction binding the contract method 0xcbda2992.
//
// Solidity: function setProver(address prover_) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetProver(opts *bind.TransactOpts, prover_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setProver", prover_)
}

// SetProver is a paid mutator transaction binding the contract method 0xcbda2992.
//
// Solidity: function setProver(address prover_) returns()
func (_SuperGovernor *SuperGovernorSession) SetProver(prover_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetProver(&_SuperGovernor.TransactOpts, prover_)
}

// SetProver is a paid mutator transaction binding the contract method 0xcbda2992.
//
// Solidity: function setProver(address prover_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetProver(prover_ common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetProver(&_SuperGovernor.TransactOpts, prover_)
}

// SetStrategyHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xf5297a47.
//
// Solidity: function setStrategyHooksRootVetoStatus(address strategy_, bool vetoed_) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetStrategyHooksRootVetoStatus(opts *bind.TransactOpts, strategy_ common.Address, vetoed_ bool) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setStrategyHooksRootVetoStatus", strategy_, vetoed_)
}

// SetStrategyHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xf5297a47.
//
// Solidity: function setStrategyHooksRootVetoStatus(address strategy_, bool vetoed_) returns()
func (_SuperGovernor *SuperGovernorSession) SetStrategyHooksRootVetoStatus(strategy_ common.Address, vetoed_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetStrategyHooksRootVetoStatus(&_SuperGovernor.TransactOpts, strategy_, vetoed_)
}

// SetStrategyHooksRootVetoStatus is a paid mutator transaction binding the contract method 0xf5297a47.
//
// Solidity: function setStrategyHooksRootVetoStatus(address strategy_, bool vetoed_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetStrategyHooksRootVetoStatus(strategy_ common.Address, vetoed_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetStrategyHooksRootVetoStatus(&_SuperGovernor.TransactOpts, strategy_, vetoed_)
}

// SetSuperAssetManager is a paid mutator transaction binding the contract method 0xe778f632.
//
// Solidity: function setSuperAssetManager(address superAsset, address _superAssetManager) returns()
func (_SuperGovernor *SuperGovernorTransactor) SetSuperAssetManager(opts *bind.TransactOpts, superAsset common.Address, _superAssetManager common.Address) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "setSuperAssetManager", superAsset, _superAssetManager)
}

// SetSuperAssetManager is a paid mutator transaction binding the contract method 0xe778f632.
//
// Solidity: function setSuperAssetManager(address superAsset, address _superAssetManager) returns()
func (_SuperGovernor *SuperGovernorSession) SetSuperAssetManager(superAsset common.Address, _superAssetManager common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetSuperAssetManager(&_SuperGovernor.TransactOpts, superAsset, _superAssetManager)
}

// SetSuperAssetManager is a paid mutator transaction binding the contract method 0xe778f632.
//
// Solidity: function setSuperAssetManager(address superAsset, address _superAssetManager) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) SetSuperAssetManager(superAsset common.Address, _superAssetManager common.Address) (*types.Transaction, error) {
	return _SuperGovernor.Contract.SetSuperAssetManager(&_SuperGovernor.TransactOpts, superAsset, _superAssetManager)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xdf30fc07.
//
// Solidity: function unregisterHook(address hook_, bool isFulfillRequestsHook_) returns()
func (_SuperGovernor *SuperGovernorTransactor) UnregisterHook(opts *bind.TransactOpts, hook_ common.Address, isFulfillRequestsHook_ bool) (*types.Transaction, error) {
	return _SuperGovernor.contract.Transact(opts, "unregisterHook", hook_, isFulfillRequestsHook_)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xdf30fc07.
//
// Solidity: function unregisterHook(address hook_, bool isFulfillRequestsHook_) returns()
func (_SuperGovernor *SuperGovernorSession) UnregisterHook(hook_ common.Address, isFulfillRequestsHook_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.UnregisterHook(&_SuperGovernor.TransactOpts, hook_, isFulfillRequestsHook_)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xdf30fc07.
//
// Solidity: function unregisterHook(address hook_, bool isFulfillRequestsHook_) returns()
func (_SuperGovernor *SuperGovernorTransactorSession) UnregisterHook(hook_ common.Address, isFulfillRequestsHook_ bool) (*types.Transaction, error) {
	return _SuperGovernor.Contract.UnregisterHook(&_SuperGovernor.TransactOpts, hook_, isFulfillRequestsHook_)
}

// SuperGovernorActivePPSOracleChangedIterator is returned from FilterActivePPSOracleChanged and is used to iterate over the raw logs and unpacked data for ActivePPSOracleChanged events raised by the SuperGovernor contract.
type SuperGovernorActivePPSOracleChangedIterator struct {
	Event *SuperGovernorActivePPSOracleChanged // Event containing the contract specifics and raw log

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
func (it *SuperGovernorActivePPSOracleChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorActivePPSOracleChanged)
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
		it.Event = new(SuperGovernorActivePPSOracleChanged)
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
func (it *SuperGovernorActivePPSOracleChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorActivePPSOracleChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorActivePPSOracleChanged represents a ActivePPSOracleChanged event raised by the SuperGovernor contract.
type SuperGovernorActivePPSOracleChanged struct {
	OldOracle common.Address
	NewOracle common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterActivePPSOracleChanged is a free log retrieval operation binding the contract event 0x6f32d4a08b9b9b8ee365ed09addde1536e0cc6a14a46e120923bafef349131e4.
//
// Solidity: event ActivePPSOracleChanged(address indexed oldOracle, address indexed newOracle)
func (_SuperGovernor *SuperGovernorFilterer) FilterActivePPSOracleChanged(opts *bind.FilterOpts, oldOracle []common.Address, newOracle []common.Address) (*SuperGovernorActivePPSOracleChangedIterator, error) {

	var oldOracleRule []interface{}
	for _, oldOracleItem := range oldOracle {
		oldOracleRule = append(oldOracleRule, oldOracleItem)
	}
	var newOracleRule []interface{}
	for _, newOracleItem := range newOracle {
		newOracleRule = append(newOracleRule, newOracleItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ActivePPSOracleChanged", oldOracleRule, newOracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorActivePPSOracleChangedIterator{contract: _SuperGovernor.contract, event: "ActivePPSOracleChanged", logs: logs, sub: sub}, nil
}

// WatchActivePPSOracleChanged is a free log subscription operation binding the contract event 0x6f32d4a08b9b9b8ee365ed09addde1536e0cc6a14a46e120923bafef349131e4.
//
// Solidity: event ActivePPSOracleChanged(address indexed oldOracle, address indexed newOracle)
func (_SuperGovernor *SuperGovernorFilterer) WatchActivePPSOracleChanged(opts *bind.WatchOpts, sink chan<- *SuperGovernorActivePPSOracleChanged, oldOracle []common.Address, newOracle []common.Address) (event.Subscription, error) {

	var oldOracleRule []interface{}
	for _, oldOracleItem := range oldOracle {
		oldOracleRule = append(oldOracleRule, oldOracleItem)
	}
	var newOracleRule []interface{}
	for _, newOracleItem := range newOracle {
		newOracleRule = append(newOracleRule, newOracleItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ActivePPSOracleChanged", oldOracleRule, newOracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorActivePPSOracleChanged)
				if err := _SuperGovernor.contract.UnpackLog(event, "ActivePPSOracleChanged", log); err != nil {
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

// ParseActivePPSOracleChanged is a log parse operation binding the contract event 0x6f32d4a08b9b9b8ee365ed09addde1536e0cc6a14a46e120923bafef349131e4.
//
// Solidity: event ActivePPSOracleChanged(address indexed oldOracle, address indexed newOracle)
func (_SuperGovernor *SuperGovernorFilterer) ParseActivePPSOracleChanged(log types.Log) (*SuperGovernorActivePPSOracleChanged, error) {
	event := new(SuperGovernorActivePPSOracleChanged)
	if err := _SuperGovernor.contract.UnpackLog(event, "ActivePPSOracleChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorActivePPSOracleProposedIterator is returned from FilterActivePPSOracleProposed and is used to iterate over the raw logs and unpacked data for ActivePPSOracleProposed events raised by the SuperGovernor contract.
type SuperGovernorActivePPSOracleProposedIterator struct {
	Event *SuperGovernorActivePPSOracleProposed // Event containing the contract specifics and raw log

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
func (it *SuperGovernorActivePPSOracleProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorActivePPSOracleProposed)
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
		it.Event = new(SuperGovernorActivePPSOracleProposed)
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
func (it *SuperGovernorActivePPSOracleProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorActivePPSOracleProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorActivePPSOracleProposed represents a ActivePPSOracleProposed event raised by the SuperGovernor contract.
type SuperGovernorActivePPSOracleProposed struct {
	Oracle        common.Address
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterActivePPSOracleProposed is a free log retrieval operation binding the contract event 0x0081013d01b2d41dec72c3449ec25ce9dda2847a6e11ad584836ab3589efe675.
//
// Solidity: event ActivePPSOracleProposed(address indexed oracle, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) FilterActivePPSOracleProposed(opts *bind.FilterOpts, oracle []common.Address) (*SuperGovernorActivePPSOracleProposedIterator, error) {

	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ActivePPSOracleProposed", oracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorActivePPSOracleProposedIterator{contract: _SuperGovernor.contract, event: "ActivePPSOracleProposed", logs: logs, sub: sub}, nil
}

// WatchActivePPSOracleProposed is a free log subscription operation binding the contract event 0x0081013d01b2d41dec72c3449ec25ce9dda2847a6e11ad584836ab3589efe675.
//
// Solidity: event ActivePPSOracleProposed(address indexed oracle, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) WatchActivePPSOracleProposed(opts *bind.WatchOpts, sink chan<- *SuperGovernorActivePPSOracleProposed, oracle []common.Address) (event.Subscription, error) {

	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ActivePPSOracleProposed", oracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorActivePPSOracleProposed)
				if err := _SuperGovernor.contract.UnpackLog(event, "ActivePPSOracleProposed", log); err != nil {
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

// ParseActivePPSOracleProposed is a log parse operation binding the contract event 0x0081013d01b2d41dec72c3449ec25ce9dda2847a6e11ad584836ab3589efe675.
//
// Solidity: event ActivePPSOracleProposed(address indexed oracle, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) ParseActivePPSOracleProposed(log types.Log) (*SuperGovernorActivePPSOracleProposed, error) {
	event := new(SuperGovernorActivePPSOracleProposed)
	if err := _SuperGovernor.contract.UnpackLog(event, "ActivePPSOracleProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorActivePPSOracleSetIterator is returned from FilterActivePPSOracleSet and is used to iterate over the raw logs and unpacked data for ActivePPSOracleSet events raised by the SuperGovernor contract.
type SuperGovernorActivePPSOracleSetIterator struct {
	Event *SuperGovernorActivePPSOracleSet // Event containing the contract specifics and raw log

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
func (it *SuperGovernorActivePPSOracleSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorActivePPSOracleSet)
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
		it.Event = new(SuperGovernorActivePPSOracleSet)
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
func (it *SuperGovernorActivePPSOracleSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorActivePPSOracleSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorActivePPSOracleSet represents a ActivePPSOracleSet event raised by the SuperGovernor contract.
type SuperGovernorActivePPSOracleSet struct {
	Oracle common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterActivePPSOracleSet is a free log retrieval operation binding the contract event 0x4f8ebeedbe3d26fd9e31b446c8da12464fc23cd6ce8c45510c211175190d62fa.
//
// Solidity: event ActivePPSOracleSet(address indexed oracle)
func (_SuperGovernor *SuperGovernorFilterer) FilterActivePPSOracleSet(opts *bind.FilterOpts, oracle []common.Address) (*SuperGovernorActivePPSOracleSetIterator, error) {

	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ActivePPSOracleSet", oracleRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorActivePPSOracleSetIterator{contract: _SuperGovernor.contract, event: "ActivePPSOracleSet", logs: logs, sub: sub}, nil
}

// WatchActivePPSOracleSet is a free log subscription operation binding the contract event 0x4f8ebeedbe3d26fd9e31b446c8da12464fc23cd6ce8c45510c211175190d62fa.
//
// Solidity: event ActivePPSOracleSet(address indexed oracle)
func (_SuperGovernor *SuperGovernorFilterer) WatchActivePPSOracleSet(opts *bind.WatchOpts, sink chan<- *SuperGovernorActivePPSOracleSet, oracle []common.Address) (event.Subscription, error) {

	var oracleRule []interface{}
	for _, oracleItem := range oracle {
		oracleRule = append(oracleRule, oracleItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ActivePPSOracleSet", oracleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorActivePPSOracleSet)
				if err := _SuperGovernor.contract.UnpackLog(event, "ActivePPSOracleSet", log); err != nil {
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

// ParseActivePPSOracleSet is a log parse operation binding the contract event 0x4f8ebeedbe3d26fd9e31b446c8da12464fc23cd6ce8c45510c211175190d62fa.
//
// Solidity: event ActivePPSOracleSet(address indexed oracle)
func (_SuperGovernor *SuperGovernorFilterer) ParseActivePPSOracleSet(log types.Log) (*SuperGovernorActivePPSOracleSet, error) {
	event := new(SuperGovernorActivePPSOracleSet)
	if err := _SuperGovernor.contract.UnpackLog(event, "ActivePPSOracleSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorAddressSetIterator is returned from FilterAddressSet and is used to iterate over the raw logs and unpacked data for AddressSet events raised by the SuperGovernor contract.
type SuperGovernorAddressSetIterator struct {
	Event *SuperGovernorAddressSet // Event containing the contract specifics and raw log

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
func (it *SuperGovernorAddressSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorAddressSet)
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
		it.Event = new(SuperGovernorAddressSet)
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
func (it *SuperGovernorAddressSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorAddressSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorAddressSet represents a AddressSet event raised by the SuperGovernor contract.
type SuperGovernorAddressSet struct {
	Key   [32]byte
	Value common.Address
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterAddressSet is a free log retrieval operation binding the contract event 0xb37614c7d254ea8d16eb81fa11dddaeb266aa8ba4917980859c7740aff30c691.
//
// Solidity: event AddressSet(bytes32 indexed key, address indexed value)
func (_SuperGovernor *SuperGovernorFilterer) FilterAddressSet(opts *bind.FilterOpts, key [][32]byte, value []common.Address) (*SuperGovernorAddressSetIterator, error) {

	var keyRule []interface{}
	for _, keyItem := range key {
		keyRule = append(keyRule, keyItem)
	}
	var valueRule []interface{}
	for _, valueItem := range value {
		valueRule = append(valueRule, valueItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "AddressSet", keyRule, valueRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorAddressSetIterator{contract: _SuperGovernor.contract, event: "AddressSet", logs: logs, sub: sub}, nil
}

// WatchAddressSet is a free log subscription operation binding the contract event 0xb37614c7d254ea8d16eb81fa11dddaeb266aa8ba4917980859c7740aff30c691.
//
// Solidity: event AddressSet(bytes32 indexed key, address indexed value)
func (_SuperGovernor *SuperGovernorFilterer) WatchAddressSet(opts *bind.WatchOpts, sink chan<- *SuperGovernorAddressSet, key [][32]byte, value []common.Address) (event.Subscription, error) {

	var keyRule []interface{}
	for _, keyItem := range key {
		keyRule = append(keyRule, keyItem)
	}
	var valueRule []interface{}
	for _, valueItem := range value {
		valueRule = append(valueRule, valueItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "AddressSet", keyRule, valueRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorAddressSet)
				if err := _SuperGovernor.contract.UnpackLog(event, "AddressSet", log); err != nil {
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

// ParseAddressSet is a log parse operation binding the contract event 0xb37614c7d254ea8d16eb81fa11dddaeb266aa8ba4917980859c7740aff30c691.
//
// Solidity: event AddressSet(bytes32 indexed key, address indexed value)
func (_SuperGovernor *SuperGovernorFilterer) ParseAddressSet(log types.Log) (*SuperGovernorAddressSet, error) {
	event := new(SuperGovernorAddressSet)
	if err := _SuperGovernor.contract.UnpackLog(event, "AddressSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorExecutorAddedIterator is returned from FilterExecutorAdded and is used to iterate over the raw logs and unpacked data for ExecutorAdded events raised by the SuperGovernor contract.
type SuperGovernorExecutorAddedIterator struct {
	Event *SuperGovernorExecutorAdded // Event containing the contract specifics and raw log

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
func (it *SuperGovernorExecutorAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorExecutorAdded)
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
		it.Event = new(SuperGovernorExecutorAdded)
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
func (it *SuperGovernorExecutorAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorExecutorAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorExecutorAdded represents a ExecutorAdded event raised by the SuperGovernor contract.
type SuperGovernorExecutorAdded struct {
	Executor common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterExecutorAdded is a free log retrieval operation binding the contract event 0xae5b7c3b000f575c241001dc9bcb3d8778376889353b07121115574eceff78c5.
//
// Solidity: event ExecutorAdded(address indexed executor)
func (_SuperGovernor *SuperGovernorFilterer) FilterExecutorAdded(opts *bind.FilterOpts, executor []common.Address) (*SuperGovernorExecutorAddedIterator, error) {

	var executorRule []interface{}
	for _, executorItem := range executor {
		executorRule = append(executorRule, executorItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ExecutorAdded", executorRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorExecutorAddedIterator{contract: _SuperGovernor.contract, event: "ExecutorAdded", logs: logs, sub: sub}, nil
}

// WatchExecutorAdded is a free log subscription operation binding the contract event 0xae5b7c3b000f575c241001dc9bcb3d8778376889353b07121115574eceff78c5.
//
// Solidity: event ExecutorAdded(address indexed executor)
func (_SuperGovernor *SuperGovernorFilterer) WatchExecutorAdded(opts *bind.WatchOpts, sink chan<- *SuperGovernorExecutorAdded, executor []common.Address) (event.Subscription, error) {

	var executorRule []interface{}
	for _, executorItem := range executor {
		executorRule = append(executorRule, executorItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ExecutorAdded", executorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorExecutorAdded)
				if err := _SuperGovernor.contract.UnpackLog(event, "ExecutorAdded", log); err != nil {
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

// ParseExecutorAdded is a log parse operation binding the contract event 0xae5b7c3b000f575c241001dc9bcb3d8778376889353b07121115574eceff78c5.
//
// Solidity: event ExecutorAdded(address indexed executor)
func (_SuperGovernor *SuperGovernorFilterer) ParseExecutorAdded(log types.Log) (*SuperGovernorExecutorAdded, error) {
	event := new(SuperGovernorExecutorAdded)
	if err := _SuperGovernor.contract.UnpackLog(event, "ExecutorAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorExecutorRemovedIterator is returned from FilterExecutorRemoved and is used to iterate over the raw logs and unpacked data for ExecutorRemoved events raised by the SuperGovernor contract.
type SuperGovernorExecutorRemovedIterator struct {
	Event *SuperGovernorExecutorRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorExecutorRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorExecutorRemoved)
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
		it.Event = new(SuperGovernorExecutorRemoved)
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
func (it *SuperGovernorExecutorRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorExecutorRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorExecutorRemoved represents a ExecutorRemoved event raised by the SuperGovernor contract.
type SuperGovernorExecutorRemoved struct {
	Executor common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterExecutorRemoved is a free log retrieval operation binding the contract event 0x4a2cf608bfb427f53279ec7f0eadf48913b9346ccefc3af138dbdec14ea0907d.
//
// Solidity: event ExecutorRemoved(address indexed executor)
func (_SuperGovernor *SuperGovernorFilterer) FilterExecutorRemoved(opts *bind.FilterOpts, executor []common.Address) (*SuperGovernorExecutorRemovedIterator, error) {

	var executorRule []interface{}
	for _, executorItem := range executor {
		executorRule = append(executorRule, executorItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ExecutorRemoved", executorRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorExecutorRemovedIterator{contract: _SuperGovernor.contract, event: "ExecutorRemoved", logs: logs, sub: sub}, nil
}

// WatchExecutorRemoved is a free log subscription operation binding the contract event 0x4a2cf608bfb427f53279ec7f0eadf48913b9346ccefc3af138dbdec14ea0907d.
//
// Solidity: event ExecutorRemoved(address indexed executor)
func (_SuperGovernor *SuperGovernorFilterer) WatchExecutorRemoved(opts *bind.WatchOpts, sink chan<- *SuperGovernorExecutorRemoved, executor []common.Address) (event.Subscription, error) {

	var executorRule []interface{}
	for _, executorItem := range executor {
		executorRule = append(executorRule, executorItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ExecutorRemoved", executorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorExecutorRemoved)
				if err := _SuperGovernor.contract.UnpackLog(event, "ExecutorRemoved", log); err != nil {
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

// ParseExecutorRemoved is a log parse operation binding the contract event 0x4a2cf608bfb427f53279ec7f0eadf48913b9346ccefc3af138dbdec14ea0907d.
//
// Solidity: event ExecutorRemoved(address indexed executor)
func (_SuperGovernor *SuperGovernorFilterer) ParseExecutorRemoved(log types.Log) (*SuperGovernorExecutorRemoved, error) {
	event := new(SuperGovernorExecutorRemoved)
	if err := _SuperGovernor.contract.UnpackLog(event, "ExecutorRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorFeeProposedIterator is returned from FilterFeeProposed and is used to iterate over the raw logs and unpacked data for FeeProposed events raised by the SuperGovernor contract.
type SuperGovernorFeeProposedIterator struct {
	Event *SuperGovernorFeeProposed // Event containing the contract specifics and raw log

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
func (it *SuperGovernorFeeProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorFeeProposed)
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
		it.Event = new(SuperGovernorFeeProposed)
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
func (it *SuperGovernorFeeProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorFeeProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorFeeProposed represents a FeeProposed event raised by the SuperGovernor contract.
type SuperGovernorFeeProposed struct {
	FeeType       uint8
	Value         *big.Int
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterFeeProposed is a free log retrieval operation binding the contract event 0x79548367f12987b3f5043ed1f421f89ebc84ab67cdaa9ee1e4d2a9e76b58ba0b.
//
// Solidity: event FeeProposed(uint8 indexed feeType, uint256 value, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) FilterFeeProposed(opts *bind.FilterOpts, feeType []uint8) (*SuperGovernorFeeProposedIterator, error) {

	var feeTypeRule []interface{}
	for _, feeTypeItem := range feeType {
		feeTypeRule = append(feeTypeRule, feeTypeItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "FeeProposed", feeTypeRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorFeeProposedIterator{contract: _SuperGovernor.contract, event: "FeeProposed", logs: logs, sub: sub}, nil
}

// WatchFeeProposed is a free log subscription operation binding the contract event 0x79548367f12987b3f5043ed1f421f89ebc84ab67cdaa9ee1e4d2a9e76b58ba0b.
//
// Solidity: event FeeProposed(uint8 indexed feeType, uint256 value, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) WatchFeeProposed(opts *bind.WatchOpts, sink chan<- *SuperGovernorFeeProposed, feeType []uint8) (event.Subscription, error) {

	var feeTypeRule []interface{}
	for _, feeTypeItem := range feeType {
		feeTypeRule = append(feeTypeRule, feeTypeItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "FeeProposed", feeTypeRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorFeeProposed)
				if err := _SuperGovernor.contract.UnpackLog(event, "FeeProposed", log); err != nil {
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

// ParseFeeProposed is a log parse operation binding the contract event 0x79548367f12987b3f5043ed1f421f89ebc84ab67cdaa9ee1e4d2a9e76b58ba0b.
//
// Solidity: event FeeProposed(uint8 indexed feeType, uint256 value, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) ParseFeeProposed(log types.Log) (*SuperGovernorFeeProposed, error) {
	event := new(SuperGovernorFeeProposed)
	if err := _SuperGovernor.contract.UnpackLog(event, "FeeProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorFeeUpdatedIterator is returned from FilterFeeUpdated and is used to iterate over the raw logs and unpacked data for FeeUpdated events raised by the SuperGovernor contract.
type SuperGovernorFeeUpdatedIterator struct {
	Event *SuperGovernorFeeUpdated // Event containing the contract specifics and raw log

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
func (it *SuperGovernorFeeUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorFeeUpdated)
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
		it.Event = new(SuperGovernorFeeUpdated)
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
func (it *SuperGovernorFeeUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorFeeUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorFeeUpdated represents a FeeUpdated event raised by the SuperGovernor contract.
type SuperGovernorFeeUpdated struct {
	FeeType uint8
	Value   *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFeeUpdated is a free log retrieval operation binding the contract event 0x53b82d85cd75c3f353186408e2e619ae5f01c371100dc061ee0423d12acb7508.
//
// Solidity: event FeeUpdated(uint8 indexed feeType, uint256 value)
func (_SuperGovernor *SuperGovernorFilterer) FilterFeeUpdated(opts *bind.FilterOpts, feeType []uint8) (*SuperGovernorFeeUpdatedIterator, error) {

	var feeTypeRule []interface{}
	for _, feeTypeItem := range feeType {
		feeTypeRule = append(feeTypeRule, feeTypeItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "FeeUpdated", feeTypeRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorFeeUpdatedIterator{contract: _SuperGovernor.contract, event: "FeeUpdated", logs: logs, sub: sub}, nil
}

// WatchFeeUpdated is a free log subscription operation binding the contract event 0x53b82d85cd75c3f353186408e2e619ae5f01c371100dc061ee0423d12acb7508.
//
// Solidity: event FeeUpdated(uint8 indexed feeType, uint256 value)
func (_SuperGovernor *SuperGovernorFilterer) WatchFeeUpdated(opts *bind.WatchOpts, sink chan<- *SuperGovernorFeeUpdated, feeType []uint8) (event.Subscription, error) {

	var feeTypeRule []interface{}
	for _, feeTypeItem := range feeType {
		feeTypeRule = append(feeTypeRule, feeTypeItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "FeeUpdated", feeTypeRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorFeeUpdated)
				if err := _SuperGovernor.contract.UnpackLog(event, "FeeUpdated", log); err != nil {
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

// ParseFeeUpdated is a log parse operation binding the contract event 0x53b82d85cd75c3f353186408e2e619ae5f01c371100dc061ee0423d12acb7508.
//
// Solidity: event FeeUpdated(uint8 indexed feeType, uint256 value)
func (_SuperGovernor *SuperGovernorFilterer) ParseFeeUpdated(log types.Log) (*SuperGovernorFeeUpdated, error) {
	event := new(SuperGovernorFeeUpdated)
	if err := _SuperGovernor.contract.UnpackLog(event, "FeeUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorFulfillRequestsHookRegisteredIterator is returned from FilterFulfillRequestsHookRegistered and is used to iterate over the raw logs and unpacked data for FulfillRequestsHookRegistered events raised by the SuperGovernor contract.
type SuperGovernorFulfillRequestsHookRegisteredIterator struct {
	Event *SuperGovernorFulfillRequestsHookRegistered // Event containing the contract specifics and raw log

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
func (it *SuperGovernorFulfillRequestsHookRegisteredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorFulfillRequestsHookRegistered)
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
		it.Event = new(SuperGovernorFulfillRequestsHookRegistered)
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
func (it *SuperGovernorFulfillRequestsHookRegisteredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorFulfillRequestsHookRegisteredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorFulfillRequestsHookRegistered represents a FulfillRequestsHookRegistered event raised by the SuperGovernor contract.
type SuperGovernorFulfillRequestsHookRegistered struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterFulfillRequestsHookRegistered is a free log retrieval operation binding the contract event 0x11764f0d0c3db8483b5aa057c1f5266bac770010886dc97e83bec7f34f315807.
//
// Solidity: event FulfillRequestsHookRegistered(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) FilterFulfillRequestsHookRegistered(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorFulfillRequestsHookRegisteredIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "FulfillRequestsHookRegistered", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorFulfillRequestsHookRegisteredIterator{contract: _SuperGovernor.contract, event: "FulfillRequestsHookRegistered", logs: logs, sub: sub}, nil
}

// WatchFulfillRequestsHookRegistered is a free log subscription operation binding the contract event 0x11764f0d0c3db8483b5aa057c1f5266bac770010886dc97e83bec7f34f315807.
//
// Solidity: event FulfillRequestsHookRegistered(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) WatchFulfillRequestsHookRegistered(opts *bind.WatchOpts, sink chan<- *SuperGovernorFulfillRequestsHookRegistered, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "FulfillRequestsHookRegistered", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorFulfillRequestsHookRegistered)
				if err := _SuperGovernor.contract.UnpackLog(event, "FulfillRequestsHookRegistered", log); err != nil {
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

// ParseFulfillRequestsHookRegistered is a log parse operation binding the contract event 0x11764f0d0c3db8483b5aa057c1f5266bac770010886dc97e83bec7f34f315807.
//
// Solidity: event FulfillRequestsHookRegistered(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) ParseFulfillRequestsHookRegistered(log types.Log) (*SuperGovernorFulfillRequestsHookRegistered, error) {
	event := new(SuperGovernorFulfillRequestsHookRegistered)
	if err := _SuperGovernor.contract.UnpackLog(event, "FulfillRequestsHookRegistered", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorFulfillRequestsHookUnregisteredIterator is returned from FilterFulfillRequestsHookUnregistered and is used to iterate over the raw logs and unpacked data for FulfillRequestsHookUnregistered events raised by the SuperGovernor contract.
type SuperGovernorFulfillRequestsHookUnregisteredIterator struct {
	Event *SuperGovernorFulfillRequestsHookUnregistered // Event containing the contract specifics and raw log

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
func (it *SuperGovernorFulfillRequestsHookUnregisteredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorFulfillRequestsHookUnregistered)
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
		it.Event = new(SuperGovernorFulfillRequestsHookUnregistered)
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
func (it *SuperGovernorFulfillRequestsHookUnregisteredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorFulfillRequestsHookUnregisteredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorFulfillRequestsHookUnregistered represents a FulfillRequestsHookUnregistered event raised by the SuperGovernor contract.
type SuperGovernorFulfillRequestsHookUnregistered struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterFulfillRequestsHookUnregistered is a free log retrieval operation binding the contract event 0x305fc42e276ebac0666dd3b0dbe7bd4014ce8a289b4078026176e821c4b5ef1d.
//
// Solidity: event FulfillRequestsHookUnregistered(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) FilterFulfillRequestsHookUnregistered(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorFulfillRequestsHookUnregisteredIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "FulfillRequestsHookUnregistered", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorFulfillRequestsHookUnregisteredIterator{contract: _SuperGovernor.contract, event: "FulfillRequestsHookUnregistered", logs: logs, sub: sub}, nil
}

// WatchFulfillRequestsHookUnregistered is a free log subscription operation binding the contract event 0x305fc42e276ebac0666dd3b0dbe7bd4014ce8a289b4078026176e821c4b5ef1d.
//
// Solidity: event FulfillRequestsHookUnregistered(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) WatchFulfillRequestsHookUnregistered(opts *bind.WatchOpts, sink chan<- *SuperGovernorFulfillRequestsHookUnregistered, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "FulfillRequestsHookUnregistered", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorFulfillRequestsHookUnregistered)
				if err := _SuperGovernor.contract.UnpackLog(event, "FulfillRequestsHookUnregistered", log); err != nil {
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

// ParseFulfillRequestsHookUnregistered is a log parse operation binding the contract event 0x305fc42e276ebac0666dd3b0dbe7bd4014ce8a289b4078026176e821c4b5ef1d.
//
// Solidity: event FulfillRequestsHookUnregistered(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) ParseFulfillRequestsHookUnregistered(log types.Log) (*SuperGovernorFulfillRequestsHookUnregistered, error) {
	event := new(SuperGovernorFulfillRequestsHookUnregistered)
	if err := _SuperGovernor.contract.UnpackLog(event, "FulfillRequestsHookUnregistered", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorHookApprovedIterator is returned from FilterHookApproved and is used to iterate over the raw logs and unpacked data for HookApproved events raised by the SuperGovernor contract.
type SuperGovernorHookApprovedIterator struct {
	Event *SuperGovernorHookApproved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorHookApprovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorHookApproved)
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
		it.Event = new(SuperGovernorHookApproved)
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
func (it *SuperGovernorHookApprovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorHookApprovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorHookApproved represents a HookApproved event raised by the SuperGovernor contract.
type SuperGovernorHookApproved struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterHookApproved is a free log retrieval operation binding the contract event 0x6b2d5736790b4cdb325004b8784c7b94dc55a32af9d82d1f6ceb5bd8c7c8573e.
//
// Solidity: event HookApproved(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) FilterHookApproved(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorHookApprovedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "HookApproved", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorHookApprovedIterator{contract: _SuperGovernor.contract, event: "HookApproved", logs: logs, sub: sub}, nil
}

// WatchHookApproved is a free log subscription operation binding the contract event 0x6b2d5736790b4cdb325004b8784c7b94dc55a32af9d82d1f6ceb5bd8c7c8573e.
//
// Solidity: event HookApproved(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) WatchHookApproved(opts *bind.WatchOpts, sink chan<- *SuperGovernorHookApproved, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "HookApproved", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorHookApproved)
				if err := _SuperGovernor.contract.UnpackLog(event, "HookApproved", log); err != nil {
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

// ParseHookApproved is a log parse operation binding the contract event 0x6b2d5736790b4cdb325004b8784c7b94dc55a32af9d82d1f6ceb5bd8c7c8573e.
//
// Solidity: event HookApproved(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) ParseHookApproved(log types.Log) (*SuperGovernorHookApproved, error) {
	event := new(SuperGovernorHookApproved)
	if err := _SuperGovernor.contract.UnpackLog(event, "HookApproved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorHookRemovedIterator is returned from FilterHookRemoved and is used to iterate over the raw logs and unpacked data for HookRemoved events raised by the SuperGovernor contract.
type SuperGovernorHookRemovedIterator struct {
	Event *SuperGovernorHookRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorHookRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorHookRemoved)
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
		it.Event = new(SuperGovernorHookRemoved)
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
func (it *SuperGovernorHookRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorHookRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorHookRemoved represents a HookRemoved event raised by the SuperGovernor contract.
type SuperGovernorHookRemoved struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterHookRemoved is a free log retrieval operation binding the contract event 0x47d0871e905ac6550f54ba266e0d90d2dc8ed67a957c064ca3438eddf4e3fd89.
//
// Solidity: event HookRemoved(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) FilterHookRemoved(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorHookRemovedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "HookRemoved", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorHookRemovedIterator{contract: _SuperGovernor.contract, event: "HookRemoved", logs: logs, sub: sub}, nil
}

// WatchHookRemoved is a free log subscription operation binding the contract event 0x47d0871e905ac6550f54ba266e0d90d2dc8ed67a957c064ca3438eddf4e3fd89.
//
// Solidity: event HookRemoved(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) WatchHookRemoved(opts *bind.WatchOpts, sink chan<- *SuperGovernorHookRemoved, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "HookRemoved", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorHookRemoved)
				if err := _SuperGovernor.contract.UnpackLog(event, "HookRemoved", log); err != nil {
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

// ParseHookRemoved is a log parse operation binding the contract event 0x47d0871e905ac6550f54ba266e0d90d2dc8ed67a957c064ca3438eddf4e3fd89.
//
// Solidity: event HookRemoved(address indexed hook)
func (_SuperGovernor *SuperGovernorFilterer) ParseHookRemoved(log types.Log) (*SuperGovernorHookRemoved, error) {
	event := new(SuperGovernorHookRemoved)
	if err := _SuperGovernor.contract.UnpackLog(event, "HookRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorPPSOracleQuorumUpdatedIterator is returned from FilterPPSOracleQuorumUpdated and is used to iterate over the raw logs and unpacked data for PPSOracleQuorumUpdated events raised by the SuperGovernor contract.
type SuperGovernorPPSOracleQuorumUpdatedIterator struct {
	Event *SuperGovernorPPSOracleQuorumUpdated // Event containing the contract specifics and raw log

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
func (it *SuperGovernorPPSOracleQuorumUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorPPSOracleQuorumUpdated)
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
		it.Event = new(SuperGovernorPPSOracleQuorumUpdated)
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
func (it *SuperGovernorPPSOracleQuorumUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorPPSOracleQuorumUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorPPSOracleQuorumUpdated represents a PPSOracleQuorumUpdated event raised by the SuperGovernor contract.
type SuperGovernorPPSOracleQuorumUpdated struct {
	Quorum *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterPPSOracleQuorumUpdated is a free log retrieval operation binding the contract event 0xf957b69cfa930a437fa0211ed212fe9b40bfbf99f4e5734d9d6068834d33a928.
//
// Solidity: event PPSOracleQuorumUpdated(uint256 quorum)
func (_SuperGovernor *SuperGovernorFilterer) FilterPPSOracleQuorumUpdated(opts *bind.FilterOpts) (*SuperGovernorPPSOracleQuorumUpdatedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "PPSOracleQuorumUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorPPSOracleQuorumUpdatedIterator{contract: _SuperGovernor.contract, event: "PPSOracleQuorumUpdated", logs: logs, sub: sub}, nil
}

// WatchPPSOracleQuorumUpdated is a free log subscription operation binding the contract event 0xf957b69cfa930a437fa0211ed212fe9b40bfbf99f4e5734d9d6068834d33a928.
//
// Solidity: event PPSOracleQuorumUpdated(uint256 quorum)
func (_SuperGovernor *SuperGovernorFilterer) WatchPPSOracleQuorumUpdated(opts *bind.WatchOpts, sink chan<- *SuperGovernorPPSOracleQuorumUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "PPSOracleQuorumUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorPPSOracleQuorumUpdated)
				if err := _SuperGovernor.contract.UnpackLog(event, "PPSOracleQuorumUpdated", log); err != nil {
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

// ParsePPSOracleQuorumUpdated is a log parse operation binding the contract event 0xf957b69cfa930a437fa0211ed212fe9b40bfbf99f4e5734d9d6068834d33a928.
//
// Solidity: event PPSOracleQuorumUpdated(uint256 quorum)
func (_SuperGovernor *SuperGovernorFilterer) ParsePPSOracleQuorumUpdated(log types.Log) (*SuperGovernorPPSOracleQuorumUpdated, error) {
	event := new(SuperGovernorPPSOracleQuorumUpdated)
	if err := _SuperGovernor.contract.UnpackLog(event, "PPSOracleQuorumUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorProverSetIterator is returned from FilterProverSet and is used to iterate over the raw logs and unpacked data for ProverSet events raised by the SuperGovernor contract.
type SuperGovernorProverSetIterator struct {
	Event *SuperGovernorProverSet // Event containing the contract specifics and raw log

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
func (it *SuperGovernorProverSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorProverSet)
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
		it.Event = new(SuperGovernorProverSet)
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
func (it *SuperGovernorProverSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorProverSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorProverSet represents a ProverSet event raised by the SuperGovernor contract.
type SuperGovernorProverSet struct {
	Prover common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterProverSet is a free log retrieval operation binding the contract event 0xc881e48d34a3dc6ca8b8ab38320d54f4972a7ade617113524dc2c2bf44984c8a.
//
// Solidity: event ProverSet(address indexed prover)
func (_SuperGovernor *SuperGovernorFilterer) FilterProverSet(opts *bind.FilterOpts, prover []common.Address) (*SuperGovernorProverSetIterator, error) {

	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ProverSet", proverRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorProverSetIterator{contract: _SuperGovernor.contract, event: "ProverSet", logs: logs, sub: sub}, nil
}

// WatchProverSet is a free log subscription operation binding the contract event 0xc881e48d34a3dc6ca8b8ab38320d54f4972a7ade617113524dc2c2bf44984c8a.
//
// Solidity: event ProverSet(address indexed prover)
func (_SuperGovernor *SuperGovernorFilterer) WatchProverSet(opts *bind.WatchOpts, sink chan<- *SuperGovernorProverSet, prover []common.Address) (event.Subscription, error) {

	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ProverSet", proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorProverSet)
				if err := _SuperGovernor.contract.UnpackLog(event, "ProverSet", log); err != nil {
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

// ParseProverSet is a log parse operation binding the contract event 0xc881e48d34a3dc6ca8b8ab38320d54f4972a7ade617113524dc2c2bf44984c8a.
//
// Solidity: event ProverSet(address indexed prover)
func (_SuperGovernor *SuperGovernorFilterer) ParseProverSet(log types.Log) (*SuperGovernorProverSet, error) {
	event := new(SuperGovernorProverSet)
	if err := _SuperGovernor.contract.UnpackLog(event, "ProverSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorRelayerAddedIterator is returned from FilterRelayerAdded and is used to iterate over the raw logs and unpacked data for RelayerAdded events raised by the SuperGovernor contract.
type SuperGovernorRelayerAddedIterator struct {
	Event *SuperGovernorRelayerAdded // Event containing the contract specifics and raw log

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
func (it *SuperGovernorRelayerAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorRelayerAdded)
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
		it.Event = new(SuperGovernorRelayerAdded)
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
func (it *SuperGovernorRelayerAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorRelayerAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorRelayerAdded represents a RelayerAdded event raised by the SuperGovernor contract.
type SuperGovernorRelayerAdded struct {
	Relayer common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRelayerAdded is a free log retrieval operation binding the contract event 0x03580ee9f53a62b7cb409a2cb56f9be87747dd15017afc5cef6eef321e4fb2c5.
//
// Solidity: event RelayerAdded(address indexed relayer)
func (_SuperGovernor *SuperGovernorFilterer) FilterRelayerAdded(opts *bind.FilterOpts, relayer []common.Address) (*SuperGovernorRelayerAddedIterator, error) {

	var relayerRule []interface{}
	for _, relayerItem := range relayer {
		relayerRule = append(relayerRule, relayerItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "RelayerAdded", relayerRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorRelayerAddedIterator{contract: _SuperGovernor.contract, event: "RelayerAdded", logs: logs, sub: sub}, nil
}

// WatchRelayerAdded is a free log subscription operation binding the contract event 0x03580ee9f53a62b7cb409a2cb56f9be87747dd15017afc5cef6eef321e4fb2c5.
//
// Solidity: event RelayerAdded(address indexed relayer)
func (_SuperGovernor *SuperGovernorFilterer) WatchRelayerAdded(opts *bind.WatchOpts, sink chan<- *SuperGovernorRelayerAdded, relayer []common.Address) (event.Subscription, error) {

	var relayerRule []interface{}
	for _, relayerItem := range relayer {
		relayerRule = append(relayerRule, relayerItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "RelayerAdded", relayerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorRelayerAdded)
				if err := _SuperGovernor.contract.UnpackLog(event, "RelayerAdded", log); err != nil {
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

// ParseRelayerAdded is a log parse operation binding the contract event 0x03580ee9f53a62b7cb409a2cb56f9be87747dd15017afc5cef6eef321e4fb2c5.
//
// Solidity: event RelayerAdded(address indexed relayer)
func (_SuperGovernor *SuperGovernorFilterer) ParseRelayerAdded(log types.Log) (*SuperGovernorRelayerAdded, error) {
	event := new(SuperGovernorRelayerAdded)
	if err := _SuperGovernor.contract.UnpackLog(event, "RelayerAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorRelayerRemovedIterator is returned from FilterRelayerRemoved and is used to iterate over the raw logs and unpacked data for RelayerRemoved events raised by the SuperGovernor contract.
type SuperGovernorRelayerRemovedIterator struct {
	Event *SuperGovernorRelayerRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorRelayerRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorRelayerRemoved)
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
		it.Event = new(SuperGovernorRelayerRemoved)
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
func (it *SuperGovernorRelayerRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorRelayerRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorRelayerRemoved represents a RelayerRemoved event raised by the SuperGovernor contract.
type SuperGovernorRelayerRemoved struct {
	Relayer common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRelayerRemoved is a free log retrieval operation binding the contract event 0x10e1f7ce9fd7d1b90a66d13a2ab3cb8dd7f29f3f8d520b143b063ccfbab6906b.
//
// Solidity: event RelayerRemoved(address indexed relayer)
func (_SuperGovernor *SuperGovernorFilterer) FilterRelayerRemoved(opts *bind.FilterOpts, relayer []common.Address) (*SuperGovernorRelayerRemovedIterator, error) {

	var relayerRule []interface{}
	for _, relayerItem := range relayer {
		relayerRule = append(relayerRule, relayerItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "RelayerRemoved", relayerRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorRelayerRemovedIterator{contract: _SuperGovernor.contract, event: "RelayerRemoved", logs: logs, sub: sub}, nil
}

// WatchRelayerRemoved is a free log subscription operation binding the contract event 0x10e1f7ce9fd7d1b90a66d13a2ab3cb8dd7f29f3f8d520b143b063ccfbab6906b.
//
// Solidity: event RelayerRemoved(address indexed relayer)
func (_SuperGovernor *SuperGovernorFilterer) WatchRelayerRemoved(opts *bind.WatchOpts, sink chan<- *SuperGovernorRelayerRemoved, relayer []common.Address) (event.Subscription, error) {

	var relayerRule []interface{}
	for _, relayerItem := range relayer {
		relayerRule = append(relayerRule, relayerItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "RelayerRemoved", relayerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorRelayerRemoved)
				if err := _SuperGovernor.contract.UnpackLog(event, "RelayerRemoved", log); err != nil {
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

// ParseRelayerRemoved is a log parse operation binding the contract event 0x10e1f7ce9fd7d1b90a66d13a2ab3cb8dd7f29f3f8d520b143b063ccfbab6906b.
//
// Solidity: event RelayerRemoved(address indexed relayer)
func (_SuperGovernor *SuperGovernorFilterer) ParseRelayerRemoved(log types.Log) (*SuperGovernorRelayerRemoved, error) {
	event := new(SuperGovernorRelayerRemoved)
	if err := _SuperGovernor.contract.UnpackLog(event, "RelayerRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorRevenueShareUpdatedIterator is returned from FilterRevenueShareUpdated and is used to iterate over the raw logs and unpacked data for RevenueShareUpdated events raised by the SuperGovernor contract.
type SuperGovernorRevenueShareUpdatedIterator struct {
	Event *SuperGovernorRevenueShareUpdated // Event containing the contract specifics and raw log

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
func (it *SuperGovernorRevenueShareUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorRevenueShareUpdated)
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
		it.Event = new(SuperGovernorRevenueShareUpdated)
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
func (it *SuperGovernorRevenueShareUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorRevenueShareUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorRevenueShareUpdated represents a RevenueShareUpdated event raised by the SuperGovernor contract.
type SuperGovernorRevenueShareUpdated struct {
	Share *big.Int
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterRevenueShareUpdated is a free log retrieval operation binding the contract event 0x343a3cad72a9e3a0fe71e8417402226b647587dfd1713f79f85413ed27df7f7b.
//
// Solidity: event RevenueShareUpdated(uint256 share)
func (_SuperGovernor *SuperGovernorFilterer) FilterRevenueShareUpdated(opts *bind.FilterOpts) (*SuperGovernorRevenueShareUpdatedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "RevenueShareUpdated")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorRevenueShareUpdatedIterator{contract: _SuperGovernor.contract, event: "RevenueShareUpdated", logs: logs, sub: sub}, nil
}

// WatchRevenueShareUpdated is a free log subscription operation binding the contract event 0x343a3cad72a9e3a0fe71e8417402226b647587dfd1713f79f85413ed27df7f7b.
//
// Solidity: event RevenueShareUpdated(uint256 share)
func (_SuperGovernor *SuperGovernorFilterer) WatchRevenueShareUpdated(opts *bind.WatchOpts, sink chan<- *SuperGovernorRevenueShareUpdated) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "RevenueShareUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorRevenueShareUpdated)
				if err := _SuperGovernor.contract.UnpackLog(event, "RevenueShareUpdated", log); err != nil {
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

// ParseRevenueShareUpdated is a log parse operation binding the contract event 0x343a3cad72a9e3a0fe71e8417402226b647587dfd1713f79f85413ed27df7f7b.
//
// Solidity: event RevenueShareUpdated(uint256 share)
func (_SuperGovernor *SuperGovernorFilterer) ParseRevenueShareUpdated(log types.Log) (*SuperGovernorRevenueShareUpdated, error) {
	event := new(SuperGovernorRevenueShareUpdated)
	if err := _SuperGovernor.contract.UnpackLog(event, "RevenueShareUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorRoleAdminChangedIterator is returned from FilterRoleAdminChanged and is used to iterate over the raw logs and unpacked data for RoleAdminChanged events raised by the SuperGovernor contract.
type SuperGovernorRoleAdminChangedIterator struct {
	Event *SuperGovernorRoleAdminChanged // Event containing the contract specifics and raw log

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
func (it *SuperGovernorRoleAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorRoleAdminChanged)
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
		it.Event = new(SuperGovernorRoleAdminChanged)
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
func (it *SuperGovernorRoleAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorRoleAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorRoleAdminChanged represents a RoleAdminChanged event raised by the SuperGovernor contract.
type SuperGovernorRoleAdminChanged struct {
	Role              [32]byte
	PreviousAdminRole [32]byte
	NewAdminRole      [32]byte
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterRoleAdminChanged is a free log retrieval operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperGovernor *SuperGovernorFilterer) FilterRoleAdminChanged(opts *bind.FilterOpts, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (*SuperGovernorRoleAdminChangedIterator, error) {

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

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorRoleAdminChangedIterator{contract: _SuperGovernor.contract, event: "RoleAdminChanged", logs: logs, sub: sub}, nil
}

// WatchRoleAdminChanged is a free log subscription operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_SuperGovernor *SuperGovernorFilterer) WatchRoleAdminChanged(opts *bind.WatchOpts, sink chan<- *SuperGovernorRoleAdminChanged, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (event.Subscription, error) {

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

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorRoleAdminChanged)
				if err := _SuperGovernor.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
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
func (_SuperGovernor *SuperGovernorFilterer) ParseRoleAdminChanged(log types.Log) (*SuperGovernorRoleAdminChanged, error) {
	event := new(SuperGovernorRoleAdminChanged)
	if err := _SuperGovernor.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorRoleGrantedIterator is returned from FilterRoleGranted and is used to iterate over the raw logs and unpacked data for RoleGranted events raised by the SuperGovernor contract.
type SuperGovernorRoleGrantedIterator struct {
	Event *SuperGovernorRoleGranted // Event containing the contract specifics and raw log

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
func (it *SuperGovernorRoleGrantedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorRoleGranted)
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
		it.Event = new(SuperGovernorRoleGranted)
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
func (it *SuperGovernorRoleGrantedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorRoleGrantedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorRoleGranted represents a RoleGranted event raised by the SuperGovernor contract.
type SuperGovernorRoleGranted struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleGranted is a free log retrieval operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperGovernor *SuperGovernorFilterer) FilterRoleGranted(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperGovernorRoleGrantedIterator, error) {

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

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorRoleGrantedIterator{contract: _SuperGovernor.contract, event: "RoleGranted", logs: logs, sub: sub}, nil
}

// WatchRoleGranted is a free log subscription operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperGovernor *SuperGovernorFilterer) WatchRoleGranted(opts *bind.WatchOpts, sink chan<- *SuperGovernorRoleGranted, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorRoleGranted)
				if err := _SuperGovernor.contract.UnpackLog(event, "RoleGranted", log); err != nil {
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
func (_SuperGovernor *SuperGovernorFilterer) ParseRoleGranted(log types.Log) (*SuperGovernorRoleGranted, error) {
	event := new(SuperGovernorRoleGranted)
	if err := _SuperGovernor.contract.UnpackLog(event, "RoleGranted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorRoleRevokedIterator is returned from FilterRoleRevoked and is used to iterate over the raw logs and unpacked data for RoleRevoked events raised by the SuperGovernor contract.
type SuperGovernorRoleRevokedIterator struct {
	Event *SuperGovernorRoleRevoked // Event containing the contract specifics and raw log

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
func (it *SuperGovernorRoleRevokedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorRoleRevoked)
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
		it.Event = new(SuperGovernorRoleRevoked)
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
func (it *SuperGovernorRoleRevokedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorRoleRevokedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorRoleRevoked represents a RoleRevoked event raised by the SuperGovernor contract.
type SuperGovernorRoleRevoked struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleRevoked is a free log retrieval operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperGovernor *SuperGovernorFilterer) FilterRoleRevoked(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*SuperGovernorRoleRevokedIterator, error) {

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

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorRoleRevokedIterator{contract: _SuperGovernor.contract, event: "RoleRevoked", logs: logs, sub: sub}, nil
}

// WatchRoleRevoked is a free log subscription operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_SuperGovernor *SuperGovernorFilterer) WatchRoleRevoked(opts *bind.WatchOpts, sink chan<- *SuperGovernorRoleRevoked, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorRoleRevoked)
				if err := _SuperGovernor.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
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
func (_SuperGovernor *SuperGovernorFilterer) ParseRoleRevoked(log types.Log) (*SuperGovernorRoleRevoked, error) {
	event := new(SuperGovernorRoleRevoked)
	if err := _SuperGovernor.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorStrategistAddedIterator is returned from FilterStrategistAdded and is used to iterate over the raw logs and unpacked data for StrategistAdded events raised by the SuperGovernor contract.
type SuperGovernorStrategistAddedIterator struct {
	Event *SuperGovernorStrategistAdded // Event containing the contract specifics and raw log

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
func (it *SuperGovernorStrategistAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorStrategistAdded)
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
		it.Event = new(SuperGovernorStrategistAdded)
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
func (it *SuperGovernorStrategistAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorStrategistAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorStrategistAdded represents a StrategistAdded event raised by the SuperGovernor contract.
type SuperGovernorStrategistAdded struct {
	Strategist common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterStrategistAdded is a free log retrieval operation binding the contract event 0xb7bc4a807819acf1980215983104cd2f50404cc9d86a0078869e431167d55a1b.
//
// Solidity: event StrategistAdded(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) FilterStrategistAdded(opts *bind.FilterOpts, strategist []common.Address) (*SuperGovernorStrategistAddedIterator, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "StrategistAdded", strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorStrategistAddedIterator{contract: _SuperGovernor.contract, event: "StrategistAdded", logs: logs, sub: sub}, nil
}

// WatchStrategistAdded is a free log subscription operation binding the contract event 0xb7bc4a807819acf1980215983104cd2f50404cc9d86a0078869e431167d55a1b.
//
// Solidity: event StrategistAdded(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) WatchStrategistAdded(opts *bind.WatchOpts, sink chan<- *SuperGovernorStrategistAdded, strategist []common.Address) (event.Subscription, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "StrategistAdded", strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorStrategistAdded)
				if err := _SuperGovernor.contract.UnpackLog(event, "StrategistAdded", log); err != nil {
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

// ParseStrategistAdded is a log parse operation binding the contract event 0xb7bc4a807819acf1980215983104cd2f50404cc9d86a0078869e431167d55a1b.
//
// Solidity: event StrategistAdded(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) ParseStrategistAdded(log types.Log) (*SuperGovernorStrategistAdded, error) {
	event := new(SuperGovernorStrategistAdded)
	if err := _SuperGovernor.contract.UnpackLog(event, "StrategistAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorStrategistRemovedIterator is returned from FilterStrategistRemoved and is used to iterate over the raw logs and unpacked data for StrategistRemoved events raised by the SuperGovernor contract.
type SuperGovernorStrategistRemovedIterator struct {
	Event *SuperGovernorStrategistRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorStrategistRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorStrategistRemoved)
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
		it.Event = new(SuperGovernorStrategistRemoved)
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
func (it *SuperGovernorStrategistRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorStrategistRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorStrategistRemoved represents a StrategistRemoved event raised by the SuperGovernor contract.
type SuperGovernorStrategistRemoved struct {
	Strategist common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterStrategistRemoved is a free log retrieval operation binding the contract event 0x2f4370deaa4838aa66a5370105f58c9d313fc7d4f22271170e74081a0a0c26a1.
//
// Solidity: event StrategistRemoved(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) FilterStrategistRemoved(opts *bind.FilterOpts, strategist []common.Address) (*SuperGovernorStrategistRemovedIterator, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "StrategistRemoved", strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorStrategistRemovedIterator{contract: _SuperGovernor.contract, event: "StrategistRemoved", logs: logs, sub: sub}, nil
}

// WatchStrategistRemoved is a free log subscription operation binding the contract event 0x2f4370deaa4838aa66a5370105f58c9d313fc7d4f22271170e74081a0a0c26a1.
//
// Solidity: event StrategistRemoved(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) WatchStrategistRemoved(opts *bind.WatchOpts, sink chan<- *SuperGovernorStrategistRemoved, strategist []common.Address) (event.Subscription, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "StrategistRemoved", strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorStrategistRemoved)
				if err := _SuperGovernor.contract.UnpackLog(event, "StrategistRemoved", log); err != nil {
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

// ParseStrategistRemoved is a log parse operation binding the contract event 0x2f4370deaa4838aa66a5370105f58c9d313fc7d4f22271170e74081a0a0c26a1.
//
// Solidity: event StrategistRemoved(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) ParseStrategistRemoved(log types.Log) (*SuperGovernorStrategistRemoved, error) {
	event := new(SuperGovernorStrategistRemoved)
	if err := _SuperGovernor.contract.UnpackLog(event, "StrategistRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorStrategistTakeoversFrozenIterator is returned from FilterStrategistTakeoversFrozen and is used to iterate over the raw logs and unpacked data for StrategistTakeoversFrozen events raised by the SuperGovernor contract.
type SuperGovernorStrategistTakeoversFrozenIterator struct {
	Event *SuperGovernorStrategistTakeoversFrozen // Event containing the contract specifics and raw log

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
func (it *SuperGovernorStrategistTakeoversFrozenIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorStrategistTakeoversFrozen)
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
		it.Event = new(SuperGovernorStrategistTakeoversFrozen)
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
func (it *SuperGovernorStrategistTakeoversFrozenIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorStrategistTakeoversFrozenIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorStrategistTakeoversFrozen represents a StrategistTakeoversFrozen event raised by the SuperGovernor contract.
type SuperGovernorStrategistTakeoversFrozen struct {
	Raw types.Log // Blockchain specific contextual infos
}

// FilterStrategistTakeoversFrozen is a free log retrieval operation binding the contract event 0x64db12abd2060a62e7b55cea37074f5477f801baed3a294c7b30bf85160e2d3a.
//
// Solidity: event StrategistTakeoversFrozen()
func (_SuperGovernor *SuperGovernorFilterer) FilterStrategistTakeoversFrozen(opts *bind.FilterOpts) (*SuperGovernorStrategistTakeoversFrozenIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "StrategistTakeoversFrozen")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorStrategistTakeoversFrozenIterator{contract: _SuperGovernor.contract, event: "StrategistTakeoversFrozen", logs: logs, sub: sub}, nil
}

// WatchStrategistTakeoversFrozen is a free log subscription operation binding the contract event 0x64db12abd2060a62e7b55cea37074f5477f801baed3a294c7b30bf85160e2d3a.
//
// Solidity: event StrategistTakeoversFrozen()
func (_SuperGovernor *SuperGovernorFilterer) WatchStrategistTakeoversFrozen(opts *bind.WatchOpts, sink chan<- *SuperGovernorStrategistTakeoversFrozen) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "StrategistTakeoversFrozen")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorStrategistTakeoversFrozen)
				if err := _SuperGovernor.contract.UnpackLog(event, "StrategistTakeoversFrozen", log); err != nil {
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

// ParseStrategistTakeoversFrozen is a log parse operation binding the contract event 0x64db12abd2060a62e7b55cea37074f5477f801baed3a294c7b30bf85160e2d3a.
//
// Solidity: event StrategistTakeoversFrozen()
func (_SuperGovernor *SuperGovernorFilterer) ParseStrategistTakeoversFrozen(log types.Log) (*SuperGovernorStrategistTakeoversFrozen, error) {
	event := new(SuperGovernorStrategistTakeoversFrozen)
	if err := _SuperGovernor.contract.UnpackLog(event, "StrategistTakeoversFrozen", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorSuperBankHookMerkleRootProposedIterator is returned from FilterSuperBankHookMerkleRootProposed and is used to iterate over the raw logs and unpacked data for SuperBankHookMerkleRootProposed events raised by the SuperGovernor contract.
type SuperGovernorSuperBankHookMerkleRootProposedIterator struct {
	Event *SuperGovernorSuperBankHookMerkleRootProposed // Event containing the contract specifics and raw log

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
func (it *SuperGovernorSuperBankHookMerkleRootProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorSuperBankHookMerkleRootProposed)
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
		it.Event = new(SuperGovernorSuperBankHookMerkleRootProposed)
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
func (it *SuperGovernorSuperBankHookMerkleRootProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorSuperBankHookMerkleRootProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorSuperBankHookMerkleRootProposed represents a SuperBankHookMerkleRootProposed event raised by the SuperGovernor contract.
type SuperGovernorSuperBankHookMerkleRootProposed struct {
	Hook          common.Address
	NewRoot       [32]byte
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterSuperBankHookMerkleRootProposed is a free log retrieval operation binding the contract event 0x2f45381bbf8fc39bccf5516ecef3bec5e43aed86711ddaa35c12ab2d6073fd36.
//
// Solidity: event SuperBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) FilterSuperBankHookMerkleRootProposed(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorSuperBankHookMerkleRootProposedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "SuperBankHookMerkleRootProposed", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorSuperBankHookMerkleRootProposedIterator{contract: _SuperGovernor.contract, event: "SuperBankHookMerkleRootProposed", logs: logs, sub: sub}, nil
}

// WatchSuperBankHookMerkleRootProposed is a free log subscription operation binding the contract event 0x2f45381bbf8fc39bccf5516ecef3bec5e43aed86711ddaa35c12ab2d6073fd36.
//
// Solidity: event SuperBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) WatchSuperBankHookMerkleRootProposed(opts *bind.WatchOpts, sink chan<- *SuperGovernorSuperBankHookMerkleRootProposed, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "SuperBankHookMerkleRootProposed", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorSuperBankHookMerkleRootProposed)
				if err := _SuperGovernor.contract.UnpackLog(event, "SuperBankHookMerkleRootProposed", log); err != nil {
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

// ParseSuperBankHookMerkleRootProposed is a log parse operation binding the contract event 0x2f45381bbf8fc39bccf5516ecef3bec5e43aed86711ddaa35c12ab2d6073fd36.
//
// Solidity: event SuperBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) ParseSuperBankHookMerkleRootProposed(log types.Log) (*SuperGovernorSuperBankHookMerkleRootProposed, error) {
	event := new(SuperGovernorSuperBankHookMerkleRootProposed)
	if err := _SuperGovernor.contract.UnpackLog(event, "SuperBankHookMerkleRootProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorSuperBankHookMerkleRootUpdatedIterator is returned from FilterSuperBankHookMerkleRootUpdated and is used to iterate over the raw logs and unpacked data for SuperBankHookMerkleRootUpdated events raised by the SuperGovernor contract.
type SuperGovernorSuperBankHookMerkleRootUpdatedIterator struct {
	Event *SuperGovernorSuperBankHookMerkleRootUpdated // Event containing the contract specifics and raw log

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
func (it *SuperGovernorSuperBankHookMerkleRootUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorSuperBankHookMerkleRootUpdated)
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
		it.Event = new(SuperGovernorSuperBankHookMerkleRootUpdated)
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
func (it *SuperGovernorSuperBankHookMerkleRootUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorSuperBankHookMerkleRootUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorSuperBankHookMerkleRootUpdated represents a SuperBankHookMerkleRootUpdated event raised by the SuperGovernor contract.
type SuperGovernorSuperBankHookMerkleRootUpdated struct {
	Hook    common.Address
	NewRoot [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperBankHookMerkleRootUpdated is a free log retrieval operation binding the contract event 0xac299fc62dbe9994754db34d3374ec4eb38e185895e08b5bbffa75e98bf2a53f.
//
// Solidity: event SuperBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot)
func (_SuperGovernor *SuperGovernorFilterer) FilterSuperBankHookMerkleRootUpdated(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorSuperBankHookMerkleRootUpdatedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "SuperBankHookMerkleRootUpdated", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorSuperBankHookMerkleRootUpdatedIterator{contract: _SuperGovernor.contract, event: "SuperBankHookMerkleRootUpdated", logs: logs, sub: sub}, nil
}

// WatchSuperBankHookMerkleRootUpdated is a free log subscription operation binding the contract event 0xac299fc62dbe9994754db34d3374ec4eb38e185895e08b5bbffa75e98bf2a53f.
//
// Solidity: event SuperBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot)
func (_SuperGovernor *SuperGovernorFilterer) WatchSuperBankHookMerkleRootUpdated(opts *bind.WatchOpts, sink chan<- *SuperGovernorSuperBankHookMerkleRootUpdated, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "SuperBankHookMerkleRootUpdated", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorSuperBankHookMerkleRootUpdated)
				if err := _SuperGovernor.contract.UnpackLog(event, "SuperBankHookMerkleRootUpdated", log); err != nil {
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

// ParseSuperBankHookMerkleRootUpdated is a log parse operation binding the contract event 0xac299fc62dbe9994754db34d3374ec4eb38e185895e08b5bbffa75e98bf2a53f.
//
// Solidity: event SuperBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot)
func (_SuperGovernor *SuperGovernorFilterer) ParseSuperBankHookMerkleRootUpdated(log types.Log) (*SuperGovernorSuperBankHookMerkleRootUpdated, error) {
	event := new(SuperGovernorSuperBankHookMerkleRootUpdated)
	if err := _SuperGovernor.contract.UnpackLog(event, "SuperBankHookMerkleRootUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorSuperformStrategistAddedIterator is returned from FilterSuperformStrategistAdded and is used to iterate over the raw logs and unpacked data for SuperformStrategistAdded events raised by the SuperGovernor contract.
type SuperGovernorSuperformStrategistAddedIterator struct {
	Event *SuperGovernorSuperformStrategistAdded // Event containing the contract specifics and raw log

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
func (it *SuperGovernorSuperformStrategistAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorSuperformStrategistAdded)
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
		it.Event = new(SuperGovernorSuperformStrategistAdded)
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
func (it *SuperGovernorSuperformStrategistAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorSuperformStrategistAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorSuperformStrategistAdded represents a SuperformStrategistAdded event raised by the SuperGovernor contract.
type SuperGovernorSuperformStrategistAdded struct {
	Strategist common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSuperformStrategistAdded is a free log retrieval operation binding the contract event 0x0d9e04b66e574eed4c03dc494cb9b7a5c865f9a5910d5c727445b2eed7aab497.
//
// Solidity: event SuperformStrategistAdded(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) FilterSuperformStrategistAdded(opts *bind.FilterOpts, strategist []common.Address) (*SuperGovernorSuperformStrategistAddedIterator, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "SuperformStrategistAdded", strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorSuperformStrategistAddedIterator{contract: _SuperGovernor.contract, event: "SuperformStrategistAdded", logs: logs, sub: sub}, nil
}

// WatchSuperformStrategistAdded is a free log subscription operation binding the contract event 0x0d9e04b66e574eed4c03dc494cb9b7a5c865f9a5910d5c727445b2eed7aab497.
//
// Solidity: event SuperformStrategistAdded(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) WatchSuperformStrategistAdded(opts *bind.WatchOpts, sink chan<- *SuperGovernorSuperformStrategistAdded, strategist []common.Address) (event.Subscription, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "SuperformStrategistAdded", strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorSuperformStrategistAdded)
				if err := _SuperGovernor.contract.UnpackLog(event, "SuperformStrategistAdded", log); err != nil {
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

// ParseSuperformStrategistAdded is a log parse operation binding the contract event 0x0d9e04b66e574eed4c03dc494cb9b7a5c865f9a5910d5c727445b2eed7aab497.
//
// Solidity: event SuperformStrategistAdded(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) ParseSuperformStrategistAdded(log types.Log) (*SuperGovernorSuperformStrategistAdded, error) {
	event := new(SuperGovernorSuperformStrategistAdded)
	if err := _SuperGovernor.contract.UnpackLog(event, "SuperformStrategistAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorSuperformStrategistRemovedIterator is returned from FilterSuperformStrategistRemoved and is used to iterate over the raw logs and unpacked data for SuperformStrategistRemoved events raised by the SuperGovernor contract.
type SuperGovernorSuperformStrategistRemovedIterator struct {
	Event *SuperGovernorSuperformStrategistRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorSuperformStrategistRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorSuperformStrategistRemoved)
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
		it.Event = new(SuperGovernorSuperformStrategistRemoved)
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
func (it *SuperGovernorSuperformStrategistRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorSuperformStrategistRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorSuperformStrategistRemoved represents a SuperformStrategistRemoved event raised by the SuperGovernor contract.
type SuperGovernorSuperformStrategistRemoved struct {
	Strategist common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSuperformStrategistRemoved is a free log retrieval operation binding the contract event 0x6eebcc6b9ad28a4486fa00acec4245cc669e509eb5f37051b02f293a133894ce.
//
// Solidity: event SuperformStrategistRemoved(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) FilterSuperformStrategistRemoved(opts *bind.FilterOpts, strategist []common.Address) (*SuperGovernorSuperformStrategistRemovedIterator, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "SuperformStrategistRemoved", strategistRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorSuperformStrategistRemovedIterator{contract: _SuperGovernor.contract, event: "SuperformStrategistRemoved", logs: logs, sub: sub}, nil
}

// WatchSuperformStrategistRemoved is a free log subscription operation binding the contract event 0x6eebcc6b9ad28a4486fa00acec4245cc669e509eb5f37051b02f293a133894ce.
//
// Solidity: event SuperformStrategistRemoved(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) WatchSuperformStrategistRemoved(opts *bind.WatchOpts, sink chan<- *SuperGovernorSuperformStrategistRemoved, strategist []common.Address) (event.Subscription, error) {

	var strategistRule []interface{}
	for _, strategistItem := range strategist {
		strategistRule = append(strategistRule, strategistItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "SuperformStrategistRemoved", strategistRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorSuperformStrategistRemoved)
				if err := _SuperGovernor.contract.UnpackLog(event, "SuperformStrategistRemoved", log); err != nil {
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

// ParseSuperformStrategistRemoved is a log parse operation binding the contract event 0x6eebcc6b9ad28a4486fa00acec4245cc669e509eb5f37051b02f293a133894ce.
//
// Solidity: event SuperformStrategistRemoved(address indexed strategist)
func (_SuperGovernor *SuperGovernorFilterer) ParseSuperformStrategistRemoved(log types.Log) (*SuperGovernorSuperformStrategistRemoved, error) {
	event := new(SuperGovernorSuperformStrategistRemoved)
	if err := _SuperGovernor.contract.UnpackLog(event, "SuperformStrategistRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorUpkeepCostPerUpdateChangedIterator is returned from FilterUpkeepCostPerUpdateChanged and is used to iterate over the raw logs and unpacked data for UpkeepCostPerUpdateChanged events raised by the SuperGovernor contract.
type SuperGovernorUpkeepCostPerUpdateChangedIterator struct {
	Event *SuperGovernorUpkeepCostPerUpdateChanged // Event containing the contract specifics and raw log

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
func (it *SuperGovernorUpkeepCostPerUpdateChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorUpkeepCostPerUpdateChanged)
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
		it.Event = new(SuperGovernorUpkeepCostPerUpdateChanged)
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
func (it *SuperGovernorUpkeepCostPerUpdateChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorUpkeepCostPerUpdateChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorUpkeepCostPerUpdateChanged represents a UpkeepCostPerUpdateChanged event raised by the SuperGovernor contract.
type SuperGovernorUpkeepCostPerUpdateChanged struct {
	NewCost *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUpkeepCostPerUpdateChanged is a free log retrieval operation binding the contract event 0x1ab7e1c2577ef2ff1ab808b28915a8fb8371717c6e45797badd8053ec79a8319.
//
// Solidity: event UpkeepCostPerUpdateChanged(uint256 newCost)
func (_SuperGovernor *SuperGovernorFilterer) FilterUpkeepCostPerUpdateChanged(opts *bind.FilterOpts) (*SuperGovernorUpkeepCostPerUpdateChangedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "UpkeepCostPerUpdateChanged")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorUpkeepCostPerUpdateChangedIterator{contract: _SuperGovernor.contract, event: "UpkeepCostPerUpdateChanged", logs: logs, sub: sub}, nil
}

// WatchUpkeepCostPerUpdateChanged is a free log subscription operation binding the contract event 0x1ab7e1c2577ef2ff1ab808b28915a8fb8371717c6e45797badd8053ec79a8319.
//
// Solidity: event UpkeepCostPerUpdateChanged(uint256 newCost)
func (_SuperGovernor *SuperGovernorFilterer) WatchUpkeepCostPerUpdateChanged(opts *bind.WatchOpts, sink chan<- *SuperGovernorUpkeepCostPerUpdateChanged) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "UpkeepCostPerUpdateChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorUpkeepCostPerUpdateChanged)
				if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepCostPerUpdateChanged", log); err != nil {
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

// ParseUpkeepCostPerUpdateChanged is a log parse operation binding the contract event 0x1ab7e1c2577ef2ff1ab808b28915a8fb8371717c6e45797badd8053ec79a8319.
//
// Solidity: event UpkeepCostPerUpdateChanged(uint256 newCost)
func (_SuperGovernor *SuperGovernorFilterer) ParseUpkeepCostPerUpdateChanged(log types.Log) (*SuperGovernorUpkeepCostPerUpdateChanged, error) {
	event := new(SuperGovernorUpkeepCostPerUpdateChanged)
	if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepCostPerUpdateChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorUpkeepCostPerUpdateProposedIterator is returned from FilterUpkeepCostPerUpdateProposed and is used to iterate over the raw logs and unpacked data for UpkeepCostPerUpdateProposed events raised by the SuperGovernor contract.
type SuperGovernorUpkeepCostPerUpdateProposedIterator struct {
	Event *SuperGovernorUpkeepCostPerUpdateProposed // Event containing the contract specifics and raw log

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
func (it *SuperGovernorUpkeepCostPerUpdateProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorUpkeepCostPerUpdateProposed)
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
		it.Event = new(SuperGovernorUpkeepCostPerUpdateProposed)
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
func (it *SuperGovernorUpkeepCostPerUpdateProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorUpkeepCostPerUpdateProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorUpkeepCostPerUpdateProposed represents a UpkeepCostPerUpdateProposed event raised by the SuperGovernor contract.
type SuperGovernorUpkeepCostPerUpdateProposed struct {
	NewCost       *big.Int
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterUpkeepCostPerUpdateProposed is a free log retrieval operation binding the contract event 0x9ef1e125d24f54271ecd16a06b5e5dfe9b7f92809186ab8a23afa3c9f4820673.
//
// Solidity: event UpkeepCostPerUpdateProposed(uint256 newCost, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) FilterUpkeepCostPerUpdateProposed(opts *bind.FilterOpts) (*SuperGovernorUpkeepCostPerUpdateProposedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "UpkeepCostPerUpdateProposed")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorUpkeepCostPerUpdateProposedIterator{contract: _SuperGovernor.contract, event: "UpkeepCostPerUpdateProposed", logs: logs, sub: sub}, nil
}

// WatchUpkeepCostPerUpdateProposed is a free log subscription operation binding the contract event 0x9ef1e125d24f54271ecd16a06b5e5dfe9b7f92809186ab8a23afa3c9f4820673.
//
// Solidity: event UpkeepCostPerUpdateProposed(uint256 newCost, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) WatchUpkeepCostPerUpdateProposed(opts *bind.WatchOpts, sink chan<- *SuperGovernorUpkeepCostPerUpdateProposed) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "UpkeepCostPerUpdateProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorUpkeepCostPerUpdateProposed)
				if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepCostPerUpdateProposed", log); err != nil {
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

// ParseUpkeepCostPerUpdateProposed is a log parse operation binding the contract event 0x9ef1e125d24f54271ecd16a06b5e5dfe9b7f92809186ab8a23afa3c9f4820673.
//
// Solidity: event UpkeepCostPerUpdateProposed(uint256 newCost, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) ParseUpkeepCostPerUpdateProposed(log types.Log) (*SuperGovernorUpkeepCostPerUpdateProposed, error) {
	event := new(SuperGovernorUpkeepCostPerUpdateProposed)
	if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepCostPerUpdateProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorUpkeepPaymentsChangeProposedIterator is returned from FilterUpkeepPaymentsChangeProposed and is used to iterate over the raw logs and unpacked data for UpkeepPaymentsChangeProposed events raised by the SuperGovernor contract.
type SuperGovernorUpkeepPaymentsChangeProposedIterator struct {
	Event *SuperGovernorUpkeepPaymentsChangeProposed // Event containing the contract specifics and raw log

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
func (it *SuperGovernorUpkeepPaymentsChangeProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorUpkeepPaymentsChangeProposed)
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
		it.Event = new(SuperGovernorUpkeepPaymentsChangeProposed)
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
func (it *SuperGovernorUpkeepPaymentsChangeProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorUpkeepPaymentsChangeProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorUpkeepPaymentsChangeProposed represents a UpkeepPaymentsChangeProposed event raised by the SuperGovernor contract.
type SuperGovernorUpkeepPaymentsChangeProposed struct {
	Enabled       bool
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterUpkeepPaymentsChangeProposed is a free log retrieval operation binding the contract event 0x3ccaf2442d2b29874fd84ceba9675d97d4dde7d521be650f67faab29a9afb10a.
//
// Solidity: event UpkeepPaymentsChangeProposed(bool enabled, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) FilterUpkeepPaymentsChangeProposed(opts *bind.FilterOpts) (*SuperGovernorUpkeepPaymentsChangeProposedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "UpkeepPaymentsChangeProposed")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorUpkeepPaymentsChangeProposedIterator{contract: _SuperGovernor.contract, event: "UpkeepPaymentsChangeProposed", logs: logs, sub: sub}, nil
}

// WatchUpkeepPaymentsChangeProposed is a free log subscription operation binding the contract event 0x3ccaf2442d2b29874fd84ceba9675d97d4dde7d521be650f67faab29a9afb10a.
//
// Solidity: event UpkeepPaymentsChangeProposed(bool enabled, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) WatchUpkeepPaymentsChangeProposed(opts *bind.WatchOpts, sink chan<- *SuperGovernorUpkeepPaymentsChangeProposed) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "UpkeepPaymentsChangeProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorUpkeepPaymentsChangeProposed)
				if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepPaymentsChangeProposed", log); err != nil {
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

// ParseUpkeepPaymentsChangeProposed is a log parse operation binding the contract event 0x3ccaf2442d2b29874fd84ceba9675d97d4dde7d521be650f67faab29a9afb10a.
//
// Solidity: event UpkeepPaymentsChangeProposed(bool enabled, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) ParseUpkeepPaymentsChangeProposed(log types.Log) (*SuperGovernorUpkeepPaymentsChangeProposed, error) {
	event := new(SuperGovernorUpkeepPaymentsChangeProposed)
	if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepPaymentsChangeProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorUpkeepPaymentsChangedIterator is returned from FilterUpkeepPaymentsChanged and is used to iterate over the raw logs and unpacked data for UpkeepPaymentsChanged events raised by the SuperGovernor contract.
type SuperGovernorUpkeepPaymentsChangedIterator struct {
	Event *SuperGovernorUpkeepPaymentsChanged // Event containing the contract specifics and raw log

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
func (it *SuperGovernorUpkeepPaymentsChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorUpkeepPaymentsChanged)
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
		it.Event = new(SuperGovernorUpkeepPaymentsChanged)
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
func (it *SuperGovernorUpkeepPaymentsChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorUpkeepPaymentsChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorUpkeepPaymentsChanged represents a UpkeepPaymentsChanged event raised by the SuperGovernor contract.
type SuperGovernorUpkeepPaymentsChanged struct {
	Enabled bool
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUpkeepPaymentsChanged is a free log retrieval operation binding the contract event 0x434397fd19989030741a6dd038e45b209af876fb83cafbd750fc5ad51be91ce9.
//
// Solidity: event UpkeepPaymentsChanged(bool enabled)
func (_SuperGovernor *SuperGovernorFilterer) FilterUpkeepPaymentsChanged(opts *bind.FilterOpts) (*SuperGovernorUpkeepPaymentsChangedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "UpkeepPaymentsChanged")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorUpkeepPaymentsChangedIterator{contract: _SuperGovernor.contract, event: "UpkeepPaymentsChanged", logs: logs, sub: sub}, nil
}

// WatchUpkeepPaymentsChanged is a free log subscription operation binding the contract event 0x434397fd19989030741a6dd038e45b209af876fb83cafbd750fc5ad51be91ce9.
//
// Solidity: event UpkeepPaymentsChanged(bool enabled)
func (_SuperGovernor *SuperGovernorFilterer) WatchUpkeepPaymentsChanged(opts *bind.WatchOpts, sink chan<- *SuperGovernorUpkeepPaymentsChanged) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "UpkeepPaymentsChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorUpkeepPaymentsChanged)
				if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepPaymentsChanged", log); err != nil {
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

// ParseUpkeepPaymentsChanged is a log parse operation binding the contract event 0x434397fd19989030741a6dd038e45b209af876fb83cafbd750fc5ad51be91ce9.
//
// Solidity: event UpkeepPaymentsChanged(bool enabled)
func (_SuperGovernor *SuperGovernorFilterer) ParseUpkeepPaymentsChanged(log types.Log) (*SuperGovernorUpkeepPaymentsChanged, error) {
	event := new(SuperGovernorUpkeepPaymentsChanged)
	if err := _SuperGovernor.contract.UnpackLog(event, "UpkeepPaymentsChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorValidatorAddedIterator is returned from FilterValidatorAdded and is used to iterate over the raw logs and unpacked data for ValidatorAdded events raised by the SuperGovernor contract.
type SuperGovernorValidatorAddedIterator struct {
	Event *SuperGovernorValidatorAdded // Event containing the contract specifics and raw log

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
func (it *SuperGovernorValidatorAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorValidatorAdded)
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
		it.Event = new(SuperGovernorValidatorAdded)
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
func (it *SuperGovernorValidatorAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorValidatorAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorValidatorAdded represents a ValidatorAdded event raised by the SuperGovernor contract.
type SuperGovernorValidatorAdded struct {
	Validator common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterValidatorAdded is a free log retrieval operation binding the contract event 0xe366c1c0452ed8eec96861e9e54141ebff23c9ec89fe27b996b45f5ec3884987.
//
// Solidity: event ValidatorAdded(address indexed validator)
func (_SuperGovernor *SuperGovernorFilterer) FilterValidatorAdded(opts *bind.FilterOpts, validator []common.Address) (*SuperGovernorValidatorAddedIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ValidatorAdded", validatorRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorValidatorAddedIterator{contract: _SuperGovernor.contract, event: "ValidatorAdded", logs: logs, sub: sub}, nil
}

// WatchValidatorAdded is a free log subscription operation binding the contract event 0xe366c1c0452ed8eec96861e9e54141ebff23c9ec89fe27b996b45f5ec3884987.
//
// Solidity: event ValidatorAdded(address indexed validator)
func (_SuperGovernor *SuperGovernorFilterer) WatchValidatorAdded(opts *bind.WatchOpts, sink chan<- *SuperGovernorValidatorAdded, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ValidatorAdded", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorValidatorAdded)
				if err := _SuperGovernor.contract.UnpackLog(event, "ValidatorAdded", log); err != nil {
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

// ParseValidatorAdded is a log parse operation binding the contract event 0xe366c1c0452ed8eec96861e9e54141ebff23c9ec89fe27b996b45f5ec3884987.
//
// Solidity: event ValidatorAdded(address indexed validator)
func (_SuperGovernor *SuperGovernorFilterer) ParseValidatorAdded(log types.Log) (*SuperGovernorValidatorAdded, error) {
	event := new(SuperGovernorValidatorAdded)
	if err := _SuperGovernor.contract.UnpackLog(event, "ValidatorAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorValidatorRemovedIterator is returned from FilterValidatorRemoved and is used to iterate over the raw logs and unpacked data for ValidatorRemoved events raised by the SuperGovernor contract.
type SuperGovernorValidatorRemovedIterator struct {
	Event *SuperGovernorValidatorRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorValidatorRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorValidatorRemoved)
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
		it.Event = new(SuperGovernorValidatorRemoved)
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
func (it *SuperGovernorValidatorRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorValidatorRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorValidatorRemoved represents a ValidatorRemoved event raised by the SuperGovernor contract.
type SuperGovernorValidatorRemoved struct {
	Validator common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterValidatorRemoved is a free log retrieval operation binding the contract event 0xe1434e25d6611e0db941968fdc97811c982ac1602e951637d206f5fdda9dd8f1.
//
// Solidity: event ValidatorRemoved(address indexed validator)
func (_SuperGovernor *SuperGovernorFilterer) FilterValidatorRemoved(opts *bind.FilterOpts, validator []common.Address) (*SuperGovernorValidatorRemovedIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "ValidatorRemoved", validatorRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorValidatorRemovedIterator{contract: _SuperGovernor.contract, event: "ValidatorRemoved", logs: logs, sub: sub}, nil
}

// WatchValidatorRemoved is a free log subscription operation binding the contract event 0xe1434e25d6611e0db941968fdc97811c982ac1602e951637d206f5fdda9dd8f1.
//
// Solidity: event ValidatorRemoved(address indexed validator)
func (_SuperGovernor *SuperGovernorFilterer) WatchValidatorRemoved(opts *bind.WatchOpts, sink chan<- *SuperGovernorValidatorRemoved, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "ValidatorRemoved", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorValidatorRemoved)
				if err := _SuperGovernor.contract.UnpackLog(event, "ValidatorRemoved", log); err != nil {
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

// ParseValidatorRemoved is a log parse operation binding the contract event 0xe1434e25d6611e0db941968fdc97811c982ac1602e951637d206f5fdda9dd8f1.
//
// Solidity: event ValidatorRemoved(address indexed validator)
func (_SuperGovernor *SuperGovernorFilterer) ParseValidatorRemoved(log types.Log) (*SuperGovernorValidatorRemoved, error) {
	event := new(SuperGovernorValidatorRemoved)
	if err := _SuperGovernor.contract.UnpackLog(event, "ValidatorRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorVaultBankAddressAddedIterator is returned from FilterVaultBankAddressAdded and is used to iterate over the raw logs and unpacked data for VaultBankAddressAdded events raised by the SuperGovernor contract.
type SuperGovernorVaultBankAddressAddedIterator struct {
	Event *SuperGovernorVaultBankAddressAdded // Event containing the contract specifics and raw log

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
func (it *SuperGovernorVaultBankAddressAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorVaultBankAddressAdded)
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
		it.Event = new(SuperGovernorVaultBankAddressAdded)
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
func (it *SuperGovernorVaultBankAddressAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorVaultBankAddressAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorVaultBankAddressAdded represents a VaultBankAddressAdded event raised by the SuperGovernor contract.
type SuperGovernorVaultBankAddressAdded struct {
	ChainId   uint64
	VaultBank common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterVaultBankAddressAdded is a free log retrieval operation binding the contract event 0x5cb45d0d54e4695b28909810784917d1e30ad097489dc83bfc62abac3097f169.
//
// Solidity: event VaultBankAddressAdded(uint64 indexed chainId, address indexed vaultBank)
func (_SuperGovernor *SuperGovernorFilterer) FilterVaultBankAddressAdded(opts *bind.FilterOpts, chainId []uint64, vaultBank []common.Address) (*SuperGovernorVaultBankAddressAddedIterator, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var vaultBankRule []interface{}
	for _, vaultBankItem := range vaultBank {
		vaultBankRule = append(vaultBankRule, vaultBankItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "VaultBankAddressAdded", chainIdRule, vaultBankRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorVaultBankAddressAddedIterator{contract: _SuperGovernor.contract, event: "VaultBankAddressAdded", logs: logs, sub: sub}, nil
}

// WatchVaultBankAddressAdded is a free log subscription operation binding the contract event 0x5cb45d0d54e4695b28909810784917d1e30ad097489dc83bfc62abac3097f169.
//
// Solidity: event VaultBankAddressAdded(uint64 indexed chainId, address indexed vaultBank)
func (_SuperGovernor *SuperGovernorFilterer) WatchVaultBankAddressAdded(opts *bind.WatchOpts, sink chan<- *SuperGovernorVaultBankAddressAdded, chainId []uint64, vaultBank []common.Address) (event.Subscription, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var vaultBankRule []interface{}
	for _, vaultBankItem := range vaultBank {
		vaultBankRule = append(vaultBankRule, vaultBankItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "VaultBankAddressAdded", chainIdRule, vaultBankRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorVaultBankAddressAdded)
				if err := _SuperGovernor.contract.UnpackLog(event, "VaultBankAddressAdded", log); err != nil {
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

// ParseVaultBankAddressAdded is a log parse operation binding the contract event 0x5cb45d0d54e4695b28909810784917d1e30ad097489dc83bfc62abac3097f169.
//
// Solidity: event VaultBankAddressAdded(uint64 indexed chainId, address indexed vaultBank)
func (_SuperGovernor *SuperGovernorFilterer) ParseVaultBankAddressAdded(log types.Log) (*SuperGovernorVaultBankAddressAdded, error) {
	event := new(SuperGovernorVaultBankAddressAdded)
	if err := _SuperGovernor.contract.UnpackLog(event, "VaultBankAddressAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorVaultBankHookMerkleRootProposedIterator is returned from FilterVaultBankHookMerkleRootProposed and is used to iterate over the raw logs and unpacked data for VaultBankHookMerkleRootProposed events raised by the SuperGovernor contract.
type SuperGovernorVaultBankHookMerkleRootProposedIterator struct {
	Event *SuperGovernorVaultBankHookMerkleRootProposed // Event containing the contract specifics and raw log

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
func (it *SuperGovernorVaultBankHookMerkleRootProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorVaultBankHookMerkleRootProposed)
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
		it.Event = new(SuperGovernorVaultBankHookMerkleRootProposed)
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
func (it *SuperGovernorVaultBankHookMerkleRootProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorVaultBankHookMerkleRootProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorVaultBankHookMerkleRootProposed represents a VaultBankHookMerkleRootProposed event raised by the SuperGovernor contract.
type SuperGovernorVaultBankHookMerkleRootProposed struct {
	Hook          common.Address
	NewRoot       [32]byte
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterVaultBankHookMerkleRootProposed is a free log retrieval operation binding the contract event 0xfed894aa6018dfdc5cdaaa43cc8ab59cadae93a82571bdcf49f5219065a366dd.
//
// Solidity: event VaultBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) FilterVaultBankHookMerkleRootProposed(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorVaultBankHookMerkleRootProposedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "VaultBankHookMerkleRootProposed", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorVaultBankHookMerkleRootProposedIterator{contract: _SuperGovernor.contract, event: "VaultBankHookMerkleRootProposed", logs: logs, sub: sub}, nil
}

// WatchVaultBankHookMerkleRootProposed is a free log subscription operation binding the contract event 0xfed894aa6018dfdc5cdaaa43cc8ab59cadae93a82571bdcf49f5219065a366dd.
//
// Solidity: event VaultBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) WatchVaultBankHookMerkleRootProposed(opts *bind.WatchOpts, sink chan<- *SuperGovernorVaultBankHookMerkleRootProposed, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "VaultBankHookMerkleRootProposed", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorVaultBankHookMerkleRootProposed)
				if err := _SuperGovernor.contract.UnpackLog(event, "VaultBankHookMerkleRootProposed", log); err != nil {
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

// ParseVaultBankHookMerkleRootProposed is a log parse operation binding the contract event 0xfed894aa6018dfdc5cdaaa43cc8ab59cadae93a82571bdcf49f5219065a366dd.
//
// Solidity: event VaultBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) ParseVaultBankHookMerkleRootProposed(log types.Log) (*SuperGovernorVaultBankHookMerkleRootProposed, error) {
	event := new(SuperGovernorVaultBankHookMerkleRootProposed)
	if err := _SuperGovernor.contract.UnpackLog(event, "VaultBankHookMerkleRootProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorVaultBankHookMerkleRootUpdatedIterator is returned from FilterVaultBankHookMerkleRootUpdated and is used to iterate over the raw logs and unpacked data for VaultBankHookMerkleRootUpdated events raised by the SuperGovernor contract.
type SuperGovernorVaultBankHookMerkleRootUpdatedIterator struct {
	Event *SuperGovernorVaultBankHookMerkleRootUpdated // Event containing the contract specifics and raw log

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
func (it *SuperGovernorVaultBankHookMerkleRootUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorVaultBankHookMerkleRootUpdated)
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
		it.Event = new(SuperGovernorVaultBankHookMerkleRootUpdated)
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
func (it *SuperGovernorVaultBankHookMerkleRootUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorVaultBankHookMerkleRootUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorVaultBankHookMerkleRootUpdated represents a VaultBankHookMerkleRootUpdated event raised by the SuperGovernor contract.
type SuperGovernorVaultBankHookMerkleRootUpdated struct {
	Hook    common.Address
	NewRoot [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterVaultBankHookMerkleRootUpdated is a free log retrieval operation binding the contract event 0x86b54825d63e1f082661065387182da51e6eb5a1ae1e63e1b0fd8a99aaf7e11f.
//
// Solidity: event VaultBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot)
func (_SuperGovernor *SuperGovernorFilterer) FilterVaultBankHookMerkleRootUpdated(opts *bind.FilterOpts, hook []common.Address) (*SuperGovernorVaultBankHookMerkleRootUpdatedIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "VaultBankHookMerkleRootUpdated", hookRule)
	if err != nil {
		return nil, err
	}
	return &SuperGovernorVaultBankHookMerkleRootUpdatedIterator{contract: _SuperGovernor.contract, event: "VaultBankHookMerkleRootUpdated", logs: logs, sub: sub}, nil
}

// WatchVaultBankHookMerkleRootUpdated is a free log subscription operation binding the contract event 0x86b54825d63e1f082661065387182da51e6eb5a1ae1e63e1b0fd8a99aaf7e11f.
//
// Solidity: event VaultBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot)
func (_SuperGovernor *SuperGovernorFilterer) WatchVaultBankHookMerkleRootUpdated(opts *bind.WatchOpts, sink chan<- *SuperGovernorVaultBankHookMerkleRootUpdated, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "VaultBankHookMerkleRootUpdated", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorVaultBankHookMerkleRootUpdated)
				if err := _SuperGovernor.contract.UnpackLog(event, "VaultBankHookMerkleRootUpdated", log); err != nil {
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

// ParseVaultBankHookMerkleRootUpdated is a log parse operation binding the contract event 0x86b54825d63e1f082661065387182da51e6eb5a1ae1e63e1b0fd8a99aaf7e11f.
//
// Solidity: event VaultBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot)
func (_SuperGovernor *SuperGovernorFilterer) ParseVaultBankHookMerkleRootUpdated(log types.Log) (*SuperGovernorVaultBankHookMerkleRootUpdated, error) {
	event := new(SuperGovernorVaultBankHookMerkleRootUpdated)
	if err := _SuperGovernor.contract.UnpackLog(event, "VaultBankHookMerkleRootUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorWhitelistedIncentiveTokensAddedIterator is returned from FilterWhitelistedIncentiveTokensAdded and is used to iterate over the raw logs and unpacked data for WhitelistedIncentiveTokensAdded events raised by the SuperGovernor contract.
type SuperGovernorWhitelistedIncentiveTokensAddedIterator struct {
	Event *SuperGovernorWhitelistedIncentiveTokensAdded // Event containing the contract specifics and raw log

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
func (it *SuperGovernorWhitelistedIncentiveTokensAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorWhitelistedIncentiveTokensAdded)
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
		it.Event = new(SuperGovernorWhitelistedIncentiveTokensAdded)
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
func (it *SuperGovernorWhitelistedIncentiveTokensAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorWhitelistedIncentiveTokensAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorWhitelistedIncentiveTokensAdded represents a WhitelistedIncentiveTokensAdded event raised by the SuperGovernor contract.
type SuperGovernorWhitelistedIncentiveTokensAdded struct {
	Tokens []common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterWhitelistedIncentiveTokensAdded is a free log retrieval operation binding the contract event 0xfcea9a0a0943a560b6065073054ea3e19aa43e137d7e753876775ad1179847c6.
//
// Solidity: event WhitelistedIncentiveTokensAdded(address[] tokens)
func (_SuperGovernor *SuperGovernorFilterer) FilterWhitelistedIncentiveTokensAdded(opts *bind.FilterOpts) (*SuperGovernorWhitelistedIncentiveTokensAddedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "WhitelistedIncentiveTokensAdded")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorWhitelistedIncentiveTokensAddedIterator{contract: _SuperGovernor.contract, event: "WhitelistedIncentiveTokensAdded", logs: logs, sub: sub}, nil
}

// WatchWhitelistedIncentiveTokensAdded is a free log subscription operation binding the contract event 0xfcea9a0a0943a560b6065073054ea3e19aa43e137d7e753876775ad1179847c6.
//
// Solidity: event WhitelistedIncentiveTokensAdded(address[] tokens)
func (_SuperGovernor *SuperGovernorFilterer) WatchWhitelistedIncentiveTokensAdded(opts *bind.WatchOpts, sink chan<- *SuperGovernorWhitelistedIncentiveTokensAdded) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "WhitelistedIncentiveTokensAdded")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorWhitelistedIncentiveTokensAdded)
				if err := _SuperGovernor.contract.UnpackLog(event, "WhitelistedIncentiveTokensAdded", log); err != nil {
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

// ParseWhitelistedIncentiveTokensAdded is a log parse operation binding the contract event 0xfcea9a0a0943a560b6065073054ea3e19aa43e137d7e753876775ad1179847c6.
//
// Solidity: event WhitelistedIncentiveTokensAdded(address[] tokens)
func (_SuperGovernor *SuperGovernorFilterer) ParseWhitelistedIncentiveTokensAdded(log types.Log) (*SuperGovernorWhitelistedIncentiveTokensAdded, error) {
	event := new(SuperGovernorWhitelistedIncentiveTokensAdded)
	if err := _SuperGovernor.contract.UnpackLog(event, "WhitelistedIncentiveTokensAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorWhitelistedIncentiveTokensProposedIterator is returned from FilterWhitelistedIncentiveTokensProposed and is used to iterate over the raw logs and unpacked data for WhitelistedIncentiveTokensProposed events raised by the SuperGovernor contract.
type SuperGovernorWhitelistedIncentiveTokensProposedIterator struct {
	Event *SuperGovernorWhitelistedIncentiveTokensProposed // Event containing the contract specifics and raw log

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
func (it *SuperGovernorWhitelistedIncentiveTokensProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorWhitelistedIncentiveTokensProposed)
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
		it.Event = new(SuperGovernorWhitelistedIncentiveTokensProposed)
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
func (it *SuperGovernorWhitelistedIncentiveTokensProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorWhitelistedIncentiveTokensProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorWhitelistedIncentiveTokensProposed represents a WhitelistedIncentiveTokensProposed event raised by the SuperGovernor contract.
type SuperGovernorWhitelistedIncentiveTokensProposed struct {
	Tokens        []common.Address
	EffectiveTime *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterWhitelistedIncentiveTokensProposed is a free log retrieval operation binding the contract event 0xdc25fd6bdd21f8da9b5b76d30960d45120a708e1f91ae912871da0fc21454979.
//
// Solidity: event WhitelistedIncentiveTokensProposed(address[] tokens, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) FilterWhitelistedIncentiveTokensProposed(opts *bind.FilterOpts) (*SuperGovernorWhitelistedIncentiveTokensProposedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "WhitelistedIncentiveTokensProposed")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorWhitelistedIncentiveTokensProposedIterator{contract: _SuperGovernor.contract, event: "WhitelistedIncentiveTokensProposed", logs: logs, sub: sub}, nil
}

// WatchWhitelistedIncentiveTokensProposed is a free log subscription operation binding the contract event 0xdc25fd6bdd21f8da9b5b76d30960d45120a708e1f91ae912871da0fc21454979.
//
// Solidity: event WhitelistedIncentiveTokensProposed(address[] tokens, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) WatchWhitelistedIncentiveTokensProposed(opts *bind.WatchOpts, sink chan<- *SuperGovernorWhitelistedIncentiveTokensProposed) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "WhitelistedIncentiveTokensProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorWhitelistedIncentiveTokensProposed)
				if err := _SuperGovernor.contract.UnpackLog(event, "WhitelistedIncentiveTokensProposed", log); err != nil {
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

// ParseWhitelistedIncentiveTokensProposed is a log parse operation binding the contract event 0xdc25fd6bdd21f8da9b5b76d30960d45120a708e1f91ae912871da0fc21454979.
//
// Solidity: event WhitelistedIncentiveTokensProposed(address[] tokens, uint256 effectiveTime)
func (_SuperGovernor *SuperGovernorFilterer) ParseWhitelistedIncentiveTokensProposed(log types.Log) (*SuperGovernorWhitelistedIncentiveTokensProposed, error) {
	event := new(SuperGovernorWhitelistedIncentiveTokensProposed)
	if err := _SuperGovernor.contract.UnpackLog(event, "WhitelistedIncentiveTokensProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperGovernorWhitelistedIncentiveTokensRemovedIterator is returned from FilterWhitelistedIncentiveTokensRemoved and is used to iterate over the raw logs and unpacked data for WhitelistedIncentiveTokensRemoved events raised by the SuperGovernor contract.
type SuperGovernorWhitelistedIncentiveTokensRemovedIterator struct {
	Event *SuperGovernorWhitelistedIncentiveTokensRemoved // Event containing the contract specifics and raw log

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
func (it *SuperGovernorWhitelistedIncentiveTokensRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperGovernorWhitelistedIncentiveTokensRemoved)
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
		it.Event = new(SuperGovernorWhitelistedIncentiveTokensRemoved)
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
func (it *SuperGovernorWhitelistedIncentiveTokensRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperGovernorWhitelistedIncentiveTokensRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperGovernorWhitelistedIncentiveTokensRemoved represents a WhitelistedIncentiveTokensRemoved event raised by the SuperGovernor contract.
type SuperGovernorWhitelistedIncentiveTokensRemoved struct {
	Tokens []common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterWhitelistedIncentiveTokensRemoved is a free log retrieval operation binding the contract event 0x592ccb66164159ca890f72fc24cdab8c5fcfcfe35f7455b88e594060568ce011.
//
// Solidity: event WhitelistedIncentiveTokensRemoved(address[] tokens)
func (_SuperGovernor *SuperGovernorFilterer) FilterWhitelistedIncentiveTokensRemoved(opts *bind.FilterOpts) (*SuperGovernorWhitelistedIncentiveTokensRemovedIterator, error) {

	logs, sub, err := _SuperGovernor.contract.FilterLogs(opts, "WhitelistedIncentiveTokensRemoved")
	if err != nil {
		return nil, err
	}
	return &SuperGovernorWhitelistedIncentiveTokensRemovedIterator{contract: _SuperGovernor.contract, event: "WhitelistedIncentiveTokensRemoved", logs: logs, sub: sub}, nil
}

// WatchWhitelistedIncentiveTokensRemoved is a free log subscription operation binding the contract event 0x592ccb66164159ca890f72fc24cdab8c5fcfcfe35f7455b88e594060568ce011.
//
// Solidity: event WhitelistedIncentiveTokensRemoved(address[] tokens)
func (_SuperGovernor *SuperGovernorFilterer) WatchWhitelistedIncentiveTokensRemoved(opts *bind.WatchOpts, sink chan<- *SuperGovernorWhitelistedIncentiveTokensRemoved) (event.Subscription, error) {

	logs, sub, err := _SuperGovernor.contract.WatchLogs(opts, "WhitelistedIncentiveTokensRemoved")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperGovernorWhitelistedIncentiveTokensRemoved)
				if err := _SuperGovernor.contract.UnpackLog(event, "WhitelistedIncentiveTokensRemoved", log); err != nil {
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

// ParseWhitelistedIncentiveTokensRemoved is a log parse operation binding the contract event 0x592ccb66164159ca890f72fc24cdab8c5fcfcfe35f7455b88e594060568ce011.
//
// Solidity: event WhitelistedIncentiveTokensRemoved(address[] tokens)
func (_SuperGovernor *SuperGovernorFilterer) ParseWhitelistedIncentiveTokensRemoved(log types.Log) (*SuperGovernorWhitelistedIncentiveTokensRemoved, error) {
	event := new(SuperGovernorWhitelistedIncentiveTokensRemoved)
	if err := _SuperGovernor.contract.UnpackLog(event, "WhitelistedIncentiveTokensRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
