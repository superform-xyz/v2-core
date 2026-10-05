// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package AaveV4ReserveOracle

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

// IAaveV4MarketPositionMarketPosition is an auto generated low-level Go binding around an user-defined struct.
type IAaveV4MarketPositionMarketPosition struct {
	Spoke              common.Address
	SupplyReserveId    *big.Int
	BorrowReserveId    *big.Int
	CollateralToken    common.Address
	LoanToken          common.Address
	CollateralDecimals uint8
	LoanDecimals       uint8
	SuppliedAssets     *big.Int
	DebtAssets         *big.Int
}

// IAaveV4OwnerSnapshotMarketBinding is an auto generated low-level Go binding around an user-defined struct.
type IAaveV4OwnerSnapshotMarketBinding struct {
	MarketKey       common.Address
	Spoke           common.Address
	SupplyReserveId *big.Int
	BorrowReserveId *big.Int
	SupplyKey       common.Address
	DebtKey         common.Address
}

// IAaveV4OwnerSnapshotOwnerPosition is an auto generated low-level Go binding around an user-defined struct.
type IAaveV4OwnerSnapshotOwnerPosition struct {
	SourceKey          common.Address
	Spoke              common.Address
	ReserveId          *big.Int
	Underlying         common.Address
	UnderlyingDecimals uint8
	Side               uint8
	Assets             *big.Int
	Symbol             string
}

// IAaveV4OwnerSnapshotWalletBalance is an auto generated low-level Go binding around an user-defined struct.
type IAaveV4OwnerSnapshotWalletBalance struct {
	Token    common.Address
	Decimals uint8
	Balance  *big.Int
}

// AaveV4ReserveOracleMetaData contains all meta data concerning the AaveV4ReserveOracle contract.
var AaveV4ReserveOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"REGISTRY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractAaveV4ReserveRegistryV2\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getMarketPosition\",\"inputs\":[{\"name\":\"marketKey\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"position\",\"type\":\"tuple\",\"internalType\":\"structIAaveV4MarketPosition.MarketPosition\",\"components\":[{\"name\":\"spoke\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"supplyReserveId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"borrowReserveId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"collateralToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"loanToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"collateralDecimals\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"loanDecimals\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"suppliedAssets\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"debtAssets\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOwnerSnapshot\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"marketKeys\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"configuredSpokes\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"cashTokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"vaultAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"maxReservesPerSpoke\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"markets\",\"type\":\"tuple[]\",\"internalType\":\"structIAaveV4OwnerSnapshot.MarketBinding[]\",\"components\":[{\"name\":\"marketKey\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spoke\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"supplyReserveId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"borrowReserveId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"supplyKey\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"debtKey\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"positions\",\"type\":\"tuple[]\",\"internalType\":\"structIAaveV4OwnerSnapshot.OwnerPosition[]\",\"components\":[{\"name\":\"sourceKey\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spoke\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"reserveId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"underlying\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"underlyingDecimals\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"side\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"assets\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"symbol\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"balances\",\"type\":\"tuple[]\",\"internalType\":\"structIAaveV4OwnerSnapshot.WalletBalance[]\",\"components\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"decimals\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"},{\"name\":\"succeeded\",\"type\":\"bool[][]\",\"internalType\":\"bool[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"sideOf\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"side\",\"type\":\"uint8\",\"internalType\":\"enumAaveV4ReserveRegistryV2.Side\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SNAPSHOT_DECIMALS_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SNAPSHOT_RESERVE_LIMIT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UNHANDLED_SIDE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// AaveV4ReserveOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use AaveV4ReserveOracleMetaData.ABI instead.
var AaveV4ReserveOracleABI = AaveV4ReserveOracleMetaData.ABI

// AaveV4ReserveOracle is an auto generated Go binding around an Ethereum contract.
type AaveV4ReserveOracle struct {
	AaveV4ReserveOracleCaller     // Read-only binding to the contract
	AaveV4ReserveOracleTransactor // Write-only binding to the contract
	AaveV4ReserveOracleFilterer   // Log filterer for contract events
}

// AaveV4ReserveOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type AaveV4ReserveOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AaveV4ReserveOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AaveV4ReserveOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AaveV4ReserveOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AaveV4ReserveOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AaveV4ReserveOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AaveV4ReserveOracleSession struct {
	Contract     *AaveV4ReserveOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts        // Call options to use throughout this session
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// AaveV4ReserveOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AaveV4ReserveOracleCallerSession struct {
	Contract *AaveV4ReserveOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts              // Call options to use throughout this session
}

// AaveV4ReserveOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AaveV4ReserveOracleTransactorSession struct {
	Contract     *AaveV4ReserveOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// AaveV4ReserveOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type AaveV4ReserveOracleRaw struct {
	Contract *AaveV4ReserveOracle // Generic contract binding to access the raw methods on
}

// AaveV4ReserveOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AaveV4ReserveOracleCallerRaw struct {
	Contract *AaveV4ReserveOracleCaller // Generic read-only contract binding to access the raw methods on
}

// AaveV4ReserveOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AaveV4ReserveOracleTransactorRaw struct {
	Contract *AaveV4ReserveOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAaveV4ReserveOracle creates a new instance of AaveV4ReserveOracle, bound to a specific deployed contract.
func NewAaveV4ReserveOracle(address common.Address, backend bind.ContractBackend) (*AaveV4ReserveOracle, error) {
	contract, err := bindAaveV4ReserveOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AaveV4ReserveOracle{AaveV4ReserveOracleCaller: AaveV4ReserveOracleCaller{contract: contract}, AaveV4ReserveOracleTransactor: AaveV4ReserveOracleTransactor{contract: contract}, AaveV4ReserveOracleFilterer: AaveV4ReserveOracleFilterer{contract: contract}}, nil
}

// NewAaveV4ReserveOracleCaller creates a new read-only instance of AaveV4ReserveOracle, bound to a specific deployed contract.
func NewAaveV4ReserveOracleCaller(address common.Address, caller bind.ContractCaller) (*AaveV4ReserveOracleCaller, error) {
	contract, err := bindAaveV4ReserveOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AaveV4ReserveOracleCaller{contract: contract}, nil
}

// NewAaveV4ReserveOracleTransactor creates a new write-only instance of AaveV4ReserveOracle, bound to a specific deployed contract.
func NewAaveV4ReserveOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*AaveV4ReserveOracleTransactor, error) {
	contract, err := bindAaveV4ReserveOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AaveV4ReserveOracleTransactor{contract: contract}, nil
}

// NewAaveV4ReserveOracleFilterer creates a new log filterer instance of AaveV4ReserveOracle, bound to a specific deployed contract.
func NewAaveV4ReserveOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*AaveV4ReserveOracleFilterer, error) {
	contract, err := bindAaveV4ReserveOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AaveV4ReserveOracleFilterer{contract: contract}, nil
}

// bindAaveV4ReserveOracle binds a generic wrapper to an already deployed contract.
func bindAaveV4ReserveOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AaveV4ReserveOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AaveV4ReserveOracle *AaveV4ReserveOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AaveV4ReserveOracle.Contract.AaveV4ReserveOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AaveV4ReserveOracle *AaveV4ReserveOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AaveV4ReserveOracle.Contract.AaveV4ReserveOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AaveV4ReserveOracle *AaveV4ReserveOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AaveV4ReserveOracle.Contract.AaveV4ReserveOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AaveV4ReserveOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AaveV4ReserveOracle *AaveV4ReserveOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AaveV4ReserveOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AaveV4ReserveOracle *AaveV4ReserveOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AaveV4ReserveOracle.Contract.contract.Transact(opts, method, params...)
}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) REGISTRY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "REGISTRY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) REGISTRY() (common.Address, error) {
	return _AaveV4ReserveOracle.Contract.REGISTRY(&_AaveV4ReserveOracle.CallOpts)
}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) REGISTRY() (common.Address, error) {
	return _AaveV4ReserveOracle.Contract.REGISTRY(&_AaveV4ReserveOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _AaveV4ReserveOracle.Contract.SUPERLEDGERCONFIGURATION(&_AaveV4ReserveOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _AaveV4ReserveOracle.Contract.SUPERLEDGERCONFIGURATION(&_AaveV4ReserveOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) Decimals(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "decimals", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _AaveV4ReserveOracle.Contract.Decimals(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address yieldSourceAddress) view returns(uint8)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) Decimals(yieldSourceAddress common.Address) (uint8, error) {
	return _AaveV4ReserveOracle.Contract.Decimals(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetAssetOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getAssetOutput", arg0, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetAssetOutput(&_AaveV4ReserveOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address , address , uint256 sharesIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetAssetOutput(arg0 common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetAssetOutput(&_AaveV4ReserveOracle.CallOpts, arg0, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getAssetOutputWithFees", arg0, yieldSourceAddress, assetOut, arg3, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetAssetOutputWithFees(arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetAssetOutputWithFees(&_AaveV4ReserveOracle.CallOpts, arg0, yieldSourceAddress, assetOut, arg3, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 , address yieldSourceAddress, address assetOut, address , uint256 usedShares) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetAssetOutputWithFees(arg0 [32]byte, yieldSourceAddress common.Address, assetOut common.Address, arg3 common.Address, usedShares *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetAssetOutputWithFees(&_AaveV4ReserveOracle.CallOpts, arg0, yieldSourceAddress, assetOut, arg3, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetBalanceOfOwner(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetBalanceOfOwner(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetMarketPosition is a free data retrieval call binding the contract method 0x0fc97256.
//
// Solidity: function getMarketPosition(address marketKey, address owner) view returns((address,uint256,uint256,address,address,uint8,uint8,uint256,uint256) position)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetMarketPosition(opts *bind.CallOpts, marketKey common.Address, owner common.Address) (IAaveV4MarketPositionMarketPosition, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getMarketPosition", marketKey, owner)

	if err != nil {
		return *new(IAaveV4MarketPositionMarketPosition), err
	}

	out0 := *abi.ConvertType(out[0], new(IAaveV4MarketPositionMarketPosition)).(*IAaveV4MarketPositionMarketPosition)

	return out0, err

}

// GetMarketPosition is a free data retrieval call binding the contract method 0x0fc97256.
//
// Solidity: function getMarketPosition(address marketKey, address owner) view returns((address,uint256,uint256,address,address,uint8,uint8,uint256,uint256) position)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetMarketPosition(marketKey common.Address, owner common.Address) (IAaveV4MarketPositionMarketPosition, error) {
	return _AaveV4ReserveOracle.Contract.GetMarketPosition(&_AaveV4ReserveOracle.CallOpts, marketKey, owner)
}

// GetMarketPosition is a free data retrieval call binding the contract method 0x0fc97256.
//
// Solidity: function getMarketPosition(address marketKey, address owner) view returns((address,uint256,uint256,address,address,uint8,uint8,uint256,uint256) position)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetMarketPosition(marketKey common.Address, owner common.Address) (IAaveV4MarketPositionMarketPosition, error) {
	return _AaveV4ReserveOracle.Contract.GetMarketPosition(&_AaveV4ReserveOracle.CallOpts, marketKey, owner)
}

// GetOwnerSnapshot is a free data retrieval call binding the contract method 0x808efc81.
//
// Solidity: function getOwnerSnapshot(address owner, address[] marketKeys, address[] configuredSpokes, address[] cashTokens, address vaultAsset, uint256 maxReservesPerSpoke) view returns((address,address,uint256,uint256,address,address)[] markets, (address,address,uint256,address,uint8,uint8,uint256,string)[] positions, (address,uint8,uint256)[] balances)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetOwnerSnapshot(opts *bind.CallOpts, owner common.Address, marketKeys []common.Address, configuredSpokes []common.Address, cashTokens []common.Address, vaultAsset common.Address, maxReservesPerSpoke *big.Int) (struct {
	Markets   []IAaveV4OwnerSnapshotMarketBinding
	Positions []IAaveV4OwnerSnapshotOwnerPosition
	Balances  []IAaveV4OwnerSnapshotWalletBalance
}, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getOwnerSnapshot", owner, marketKeys, configuredSpokes, cashTokens, vaultAsset, maxReservesPerSpoke)

	outstruct := new(struct {
		Markets   []IAaveV4OwnerSnapshotMarketBinding
		Positions []IAaveV4OwnerSnapshotOwnerPosition
		Balances  []IAaveV4OwnerSnapshotWalletBalance
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Markets = *abi.ConvertType(out[0], new([]IAaveV4OwnerSnapshotMarketBinding)).(*[]IAaveV4OwnerSnapshotMarketBinding)
	outstruct.Positions = *abi.ConvertType(out[1], new([]IAaveV4OwnerSnapshotOwnerPosition)).(*[]IAaveV4OwnerSnapshotOwnerPosition)
	outstruct.Balances = *abi.ConvertType(out[2], new([]IAaveV4OwnerSnapshotWalletBalance)).(*[]IAaveV4OwnerSnapshotWalletBalance)

	return *outstruct, err

}

// GetOwnerSnapshot is a free data retrieval call binding the contract method 0x808efc81.
//
// Solidity: function getOwnerSnapshot(address owner, address[] marketKeys, address[] configuredSpokes, address[] cashTokens, address vaultAsset, uint256 maxReservesPerSpoke) view returns((address,address,uint256,uint256,address,address)[] markets, (address,address,uint256,address,uint8,uint8,uint256,string)[] positions, (address,uint8,uint256)[] balances)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetOwnerSnapshot(owner common.Address, marketKeys []common.Address, configuredSpokes []common.Address, cashTokens []common.Address, vaultAsset common.Address, maxReservesPerSpoke *big.Int) (struct {
	Markets   []IAaveV4OwnerSnapshotMarketBinding
	Positions []IAaveV4OwnerSnapshotOwnerPosition
	Balances  []IAaveV4OwnerSnapshotWalletBalance
}, error) {
	return _AaveV4ReserveOracle.Contract.GetOwnerSnapshot(&_AaveV4ReserveOracle.CallOpts, owner, marketKeys, configuredSpokes, cashTokens, vaultAsset, maxReservesPerSpoke)
}

// GetOwnerSnapshot is a free data retrieval call binding the contract method 0x808efc81.
//
// Solidity: function getOwnerSnapshot(address owner, address[] marketKeys, address[] configuredSpokes, address[] cashTokens, address vaultAsset, uint256 maxReservesPerSpoke) view returns((address,address,uint256,uint256,address,address)[] markets, (address,address,uint256,address,uint8,uint8,uint256,string)[] positions, (address,uint8,uint256)[] balances)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetOwnerSnapshot(owner common.Address, marketKeys []common.Address, configuredSpokes []common.Address, cashTokens []common.Address, vaultAsset common.Address, maxReservesPerSpoke *big.Int) (struct {
	Markets   []IAaveV4OwnerSnapshotMarketBinding
	Positions []IAaveV4OwnerSnapshotOwnerPosition
	Balances  []IAaveV4OwnerSnapshotWalletBalance
}, error) {
	return _AaveV4ReserveOracle.Contract.GetOwnerSnapshot(&_AaveV4ReserveOracle.CallOpts, owner, marketKeys, configuredSpokes, cashTokens, vaultAsset, maxReservesPerSpoke)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetPricePerShare(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetPricePerShare(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetPricePerShareMultiple(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetPricePerShareMultiple(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetShareOutput(&_AaveV4ReserveOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetShareOutput(&_AaveV4ReserveOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetTVL(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetTVL(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetTVLByOwnerOfShares(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetTVLByOwnerOfShares(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	outstruct := new(struct {
		UserTvls  [][]*big.Int
		Succeeded [][]bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.UserTvls = *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)
	outstruct.Succeeded = *abi.ConvertType(out[1], new([][]bool)).(*[][]bool)

	return *outstruct, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _AaveV4ReserveOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _AaveV4ReserveOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetTVLMultiple(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetTVLMultiple(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", arg0, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) GetWithdrawalShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetWithdrawalShareOutput(&_AaveV4ReserveOracle.CallOpts, arg0, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address , address , uint256 assetsIn) pure returns(uint256)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) GetWithdrawalShareOutput(arg0 common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _AaveV4ReserveOracle.Contract.GetWithdrawalShareOutput(&_AaveV4ReserveOracle.CallOpts, arg0, arg1, assetsIn)
}

// SideOf is a free data retrieval call binding the contract method 0xdc61fddb.
//
// Solidity: function sideOf(address yieldSourceAddress) view returns(uint8 side)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCaller) SideOf(opts *bind.CallOpts, yieldSourceAddress common.Address) (uint8, error) {
	var out []interface{}
	err := _AaveV4ReserveOracle.contract.Call(opts, &out, "sideOf", yieldSourceAddress)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// SideOf is a free data retrieval call binding the contract method 0xdc61fddb.
//
// Solidity: function sideOf(address yieldSourceAddress) view returns(uint8 side)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleSession) SideOf(yieldSourceAddress common.Address) (uint8, error) {
	return _AaveV4ReserveOracle.Contract.SideOf(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}

// SideOf is a free data retrieval call binding the contract method 0xdc61fddb.
//
// Solidity: function sideOf(address yieldSourceAddress) view returns(uint8 side)
func (_AaveV4ReserveOracle *AaveV4ReserveOracleCallerSession) SideOf(yieldSourceAddress common.Address) (uint8, error) {
	return _AaveV4ReserveOracle.Contract.SideOf(&_AaveV4ReserveOracle.CallOpts, yieldSourceAddress)
}
