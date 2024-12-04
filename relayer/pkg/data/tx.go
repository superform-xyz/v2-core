package data

import (
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

type TxStatus string

const (
	SucceedTxStatus    TxStatus = "succeed"
	ErroredTxStatus    TxStatus = "errored"
	ProcessingTxStatus TxStatus = "processing"
	PendingTxStatus    TxStatus = "pending"
	FailedTxStatus     TxStatus = "failed"
)

type TransactionsQ interface {
	New() TransactionsQ

	Insert(tx Transaction) error
	Update(tx Transaction) error
	Delete() error

	Select() ([]Transaction, error)
	Get() (*Transaction, error)

	FilterByIds(ids ...string) TransactionsQ
	FilterByStatus(status TxStatus) TransactionsQ
}

type Transaction struct {
	ID        string
	ChainID   uint64
	Address   common.Address
	Data      []byte
	GasLimit  uint64
	Tx        *types.Transaction
	Receipt   *types.Receipt
	Status    TxStatus
	Msg       string
	UpdatedAt time.Time
	CreatedAt time.Time
}

func (tx *Transaction) IsCompleted() bool {
	return tx.Status == ErroredTxStatus ||
		tx.Status == FailedTxStatus ||
		tx.Status == SucceedTxStatus
}
