package pg

import (
	"time"

	sq "github.com/Masterminds/squirrel"
	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"gitlab.com/distributed_lab/kit/pgdb"
)

const (
	txsTable = "transactions"

	idTxsColumn     = "id"
	statusTxsColumn = "status"
)

type txModel struct {
	ID         string        `db:"id"`
	ChainID    uint64        `db:"chain_id"`
	Address    string        `db:"address"`
	Data       []byte        `db:"data"`
	GasLimit   uint64        `db:"gas_limit"`
	RawTx      []byte        `db:"raw_tx"`
	RawReceipt []byte        `db:"raw_receipt"`
	Status     data.TxStatus `db:"status"`
	Msg        string        `db:"msg"`
	UpdatedAt  time.Time     `db:"updated_at"`
	CreatedAt  time.Time     `db:"created_at"`
}

type transactionsQ struct {
	db       *pgdb.DB
	selector sq.SelectBuilder
	updater  sq.UpdateBuilder
	deleter  sq.DeleteBuilder
}

func NewTransactionsQ(db *pgdb.DB) data.TransactionsQ {
	return &transactionsQ{
		db:       db,
		selector: sq.Select("*").From(txsTable),
		updater:  sq.Update(txsTable),
		deleter:  sq.Delete(txsTable),
	}
}

func (q transactionsQ) New() data.TransactionsQ {
	return NewTransactionsQ(q.db.Clone())
}

func (q transactionsQ) Insert(tx data.Transaction) error {
	modelData, err := transactionToTxModel(tx)
	if err != nil {
		return errors.Wrap(err, "failed to convert tx to model data")
	}

	return q.db.Exec(sq.Insert(txsTable).SetMap(modelData))
}

func (q transactionsQ) Update(tx data.Transaction) error {
	modelData, err := transactionToTxModel(tx)
	if err != nil {
		return errors.Wrap(err, "failed to convert tx to model data")
	}

	return q.db.Exec(q.updater.SetMap(modelData))
}

func (q transactionsQ) Delete() error {
	return q.db.Exec(q.deleter)
}

func (q transactionsQ) Select() ([]data.Transaction, error) {
	var (
		models []txModel
		result []data.Transaction
	)

	if err := q.db.Select(&models, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to select transactions")
	}

	for _, model := range models {
		tx, err := txModelToTransaction(model)
		if err != nil {
			return nil, errors.Wrap(err, "failed to convert model to transaction")
		}
		result = append(result, *tx)
	}

	return result, nil
}

func (q transactionsQ) Get() (*data.Transaction, error) {
	var model txModel

	if err := q.db.Get(&model, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to get transaction")
	}

	tx, err := txModelToTransaction(model)
	if err != nil {
		return nil, errors.Wrap(err, "failed to convert model to transaction")
	}

	return tx, nil
}

func (q transactionsQ) FilterByIds(ids ...string) data.TransactionsQ {
	return q.withFilters(sq.Eq{idTxsColumn: ids})
}

func (q transactionsQ) FilterByStatus(status data.TxStatus) data.TransactionsQ {
	return q.withFilters(sq.Eq{statusTxsColumn: status})
}

func (q transactionsQ) withFilters(stmt interface{}) data.TransactionsQ {
	q.selector = q.selector.Where(stmt)
	q.updater = q.updater.Where(stmt)
	q.deleter = q.deleter.Where(stmt)

	return q
}
