// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package UniV2LPYieldSourceOracle

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

// UniV2LPYieldSourceOracleMetaData contains all meta data concerning the UniV2LPYieldSourceOracle contract.
var UniV2LPYieldSourceOracleMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"superLedgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feed0_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"feed1_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token0_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token1_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"maxStaleness_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"sequencerUptimeFeed_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"gracePeriod_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"FEED0\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIAggregatorV3\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEED0_MAX_ANSWER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"int192\",\"internalType\":\"int192\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEED0_MIN_ANSWER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"int192\",\"internalType\":\"int192\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEED0_SCALE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEED1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIAggregatorV3\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEED1_MAX_ANSWER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"int192\",\"internalType\":\"int192\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEED1_MIN_ANSWER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"int192\",\"internalType\":\"int192\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEED1_SCALE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GRACE_PERIOD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAX_STALENESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SEQUENCER_UPTIME_FEED\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIAggregatorV3\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TOKEN0_SCALE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TOKEN1_DECIMALS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decimals\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getAssetOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sharesIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAssetOutputWithFees\",\"inputs\":[{\"name\":\"yieldSourceOracleId\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetOut\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usedShares\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBalanceOfOwner\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShare\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPricePerShareMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"pricesPerShare\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVL\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfShares\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"ownerOfShares\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLByOwnerOfSharesMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"ownersOfShares\",\"type\":\"address[][]\",\"internalType\":\"address[][]\"}],\"outputs\":[{\"name\":\"userTvls\",\"type\":\"uint256[][]\",\"internalType\":\"uint256[][]\"},{\"name\":\"succeeded\",\"type\":\"bool[][]\",\"internalType\":\"bool[][]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTVLMultiple\",\"inputs\":[{\"name\":\"yieldSourceAddresses\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"tvls\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getWithdrawalShareOutput\",\"inputs\":[{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetsIn\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"GRACE_PERIOD_NOT_OVER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_BASE_ASSET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PRICE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_STALENESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SEQUENCER_DOWN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"STALE_PRICE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_TOTAL_SUPPLY\",\"inputs\":[]}]",
}

// UniV2LPYieldSourceOracleABI is the input ABI used to generate the binding from.
// Deprecated: Use UniV2LPYieldSourceOracleMetaData.ABI instead.
var UniV2LPYieldSourceOracleABI = UniV2LPYieldSourceOracleMetaData.ABI

// UniV2LPYieldSourceOracle is an auto generated Go binding around an Ethereum contract.
type UniV2LPYieldSourceOracle struct {
	UniV2LPYieldSourceOracleCaller     // Read-only binding to the contract
	UniV2LPYieldSourceOracleTransactor // Write-only binding to the contract
	UniV2LPYieldSourceOracleFilterer   // Log filterer for contract events
}

// UniV2LPYieldSourceOracleCaller is an auto generated read-only Go binding around an Ethereum contract.
type UniV2LPYieldSourceOracleCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// UniV2LPYieldSourceOracleTransactor is an auto generated write-only Go binding around an Ethereum contract.
type UniV2LPYieldSourceOracleTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// UniV2LPYieldSourceOracleFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type UniV2LPYieldSourceOracleFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// UniV2LPYieldSourceOracleSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type UniV2LPYieldSourceOracleSession struct {
	Contract     *UniV2LPYieldSourceOracle // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// UniV2LPYieldSourceOracleCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type UniV2LPYieldSourceOracleCallerSession struct {
	Contract *UniV2LPYieldSourceOracleCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// UniV2LPYieldSourceOracleTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type UniV2LPYieldSourceOracleTransactorSession struct {
	Contract     *UniV2LPYieldSourceOracleTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// UniV2LPYieldSourceOracleRaw is an auto generated low-level Go binding around an Ethereum contract.
type UniV2LPYieldSourceOracleRaw struct {
	Contract *UniV2LPYieldSourceOracle // Generic contract binding to access the raw methods on
}

// UniV2LPYieldSourceOracleCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type UniV2LPYieldSourceOracleCallerRaw struct {
	Contract *UniV2LPYieldSourceOracleCaller // Generic read-only contract binding to access the raw methods on
}

// UniV2LPYieldSourceOracleTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type UniV2LPYieldSourceOracleTransactorRaw struct {
	Contract *UniV2LPYieldSourceOracleTransactor // Generic write-only contract binding to access the raw methods on
}

// NewUniV2LPYieldSourceOracle creates a new instance of UniV2LPYieldSourceOracle, bound to a specific deployed contract.
func NewUniV2LPYieldSourceOracle(address common.Address, backend bind.ContractBackend) (*UniV2LPYieldSourceOracle, error) {
	contract, err := bindUniV2LPYieldSourceOracle(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &UniV2LPYieldSourceOracle{UniV2LPYieldSourceOracleCaller: UniV2LPYieldSourceOracleCaller{contract: contract}, UniV2LPYieldSourceOracleTransactor: UniV2LPYieldSourceOracleTransactor{contract: contract}, UniV2LPYieldSourceOracleFilterer: UniV2LPYieldSourceOracleFilterer{contract: contract}}, nil
}

// NewUniV2LPYieldSourceOracleCaller creates a new read-only instance of UniV2LPYieldSourceOracle, bound to a specific deployed contract.
func NewUniV2LPYieldSourceOracleCaller(address common.Address, caller bind.ContractCaller) (*UniV2LPYieldSourceOracleCaller, error) {
	contract, err := bindUniV2LPYieldSourceOracle(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &UniV2LPYieldSourceOracleCaller{contract: contract}, nil
}

// NewUniV2LPYieldSourceOracleTransactor creates a new write-only instance of UniV2LPYieldSourceOracle, bound to a specific deployed contract.
func NewUniV2LPYieldSourceOracleTransactor(address common.Address, transactor bind.ContractTransactor) (*UniV2LPYieldSourceOracleTransactor, error) {
	contract, err := bindUniV2LPYieldSourceOracle(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &UniV2LPYieldSourceOracleTransactor{contract: contract}, nil
}

// NewUniV2LPYieldSourceOracleFilterer creates a new log filterer instance of UniV2LPYieldSourceOracle, bound to a specific deployed contract.
func NewUniV2LPYieldSourceOracleFilterer(address common.Address, filterer bind.ContractFilterer) (*UniV2LPYieldSourceOracleFilterer, error) {
	contract, err := bindUniV2LPYieldSourceOracle(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &UniV2LPYieldSourceOracleFilterer{contract: contract}, nil
}

// bindUniV2LPYieldSourceOracle binds a generic wrapper to an already deployed contract.
func bindUniV2LPYieldSourceOracle(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := UniV2LPYieldSourceOracleMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _UniV2LPYieldSourceOracle.Contract.UniV2LPYieldSourceOracleCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _UniV2LPYieldSourceOracle.Contract.UniV2LPYieldSourceOracleTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _UniV2LPYieldSourceOracle.Contract.UniV2LPYieldSourceOracleTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _UniV2LPYieldSourceOracle.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _UniV2LPYieldSourceOracle.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _UniV2LPYieldSourceOracle.Contract.contract.Transact(opts, method, params...)
}

// FEED0 is a free data retrieval call binding the contract method 0x36c03936.
//
// Solidity: function FEED0() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED0(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED0")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FEED0 is a free data retrieval call binding the contract method 0x36c03936.
//
// Solidity: function FEED0() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED0() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED0 is a free data retrieval call binding the contract method 0x36c03936.
//
// Solidity: function FEED0() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED0() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED0MAXANSWER is a free data retrieval call binding the contract method 0x5dc23683.
//
// Solidity: function FEED0_MAX_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED0MAXANSWER(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED0_MAX_ANSWER")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEED0MAXANSWER is a free data retrieval call binding the contract method 0x5dc23683.
//
// Solidity: function FEED0_MAX_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED0MAXANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0MAXANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED0MAXANSWER is a free data retrieval call binding the contract method 0x5dc23683.
//
// Solidity: function FEED0_MAX_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED0MAXANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0MAXANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED0MINANSWER is a free data retrieval call binding the contract method 0x5fa2e26c.
//
// Solidity: function FEED0_MIN_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED0MINANSWER(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED0_MIN_ANSWER")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEED0MINANSWER is a free data retrieval call binding the contract method 0x5fa2e26c.
//
// Solidity: function FEED0_MIN_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED0MINANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0MINANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED0MINANSWER is a free data retrieval call binding the contract method 0x5fa2e26c.
//
// Solidity: function FEED0_MIN_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED0MINANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0MINANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED0SCALE is a free data retrieval call binding the contract method 0x4b919fed.
//
// Solidity: function FEED0_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED0SCALE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED0_SCALE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEED0SCALE is a free data retrieval call binding the contract method 0x4b919fed.
//
// Solidity: function FEED0_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED0SCALE() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0SCALE(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED0SCALE is a free data retrieval call binding the contract method 0x4b919fed.
//
// Solidity: function FEED0_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED0SCALE() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED0SCALE(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1 is a free data retrieval call binding the contract method 0xbc04cb0f.
//
// Solidity: function FEED1() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED1(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED1")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FEED1 is a free data retrieval call binding the contract method 0xbc04cb0f.
//
// Solidity: function FEED1() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED1() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1 is a free data retrieval call binding the contract method 0xbc04cb0f.
//
// Solidity: function FEED1() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED1() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1MAXANSWER is a free data retrieval call binding the contract method 0x24a8ba4c.
//
// Solidity: function FEED1_MAX_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED1MAXANSWER(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED1_MAX_ANSWER")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEED1MAXANSWER is a free data retrieval call binding the contract method 0x24a8ba4c.
//
// Solidity: function FEED1_MAX_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED1MAXANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1MAXANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1MAXANSWER is a free data retrieval call binding the contract method 0x24a8ba4c.
//
// Solidity: function FEED1_MAX_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED1MAXANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1MAXANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1MINANSWER is a free data retrieval call binding the contract method 0x47ecd092.
//
// Solidity: function FEED1_MIN_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED1MINANSWER(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED1_MIN_ANSWER")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEED1MINANSWER is a free data retrieval call binding the contract method 0x47ecd092.
//
// Solidity: function FEED1_MIN_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED1MINANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1MINANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1MINANSWER is a free data retrieval call binding the contract method 0x47ecd092.
//
// Solidity: function FEED1_MIN_ANSWER() view returns(int192)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED1MINANSWER() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1MINANSWER(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1SCALE is a free data retrieval call binding the contract method 0x25b149fa.
//
// Solidity: function FEED1_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) FEED1SCALE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "FEED1_SCALE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEED1SCALE is a free data retrieval call binding the contract method 0x25b149fa.
//
// Solidity: function FEED1_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) FEED1SCALE() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1SCALE(&_UniV2LPYieldSourceOracle.CallOpts)
}

// FEED1SCALE is a free data retrieval call binding the contract method 0x25b149fa.
//
// Solidity: function FEED1_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) FEED1SCALE() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.FEED1SCALE(&_UniV2LPYieldSourceOracle.CallOpts)
}

// GRACEPERIOD is a free data retrieval call binding the contract method 0xc1a287e2.
//
// Solidity: function GRACE_PERIOD() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GRACEPERIOD(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "GRACE_PERIOD")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GRACEPERIOD is a free data retrieval call binding the contract method 0xc1a287e2.
//
// Solidity: function GRACE_PERIOD() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GRACEPERIOD() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GRACEPERIOD(&_UniV2LPYieldSourceOracle.CallOpts)
}

// GRACEPERIOD is a free data retrieval call binding the contract method 0xc1a287e2.
//
// Solidity: function GRACE_PERIOD() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GRACEPERIOD() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GRACEPERIOD(&_UniV2LPYieldSourceOracle.CallOpts)
}

// MAXSTALENESS is a free data retrieval call binding the contract method 0xcaca95a4.
//
// Solidity: function MAX_STALENESS() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) MAXSTALENESS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "MAX_STALENESS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MAXSTALENESS is a free data retrieval call binding the contract method 0xcaca95a4.
//
// Solidity: function MAX_STALENESS() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) MAXSTALENESS() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.MAXSTALENESS(&_UniV2LPYieldSourceOracle.CallOpts)
}

// MAXSTALENESS is a free data retrieval call binding the contract method 0xcaca95a4.
//
// Solidity: function MAX_STALENESS() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) MAXSTALENESS() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.MAXSTALENESS(&_UniV2LPYieldSourceOracle.CallOpts)
}

// SEQUENCERUPTIMEFEED is a free data retrieval call binding the contract method 0xc5980182.
//
// Solidity: function SEQUENCER_UPTIME_FEED() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) SEQUENCERUPTIMEFEED(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "SEQUENCER_UPTIME_FEED")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SEQUENCERUPTIMEFEED is a free data retrieval call binding the contract method 0xc5980182.
//
// Solidity: function SEQUENCER_UPTIME_FEED() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) SEQUENCERUPTIMEFEED() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.SEQUENCERUPTIMEFEED(&_UniV2LPYieldSourceOracle.CallOpts)
}

// SEQUENCERUPTIMEFEED is a free data retrieval call binding the contract method 0xc5980182.
//
// Solidity: function SEQUENCER_UPTIME_FEED() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) SEQUENCERUPTIMEFEED() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.SEQUENCERUPTIMEFEED(&_UniV2LPYieldSourceOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) SUPERLEDGERCONFIGURATION(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_UniV2LPYieldSourceOracle.CallOpts)
}

// SUPERLEDGERCONFIGURATION is a free data retrieval call binding the contract method 0x8717164a.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION() view returns(address)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) SUPERLEDGERCONFIGURATION() (common.Address, error) {
	return _UniV2LPYieldSourceOracle.Contract.SUPERLEDGERCONFIGURATION(&_UniV2LPYieldSourceOracle.CallOpts)
}

// TOKEN0SCALE is a free data retrieval call binding the contract method 0xe953670b.
//
// Solidity: function TOKEN0_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) TOKEN0SCALE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "TOKEN0_SCALE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TOKEN0SCALE is a free data retrieval call binding the contract method 0xe953670b.
//
// Solidity: function TOKEN0_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) TOKEN0SCALE() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.TOKEN0SCALE(&_UniV2LPYieldSourceOracle.CallOpts)
}

// TOKEN0SCALE is a free data retrieval call binding the contract method 0xe953670b.
//
// Solidity: function TOKEN0_SCALE() view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) TOKEN0SCALE() (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.TOKEN0SCALE(&_UniV2LPYieldSourceOracle.CallOpts)
}

// TOKEN1DECIMALS is a free data retrieval call binding the contract method 0x5ecc99ab.
//
// Solidity: function TOKEN1_DECIMALS() view returns(uint8)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) TOKEN1DECIMALS(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "TOKEN1_DECIMALS")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// TOKEN1DECIMALS is a free data retrieval call binding the contract method 0x5ecc99ab.
//
// Solidity: function TOKEN1_DECIMALS() view returns(uint8)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) TOKEN1DECIMALS() (uint8, error) {
	return _UniV2LPYieldSourceOracle.Contract.TOKEN1DECIMALS(&_UniV2LPYieldSourceOracle.CallOpts)
}

// TOKEN1DECIMALS is a free data retrieval call binding the contract method 0x5ecc99ab.
//
// Solidity: function TOKEN1_DECIMALS() view returns(uint8)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) TOKEN1DECIMALS() (uint8, error) {
	return _UniV2LPYieldSourceOracle.Contract.TOKEN1DECIMALS(&_UniV2LPYieldSourceOracle.CallOpts)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) Decimals(opts *bind.CallOpts, arg0 common.Address) (uint8, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "decimals", arg0)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) Decimals(arg0 common.Address) (uint8, error) {
	return _UniV2LPYieldSourceOracle.Contract.Decimals(&_UniV2LPYieldSourceOracle.CallOpts, arg0)
}

// Decimals is a free data retrieval call binding the contract method 0xd449a832.
//
// Solidity: function decimals(address ) pure returns(uint8)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) Decimals(arg0 common.Address) (uint8, error) {
	return _UniV2LPYieldSourceOracle.Contract.Decimals(&_UniV2LPYieldSourceOracle.CallOpts, arg0)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetAssetOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getAssetOutput", yieldSourceAddress, arg1, sharesIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetAssetOutput(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutput is a free data retrieval call binding the contract method 0xaa5815fd.
//
// Solidity: function getAssetOutput(address yieldSourceAddress, address , uint256 sharesIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetAssetOutput(yieldSourceAddress common.Address, arg1 common.Address, sharesIn *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetAssetOutput(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, sharesIn)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetAssetOutputWithFees(opts *bind.CallOpts, yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getAssetOutputWithFees", yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetAssetOutputWithFees(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetAssetOutputWithFees is a free data retrieval call binding the contract method 0x2f112c46.
//
// Solidity: function getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetAssetOutputWithFees(yieldSourceOracleId [32]byte, yieldSourceAddress common.Address, assetOut common.Address, user common.Address, usedShares *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetAssetOutputWithFees(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceOracleId, yieldSourceAddress, assetOut, user, usedShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetBalanceOfOwner(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getBalanceOfOwner", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetBalanceOfOwner(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetBalanceOfOwner is a free data retrieval call binding the contract method 0xfea8af5f.
//
// Solidity: function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetBalanceOfOwner(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetBalanceOfOwner(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetPricePerShare(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getPricePerShare", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetPricePerShare(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShare is a free data retrieval call binding the contract method 0xec422afd.
//
// Solidity: function getPricePerShare(address yieldSourceAddress) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetPricePerShare(yieldSourceAddress common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetPricePerShare(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetPricePerShareMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getPricePerShareMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetPricePerShareMultiple(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetPricePerShareMultiple is a free data retrieval call binding the contract method 0xa7a128b4.
//
// Solidity: function getPricePerShareMultiple(address[] yieldSourceAddresses) view returns(uint256[] pricesPerShare)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetPricePerShareMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetPricePerShareMultiple(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetShareOutput(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetShareOutput is a free data retrieval call binding the contract method 0x056f143c.
//
// Solidity: function getShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetShareOutput(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetTVL(opts *bind.CallOpts, yieldSourceAddress common.Address) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getTVL", yieldSourceAddress)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVL(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVL is a free data retrieval call binding the contract method 0x0f40517a.
//
// Solidity: function getTVL(address yieldSourceAddress) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetTVL(yieldSourceAddress common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVL(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetTVLByOwnerOfShares(opts *bind.CallOpts, yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfShares", yieldSourceAddress, ownerOfShares)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfShares is a free data retrieval call binding the contract method 0x4fecb266.
//
// Solidity: function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetTVLByOwnerOfShares(yieldSourceAddress common.Address, ownerOfShares common.Address) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVLByOwnerOfShares(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, ownerOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetTVLByOwnerOfSharesMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getTVLByOwnerOfSharesMultiple", yieldSourceAddresses, ownersOfShares)

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
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLByOwnerOfSharesMultiple is a free data retrieval call binding the contract method 0x34f99b48.
//
// Solidity: function getTVLByOwnerOfSharesMultiple(address[] yieldSourceAddresses, address[][] ownersOfShares) view returns(uint256[][] userTvls, bool[][] succeeded)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetTVLByOwnerOfSharesMultiple(yieldSourceAddresses []common.Address, ownersOfShares [][]common.Address) (struct {
	UserTvls  [][]*big.Int
	Succeeded [][]bool
}, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVLByOwnerOfSharesMultiple(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddresses, ownersOfShares)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetTVLMultiple(opts *bind.CallOpts, yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getTVLMultiple", yieldSourceAddresses)

	if err != nil {
		return *new([]*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new([]*big.Int)).(*[]*big.Int)

	return out0, err

}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVLMultiple(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetTVLMultiple is a free data retrieval call binding the contract method 0xcacc7b0e.
//
// Solidity: function getTVLMultiple(address[] yieldSourceAddresses) view returns(uint256[] tvls)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetTVLMultiple(yieldSourceAddresses []common.Address) ([]*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetTVLMultiple(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddresses)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCaller) GetWithdrawalShareOutput(opts *bind.CallOpts, yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _UniV2LPYieldSourceOracle.contract.Call(opts, &out, "getWithdrawalShareOutput", yieldSourceAddress, arg1, assetsIn)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}

// GetWithdrawalShareOutput is a free data retrieval call binding the contract method 0x7eeb8107.
//
// Solidity: function getWithdrawalShareOutput(address yieldSourceAddress, address , uint256 assetsIn) view returns(uint256)
func (_UniV2LPYieldSourceOracle *UniV2LPYieldSourceOracleCallerSession) GetWithdrawalShareOutput(yieldSourceAddress common.Address, arg1 common.Address, assetsIn *big.Int) (*big.Int, error) {
	return _UniV2LPYieldSourceOracle.Contract.GetWithdrawalShareOutput(&_UniV2LPYieldSourceOracle.CallOpts, yieldSourceAddress, arg1, assetsIn)
}
