// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperCollectiveVault

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

// SuperCollectiveVaultMetaData contains all meta data concerning the SuperCollectiveVault contract.
var SuperCollectiveVaultMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"owner_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"allowedExecutors_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"batchClaim\",\"inputs\":[{\"name\":\"targets\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"gasLimit\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"val\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"maxReturnDataCopy\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"batchUnlock\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"tokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"amounts\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"canClaim\",\"inputs\":[{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"rewardToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"proof\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"claim\",\"inputs\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"maxReturnDataCopy\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"distributeRewards\",\"inputs\":[{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"rewardToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"proof\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isMerkleRootRegistered\",\"inputs\":[{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lock\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unlock\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"updateMerkleRoot\",\"inputs\":[{\"name\":\"merkleRoot_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"status\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"viewAllLockedAssets\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"viewLockedAmount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"BatchClaimRewards\",\"inputs\":[{\"name\":\"targets\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ClaimRewards\",\"inputs\":[{\"name\":\"target\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"result\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"DistributeRewards\",\"inputs\":[{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"rewardToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Lock\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MerkleRootUpdated\",\"inputs\":[{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"status\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unlock\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ALREADY_DISTRIBUTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CLAIM_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_AMOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CLAIM_TARGET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_MERKLE_ROOT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOTHING_TO_CLAIM\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_LOCKED_ASSETS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OwnableInvalidOwner\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TOKEN_NOT_FOUND\",\"inputs\":[]}]",
}

// SuperCollectiveVaultABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperCollectiveVaultMetaData.ABI instead.
var SuperCollectiveVaultABI = SuperCollectiveVaultMetaData.ABI

// SuperCollectiveVault is an auto generated Go binding around an Ethereum contract.
type SuperCollectiveVault struct {
	SuperCollectiveVaultCaller     // Read-only binding to the contract
	SuperCollectiveVaultTransactor // Write-only binding to the contract
	SuperCollectiveVaultFilterer   // Log filterer for contract events
}

// SuperCollectiveVaultCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperCollectiveVaultCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperCollectiveVaultTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperCollectiveVaultTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperCollectiveVaultFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperCollectiveVaultFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperCollectiveVaultSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperCollectiveVaultSession struct {
	Contract     *SuperCollectiveVault // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// SuperCollectiveVaultCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperCollectiveVaultCallerSession struct {
	Contract *SuperCollectiveVaultCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// SuperCollectiveVaultTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperCollectiveVaultTransactorSession struct {
	Contract     *SuperCollectiveVaultTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// SuperCollectiveVaultRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperCollectiveVaultRaw struct {
	Contract *SuperCollectiveVault // Generic contract binding to access the raw methods on
}

// SuperCollectiveVaultCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperCollectiveVaultCallerRaw struct {
	Contract *SuperCollectiveVaultCaller // Generic read-only contract binding to access the raw methods on
}

// SuperCollectiveVaultTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperCollectiveVaultTransactorRaw struct {
	Contract *SuperCollectiveVaultTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperCollectiveVault creates a new instance of SuperCollectiveVault, bound to a specific deployed contract.
func NewSuperCollectiveVault(address common.Address, backend bind.ContractBackend) (*SuperCollectiveVault, error) {
	contract, err := bindSuperCollectiveVault(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVault{SuperCollectiveVaultCaller: SuperCollectiveVaultCaller{contract: contract}, SuperCollectiveVaultTransactor: SuperCollectiveVaultTransactor{contract: contract}, SuperCollectiveVaultFilterer: SuperCollectiveVaultFilterer{contract: contract}}, nil
}

// NewSuperCollectiveVaultCaller creates a new read-only instance of SuperCollectiveVault, bound to a specific deployed contract.
func NewSuperCollectiveVaultCaller(address common.Address, caller bind.ContractCaller) (*SuperCollectiveVaultCaller, error) {
	contract, err := bindSuperCollectiveVault(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultCaller{contract: contract}, nil
}

// NewSuperCollectiveVaultTransactor creates a new write-only instance of SuperCollectiveVault, bound to a specific deployed contract.
func NewSuperCollectiveVaultTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperCollectiveVaultTransactor, error) {
	contract, err := bindSuperCollectiveVault(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultTransactor{contract: contract}, nil
}

// NewSuperCollectiveVaultFilterer creates a new log filterer instance of SuperCollectiveVault, bound to a specific deployed contract.
func NewSuperCollectiveVaultFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperCollectiveVaultFilterer, error) {
	contract, err := bindSuperCollectiveVault(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultFilterer{contract: contract}, nil
}

// bindSuperCollectiveVault binds a generic wrapper to an already deployed contract.
func bindSuperCollectiveVault(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperCollectiveVaultMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperCollectiveVault *SuperCollectiveVaultRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperCollectiveVault.Contract.SuperCollectiveVaultCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperCollectiveVault *SuperCollectiveVaultRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.SuperCollectiveVaultTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperCollectiveVault *SuperCollectiveVaultRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.SuperCollectiveVaultTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperCollectiveVault *SuperCollectiveVaultCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperCollectiveVault.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.contract.Transact(opts, method, params...)
}

// CanClaim is a free data retrieval call binding the contract method 0xe3a4f6cc.
//
// Solidity: function canClaim(bytes32 merkleRoot, address account, address rewardToken, uint256 amount, bytes32[] proof) view returns(bool)
func (_SuperCollectiveVault *SuperCollectiveVaultCaller) CanClaim(opts *bind.CallOpts, merkleRoot [32]byte, account common.Address, rewardToken common.Address, amount *big.Int, proof [][32]byte) (bool, error) {
	var out []interface{}
	err := _SuperCollectiveVault.contract.Call(opts, &out, "canClaim", merkleRoot, account, rewardToken, amount, proof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// CanClaim is a free data retrieval call binding the contract method 0xe3a4f6cc.
//
// Solidity: function canClaim(bytes32 merkleRoot, address account, address rewardToken, uint256 amount, bytes32[] proof) view returns(bool)
func (_SuperCollectiveVault *SuperCollectiveVaultSession) CanClaim(merkleRoot [32]byte, account common.Address, rewardToken common.Address, amount *big.Int, proof [][32]byte) (bool, error) {
	return _SuperCollectiveVault.Contract.CanClaim(&_SuperCollectiveVault.CallOpts, merkleRoot, account, rewardToken, amount, proof)
}

// CanClaim is a free data retrieval call binding the contract method 0xe3a4f6cc.
//
// Solidity: function canClaim(bytes32 merkleRoot, address account, address rewardToken, uint256 amount, bytes32[] proof) view returns(bool)
func (_SuperCollectiveVault *SuperCollectiveVaultCallerSession) CanClaim(merkleRoot [32]byte, account common.Address, rewardToken common.Address, amount *big.Int, proof [][32]byte) (bool, error) {
	return _SuperCollectiveVault.Contract.CanClaim(&_SuperCollectiveVault.CallOpts, merkleRoot, account, rewardToken, amount, proof)
}

// IsMerkleRootRegistered is a free data retrieval call binding the contract method 0x6143ee14.
//
// Solidity: function isMerkleRootRegistered(bytes32 merkleRoot) view returns(bool)
func (_SuperCollectiveVault *SuperCollectiveVaultCaller) IsMerkleRootRegistered(opts *bind.CallOpts, merkleRoot [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperCollectiveVault.contract.Call(opts, &out, "isMerkleRootRegistered", merkleRoot)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMerkleRootRegistered is a free data retrieval call binding the contract method 0x6143ee14.
//
// Solidity: function isMerkleRootRegistered(bytes32 merkleRoot) view returns(bool)
func (_SuperCollectiveVault *SuperCollectiveVaultSession) IsMerkleRootRegistered(merkleRoot [32]byte) (bool, error) {
	return _SuperCollectiveVault.Contract.IsMerkleRootRegistered(&_SuperCollectiveVault.CallOpts, merkleRoot)
}

// IsMerkleRootRegistered is a free data retrieval call binding the contract method 0x6143ee14.
//
// Solidity: function isMerkleRootRegistered(bytes32 merkleRoot) view returns(bool)
func (_SuperCollectiveVault *SuperCollectiveVaultCallerSession) IsMerkleRootRegistered(merkleRoot [32]byte) (bool, error) {
	return _SuperCollectiveVault.Contract.IsMerkleRootRegistered(&_SuperCollectiveVault.CallOpts, merkleRoot)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperCollectiveVault *SuperCollectiveVaultCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperCollectiveVault.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperCollectiveVault *SuperCollectiveVaultSession) Owner() (common.Address, error) {
	return _SuperCollectiveVault.Contract.Owner(&_SuperCollectiveVault.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SuperCollectiveVault *SuperCollectiveVaultCallerSession) Owner() (common.Address, error) {
	return _SuperCollectiveVault.Contract.Owner(&_SuperCollectiveVault.CallOpts)
}

// ViewAllLockedAssets is a free data retrieval call binding the contract method 0x57dbaa97.
//
// Solidity: function viewAllLockedAssets(address account) view returns(address[])
func (_SuperCollectiveVault *SuperCollectiveVaultCaller) ViewAllLockedAssets(opts *bind.CallOpts, account common.Address) ([]common.Address, error) {
	var out []interface{}
	err := _SuperCollectiveVault.contract.Call(opts, &out, "viewAllLockedAssets", account)

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// ViewAllLockedAssets is a free data retrieval call binding the contract method 0x57dbaa97.
//
// Solidity: function viewAllLockedAssets(address account) view returns(address[])
func (_SuperCollectiveVault *SuperCollectiveVaultSession) ViewAllLockedAssets(account common.Address) ([]common.Address, error) {
	return _SuperCollectiveVault.Contract.ViewAllLockedAssets(&_SuperCollectiveVault.CallOpts, account)
}

// ViewAllLockedAssets is a free data retrieval call binding the contract method 0x57dbaa97.
//
// Solidity: function viewAllLockedAssets(address account) view returns(address[])
func (_SuperCollectiveVault *SuperCollectiveVaultCallerSession) ViewAllLockedAssets(account common.Address) ([]common.Address, error) {
	return _SuperCollectiveVault.Contract.ViewAllLockedAssets(&_SuperCollectiveVault.CallOpts, account)
}

// ViewLockedAmount is a free data retrieval call binding the contract method 0xa600128c.
//
// Solidity: function viewLockedAmount(address account, address token) view returns(uint256)
func (_SuperCollectiveVault *SuperCollectiveVaultCaller) ViewLockedAmount(opts *bind.CallOpts, account common.Address, token common.Address) (*big.Int, error) {
	var out []interface{}
	err := _SuperCollectiveVault.contract.Call(opts, &out, "viewLockedAmount", account, token)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ViewLockedAmount is a free data retrieval call binding the contract method 0xa600128c.
//
// Solidity: function viewLockedAmount(address account, address token) view returns(uint256)
func (_SuperCollectiveVault *SuperCollectiveVaultSession) ViewLockedAmount(account common.Address, token common.Address) (*big.Int, error) {
	return _SuperCollectiveVault.Contract.ViewLockedAmount(&_SuperCollectiveVault.CallOpts, account, token)
}

// ViewLockedAmount is a free data retrieval call binding the contract method 0xa600128c.
//
// Solidity: function viewLockedAmount(address account, address token) view returns(uint256)
func (_SuperCollectiveVault *SuperCollectiveVaultCallerSession) ViewLockedAmount(account common.Address, token common.Address) (*big.Int, error) {
	return _SuperCollectiveVault.Contract.ViewLockedAmount(&_SuperCollectiveVault.CallOpts, account, token)
}

// BatchClaim is a paid mutator transaction binding the contract method 0x615770b8.
//
// Solidity: function batchClaim(address[] targets, uint256[] gasLimit, uint256[] val, uint16 maxReturnDataCopy, bytes data) payable returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) BatchClaim(opts *bind.TransactOpts, targets []common.Address, gasLimit []*big.Int, val []*big.Int, maxReturnDataCopy uint16, data []byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "batchClaim", targets, gasLimit, val, maxReturnDataCopy, data)
}

// BatchClaim is a paid mutator transaction binding the contract method 0x615770b8.
//
// Solidity: function batchClaim(address[] targets, uint256[] gasLimit, uint256[] val, uint16 maxReturnDataCopy, bytes data) payable returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) BatchClaim(targets []common.Address, gasLimit []*big.Int, val []*big.Int, maxReturnDataCopy uint16, data []byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.BatchClaim(&_SuperCollectiveVault.TransactOpts, targets, gasLimit, val, maxReturnDataCopy, data)
}

// BatchClaim is a paid mutator transaction binding the contract method 0x615770b8.
//
// Solidity: function batchClaim(address[] targets, uint256[] gasLimit, uint256[] val, uint16 maxReturnDataCopy, bytes data) payable returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) BatchClaim(targets []common.Address, gasLimit []*big.Int, val []*big.Int, maxReturnDataCopy uint16, data []byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.BatchClaim(&_SuperCollectiveVault.TransactOpts, targets, gasLimit, val, maxReturnDataCopy, data)
}

// BatchUnlock is a paid mutator transaction binding the contract method 0x6ed261b4.
//
// Solidity: function batchUnlock(address account, address[] tokens, uint256[] amounts) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) BatchUnlock(opts *bind.TransactOpts, account common.Address, tokens []common.Address, amounts []*big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "batchUnlock", account, tokens, amounts)
}

// BatchUnlock is a paid mutator transaction binding the contract method 0x6ed261b4.
//
// Solidity: function batchUnlock(address account, address[] tokens, uint256[] amounts) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) BatchUnlock(account common.Address, tokens []common.Address, amounts []*big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.BatchUnlock(&_SuperCollectiveVault.TransactOpts, account, tokens, amounts)
}

// BatchUnlock is a paid mutator transaction binding the contract method 0x6ed261b4.
//
// Solidity: function batchUnlock(address account, address[] tokens, uint256[] amounts) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) BatchUnlock(account common.Address, tokens []common.Address, amounts []*big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.BatchUnlock(&_SuperCollectiveVault.TransactOpts, account, tokens, amounts)
}

// Claim is a paid mutator transaction binding the contract method 0x551fb172.
//
// Solidity: function claim(address target, uint256 gasLimit, uint16 maxReturnDataCopy, bytes data) payable returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) Claim(opts *bind.TransactOpts, target common.Address, gasLimit *big.Int, maxReturnDataCopy uint16, data []byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "claim", target, gasLimit, maxReturnDataCopy, data)
}

// Claim is a paid mutator transaction binding the contract method 0x551fb172.
//
// Solidity: function claim(address target, uint256 gasLimit, uint16 maxReturnDataCopy, bytes data) payable returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) Claim(target common.Address, gasLimit *big.Int, maxReturnDataCopy uint16, data []byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.Claim(&_SuperCollectiveVault.TransactOpts, target, gasLimit, maxReturnDataCopy, data)
}

// Claim is a paid mutator transaction binding the contract method 0x551fb172.
//
// Solidity: function claim(address target, uint256 gasLimit, uint16 maxReturnDataCopy, bytes data) payable returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) Claim(target common.Address, gasLimit *big.Int, maxReturnDataCopy uint16, data []byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.Claim(&_SuperCollectiveVault.TransactOpts, target, gasLimit, maxReturnDataCopy, data)
}

// DistributeRewards is a paid mutator transaction binding the contract method 0x66237bc7.
//
// Solidity: function distributeRewards(bytes32 merkleRoot, address account, address rewardToken, uint256 amount, bytes32[] proof) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) DistributeRewards(opts *bind.TransactOpts, merkleRoot [32]byte, account common.Address, rewardToken common.Address, amount *big.Int, proof [][32]byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "distributeRewards", merkleRoot, account, rewardToken, amount, proof)
}

// DistributeRewards is a paid mutator transaction binding the contract method 0x66237bc7.
//
// Solidity: function distributeRewards(bytes32 merkleRoot, address account, address rewardToken, uint256 amount, bytes32[] proof) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) DistributeRewards(merkleRoot [32]byte, account common.Address, rewardToken common.Address, amount *big.Int, proof [][32]byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.DistributeRewards(&_SuperCollectiveVault.TransactOpts, merkleRoot, account, rewardToken, amount, proof)
}

// DistributeRewards is a paid mutator transaction binding the contract method 0x66237bc7.
//
// Solidity: function distributeRewards(bytes32 merkleRoot, address account, address rewardToken, uint256 amount, bytes32[] proof) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) DistributeRewards(merkleRoot [32]byte, account common.Address, rewardToken common.Address, amount *big.Int, proof [][32]byte) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.DistributeRewards(&_SuperCollectiveVault.TransactOpts, merkleRoot, account, rewardToken, amount, proof)
}

// Lock is a paid mutator transaction binding the contract method 0x7750c9f0.
//
// Solidity: function lock(address account, address token, uint256 amount) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) Lock(opts *bind.TransactOpts, account common.Address, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "lock", account, token, amount)
}

// Lock is a paid mutator transaction binding the contract method 0x7750c9f0.
//
// Solidity: function lock(address account, address token, uint256 amount) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) Lock(account common.Address, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.Lock(&_SuperCollectiveVault.TransactOpts, account, token, amount)
}

// Lock is a paid mutator transaction binding the contract method 0x7750c9f0.
//
// Solidity: function lock(address account, address token, uint256 amount) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) Lock(account common.Address, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.Lock(&_SuperCollectiveVault.TransactOpts, account, token, amount)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) RenounceOwnership() (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.RenounceOwnership(&_SuperCollectiveVault.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.RenounceOwnership(&_SuperCollectiveVault.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.TransferOwnership(&_SuperCollectiveVault.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.TransferOwnership(&_SuperCollectiveVault.TransactOpts, newOwner)
}

// Unlock is a paid mutator transaction binding the contract method 0x59508f8f.
//
// Solidity: function unlock(address account, address token, uint256 amount) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) Unlock(opts *bind.TransactOpts, account common.Address, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "unlock", account, token, amount)
}

// Unlock is a paid mutator transaction binding the contract method 0x59508f8f.
//
// Solidity: function unlock(address account, address token, uint256 amount) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) Unlock(account common.Address, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.Unlock(&_SuperCollectiveVault.TransactOpts, account, token, amount)
}

// Unlock is a paid mutator transaction binding the contract method 0x59508f8f.
//
// Solidity: function unlock(address account, address token, uint256 amount) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) Unlock(account common.Address, token common.Address, amount *big.Int) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.Unlock(&_SuperCollectiveVault.TransactOpts, account, token, amount)
}

// UpdateMerkleRoot is a paid mutator transaction binding the contract method 0xf4e7047b.
//
// Solidity: function updateMerkleRoot(bytes32 merkleRoot_, bool status) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactor) UpdateMerkleRoot(opts *bind.TransactOpts, merkleRoot_ [32]byte, status bool) (*types.Transaction, error) {
	return _SuperCollectiveVault.contract.Transact(opts, "updateMerkleRoot", merkleRoot_, status)
}

// UpdateMerkleRoot is a paid mutator transaction binding the contract method 0xf4e7047b.
//
// Solidity: function updateMerkleRoot(bytes32 merkleRoot_, bool status) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultSession) UpdateMerkleRoot(merkleRoot_ [32]byte, status bool) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.UpdateMerkleRoot(&_SuperCollectiveVault.TransactOpts, merkleRoot_, status)
}

// UpdateMerkleRoot is a paid mutator transaction binding the contract method 0xf4e7047b.
//
// Solidity: function updateMerkleRoot(bytes32 merkleRoot_, bool status) returns()
func (_SuperCollectiveVault *SuperCollectiveVaultTransactorSession) UpdateMerkleRoot(merkleRoot_ [32]byte, status bool) (*types.Transaction, error) {
	return _SuperCollectiveVault.Contract.UpdateMerkleRoot(&_SuperCollectiveVault.TransactOpts, merkleRoot_, status)
}

// SuperCollectiveVaultBatchClaimRewardsIterator is returned from FilterBatchClaimRewards and is used to iterate over the raw logs and unpacked data for BatchClaimRewards events raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultBatchClaimRewardsIterator struct {
	Event *SuperCollectiveVaultBatchClaimRewards // Event containing the contract specifics and raw log

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
func (it *SuperCollectiveVaultBatchClaimRewardsIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperCollectiveVaultBatchClaimRewards)
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
		it.Event = new(SuperCollectiveVaultBatchClaimRewards)
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
func (it *SuperCollectiveVaultBatchClaimRewardsIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperCollectiveVaultBatchClaimRewardsIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperCollectiveVaultBatchClaimRewards represents a BatchClaimRewards event raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultBatchClaimRewards struct {
	Targets []common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBatchClaimRewards is a free log retrieval operation binding the contract event 0xef69d1b2a25a6199af62e942b158d9d5f6d2807ed2704cb7b0b1138bf55aa0d6.
//
// Solidity: event BatchClaimRewards(address[] targets)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) FilterBatchClaimRewards(opts *bind.FilterOpts) (*SuperCollectiveVaultBatchClaimRewardsIterator, error) {

	logs, sub, err := _SuperCollectiveVault.contract.FilterLogs(opts, "BatchClaimRewards")
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultBatchClaimRewardsIterator{contract: _SuperCollectiveVault.contract, event: "BatchClaimRewards", logs: logs, sub: sub}, nil
}

// WatchBatchClaimRewards is a free log subscription operation binding the contract event 0xef69d1b2a25a6199af62e942b158d9d5f6d2807ed2704cb7b0b1138bf55aa0d6.
//
// Solidity: event BatchClaimRewards(address[] targets)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) WatchBatchClaimRewards(opts *bind.WatchOpts, sink chan<- *SuperCollectiveVaultBatchClaimRewards) (event.Subscription, error) {

	logs, sub, err := _SuperCollectiveVault.contract.WatchLogs(opts, "BatchClaimRewards")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperCollectiveVaultBatchClaimRewards)
				if err := _SuperCollectiveVault.contract.UnpackLog(event, "BatchClaimRewards", log); err != nil {
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

// ParseBatchClaimRewards is a log parse operation binding the contract event 0xef69d1b2a25a6199af62e942b158d9d5f6d2807ed2704cb7b0b1138bf55aa0d6.
//
// Solidity: event BatchClaimRewards(address[] targets)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) ParseBatchClaimRewards(log types.Log) (*SuperCollectiveVaultBatchClaimRewards, error) {
	event := new(SuperCollectiveVaultBatchClaimRewards)
	if err := _SuperCollectiveVault.contract.UnpackLog(event, "BatchClaimRewards", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperCollectiveVaultClaimRewardsIterator is returned from FilterClaimRewards and is used to iterate over the raw logs and unpacked data for ClaimRewards events raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultClaimRewardsIterator struct {
	Event *SuperCollectiveVaultClaimRewards // Event containing the contract specifics and raw log

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
func (it *SuperCollectiveVaultClaimRewardsIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperCollectiveVaultClaimRewards)
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
		it.Event = new(SuperCollectiveVaultClaimRewards)
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
func (it *SuperCollectiveVaultClaimRewardsIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperCollectiveVaultClaimRewardsIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperCollectiveVaultClaimRewards represents a ClaimRewards event raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultClaimRewards struct {
	Target common.Address
	Result []byte
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterClaimRewards is a free log retrieval operation binding the contract event 0xfa1545f8817220aeace5cd10bd4bd6159c49c09c03569b0b5000d0f6abbe55bb.
//
// Solidity: event ClaimRewards(address indexed target, bytes result)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) FilterClaimRewards(opts *bind.FilterOpts, target []common.Address) (*SuperCollectiveVaultClaimRewardsIterator, error) {

	var targetRule []interface{}
	for _, targetItem := range target {
		targetRule = append(targetRule, targetItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.FilterLogs(opts, "ClaimRewards", targetRule)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultClaimRewardsIterator{contract: _SuperCollectiveVault.contract, event: "ClaimRewards", logs: logs, sub: sub}, nil
}

// WatchClaimRewards is a free log subscription operation binding the contract event 0xfa1545f8817220aeace5cd10bd4bd6159c49c09c03569b0b5000d0f6abbe55bb.
//
// Solidity: event ClaimRewards(address indexed target, bytes result)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) WatchClaimRewards(opts *bind.WatchOpts, sink chan<- *SuperCollectiveVaultClaimRewards, target []common.Address) (event.Subscription, error) {

	var targetRule []interface{}
	for _, targetItem := range target {
		targetRule = append(targetRule, targetItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.WatchLogs(opts, "ClaimRewards", targetRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperCollectiveVaultClaimRewards)
				if err := _SuperCollectiveVault.contract.UnpackLog(event, "ClaimRewards", log); err != nil {
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

// ParseClaimRewards is a log parse operation binding the contract event 0xfa1545f8817220aeace5cd10bd4bd6159c49c09c03569b0b5000d0f6abbe55bb.
//
// Solidity: event ClaimRewards(address indexed target, bytes result)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) ParseClaimRewards(log types.Log) (*SuperCollectiveVaultClaimRewards, error) {
	event := new(SuperCollectiveVaultClaimRewards)
	if err := _SuperCollectiveVault.contract.UnpackLog(event, "ClaimRewards", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperCollectiveVaultDistributeRewardsIterator is returned from FilterDistributeRewards and is used to iterate over the raw logs and unpacked data for DistributeRewards events raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultDistributeRewardsIterator struct {
	Event *SuperCollectiveVaultDistributeRewards // Event containing the contract specifics and raw log

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
func (it *SuperCollectiveVaultDistributeRewardsIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperCollectiveVaultDistributeRewards)
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
		it.Event = new(SuperCollectiveVaultDistributeRewards)
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
func (it *SuperCollectiveVaultDistributeRewardsIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperCollectiveVaultDistributeRewardsIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperCollectiveVaultDistributeRewards represents a DistributeRewards event raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultDistributeRewards struct {
	MerkleRoot  [32]byte
	Account     common.Address
	RewardToken common.Address
	Amount      *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterDistributeRewards is a free log retrieval operation binding the contract event 0x6500baecc7450209c605a9ac3603eee397dd7af89f0e83120666d26e62d310bd.
//
// Solidity: event DistributeRewards(bytes32 indexed merkleRoot, address indexed account, address indexed rewardToken, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) FilterDistributeRewards(opts *bind.FilterOpts, merkleRoot [][32]byte, account []common.Address, rewardToken []common.Address) (*SuperCollectiveVaultDistributeRewardsIterator, error) {

	var merkleRootRule []interface{}
	for _, merkleRootItem := range merkleRoot {
		merkleRootRule = append(merkleRootRule, merkleRootItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var rewardTokenRule []interface{}
	for _, rewardTokenItem := range rewardToken {
		rewardTokenRule = append(rewardTokenRule, rewardTokenItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.FilterLogs(opts, "DistributeRewards", merkleRootRule, accountRule, rewardTokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultDistributeRewardsIterator{contract: _SuperCollectiveVault.contract, event: "DistributeRewards", logs: logs, sub: sub}, nil
}

// WatchDistributeRewards is a free log subscription operation binding the contract event 0x6500baecc7450209c605a9ac3603eee397dd7af89f0e83120666d26e62d310bd.
//
// Solidity: event DistributeRewards(bytes32 indexed merkleRoot, address indexed account, address indexed rewardToken, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) WatchDistributeRewards(opts *bind.WatchOpts, sink chan<- *SuperCollectiveVaultDistributeRewards, merkleRoot [][32]byte, account []common.Address, rewardToken []common.Address) (event.Subscription, error) {

	var merkleRootRule []interface{}
	for _, merkleRootItem := range merkleRoot {
		merkleRootRule = append(merkleRootRule, merkleRootItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var rewardTokenRule []interface{}
	for _, rewardTokenItem := range rewardToken {
		rewardTokenRule = append(rewardTokenRule, rewardTokenItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.WatchLogs(opts, "DistributeRewards", merkleRootRule, accountRule, rewardTokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperCollectiveVaultDistributeRewards)
				if err := _SuperCollectiveVault.contract.UnpackLog(event, "DistributeRewards", log); err != nil {
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

// ParseDistributeRewards is a log parse operation binding the contract event 0x6500baecc7450209c605a9ac3603eee397dd7af89f0e83120666d26e62d310bd.
//
// Solidity: event DistributeRewards(bytes32 indexed merkleRoot, address indexed account, address indexed rewardToken, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) ParseDistributeRewards(log types.Log) (*SuperCollectiveVaultDistributeRewards, error) {
	event := new(SuperCollectiveVaultDistributeRewards)
	if err := _SuperCollectiveVault.contract.UnpackLog(event, "DistributeRewards", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperCollectiveVaultLockIterator is returned from FilterLock and is used to iterate over the raw logs and unpacked data for Lock events raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultLockIterator struct {
	Event *SuperCollectiveVaultLock // Event containing the contract specifics and raw log

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
func (it *SuperCollectiveVaultLockIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperCollectiveVaultLock)
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
		it.Event = new(SuperCollectiveVaultLock)
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
func (it *SuperCollectiveVaultLockIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperCollectiveVaultLockIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperCollectiveVaultLock represents a Lock event raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultLock struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterLock is a free log retrieval operation binding the contract event 0xec36c0364d931187a76cf66d7eee08fad0ec2e8b7458a8d8b26b36769d4d13f3.
//
// Solidity: event Lock(address indexed account, address indexed token, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) FilterLock(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*SuperCollectiveVaultLockIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.FilterLogs(opts, "Lock", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultLockIterator{contract: _SuperCollectiveVault.contract, event: "Lock", logs: logs, sub: sub}, nil
}

// WatchLock is a free log subscription operation binding the contract event 0xec36c0364d931187a76cf66d7eee08fad0ec2e8b7458a8d8b26b36769d4d13f3.
//
// Solidity: event Lock(address indexed account, address indexed token, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) WatchLock(opts *bind.WatchOpts, sink chan<- *SuperCollectiveVaultLock, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.WatchLogs(opts, "Lock", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperCollectiveVaultLock)
				if err := _SuperCollectiveVault.contract.UnpackLog(event, "Lock", log); err != nil {
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

// ParseLock is a log parse operation binding the contract event 0xec36c0364d931187a76cf66d7eee08fad0ec2e8b7458a8d8b26b36769d4d13f3.
//
// Solidity: event Lock(address indexed account, address indexed token, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) ParseLock(log types.Log) (*SuperCollectiveVaultLock, error) {
	event := new(SuperCollectiveVaultLock)
	if err := _SuperCollectiveVault.contract.UnpackLog(event, "Lock", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperCollectiveVaultMerkleRootUpdatedIterator is returned from FilterMerkleRootUpdated and is used to iterate over the raw logs and unpacked data for MerkleRootUpdated events raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultMerkleRootUpdatedIterator struct {
	Event *SuperCollectiveVaultMerkleRootUpdated // Event containing the contract specifics and raw log

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
func (it *SuperCollectiveVaultMerkleRootUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperCollectiveVaultMerkleRootUpdated)
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
		it.Event = new(SuperCollectiveVaultMerkleRootUpdated)
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
func (it *SuperCollectiveVaultMerkleRootUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperCollectiveVaultMerkleRootUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperCollectiveVaultMerkleRootUpdated represents a MerkleRootUpdated event raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultMerkleRootUpdated struct {
	MerkleRoot [32]byte
	Status     bool
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterMerkleRootUpdated is a free log retrieval operation binding the contract event 0xc72271867375e4dc99b635d35b37f44698b889895effb6891602e23128d4f68d.
//
// Solidity: event MerkleRootUpdated(bytes32 indexed merkleRoot, bool status)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) FilterMerkleRootUpdated(opts *bind.FilterOpts, merkleRoot [][32]byte) (*SuperCollectiveVaultMerkleRootUpdatedIterator, error) {

	var merkleRootRule []interface{}
	for _, merkleRootItem := range merkleRoot {
		merkleRootRule = append(merkleRootRule, merkleRootItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.FilterLogs(opts, "MerkleRootUpdated", merkleRootRule)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultMerkleRootUpdatedIterator{contract: _SuperCollectiveVault.contract, event: "MerkleRootUpdated", logs: logs, sub: sub}, nil
}

// WatchMerkleRootUpdated is a free log subscription operation binding the contract event 0xc72271867375e4dc99b635d35b37f44698b889895effb6891602e23128d4f68d.
//
// Solidity: event MerkleRootUpdated(bytes32 indexed merkleRoot, bool status)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) WatchMerkleRootUpdated(opts *bind.WatchOpts, sink chan<- *SuperCollectiveVaultMerkleRootUpdated, merkleRoot [][32]byte) (event.Subscription, error) {

	var merkleRootRule []interface{}
	for _, merkleRootItem := range merkleRoot {
		merkleRootRule = append(merkleRootRule, merkleRootItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.WatchLogs(opts, "MerkleRootUpdated", merkleRootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperCollectiveVaultMerkleRootUpdated)
				if err := _SuperCollectiveVault.contract.UnpackLog(event, "MerkleRootUpdated", log); err != nil {
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

// ParseMerkleRootUpdated is a log parse operation binding the contract event 0xc72271867375e4dc99b635d35b37f44698b889895effb6891602e23128d4f68d.
//
// Solidity: event MerkleRootUpdated(bytes32 indexed merkleRoot, bool status)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) ParseMerkleRootUpdated(log types.Log) (*SuperCollectiveVaultMerkleRootUpdated, error) {
	event := new(SuperCollectiveVaultMerkleRootUpdated)
	if err := _SuperCollectiveVault.contract.UnpackLog(event, "MerkleRootUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperCollectiveVaultOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultOwnershipTransferredIterator struct {
	Event *SuperCollectiveVaultOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SuperCollectiveVaultOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperCollectiveVaultOwnershipTransferred)
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
		it.Event = new(SuperCollectiveVaultOwnershipTransferred)
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
func (it *SuperCollectiveVaultOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperCollectiveVaultOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperCollectiveVaultOwnershipTransferred represents a OwnershipTransferred event raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SuperCollectiveVaultOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultOwnershipTransferredIterator{contract: _SuperCollectiveVault.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SuperCollectiveVaultOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperCollectiveVaultOwnershipTransferred)
				if err := _SuperCollectiveVault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) ParseOwnershipTransferred(log types.Log) (*SuperCollectiveVaultOwnershipTransferred, error) {
	event := new(SuperCollectiveVaultOwnershipTransferred)
	if err := _SuperCollectiveVault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperCollectiveVaultUnlockIterator is returned from FilterUnlock and is used to iterate over the raw logs and unpacked data for Unlock events raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultUnlockIterator struct {
	Event *SuperCollectiveVaultUnlock // Event containing the contract specifics and raw log

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
func (it *SuperCollectiveVaultUnlockIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperCollectiveVaultUnlock)
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
		it.Event = new(SuperCollectiveVaultUnlock)
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
func (it *SuperCollectiveVaultUnlockIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperCollectiveVaultUnlockIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperCollectiveVaultUnlock represents a Unlock event raised by the SuperCollectiveVault contract.
type SuperCollectiveVaultUnlock struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnlock is a free log retrieval operation binding the contract event 0xc1c90b8e0705b212262c0dbd7580efe1862c2f185bf96899226f7596beb2db09.
//
// Solidity: event Unlock(address indexed account, address indexed token, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) FilterUnlock(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*SuperCollectiveVaultUnlockIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.FilterLogs(opts, "Unlock", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperCollectiveVaultUnlockIterator{contract: _SuperCollectiveVault.contract, event: "Unlock", logs: logs, sub: sub}, nil
}

// WatchUnlock is a free log subscription operation binding the contract event 0xc1c90b8e0705b212262c0dbd7580efe1862c2f185bf96899226f7596beb2db09.
//
// Solidity: event Unlock(address indexed account, address indexed token, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) WatchUnlock(opts *bind.WatchOpts, sink chan<- *SuperCollectiveVaultUnlock, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperCollectiveVault.contract.WatchLogs(opts, "Unlock", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperCollectiveVaultUnlock)
				if err := _SuperCollectiveVault.contract.UnpackLog(event, "Unlock", log); err != nil {
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

// ParseUnlock is a log parse operation binding the contract event 0xc1c90b8e0705b212262c0dbd7580efe1862c2f185bf96899226f7596beb2db09.
//
// Solidity: event Unlock(address indexed account, address indexed token, uint256 amount)
func (_SuperCollectiveVault *SuperCollectiveVaultFilterer) ParseUnlock(log types.Log) (*SuperCollectiveVaultUnlock, error) {
	event := new(SuperCollectiveVaultUnlock)
	if err := _SuperCollectiveVault.contract.UnpackLog(event, "Unlock", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
