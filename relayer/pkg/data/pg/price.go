package pg

import (
	"math/big"
	"time"

	sq "github.com/Masterminds/squirrel"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"gitlab.com/distributed_lab/kit/pgdb"
)

const (
	pricesTable         = "prices"
	idPricesColumn      = "id"
	chainIdPricesColumn = "chain_id"
	assetPricesColumn   = "asset"
	vaultPricesColumn   = "vault"
)

type priceModel struct {
	ID         string    `db:"id"`
	ChainID    uint64    `db:"chain_id"`
	Asset      string    `db:"asset"`
	Vault      string    `db:"vault"`
	AssetPrice int64     `db:"asset_price"`
	SharePrice int64     `db:"share_price"`
	UpdatedAt  time.Time `db:"updated_at"`
	CreatedAt  time.Time `db:"created_at"`
}

type pricesQ struct {
	db       *pgdb.DB
	selector sq.SelectBuilder
	updater  sq.UpdateBuilder
	deleter  sq.DeleteBuilder
}

func NewPricesQ(db *pgdb.DB) data.PricesQ {
	return &pricesQ{
		db:       db,
		selector: sq.Select("*").From(pricesTable),
		updater:  sq.Update(pricesTable),
		deleter:  sq.Delete(pricesTable),
	}
}

func (q pricesQ) New() data.PricesQ {
	return NewPricesQ(q.db.Clone())
}

func (q pricesQ) Upsert(price data.Price) error {
	updateStmt, args := sq.Update(" ").
		Set("asset_price", price.AssetPrice.Int64()).
		Set("share_price", price.SharePrice.Int64()).
		Set("updated_at", price.UpdatedAt).
		MustSql()

	query := sq.Insert(pricesTable).SetMap(map[string]interface{}{
		"id":          price.ID,
		"chain_id":    price.ChainID,
		"asset":       price.Asset.Hex(),
		"vault":       price.Asset.Hex(),
		"asset_price": price.AssetPrice.Int64(),
		"share_price": price.SharePrice.Int64(),
		"updated_at":  price.UpdatedAt,
		"created_at":  price.CreatedAt,
	}).Suffix("ON CONFLICT (chain_id, vault) DO "+updateStmt, args...)

	return q.db.Exec(query)
}

func (q pricesQ) Insert(price data.Price) error {
	return q.db.Exec(sq.Insert(pricesTable).SetMap(map[string]interface{}{
		"id":          price.ID,
		"chain_id":    price.ChainID,
		"asset":       price.Asset.Hex(),
		"vault":       price.Asset.Hex(),
		"asset_price": price.AssetPrice.Int64(),
		"share_price": price.SharePrice.Int64(),
		"updated_at":  price.UpdatedAt,
		"created_at":  price.CreatedAt,
	}))
}

func (q pricesQ) Update(price data.Price) error {
	return q.db.Exec(q.updater.SetMap(map[string]interface{}{
		"chain_id":    price.ChainID,
		"asset":       price.Asset.Hex(),
		"vault":       price.Asset.Hex(),
		"asset_price": price.AssetPrice.Int64(),
		"share_price": price.SharePrice.Int64(),
		"updated_at":  price.UpdatedAt,
		"created_at":  price.CreatedAt,
	}))
}

func (q pricesQ) Delete() error {
	return q.db.Exec(q.deleter)
}

func (q pricesQ) Select() ([]data.Price, error) {
	var (
		models []priceModel
		result []data.Price
	)

	if err := q.db.Select(&models, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to select prices")
	}

	for _, model := range models {
		result = append(result, data.Price{
			ID:         model.ID,
			ChainID:    model.ChainID,
			Asset:      common.HexToAddress(model.Asset),
			Vault:      common.HexToAddress(model.Vault),
			AssetPrice: new(big.Int).SetInt64(model.AssetPrice),
			SharePrice: new(big.Int).SetInt64(model.SharePrice),
			UpdatedAt:  model.UpdatedAt,
			CreatedAt:  model.CreatedAt,
		})
	}

	return result, nil
}

func (q pricesQ) Get() (*data.Price, error) {
	var model priceModel

	if err := q.db.Get(&model, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to get price")
	}

	return &data.Price{
		ID:         model.ID,
		ChainID:    model.ChainID,
		Asset:      common.HexToAddress(model.Asset),
		Vault:      common.HexToAddress(model.Vault),
		AssetPrice: new(big.Int).SetInt64(model.AssetPrice),
		SharePrice: new(big.Int).SetInt64(model.SharePrice),
		UpdatedAt:  model.UpdatedAt,
		CreatedAt:  model.CreatedAt,
	}, nil
}

func (q pricesQ) FilterByIds(ids ...string) data.PricesQ {
	return q.withFilters(sq.Eq{idPricesColumn: ids})
}

func (q pricesQ) FilterByChainIds(chains ...uint64) data.PricesQ {
	return q.withFilters(sq.Eq{chainIdPricesColumn: chains})
}

func (q pricesQ) FilterByAssets(contracts ...common.Address) data.PricesQ {
	contractsStrings := make([]string, len(contracts))
	for i, contract := range contracts {
		contractsStrings[i] = contract.Hex()
	}

	return q.withFilters(sq.Eq{assetPricesColumn: contractsStrings})
}

func (q pricesQ) FilterByVaults(contracts ...common.Address) data.PricesQ {
	contractsStrings := make([]string, len(contracts))
	for i, contract := range contracts {
		contractsStrings[i] = contract.Hex()
	}

	return q.withFilters(sq.Eq{vaultPricesColumn: contractsStrings})
}

func (q pricesQ) withFilters(stmt interface{}) data.PricesQ {
	q.selector = q.selector.Where(stmt)
	q.updater = q.updater.Where(stmt)
	q.deleter = q.deleter.Where(stmt)

	return q
}
