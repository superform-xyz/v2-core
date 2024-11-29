package pg

import (
	sq "github.com/Masterminds/squirrel"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"gitlab.com/distributed_lab/kit/pgdb"
)

const (
	blocksTable          = "blocks"
	idBlocksColumn       = "id"
	chainIdBlocksColumn  = "chain_id"
	contractBlocksColumn = "contract"
)

type blockModel struct {
	ID       string `db:"id"`
	ChainID  uint64 `db:"chain_id"`
	Contract string `db:"contract"`
	Number   uint64 `db:"number"`
}

type blocksQ struct {
	db       *pgdb.DB
	selector sq.SelectBuilder
	updater  sq.UpdateBuilder
	deleter  sq.DeleteBuilder
}

func NewBlocksQ(db *pgdb.DB) data.BlocksQ {
	return &blocksQ{
		db:       db,
		selector: sq.Select("*").From(blocksTable),
		updater:  sq.Update(blocksTable),
		deleter:  sq.Delete(blocksTable),
	}
}

func (q blocksQ) New() data.BlocksQ {
	return NewBlocksQ(q.db.Clone())
}

func (q blocksQ) Upsert(block data.Block) error {
	return q.db.Exec(sq.Insert(blocksTable).SetMap(map[string]interface{}{
		"id":       block.ID,
		"chain_id": block.ChainID,
		"contract": block.Contract.Hex(),
		"number":   block.Number,
	}).Suffix("ON CONFLICT (chain_id, contract) DO UPDATE SET number = EXCLUDED.number"))
}

func (q blocksQ) Insert(block data.Block) error {
	return q.db.Exec(sq.Insert(blocksTable).SetMap(map[string]interface{}{
		"id":       block.ID,
		"chain_id": block.ChainID,
		"contract": block.Contract.Hex(),
		"number":   block.Number,
	}))
}

func (q blocksQ) Update(block data.Block) error {
	return q.db.Exec(q.updater.SetMap(map[string]interface{}{
		"id":       block.ID,
		"chain_id": block.ChainID,
		"contract": block.Contract.Hex(),
		"number":   block.Number,
	}))
}

func (q blocksQ) Delete() error {
	return q.db.Exec(q.deleter)
}

func (q blocksQ) Select() ([]data.Block, error) {
	var (
		models []blockModel
		result []data.Block
	)

	if err := q.db.Select(&models, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to select blocks")
	}

	for _, model := range models {
		result = append(result, data.Block{
			ID:       model.ID,
			ChainID:  model.ChainID,
			Contract: common.HexToAddress(model.Contract),
			Number:   model.Number,
		})
	}

	return result, nil
}

func (q blocksQ) Get() (*data.Block, error) {
	var model blockModel

	if err := q.db.Get(&model, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to get block")
	}

	return &data.Block{
		ID:       model.ID,
		ChainID:  model.ChainID,
		Contract: common.HexToAddress(model.Contract),
		Number:   model.Number,
	}, nil
}

func (q blocksQ) FilterByIds(ids ...string) data.BlocksQ {
	return q.withFilters(sq.Eq{idBlocksColumn: ids})
}

func (q blocksQ) FilterByChainIds(chains ...uint64) data.BlocksQ {
	return q.withFilters(sq.Eq{chainIdBlocksColumn: chains})
}

func (q blocksQ) FilterByContracts(contracts ...common.Address) data.BlocksQ {
	contractsStrings := make([]string, len(contracts))
	for i, contract := range contracts {
		contractsStrings[i] = contract.Hex()
	}

	return q.withFilters(sq.Eq{contractBlocksColumn: contractsStrings})
}

func (q blocksQ) withFilters(stmt interface{}) data.BlocksQ {
	q.selector = q.selector.Where(stmt)
	q.updater = q.updater.Where(stmt)
	q.deleter = q.deleter.Where(stmt)

	return q
}
