package mem

import (
	"database/sql"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
)

type blocksQ struct {
	*sync.Mutex

	blocks  map[string]data.Block
	filters []filterer[data.Block]
}

func NewBlocksQ(blocks map[string]data.Block) data.BlocksQ {
	return &blocksQ{
		Mutex:  new(sync.Mutex),
		blocks: blocks,
	}
}

func (b blocksQ) New() data.BlocksQ {
	return NewBlocksQ(b.blocks)
}

func (b blocksQ) Upsert(block data.Block) error {
	return b.Insert(block)
}

func (b blocksQ) Insert(block data.Block) error {
	b.Lock()
	defer b.Unlock()

	b.blocks[block.ID] = block
	return nil
}

func (b blocksQ) Update(block data.Block) error {
	b.Lock()
	defer b.Unlock()

	for _, key := range filterKeys(b.blocks, b.filters) {
		_, ok := b.blocks[key]
		if !ok {
			return sql.ErrNoRows
		}

		b.blocks[key] = block
	}

	return nil
}

func (b blocksQ) Delete() error {
	b.Lock()
	defer b.Unlock()

	for _, key := range filterKeys(b.blocks, b.filters) {
		delete(b.blocks, key)
	}

	return nil
}

func (b blocksQ) Select() ([]data.Block, error) {
	result := make([]data.Block, 0, len(b.blocks))

	for _, value := range b.blocks {
		if filter(b.filters, value) {
			result = append(result, value)
		}
	}

	return result, nil
}

func (b blocksQ) Get() (*data.Block, error) {
	for _, value := range b.blocks {
		if filter(b.filters, value) {
			return &value, nil
		}
	}

	return nil, sql.ErrNoRows
}

func (b blocksQ) FilterByIds(ids ...string) data.BlocksQ {
	b.filters = append(b.filters, func(value data.Block) bool {
		return contains(ids, value.ID)
	})

	return b
}

func (b blocksQ) FilterByChainIds(chains ...uint64) data.BlocksQ {
	b.filters = append(b.filters, func(value data.Block) bool {
		return contains(chains, value.ChainID)
	})

	return b
}

func (b blocksQ) FilterByContracts(contracts ...common.Address) data.BlocksQ {
	contractsStr := make([]string, 0, len(contracts))

	for _, contract := range contracts {
		contractsStr = append(contractsStr, contract.String())
	}

	b.filters = append(b.filters, func(value data.Block) bool {
		return contains(contractsStr, value.Contract.Hex())
	})

	return b
}
