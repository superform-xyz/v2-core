package txmngr

import (
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// Tx represents the transaction DB model
type Tx struct {
	ID        string
	ChainID   uint64
	Addr      common.Address
	Data      []byte
	GasLimit  uint64
	Tx        *types.Transaction
	Receipt   *types.Receipt
	Status    string
	Msg       string
	UpdatedAt time.Time
	CreatedAt time.Time
}

// IsCompleted returns true if the transaction is completed
func (tx *Tx) IsCompleted() bool {
	return tx.Status == TxStatusErrored ||
		tx.Status == TxStatusFailed ||
		tx.Status == TxStatusSucceed
}
