// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperAssetPriceLib

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

// ISuperAssetPriceArgs is an auto generated low-level Go binding around an user-defined struct.
type ISuperAssetPriceArgs struct {
	SuperOracle         common.Address
	SuperAsset          common.Address
	Token               common.Address
	Usd                 common.Address
	DepegLowerThreshold *big.Int
	DepegUpperThreshold *big.Int
	DispersionThreshold *big.Int
}

// SuperAssetPriceLibMetaData contains all meta data concerning the SuperAssetPriceLib contract.
var SuperAssetPriceLibMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getPriceWithCircuitBreakers\",\"inputs\":[{\"name\":\"args\",\"type\":\"tuple\",\"internalType\":\"structISuperAsset.PriceArgs\",\"components\":[{\"name\":\"superOracle\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superAsset\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"usd\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"depegLowerThreshold\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"depegUpperThreshold\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"dispersionThreshold\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"outputs\":[{\"name\":\"priceUSD\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"isDepeg\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"isDispersion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"isOracleOff\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"}]",
}

// SuperAssetPriceLibABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperAssetPriceLibMetaData.ABI instead.
var SuperAssetPriceLibABI = SuperAssetPriceLibMetaData.ABI

// SuperAssetPriceLib is an auto generated Go binding around an Ethereum contract.
type SuperAssetPriceLib struct {
	SuperAssetPriceLibCaller     // Read-only binding to the contract
	SuperAssetPriceLibTransactor // Write-only binding to the contract
	SuperAssetPriceLibFilterer   // Log filterer for contract events
}

// SuperAssetPriceLibCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperAssetPriceLibCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetPriceLibTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperAssetPriceLibTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetPriceLibFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperAssetPriceLibFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperAssetPriceLibSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperAssetPriceLibSession struct {
	Contract     *SuperAssetPriceLib // Generic contract binding to set the session for
	CallOpts     bind.CallOpts       // Call options to use throughout this session
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// SuperAssetPriceLibCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperAssetPriceLibCallerSession struct {
	Contract *SuperAssetPriceLibCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts             // Call options to use throughout this session
}

// SuperAssetPriceLibTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperAssetPriceLibTransactorSession struct {
	Contract     *SuperAssetPriceLibTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// SuperAssetPriceLibRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperAssetPriceLibRaw struct {
	Contract *SuperAssetPriceLib // Generic contract binding to access the raw methods on
}

// SuperAssetPriceLibCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperAssetPriceLibCallerRaw struct {
	Contract *SuperAssetPriceLibCaller // Generic read-only contract binding to access the raw methods on
}

// SuperAssetPriceLibTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperAssetPriceLibTransactorRaw struct {
	Contract *SuperAssetPriceLibTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperAssetPriceLib creates a new instance of SuperAssetPriceLib, bound to a specific deployed contract.
func NewSuperAssetPriceLib(address common.Address, backend bind.ContractBackend) (*SuperAssetPriceLib, error) {
	contract, err := bindSuperAssetPriceLib(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperAssetPriceLib{SuperAssetPriceLibCaller: SuperAssetPriceLibCaller{contract: contract}, SuperAssetPriceLibTransactor: SuperAssetPriceLibTransactor{contract: contract}, SuperAssetPriceLibFilterer: SuperAssetPriceLibFilterer{contract: contract}}, nil
}

// NewSuperAssetPriceLibCaller creates a new read-only instance of SuperAssetPriceLib, bound to a specific deployed contract.
func NewSuperAssetPriceLibCaller(address common.Address, caller bind.ContractCaller) (*SuperAssetPriceLibCaller, error) {
	contract, err := bindSuperAssetPriceLib(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperAssetPriceLibCaller{contract: contract}, nil
}

// NewSuperAssetPriceLibTransactor creates a new write-only instance of SuperAssetPriceLib, bound to a specific deployed contract.
func NewSuperAssetPriceLibTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperAssetPriceLibTransactor, error) {
	contract, err := bindSuperAssetPriceLib(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperAssetPriceLibTransactor{contract: contract}, nil
}

// NewSuperAssetPriceLibFilterer creates a new log filterer instance of SuperAssetPriceLib, bound to a specific deployed contract.
func NewSuperAssetPriceLibFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperAssetPriceLibFilterer, error) {
	contract, err := bindSuperAssetPriceLib(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperAssetPriceLibFilterer{contract: contract}, nil
}

// bindSuperAssetPriceLib binds a generic wrapper to an already deployed contract.
func bindSuperAssetPriceLib(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperAssetPriceLibMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperAssetPriceLib *SuperAssetPriceLibRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperAssetPriceLib.Contract.SuperAssetPriceLibCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperAssetPriceLib *SuperAssetPriceLibRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperAssetPriceLib.Contract.SuperAssetPriceLibTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperAssetPriceLib *SuperAssetPriceLibRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperAssetPriceLib.Contract.SuperAssetPriceLibTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperAssetPriceLib *SuperAssetPriceLibCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperAssetPriceLib.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperAssetPriceLib *SuperAssetPriceLibTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperAssetPriceLib.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperAssetPriceLib *SuperAssetPriceLibTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperAssetPriceLib.Contract.contract.Transact(opts, method, params...)
}

// GetPriceWithCircuitBreakers is a free data retrieval call binding the contract method 0x378ed7f0.
//
// Solidity: function getPriceWithCircuitBreakers((address,address,address,address,uint256,uint256,uint256) args) view returns(uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
func (_SuperAssetPriceLib *SuperAssetPriceLibCaller) GetPriceWithCircuitBreakers(opts *bind.CallOpts, args ISuperAssetPriceArgs) (struct {
	PriceUSD     *big.Int
	IsDepeg      bool
	IsDispersion bool
	IsOracleOff  bool
}, error) {
	var out []interface{}
	err := _SuperAssetPriceLib.contract.Call(opts, &out, "getPriceWithCircuitBreakers", args)

	outstruct := new(struct {
		PriceUSD     *big.Int
		IsDepeg      bool
		IsDispersion bool
		IsOracleOff  bool
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.PriceUSD = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.IsDepeg = *abi.ConvertType(out[1], new(bool)).(*bool)
	outstruct.IsDispersion = *abi.ConvertType(out[2], new(bool)).(*bool)
	outstruct.IsOracleOff = *abi.ConvertType(out[3], new(bool)).(*bool)

	return *outstruct, err

}

// GetPriceWithCircuitBreakers is a free data retrieval call binding the contract method 0x378ed7f0.
//
// Solidity: function getPriceWithCircuitBreakers((address,address,address,address,uint256,uint256,uint256) args) view returns(uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
func (_SuperAssetPriceLib *SuperAssetPriceLibSession) GetPriceWithCircuitBreakers(args ISuperAssetPriceArgs) (struct {
	PriceUSD     *big.Int
	IsDepeg      bool
	IsDispersion bool
	IsOracleOff  bool
}, error) {
	return _SuperAssetPriceLib.Contract.GetPriceWithCircuitBreakers(&_SuperAssetPriceLib.CallOpts, args)
}

// GetPriceWithCircuitBreakers is a free data retrieval call binding the contract method 0x378ed7f0.
//
// Solidity: function getPriceWithCircuitBreakers((address,address,address,address,uint256,uint256,uint256) args) view returns(uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
func (_SuperAssetPriceLib *SuperAssetPriceLibCallerSession) GetPriceWithCircuitBreakers(args ISuperAssetPriceArgs) (struct {
	PriceUSD     *big.Int
	IsDepeg      bool
	IsDispersion bool
	IsOracleOff  bool
}, error) {
	return _SuperAssetPriceLib.Contract.GetPriceWithCircuitBreakers(&_SuperAssetPriceLib.CallOpts, args)
}
