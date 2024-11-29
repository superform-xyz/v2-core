package data

import (
	"github.com/ethereum/go-ethereum/common"
)

type BlocksQ interface {
	New() BlocksQ

	Upsert(block Block) error
	Insert(block Block) error
	Update(block Block) error
	Delete() error

	Select() ([]Block, error)
	Get() (*Block, error)

	FilterByIds(ids ...string) BlocksQ
	FilterByChainIds(chains ...uint64) BlocksQ
	FilterByContracts(contracts ...common.Address) BlocksQ
}

type Block struct {
	ID       string
	ChainID  uint64
	Contract common.Address
	Number   uint64
}
