package data

import (
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
)

type PricesQ interface {
	New() PricesQ

	Upsert(price Price) error
	Insert(price Price) error
	Update(price Price) error
	Delete() error

	Select() ([]Price, error)
	Get() (*Price, error)

	FilterByIds(ids ...string) PricesQ
	FilterByChainIds(chains ...uint64) PricesQ
	FilterByAssets(contracts ...common.Address) PricesQ
	FilterByVaults(contracts ...common.Address) PricesQ
}

type Price struct {
	ID         string
	ChainID    uint64
	Asset      common.Address
	Vault      common.Address
	AssetPrice *big.Int
	SharePrice *big.Int
	UpdatedAt  time.Time
	CreatedAt  time.Time
}
