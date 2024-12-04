package pg

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
)

func transactionToTxModel(tx data.Transaction) (map[string]interface{}, error) {
	var (
		rawTx      any
		rawReceipt any
		err        error
	)

	if tx.Tx != nil {
		rawTx, err = tx.Tx.MarshalBinary()
		if err != nil {
			return nil, errors.Wrap(err, "failed to marshal raw tx")
		}
	}

	if tx.Receipt != nil {
		rawReceipt, err = tx.Receipt.MarshalBinary()
		if err != nil {
			return nil, errors.Wrap(err, "failed to marshal raw receipt")
		}
	}

	return map[string]interface{}{
		"id":          tx.ID,
		"chain_id":    tx.ChainID,
		"address":     tx.Address.Hex(),
		"data":        tx.Data,
		"gas_limit":   tx.GasLimit,
		"raw_tx":      rawTx,
		"raw_receipt": rawReceipt,
		"status":      tx.Status,
		"msg":         tx.Msg,
		"updated_at":  tx.UpdatedAt,
		"created_at":  tx.CreatedAt,
	}, nil
}

func txModelToTransaction(tx txModel) (*data.Transaction, error) {
	var (
		ethTx   *types.Transaction = nil
		receipt *types.Receipt     = nil
	)

	if tx.RawTx != nil {
		ethTx = new(types.Transaction)
		if err := ethTx.UnmarshalBinary(tx.RawTx); err != nil {
			return nil, errors.Wrap(err, "failed to unmarshal raw tx")
		}
	}

	if tx.RawReceipt != nil {
		receipt = new(types.Receipt)
		if err := receipt.UnmarshalBinary(tx.RawReceipt); err != nil {
			return nil, errors.Wrap(err, "failed to unmarshal raw receipt")
		}
	}

	return &data.Transaction{
		ID:        tx.ID,
		ChainID:   tx.ChainID,
		Address:   common.HexToAddress(tx.Address),
		Data:      tx.Data,
		GasLimit:  tx.GasLimit,
		Tx:        ethTx,
		Receipt:   receipt,
		Status:    tx.Status,
		Msg:       tx.Msg,
		UpdatedAt: tx.UpdatedAt,
		CreatedAt: tx.CreatedAt,
	}, nil
}

func ptr(s string) *string { return &s }
