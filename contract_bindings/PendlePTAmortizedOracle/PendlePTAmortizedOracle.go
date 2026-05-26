// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package PendlePTAmortizedOracle

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

// PendlePTAmortizedOracleMetaData contains all meta data concerning the PendlePTAmortizedOracle contract.
var PendlePTAmortizedOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"admin\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"DEFAULT_ADMIN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MANAGER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TWAP_DURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"bookValues\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"lastUpdateBookValue\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"lastUpdateTime\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"correctBookValue\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newBookValue\",\"type\":\"uint128\",\"internalType\":\"uint128\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"deletePosition\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"assetsOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBookValue\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"bookValue\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"price\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRoleAdmin\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"sharesOut\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"tvl\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"grantRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"hasPosition\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"exists\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hasRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"recordPurchase\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sySpent\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ptAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"recordRedemption\",\"inputs\":[{\"name\":\"market\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ptSold\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"callerConfirmation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"revokeRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"supportsInterface\",\"inputs\":[{\"name\":\"interfaceId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"BookValueCorrected\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oldBookValue\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"newBookValue\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"correctedBy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BookValueUpdated\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newBookValue\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"timestamp\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PurchaseRecorded\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sySpent\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"ptAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RedemptionRecorded\",\"inputs\":[{\"name\":\"strategy\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"market\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"ptSold\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleAdminChanged\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"previousAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleGranted\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleRevoked\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AccessControlBadConfirmation\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AccessControlUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"neededRole\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"BOOK_VALUE_EXCEEDS_FACE_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_POSITION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MARKET_EXPIRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_POSITION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeCastOverflowedUintDowncast\",\"inputs\":[{\"name\":\"bits\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_AMOUNT\",\"inputs\":[]}]",
}

// PendlePTAmortizedOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use PendlePTAmortizedOracleMetaData.ABI instead.
var PendlePTAmortizedOracleABI = PendlePTAmortizedOracleMetaData.ABI

// PendlePTAmortizedOracle is an auto generated Go binding around an Ethereum contract.
type PendlePTAmortizedOracle struct {
	PendlePTAmortizedOracleCaller     // Read-only binding to the contract
	PendlePTAmortizedOracleTransactor // Write-only binding to the contract
	PendlePTAmortizedOracleFilterer   // Log filterer for contract events
}

// PendlePTAmortizedOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type PendlePTAmortizedOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PendlePTAmortizedOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type PendlePTAmortizedOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PendlePTAmortizedOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type PendlePTAmortizedOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PendlePTAmortizedOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type PendlePTAmortizedOracleSession struct {
	Contract     *PendlePTAmortizedOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts            // Call options to use throughout this session
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// PendlePTAmortizedOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type PendlePTAmortizedOracleCallerSession struct {
	Contract *PendlePTAmortizedOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                  // Call options to use throughout this session
}

// PendlePTAmortizedOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type PendlePTAmortizedOracleTransactorSession struct {
	Contract     *PendlePTAmortizedOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                  // Transaction auth options to use throughout this session
}

// PendlePTAmortizedOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type PendlePTAmortizedOracleRaw struct {
	Contract *PendlePTAmortizedOracle // Generic contract binding to access the raw methods on
}

// PendlePTAmortizedOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type PendlePTAmortizedOracleCallerRaw struct {
	Contract *PendlePTAmortizedOracleCaller // Generic read-only contract binding to access the raw methods on
}

// PendlePTAmortizedOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type PendlePTAmortizedOracleTransactorRaw struct {
	Contract *PendlePTAmortizedOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewPendlePTAmortizedOracle creates a new instance of PendlePTAmortizedOracle, bound to a specific deployed contract.
func NewPendlePTAmortizedOracle(address common.Address, backend bind.ContractBackend) (*PendlePTAmortizedOracle, error) {
	contract, err := bindPendlePTAmortizedOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracle{PendlePTAmortizedOracleCaller: PendlePTAmortizedOracleCaller{contract: contract}, PendlePTAmortizedOracleTransactor: PendlePTAmortizedOracleTransactor{contract: contract}, PendlePTAmortizedOracleFilterer: PendlePTAmortizedOracleFilterer{contract: contract}}, nil
}

// NewPendlePTAmortizedOracleCaller creates a new read-only instance of PendlePTAmortizedOracle, bound to a specific deployed contract.
func NewPendlePTAmortizedOracleCaller(address common.Address, caller bind.ContractCaller) (*PendlePTAmortizedOracleCaller, error) {
	contract, err := bindPendlePTAmortizedOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleCaller{contract: contract}, nil
}

// NewPendlePTAmortizedOracleTransactor creates a new write-only instance of PendlePTAmortizedOracle, bound to a specific deployed contract.
func NewPendlePTAmortizedOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*PendlePTAmortizedOracleTransactor, error) {
	contract, err := bindPendlePTAmortizedOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleTransactor{contract: contract}, nil
}

// NewPendlePTAmortizedOracleFilterer creates a new log filterer instance of PendlePTAmortizedOracle, bound to a specific deployed contract.
func NewPendlePTAmortizedOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*PendlePTAmortizedOracleFilterer, error) {
	contract, err := bindPendlePTAmortizedOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleFilterer{contract: contract}, nil
}

// bindPendlePTAmortizedOracle binds a generic wrapper to an already deployed contract.
func bindPendlePTAmortizedOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := PendlePTAmortizedOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PendlePTAmortizedOracle.Contract.PendlePTAmortizedOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.PendlePTAmortizedOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.PendlePTAmortizedOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PendlePTAmortizedOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.contract.Transact(opts, method, params...)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) DEFAULTADMINROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "DEFAULT_ADMIN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _PendlePTAmortizedOracle.Contract.DEFAULTADMINROLE(&_PendlePTAmortizedOracle.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _PendlePTAmortizedOracle.Contract.DEFAULTADMINROLE(&_PendlePTAmortizedOracle.CallOpts)
}

// MANAGERROLE is a free data retrieval call binding the contract method 0xec87621c.
//
// Solidity: function MANAGER_ROLE() view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) MANAGERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "MANAGER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// MANAGERROLE is a free data retrieval call binding the contract method 0xec87621c.
//
// Solidity: function MANAGER_ROLE() view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) MANAGERROLE() ([32]byte, error) {
	return _PendlePTAmortizedOracle.Contract.MANAGERROLE(&_PendlePTAmortizedOracle.CallOpts)
}

// MANAGERROLE is a free data retrieval call binding the contract method 0xec87621c.
//
// Solidity: function MANAGER_ROLE() view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) MANAGERROLE() ([32]byte, error) {
	return _PendlePTAmortizedOracle.Contract.MANAGERROLE(&_PendlePTAmortizedOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _PendlePTAmortizedOracle.Contract.SUPERLEDGERCONFIGURATION(&_PendlePTAmortizedOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _PendlePTAmortizedOracle.Contract.SUPERLEDGERCONFIGURATION(&_PendlePTAmortizedOracle.CallOpts)
}

// TWAPDURATION is a free data retrieval call binding the contract method 0x879ac8f8.
//
// Solidity: function TWAP_DURATION() view returns(uint32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) TWAPDURATION(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "TWAP_DURATION")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// TWAPDURATION is a free data retrieval call binding the contract method 0x879ac8f8.
//
// Solidity: function TWAP_DURATION() view returns(uint32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) TWAPDURATION() (uint32, error) {
	return _PendlePTAmortizedOracle.Contract.TWAPDURATION(&_PendlePTAmortizedOracle.CallOpts)
}

// TWAPDURATION is a free data retrieval call binding the contract method 0x879ac8f8.
//
// Solidity: function TWAP_DURATION() view returns(uint32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) TWAPDURATION() (uint32, error) {
	return _PendlePTAmortizedOracle.Contract.TWAPDURATION(&_PendlePTAmortizedOracle.CallOpts)
}

// BookValues is a free data retrieval call binding the contract method 0x53a5288f.
//
// Solidity: function bookValues(address strategy, address market) view returns(uint128 lastUpdateBookValue, uint64 lastUpdateTime)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) BookValues(opts *bind.CallOpts, strategy common.Address, market common.Address) (struct {
	LastUpdateBookValue *big.Int
	LastUpdateTime      uint64
}, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "bookValues", strategy, market)

	outstruct := new(struct {
		LastUpdateBookValue *big.Int
		LastUpdateTime      uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.LastUpdateBookValue = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.LastUpdateTime = *abi.ConvertType(out[1], new(uint64)).(*uint64)

	return *outstruct, err

}

// BookValues is a free data retrieval call binding the contract method 0x53a5288f.
//
// Solidity: function bookValues(address strategy, address market) view returns(uint128 lastUpdateBookValue, uint64 lastUpdateTime)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) BookValues(strategy common.Address, market common.Address) (struct {
	LastUpdateBookValue *big.Int
	LastUpdateTime      uint64
}, error) {
	return _PendlePTAmortizedOracle.Contract.BookValues(&_PendlePTAmortizedOracle.CallOpts, strategy, market)
}

// BookValues is a free data retrieval call binding the contract method 0x53a5288f.
//
// Solidity: function bookValues(address strategy, address market) view returns(uint128 lastUpdateBookValue, uint64 lastUpdateTime)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) BookValues(strategy common.Address, market common.Address) (struct {
	LastUpdateBookValue *big.Int
	LastUpdateTime      uint64
}, error) {
	return _PendlePTAmortizedOracle.Contract.BookValues(&_PendlePTAmortizedOracle.CallOpts, strategy, market)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address market) view returns(uint8)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) Decimals(opts *bind.CallOpts, market common.Address) (uint8, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "decimals", market)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address market) view returns(uint8)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) Decimals(market common.Address) (uint8, error) {
	return _PendlePTAmortizedOracle.Contract.Decimals(&_PendlePTAmortizedOracle.CallOpts, market)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address market) view returns(uint8)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) Decimals(market common.Address) (uint8, error) {
	return _PendlePTAmortizedOracle.Contract.Decimals(&_PendlePTAmortizedOracle.CallOpts, market)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address market, address , uint256 sharesIn) view returns(uint256 assetsOut)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetAssetOutput(opts *bind.CallOpts, market common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getAssetOutput", market, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address market, address , uint256 sharesIn) view returns(uint256 assetsOut)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetAssetOutput(market common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetAssetOutput(&_PendlePTAmortizedOracle.CallOpts, market, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address market, address , uint256 sharesIn) view returns(uint256 assetsOut)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetAssetOutput(market common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetAssetOutput(&_PendlePTAmortizedOracle.CallOpts, market, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetAssetOutputWithFees(&_PendlePTAmortizedOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetAssetOutputWithFees(&_PendlePTAmortizedOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address market, address ownerOfShares) view returns(uint256 balance)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getBalanceOfOwner", market, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address market, address ownerOfShares) view returns(uint256 balance)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetBalanceOfOwner(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetBalanceOfOwner(&_PendlePTAmortizedOracle.CallOpts, market, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address market, address ownerOfShares) view returns(uint256 balance)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetBalanceOfOwner(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetBalanceOfOwner(&_PendlePTAmortizedOracle.CallOpts, market, ownerOfShares)
}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256 bookValue)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetBookValue(opts *bind.CallOpts, strategy common.Address, market common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getBookValue", strategy, market)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256 bookValue)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetBookValue(strategy common.Address, market common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetBookValue(&_PendlePTAmortizedOracle.CallOpts, strategy, market)
}

// GetBookValue is a free data retrieval call binding the contract method 0x38caeb2a.
//
// Solidity: function getBookValue(address strategy, address market) view returns(uint256 bookValue)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetBookValue(strategy common.Address, market common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetBookValue(&_PendlePTAmortizedOracle.CallOpts, strategy, market)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address market) view returns(uint256 price)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetPricePerShare(opts *bind.CallOpts, market common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getPricePerShare", market)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address market) view returns(uint256 price)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetPricePerShare(market common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetPricePerShare(&_PendlePTAmortizedOracle.CallOpts, market)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address market) view returns(uint256 price)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetPricePerShare(market common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetPricePerShare(&_PendlePTAmortizedOracle.CallOpts, market)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetPricePerShareMultiple(&_PendlePTAmortizedOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetPricePerShareMultiple(&_PendlePTAmortizedOracle.CallOpts, yieldSourceAddresses)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetRoleAdmin(opts *bind.CallOpts, role [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getRoleAdmin", role)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _PendlePTAmortizedOracle.Contract.GetRoleAdmin(&_PendlePTAmortizedOracle.CallOpts, role)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _PendlePTAmortizedOracle.Contract.GetRoleAdmin(&_PendlePTAmortizedOracle.CallOpts, role)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address market, address , uint256 assetsIn) view returns(uint256 sharesOut)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetShareOutput(opts *bind.CallOpts, market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getShareOutput", market, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address market, address , uint256 assetsIn) view returns(uint256 sharesOut)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetShareOutput(market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetShareOutput(&_PendlePTAmortizedOracle.CallOpts, market, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address market, address , uint256 assetsIn) view returns(uint256 sharesOut)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetShareOutput(market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetShareOutput(&_PendlePTAmortizedOracle.CallOpts, market, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address market) view returns(uint256 tvl)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetTVL(opts *bind.CallOpts, market common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getTVL", market)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address market) view returns(uint256 tvl)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetTVL(market common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVL(&_PendlePTAmortizedOracle.CallOpts, market)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address market) view returns(uint256 tvl)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetTVL(market common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVL(&_PendlePTAmortizedOracle.CallOpts, market)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address market, address ownerOfShares) view returns(uint256 tvl)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", market, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address market, address ownerOfShares) view returns(uint256 tvl)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetTVLByOwnerOfShares(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVLByOwnerOfShares(&_PendlePTAmortizedOracle.CallOpts, market, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address market, address ownerOfShares) view returns(uint256 tvl)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetTVLByOwnerOfShares(market common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVLByOwnerOfShares(&_PendlePTAmortizedOracle.CallOpts, market, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

	if err != nil {
		return *new([][]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([][]*big.Int)).(*[][]*big.Int)

	return out0, err

}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_PendlePTAmortizedOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) ([][]*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_PendlePTAmortizedOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVLMultiple(&_PendlePTAmortizedOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetTVLMultiple(&_PendlePTAmortizedOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address market, address , uint256 assetsIn) view returns(uint256)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", market, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address market, address , uint256 assetsIn) view returns(uint256)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GetWithdrawalShareOutput(market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetWithdrawalShareOutput(&_PendlePTAmortizedOracle.CallOpts, market, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address market, address , uint256 assetsIn) view returns(uint256)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) GetWithdrawalShareOutput(market common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _PendlePTAmortizedOracle.Contract.GetWithdrawalShareOutput(&_PendlePTAmortizedOracle.CallOpts, market, arg1, assetsIn)
}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool exists)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) HasPosition(opts *bind.CallOpts, strategy common.Address, market common.Address) (bool, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "hasPosition", strategy, market)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool exists)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) HasPosition(strategy common.Address, market common.Address) (bool, error) {
	return _PendlePTAmortizedOracle.Contract.HasPosition(&_PendlePTAmortizedOracle.CallOpts, strategy, market)
}

// HasPosition is a free data retrieval call binding the contract method 0x24bc00b0.
//
// Solidity: function hasPosition(address strategy, address market) view returns(bool exists)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) HasPosition(strategy common.Address, market common.Address) (bool, error) {
	return _PendlePTAmortizedOracle.Contract.HasPosition(&_PendlePTAmortizedOracle.CallOpts, strategy, market)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) HasRole(opts *bind.CallOpts, role [32]byte, account common.Address) (bool, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "hasRole", role, account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _PendlePTAmortizedOracle.Contract.HasRole(&_PendlePTAmortizedOracle.CallOpts, role, account)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _PendlePTAmortizedOracle.Contract.HasRole(&_PendlePTAmortizedOracle.CallOpts, role, account)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _PendlePTAmortizedOracle.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _PendlePTAmortizedOracle.Contract.SupportsInterface(&_PendlePTAmortizedOracle.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _PendlePTAmortizedOracle.Contract.SupportsInterface(&_PendlePTAmortizedOracle.CallOpts, interfaceId)
}

// CorrectBookValue is a paid mutator transaction binding the contract method 0x3c665aa5.
//
// Solidity: function correctBookValue(address strategy, address market, uint128 newBookValue) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactor) CorrectBookValue(opts *bind.TransactOpts, strategy common.Address, market common.Address, newBookValue *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.contract.Transact(opts, "correctBookValue", strategy, market, newBookValue)
}

// CorrectBookValue is a paid mutator transaction binding the contract method 0x3c665aa5.
//
// Solidity: function correctBookValue(address strategy, address market, uint128 newBookValue) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) CorrectBookValue(strategy common.Address, market common.Address, newBookValue *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.CorrectBookValue(&_PendlePTAmortizedOracle.TransactOpts, strategy, market, newBookValue)
}

// CorrectBookValue is a paid mutator transaction binding the contract method 0x3c665aa5.
//
// Solidity: function correctBookValue(address strategy, address market, uint128 newBookValue) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorSession) CorrectBookValue(strategy common.Address, market common.Address, newBookValue *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.CorrectBookValue(&_PendlePTAmortizedOracle.TransactOpts, strategy, market, newBookValue)
}

// DeletePosition is a paid mutator transaction binding the contract method 0x3ed1ecb4.
//
// Solidity: function deletePosition(address strategy, address market) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactor) DeletePosition(opts *bind.TransactOpts, strategy common.Address, market common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.contract.Transact(opts, "deletePosition", strategy, market)
}

// DeletePosition is a paid mutator transaction binding the contract method 0x3ed1ecb4.
//
// Solidity: function deletePosition(address strategy, address market) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) DeletePosition(strategy common.Address, market common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.DeletePosition(&_PendlePTAmortizedOracle.TransactOpts, strategy, market)
}

// DeletePosition is a paid mutator transaction binding the contract method 0x3ed1ecb4.
//
// Solidity: function deletePosition(address strategy, address market) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorSession) DeletePosition(strategy common.Address, market common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.DeletePosition(&_PendlePTAmortizedOracle.TransactOpts, strategy, market)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactor) GrantRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.contract.Transact(opts, "grantRole", role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.GrantRole(&_PendlePTAmortizedOracle.TransactOpts, role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.GrantRole(&_PendlePTAmortizedOracle.TransactOpts, role, account)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactor) RecordPurchase(opts *bind.TransactOpts, market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.contract.Transact(opts, "recordPurchase", market, sySpent, ptAmount)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) RecordPurchase(market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RecordPurchase(&_PendlePTAmortizedOracle.TransactOpts, market, sySpent, ptAmount)
}

// RecordPurchase is a paid mutator transaction binding the contract method 0xc9c33f03.
//
// Solidity: function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorSession) RecordPurchase(market common.Address, sySpent *big.Int, ptAmount *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RecordPurchase(&_PendlePTAmortizedOracle.TransactOpts, market, sySpent, ptAmount)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactor) RecordRedemption(opts *bind.TransactOpts, market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.contract.Transact(opts, "recordRedemption", market, ptSold)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) RecordRedemption(market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RecordRedemption(&_PendlePTAmortizedOracle.TransactOpts, market, ptSold)
}

// RecordRedemption is a paid mutator transaction binding the contract method 0x8890b6f5.
//
// Solidity: function recordRedemption(address market, uint256 ptSold) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorSession) RecordRedemption(market common.Address, ptSold *big.Int) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RecordRedemption(&_PendlePTAmortizedOracle.TransactOpts, market, ptSold)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactor) RenounceRole(opts *bind.TransactOpts, role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.contract.Transact(opts, "renounceRole", role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RenounceRole(&_PendlePTAmortizedOracle.TransactOpts, role, callerConfirmation)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address callerConfirmation) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorSession) RenounceRole(role [32]byte, callerConfirmation common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RenounceRole(&_PendlePTAmortizedOracle.TransactOpts, role, callerConfirmation)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactor) RevokeRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.contract.Transact(opts, "revokeRole", role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RevokeRole(&_PendlePTAmortizedOracle.TransactOpts, role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleTransactorSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _PendlePTAmortizedOracle.Contract.RevokeRole(&_PendlePTAmortizedOracle.TransactOpts, role, account)
}

// PendlePTAmortizedOracleBookValueCorrectedIterator is returned from FilterBookValueCorrected and is used to iterate over the raw logs and unpacked data for BookValueCorrected events raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleBookValueCorrectedIterator struct {
	Event *PendlePTAmortizedOracleBookValueCorrected // Event containing the contract specifics and raw log

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
func (it *PendlePTAmortizedOracleBookValueCorrectedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTAmortizedOracleBookValueCorrected)
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
		it.Event = new(PendlePTAmortizedOracleBookValueCorrected)
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
func (it *PendlePTAmortizedOracleBookValueCorrectedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTAmortizedOracleBookValueCorrectedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTAmortizedOracleBookValueCorrected represents a BookValueCorrected event raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleBookValueCorrected struct {
	Strategy     common.Address
	Market       common.Address
	OldBookValue *big.Int
	NewBookValue *big.Int
	CorrectedBy  common.Address
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterBookValueCorrected is a free log retrieval operation binding the contract event 0x8a129bda9d0ea34d2c708eb68e2898023d9a56b9cb65b4e1548c52359d31c58a.
//
// Solidity: event BookValueCorrected(address indexed strategy, address indexed market, uint256 oldBookValue, uint256 newBookValue, address indexed correctedBy)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) FilterBookValueCorrected(opts *bind.FilterOpts, strategy []common.Address, market []common.Address, correctedBy []common.Address) (*PendlePTAmortizedOracleBookValueCorrectedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	var correctedByRule []interface{}
	for _, correctedByItem := range correctedBy {
		correctedByRule = append(correctedByRule, correctedByItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.FilterLogs(opts, "BookValueCorrected", strategyRule, marketRule, correctedByRule)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleBookValueCorrectedIterator{contract: _PendlePTAmortizedOracle.contract, event: "BookValueCorrected", logs: logs, sub: sub}, nil
}

// WatchBookValueCorrected is a free log subscription operation binding the contract event 0x8a129bda9d0ea34d2c708eb68e2898023d9a56b9cb65b4e1548c52359d31c58a.
//
// Solidity: event BookValueCorrected(address indexed strategy, address indexed market, uint256 oldBookValue, uint256 newBookValue, address indexed correctedBy)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) WatchBookValueCorrected(opts *bind.WatchOpts, sink chan<- *PendlePTAmortizedOracleBookValueCorrected, strategy []common.Address, market []common.Address, correctedBy []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	var correctedByRule []interface{}
	for _, correctedByItem := range correctedBy {
		correctedByRule = append(correctedByRule, correctedByItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.WatchLogs(opts, "BookValueCorrected", strategyRule, marketRule, correctedByRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTAmortizedOracleBookValueCorrected)
				if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "BookValueCorrected", log); err != nil {
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

// ParseBookValueCorrected is a log parse operation binding the contract event 0x8a129bda9d0ea34d2c708eb68e2898023d9a56b9cb65b4e1548c52359d31c58a.
//
// Solidity: event BookValueCorrected(address indexed strategy, address indexed market, uint256 oldBookValue, uint256 newBookValue, address indexed correctedBy)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) ParseBookValueCorrected(log types.Log) (*PendlePTAmortizedOracleBookValueCorrected, error) {
	event := new(PendlePTAmortizedOracleBookValueCorrected)
	if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "BookValueCorrected", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PendlePTAmortizedOracleBookValueUpdatedIterator is returned from FilterBookValueUpdated and is used to iterate over the raw logs and unpacked data for BookValueUpdated events raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleBookValueUpdatedIterator struct {
	Event *PendlePTAmortizedOracleBookValueUpdated // Event containing the contract specifics and raw log

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
func (it *PendlePTAmortizedOracleBookValueUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTAmortizedOracleBookValueUpdated)
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
		it.Event = new(PendlePTAmortizedOracleBookValueUpdated)
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
func (it *PendlePTAmortizedOracleBookValueUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTAmortizedOracleBookValueUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTAmortizedOracleBookValueUpdated represents a BookValueUpdated event raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleBookValueUpdated struct {
	Strategy     common.Address
	Market       common.Address
	NewBookValue *big.Int
	Timestamp    *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterBookValueUpdated is a free log retrieval operation binding the contract event 0xfc0fca9088aa71994022b7598f671447fab11cf158becdfad5f05141ce98f4f9.
//
// Solidity: event BookValueUpdated(address indexed strategy, address indexed market, uint256 newBookValue, uint256 timestamp)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) FilterBookValueUpdated(opts *bind.FilterOpts, strategy []common.Address, market []common.Address) (*PendlePTAmortizedOracleBookValueUpdatedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.FilterLogs(opts, "BookValueUpdated", strategyRule, marketRule)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleBookValueUpdatedIterator{contract: _PendlePTAmortizedOracle.contract, event: "BookValueUpdated", logs: logs, sub: sub}, nil
}

// WatchBookValueUpdated is a free log subscription operation binding the contract event 0xfc0fca9088aa71994022b7598f671447fab11cf158becdfad5f05141ce98f4f9.
//
// Solidity: event BookValueUpdated(address indexed strategy, address indexed market, uint256 newBookValue, uint256 timestamp)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) WatchBookValueUpdated(opts *bind.WatchOpts, sink chan<- *PendlePTAmortizedOracleBookValueUpdated, strategy []common.Address, market []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.WatchLogs(opts, "BookValueUpdated", strategyRule, marketRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTAmortizedOracleBookValueUpdated)
				if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "BookValueUpdated", log); err != nil {
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

// ParseBookValueUpdated is a log parse operation binding the contract event 0xfc0fca9088aa71994022b7598f671447fab11cf158becdfad5f05141ce98f4f9.
//
// Solidity: event BookValueUpdated(address indexed strategy, address indexed market, uint256 newBookValue, uint256 timestamp)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) ParseBookValueUpdated(log types.Log) (*PendlePTAmortizedOracleBookValueUpdated, error) {
	event := new(PendlePTAmortizedOracleBookValueUpdated)
	if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "BookValueUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PendlePTAmortizedOraclePurchaseRecordedIterator is returned from FilterPurchaseRecorded and is used to iterate over the raw logs and unpacked data for PurchaseRecorded events raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOraclePurchaseRecordedIterator struct {
	Event *PendlePTAmortizedOraclePurchaseRecorded // Event containing the contract specifics and raw log

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
func (it *PendlePTAmortizedOraclePurchaseRecordedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTAmortizedOraclePurchaseRecorded)
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
		it.Event = new(PendlePTAmortizedOraclePurchaseRecorded)
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
func (it *PendlePTAmortizedOraclePurchaseRecordedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTAmortizedOraclePurchaseRecordedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTAmortizedOraclePurchaseRecorded represents a PurchaseRecorded event raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOraclePurchaseRecorded struct {
	Strategy common.Address
	Market   common.Address
	SySpent  *big.Int
	PtAmount *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterPurchaseRecorded is a free log retrieval operation binding the contract event 0xca3eb5e06868f11093c340b698679a10f0d2ae66af994a368fb5cb489bcfd94c.
//
// Solidity: event PurchaseRecorded(address indexed strategy, address indexed market, uint256 sySpent, uint256 ptAmount)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) FilterPurchaseRecorded(opts *bind.FilterOpts, strategy []common.Address, market []common.Address) (*PendlePTAmortizedOraclePurchaseRecordedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.FilterLogs(opts, "PurchaseRecorded", strategyRule, marketRule)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOraclePurchaseRecordedIterator{contract: _PendlePTAmortizedOracle.contract, event: "PurchaseRecorded", logs: logs, sub: sub}, nil
}

// WatchPurchaseRecorded is a free log subscription operation binding the contract event 0xca3eb5e06868f11093c340b698679a10f0d2ae66af994a368fb5cb489bcfd94c.
//
// Solidity: event PurchaseRecorded(address indexed strategy, address indexed market, uint256 sySpent, uint256 ptAmount)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) WatchPurchaseRecorded(opts *bind.WatchOpts, sink chan<- *PendlePTAmortizedOraclePurchaseRecorded, strategy []common.Address, market []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.WatchLogs(opts, "PurchaseRecorded", strategyRule, marketRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTAmortizedOraclePurchaseRecorded)
				if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "PurchaseRecorded", log); err != nil {
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

// ParsePurchaseRecorded is a log parse operation binding the contract event 0xca3eb5e06868f11093c340b698679a10f0d2ae66af994a368fb5cb489bcfd94c.
//
// Solidity: event PurchaseRecorded(address indexed strategy, address indexed market, uint256 sySpent, uint256 ptAmount)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) ParsePurchaseRecorded(log types.Log) (*PendlePTAmortizedOraclePurchaseRecorded, error) {
	event := new(PendlePTAmortizedOraclePurchaseRecorded)
	if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "PurchaseRecorded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PendlePTAmortizedOracleRedemptionRecordedIterator is returned from FilterRedemptionRecorded and is used to iterate over the raw logs and unpacked data for RedemptionRecorded events raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRedemptionRecordedIterator struct {
	Event *PendlePTAmortizedOracleRedemptionRecorded // Event containing the contract specifics and raw log

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
func (it *PendlePTAmortizedOracleRedemptionRecordedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTAmortizedOracleRedemptionRecorded)
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
		it.Event = new(PendlePTAmortizedOracleRedemptionRecorded)
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
func (it *PendlePTAmortizedOracleRedemptionRecordedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTAmortizedOracleRedemptionRecordedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTAmortizedOracleRedemptionRecorded represents a RedemptionRecorded event raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRedemptionRecorded struct {
	Strategy common.Address
	Market   common.Address
	PtSold   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterRedemptionRecorded is a free log retrieval operation binding the contract event 0xc82cd28a3ccffbd96ed46ce26738caaca6a25b52594380de5bd55c1a20163b84.
//
// Solidity: event RedemptionRecorded(address indexed strategy, address indexed market, uint256 ptSold)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) FilterRedemptionRecorded(opts *bind.FilterOpts, strategy []common.Address, market []common.Address) (*PendlePTAmortizedOracleRedemptionRecordedIterator, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.FilterLogs(opts, "RedemptionRecorded", strategyRule, marketRule)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleRedemptionRecordedIterator{contract: _PendlePTAmortizedOracle.contract, event: "RedemptionRecorded", logs: logs, sub: sub}, nil
}

// WatchRedemptionRecorded is a free log subscription operation binding the contract event 0xc82cd28a3ccffbd96ed46ce26738caaca6a25b52594380de5bd55c1a20163b84.
//
// Solidity: event RedemptionRecorded(address indexed strategy, address indexed market, uint256 ptSold)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) WatchRedemptionRecorded(opts *bind.WatchOpts, sink chan<- *PendlePTAmortizedOracleRedemptionRecorded, strategy []common.Address, market []common.Address) (event.Subscription, error) {

	var strategyRule []interface{}
	for _, strategyItem := range strategy {
		strategyRule = append(strategyRule, strategyItem)
	}
	var marketRule []interface{}
	for _, marketItem := range market {
		marketRule = append(marketRule, marketItem)
	}

	logs, sub, err := _PendlePTAmortizedOracle.contract.WatchLogs(opts, "RedemptionRecorded", strategyRule, marketRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTAmortizedOracleRedemptionRecorded)
				if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RedemptionRecorded", log); err != nil {
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

// ParseRedemptionRecorded is a log parse operation binding the contract event 0xc82cd28a3ccffbd96ed46ce26738caaca6a25b52594380de5bd55c1a20163b84.
//
// Solidity: event RedemptionRecorded(address indexed strategy, address indexed market, uint256 ptSold)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) ParseRedemptionRecorded(log types.Log) (*PendlePTAmortizedOracleRedemptionRecorded, error) {
	event := new(PendlePTAmortizedOracleRedemptionRecorded)
	if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RedemptionRecorded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PendlePTAmortizedOracleRoleAdminChangedIterator is returned from FilterRoleAdminChanged and is used to iterate over the raw logs and unpacked data for RoleAdminChanged events raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRoleAdminChangedIterator struct {
	Event *PendlePTAmortizedOracleRoleAdminChanged // Event containing the contract specifics and raw log

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
func (it *PendlePTAmortizedOracleRoleAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTAmortizedOracleRoleAdminChanged)
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
		it.Event = new(PendlePTAmortizedOracleRoleAdminChanged)
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
func (it *PendlePTAmortizedOracleRoleAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTAmortizedOracleRoleAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTAmortizedOracleRoleAdminChanged represents a RoleAdminChanged event raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRoleAdminChanged struct {
	Role              [32]byte
	PreviousAdminRole [32]byte
	NewAdminRole      [32]byte
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterRoleAdminChanged is a free log retrieval operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) FilterRoleAdminChanged(opts *bind.FilterOpts, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (*PendlePTAmortizedOracleRoleAdminChangedIterator, error) {

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

	logs, sub, err := _PendlePTAmortizedOracle.contract.FilterLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleRoleAdminChangedIterator{contract: _PendlePTAmortizedOracle.contract, event: "RoleAdminChanged", logs: logs, sub: sub}, nil
}

// WatchRoleAdminChanged is a free log subscription operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) WatchRoleAdminChanged(opts *bind.WatchOpts, sink chan<- *PendlePTAmortizedOracleRoleAdminChanged, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (event.Subscription, error) {

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

	logs, sub, err := _PendlePTAmortizedOracle.contract.WatchLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTAmortizedOracleRoleAdminChanged)
				if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
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
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) ParseRoleAdminChanged(log types.Log) (*PendlePTAmortizedOracleRoleAdminChanged, error) {
	event := new(PendlePTAmortizedOracleRoleAdminChanged)
	if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PendlePTAmortizedOracleRoleGrantedIterator is returned from FilterRoleGranted and is used to iterate over the raw logs and unpacked data for RoleGranted events raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRoleGrantedIterator struct {
	Event *PendlePTAmortizedOracleRoleGranted // Event containing the contract specifics and raw log

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
func (it *PendlePTAmortizedOracleRoleGrantedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTAmortizedOracleRoleGranted)
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
		it.Event = new(PendlePTAmortizedOracleRoleGranted)
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
func (it *PendlePTAmortizedOracleRoleGrantedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTAmortizedOracleRoleGrantedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTAmortizedOracleRoleGranted represents a RoleGranted event raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRoleGranted struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleGranted is a free log retrieval operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) FilterRoleGranted(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*PendlePTAmortizedOracleRoleGrantedIterator, error) {

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

	logs, sub, err := _PendlePTAmortizedOracle.contract.FilterLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleRoleGrantedIterator{contract: _PendlePTAmortizedOracle.contract, event: "RoleGranted", logs: logs, sub: sub}, nil
}

// WatchRoleGranted is a free log subscription operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) WatchRoleGranted(opts *bind.WatchOpts, sink chan<- *PendlePTAmortizedOracleRoleGranted, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _PendlePTAmortizedOracle.contract.WatchLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTAmortizedOracleRoleGranted)
				if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RoleGranted", log); err != nil {
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
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) ParseRoleGranted(log types.Log) (*PendlePTAmortizedOracleRoleGranted, error) {
	event := new(PendlePTAmortizedOracleRoleGranted)
	if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RoleGranted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PendlePTAmortizedOracleRoleRevokedIterator is returned from FilterRoleRevoked and is used to iterate over the raw logs and unpacked data for RoleRevoked events raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRoleRevokedIterator struct {
	Event *PendlePTAmortizedOracleRoleRevoked // Event containing the contract specifics and raw log

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
func (it *PendlePTAmortizedOracleRoleRevokedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PendlePTAmortizedOracleRoleRevoked)
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
		it.Event = new(PendlePTAmortizedOracleRoleRevoked)
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
func (it *PendlePTAmortizedOracleRoleRevokedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PendlePTAmortizedOracleRoleRevokedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PendlePTAmortizedOracleRoleRevoked represents a RoleRevoked event raised by the PendlePTAmortizedOracle contract.
type PendlePTAmortizedOracleRoleRevoked struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleRevoked is a free log retrieval operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) FilterRoleRevoked(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*PendlePTAmortizedOracleRoleRevokedIterator, error) {

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

	logs, sub, err := _PendlePTAmortizedOracle.contract.FilterLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &PendlePTAmortizedOracleRoleRevokedIterator{contract: _PendlePTAmortizedOracle.contract, event: "RoleRevoked", logs: logs, sub: sub}, nil
}

// WatchRoleRevoked is a free log subscription operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) WatchRoleRevoked(opts *bind.WatchOpts, sink chan<- *PendlePTAmortizedOracleRoleRevoked, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _PendlePTAmortizedOracle.contract.WatchLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PendlePTAmortizedOracleRoleRevoked)
				if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
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
func (_PendlePTAmortizedOracle *PendlePTAmortizedOracleFilterer) ParseRoleRevoked(log types.Log) (*PendlePTAmortizedOracleRoleRevoked, error) {
	event := new(PendlePTAmortizedOracleRoleRevoked)
	if err := _PendlePTAmortizedOracle.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
