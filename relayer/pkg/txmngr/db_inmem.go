package txmngr

import (
	"context"
	"fmt"
	"sync"

	"github.com/ethereum/go-ethereum/core/types"
)

// inmemDb is an in-memory database
type inmemDb struct {
	txs     map[string]Tx
	txsLock sync.Mutex
}

// NewInmemDB creates a new in-memory database
func NewInmemDB() DB {
	return &inmemDb{
		txs: make(map[string]Tx),
	}
}

// StoreTx stores a transaction in the database
func (db *inmemDb) StoreTx(ctx context.Context, tx Tx) error {
	db.txsLock.Lock()
	defer db.txsLock.Unlock()

	db.txs[tx.ID] = tx
	return nil
}

// UpdateRawTx updates a raw transaction in the database
func (db *inmemDb) UpdateRawTx(ctx context.Context, id string, tx *types.Transaction) error {
	db.txsLock.Lock()
	defer db.txsLock.Unlock()

	txModel, ok := db.txs[id]
	if !ok {
		return fmt.Errorf("tx not found")
	}

	txModel.Tx = tx
	db.txs[id] = txModel

	return nil
}

// UpdateTxStatus updates a transaction status
func (db *inmemDb) UpdateTxStatus(ctx context.Context, id string, status, msg string, receipt *types.Receipt) error {
	db.txsLock.Lock()
	defer db.txsLock.Unlock()

	txModel, ok := db.txs[id]
	if !ok {
		return fmt.Errorf("tx not found")
	}

	txModel.Status = status
	txModel.Msg = msg
	txModel.Receipt = receipt
	db.txs[id] = txModel

	return nil
}

// ListTxs returns a list of transactions from the database using the filter
func (db *inmemDb) ListTxs(ctx context.Context, filter ListTxsFilter) ([]Tx, error) {
	db.txsLock.Lock()
	defer db.txsLock.Unlock()

	var txs []Tx
	for _, tx := range db.txs {
		if filter.Status == "" || tx.Status == filter.Status {
			txs = append(txs, tx)
		}
	}

	return txs, nil
}

// GetTx returns a transaction by its ID
func (db *inmemDb) GetTx(ctx context.Context, id string) (*Tx, error) {
	db.txsLock.Lock()
	defer db.txsLock.Unlock()

	tx, ok := db.txs[id]
	if !ok {
		return nil, nil
	}

	return &tx, nil
}
