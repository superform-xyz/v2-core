package txmngr

import (
	"context"

	"github.com/ethereum/go-ethereum/core/types"
)

// ListTxsFilter is the filter used to list transactions
type ListTxsFilter struct {
	Status string
}

// DB is the interface that wraps the basic txs related database operations
type DB interface {
	// StoreTx stores a transaction in the database
	StoreTx(ctx context.Context, tx Tx) error

	// UpdateRawTx updates a raw transaction
	UpdateRawTx(ctx context.Context, id string, tx *types.Transaction) error

	// UpdateTxStatus updates a transaction status
	UpdateTxStatus(ctx context.Context, id string, status, msg string, receipt *types.Receipt) error

	// ListTxs returns a list of transactions from the database using the filter
	ListTxs(ctx context.Context, filter ListTxsFilter) ([]Tx, error)

	// GetTx returns a transaction by its ID
	GetTx(ctx context.Context, id string) (*Tx, error)
}
