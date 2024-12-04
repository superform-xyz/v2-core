package mem

import (
	"database/sql"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
)

type pricesQ struct {
	*sync.Mutex

	prices  map[string]data.Price
	filters []filterer[data.Price]
}

func NewPricesQ(prices map[string]data.Price) data.PricesQ {
	return &pricesQ{
		Mutex:  new(sync.Mutex),
		prices: prices,
	}
}

func (p pricesQ) New() data.PricesQ {
	return NewPricesQ(p.prices)
}

func (p pricesQ) Upsert(price data.Price) error {
	return p.Insert(price)
}

func (p pricesQ) Insert(price data.Price) error {
	p.Lock()
	defer p.Unlock()

	p.prices[price.ID] = price
	return nil
}

func (p pricesQ) Update(price data.Price) error {
	p.Lock()
	defer p.Unlock()

	for _, key := range filterKeys(p.prices, p.filters) {
		_, ok := p.prices[key]
		if !ok {
			return sql.ErrNoRows
		}

		p.prices[key] = price
	}

	return nil
}

func (p pricesQ) Delete() error {
	p.Lock()
	defer p.Unlock()

	for _, key := range filterKeys(p.prices, p.filters) {
		delete(p.prices, key)
	}

	return nil
}

func (p pricesQ) Select() ([]data.Price, error) {
	result := make([]data.Price, 0, len(p.prices))

	for _, value := range p.prices {
		if filter(p.filters, value) {
			result = append(result, value)
		}
	}

	return result, nil
}

func (p pricesQ) Get() (*data.Price, error) {
	for _, value := range p.prices {
		if filter(p.filters, value) {
			return &value, nil
		}
	}

	return nil, sql.ErrNoRows
}

func (p pricesQ) FilterByIds(ids ...string) data.PricesQ {
	p.filters = append(p.filters, func(value data.Price) bool {
		return contains(ids, value.ID)
	})

	return p
}

func (p pricesQ) FilterByChainIds(chains ...uint64) data.PricesQ {
	p.filters = append(p.filters, func(value data.Price) bool {
		return contains(chains, value.ChainID)
	})

	return p
}

func (p pricesQ) FilterByAssets(contracts ...common.Address) data.PricesQ {
	contractsStr := make([]string, 0, len(contracts))

	for _, contract := range contracts {
		contractsStr = append(contractsStr, contract.String())
	}

	p.filters = append(p.filters, func(value data.Price) bool {
		return contains(contractsStr, value.Asset.Hex())
	})

	return p
}

func (p pricesQ) FilterByVaults(contracts ...common.Address) data.PricesQ {
	contractsStr := make([]string, 0, len(contracts))

	for _, contract := range contracts {
		contractsStr = append(contractsStr, contract.String())
	}

	p.filters = append(p.filters, func(value data.Price) bool {
		return contains(contractsStr, value.Vault.Hex())
	})

	return p
}
