package mem

import (
	"database/sql"
	"sync"

	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
)

type txsQ struct {
	*sync.Mutex

	txs     map[string]data.Transaction
	filters []filterer[data.Transaction]
}

func NewTransactionsQ(txs map[string]data.Transaction) data.TransactionsQ {
	return &txsQ{
		Mutex: new(sync.Mutex),
		txs:   txs,
	}
}

func (t txsQ) New() data.TransactionsQ {
	return NewTransactionsQ(t.txs)
}

func (t txsQ) Insert(tx data.Transaction) error {
	t.Lock()
	defer t.Unlock()

	t.txs[tx.ID] = tx
	return nil
}

func (t txsQ) Update(tx data.Transaction) error {
	t.Lock()
	defer t.Unlock()

	for _, key := range filterKeys(t.txs, t.filters) {
		_, ok := t.txs[key]
		if !ok {
			return errors.Errorf("transaction not found %s", tx.ID)
		}

		t.txs[key] = tx
	}

	return nil
}

func (t txsQ) Delete() error {
	t.Lock()
	defer t.Unlock()

	for _, key := range filterKeys(t.txs, t.filters) {
		delete(t.txs, key)
	}

	return nil
}

func (t txsQ) Select() ([]data.Transaction, error) {
	result := make([]data.Transaction, 0, len(t.txs))

	for _, value := range t.txs {
		if filter(t.filters, value) {
			result = append(result, value)
		}
	}

	return result, nil
}

func (t txsQ) Get() (*data.Transaction, error) {
	for _, value := range t.txs {
		if filter(t.filters, value) {
			return &value, nil
		}
	}

	return nil, sql.ErrNoRows
}

func (t txsQ) FilterByIds(ids ...string) data.TransactionsQ {
	t.filters = append(t.filters, func(value data.Transaction) bool {
		return contains(ids, value.ID)
	})

	return t

}

func (t txsQ) FilterByStatus(status data.TxStatus) data.TransactionsQ {
	t.filters = append(t.filters, func(value data.Transaction) bool {
		return value.Status == status
	})

	return t
}
