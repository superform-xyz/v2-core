package txmngr

import (
	"context"
	"database/sql"
	"encoding/hex"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/txpool"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/google/uuid"
	"github.com/pkg/errors"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

const (
	// TxStatusPending represents the pending status of a transaction
	TxStatusPending = "PENDING"

	// TxStatusProcessing represents the processing status of a transaction
	TxStatusProcessing = "PROCESSING"

	// TxStatusErrored represents the errored status of a transaction
	TxStatusErrored = "ERRORED"

	// TxStatusSucceed represents the success status of a transaction
	TxStatusSucceed = "SUCCEED"

	// TxStatusFailed represents the failed status of a transaction
	TxStatusFailed = "FAILED"
)

const (
	// priorityCoefficient is the 15% priority coefficient for the gas price calculation
	priorityCoefficient = int64(15)

	// pendingTxProcessingInterval is the interval for processing pending transactions from the DB
	pendingTxProcessingInterval = time.Second / 2

	// txCompletionWaitInterval is the interval for waiting for the tx to be broadcasted/mined
	txCompletionWaitInterval = time.Second / 2
)

var (
	// ErrNotConfirmed is the error returned when the tx is not confirmed after several attempts
	ErrNotConfirmed = errors.New("tx not confirmed after several attempts")
)

// EthClient is the interface for the Ethereum client
type EthClient interface {
	ethereum.TransactionSender
	ethereum.GasPricer
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	PendingNonceAt(ctx context.Context, account common.Address) (uint64, error)
}

// TxManager is the interface for the tx manager
type TxManager interface {
	// Start starts the tx manager
	Start(ctx context.Context)

	// Stop stops the tx manager
	Stop()

	// SendTxAsync sends a tx asynchronously
	SendTxAsync(
		ctx context.Context,
		chainId uint64,
		addr common.Address,
		data []byte,
		gasLimit uint64,
	) (string, error)

	// WaitTx waits for the tx to be broadcasted
	WaitTx(ctx context.Context, id string) (*Tx, error)

	// WaitTxCompleted waits for the tx completion
	WaitTxCompleted(ctx context.Context, id string) (*Tx, error)
}

// txManager is the implementation of the TxManager interface
type txManager struct {
	db              DB
	clients         map[uint64]EthClient
	sender          common.Address
	bumpInterval    time.Duration
	blockTime       time.Duration
	getTransactOpts func(chainId uint64) (*bind.TransactOpts, error)
	wg              sync.WaitGroup
	stop            chan struct{}
}

// New creates a new tx manager
func New(
	db DB,
	clients map[uint64]EthClient,
	sender common.Address,
	bumpInterval time.Duration,
	blockTime time.Duration,
	getTransactOpts func(chainId uint64) (*bind.TransactOpts, error),
) TxManager {
	return &txManager{
		db:              db,
		clients:         clients,
		sender:          sender,
		bumpInterval:    bumpInterval,
		blockTime:       blockTime,
		getTransactOpts: getTransactOpts,
		stop:            make(chan struct{}),
	}
}

// Start starts the tx manager
func (m *txManager) Start(ctx context.Context) {
	go m.startTxProcessor(ctx)
}

// Stop stops the tx manager
func (m *txManager) Stop() {
	close(m.stop)
	m.wg.Wait()
}

// SendTxAsync stores TX in the db and returns its ID
func (m *txManager) SendTxAsync(
	ctx context.Context,
	chainId uint64,
	addr common.Address,
	data []byte,
	gasLimit uint64,
) (string, error) {
	// Make sure the given chain ID is supported
	if _, ok := m.clients[chainId]; !ok {
		return "", errors.Errorf("unsupported chain ID: %d", chainId)
	}

	id := uuid.New().String()

	// Store tx in the database
	if err := m.db.StoreTx(ctx, Tx{
		ID:       id,
		ChainID:  chainId,
		Addr:     addr,
		Data:     data,
		GasLimit: gasLimit,
		Status:   TxStatusPending,
	}); err != nil {
		return "", errors.Wrap(err, "failed to store tx in the db")
	}

	return id, nil
}

// WaitTx waits for the tx to be broadcasted
func (m *txManager) WaitTx(ctx context.Context, id string) (*Tx, error) {
	ticker := time.NewTicker(txCompletionWaitInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			tx, err := m.db.GetTx(ctx, id)
			if err != nil {
				if err == sql.ErrNoRows {
					continue
				}
				return nil, err
			}

			if tx.Tx != nil {
				return tx, nil
			}
		}
	}
}

// WaitTxCompleted waits for the tx completion
func (m *txManager) WaitTxCompleted(ctx context.Context, id string) (*Tx, error) {
	ticker := time.NewTicker(txCompletionWaitInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			tx, err := m.db.GetTx(ctx, id)
			if err != nil {
				if err == sql.ErrNoRows {
					continue
				}
				return nil, err
			}

			if tx.IsCompleted() {
				return tx, nil
			}
		}
	}
}

func (m *txManager) startTxProcessor(ctx context.Context) {
	ticker := time.NewTicker(pendingTxProcessingInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("tx processor stopped due to cancelled context")
			return
		case <-m.stop:
			log.Info().Msg("tx processor stopped")
			return
		case <-ticker.C:
			m.processTxs(ctx)
		}
	}
}

// processTxs loads PENDING transactions from the database and processes them one by one.
// The current implementation is not allowed to run within multiple instances.
func (m *txManager) processTxs(ctx context.Context) {
	// Here we fetch PENDING transactions from the DB to process them
	pendingTxs, err := m.db.ListTxs(ctx, ListTxsFilter{
		Status: TxStatusPending,
	})
	if err != nil {
		log.Error().Err(err).Msg("failed to list PENDING txs")
		return
	}

	if len(pendingTxs) == 0 {
		return
	}

	log.Debug().Int("txs", len(pendingTxs)).Msg("processing txs")

	// Process each pending tx ONE BY ONE!!! to avoid nonce conflicts
	// There might be a case when 100 txs are sent with the sequenced nonce and some of them fails in the middle.
	// In this case, we need to re-send all following transactions with updated nonce.
	for _, tx := range pendingTxs {
		lgr := log.With().Str("txId", tx.ID).Logger()

		// Change the tx status to PROCESSING
		if err = m.db.UpdateTxStatus(ctx, tx.ID, TxStatusProcessing, "", nil); err != nil {
			lgr.Error().Err(err).Msg("failed to update tx status")
			continue
		}

		var status string
		var msg string

		// Process pending transaction
		receipt, err := m.processTx(ctx, tx)
		if err != nil {
			lgr.Error().Err(err).Msg("failed to process tx")

			status = TxStatusErrored
			msg = err.Error()
		} else {
			if receipt.Status == types.ReceiptStatusFailed {
				lgr.Error().Msg("tx failed")

				status = TxStatusFailed
			} else {
				lgr.Info().Msg("tx succeed")

				status = TxStatusSucceed
			}
		}

		// Store processed tx
		if err := m.db.UpdateTxStatus(ctx, tx.ID, status, msg, receipt); err != nil {
			lgr.Error().Err(err).Msg("failed to update processed tx status")
		}
	}
}

// processTx processes the given tx.
// PROCESS ONLY ONE TX AT TIME.
func (m *txManager) processTx(ctx context.Context, txModel Tx) (*types.Receipt, error) {
	m.wg.Add(1)
	defer m.wg.Done()

	lgr := log.With().Str("txId", txModel.ID).Logger()
	lgr.Debug().Msg("start processing tx")

	// Get the current nonce
	nonce, err := m.clients[txModel.ChainID].PendingNonceAt(ctx, m.sender)
	if err != nil {
		lgr.Error().Err(err).Msg("failed to get nonce")
		return nil, errors.Wrap(err, "failed to get nonce")
	}

	// Define current gas price which is 0
	var currentGasPrice *big.Int

	// Define previous tx hash
	var prevTx *types.Transaction

	// Create tx auth opts
	auth, err := m.getTransactOpts(txModel.ChainID)
	if err != nil {
		lgr.Error().Err(err).Msg("failed to get transact opts")
		return nil, err
	}

	// Here we wait 30 seconds for the tx to be mined and bumping the gas price if it's not.
	// Repeating 5 times the process and then break
	for i := int64(1); i <= 5; i++ { //nolint:mnd
		// Preparing an initial gas price for the given tx
		currentGasPrice, err = m.suggestGasPrice(ctx, txModel.ChainID, currentGasPrice, priorityCoefficient*i)
		if err != nil {
			lgr.Error().Err(err).Msg("failed to suggest gas price")
			return nil, errors.Wrap(err, "failed to suggest gas price")
		}

		// Building a tx with the initially prepared gas price
		signedTx, err := auth.Signer(auth.From, types.NewTx(&types.LegacyTx{
			To:       &txModel.Addr,
			Nonce:    nonce,
			GasPrice: new(big.Int).Set(currentGasPrice),
			Gas:      txModel.GasLimit,
			Data:     txModel.Data,
		}))
		if err != nil {
			lgr.Error().Err(err).Msg("failed to sign transaction")
			return nil, errors.Wrap(err, "failed to sign transaction")
		}

		// Store the tx in the DB
		if err = m.db.UpdateRawTx(ctx, txModel.ID, signedTx); err != nil {
			lgr.Error().Err(err).Msg("failed to update raw tx")
			return nil, errors.Wrap(err, "failed to update raw tx")
		}

		lgr := lgr.With().
			Uint64("nonce", signedTx.Nonce()).
			Str("gasPrice", signedTx.GasPrice().String()).
			Uint64("gas", signedTx.Gas()).
			Str("to", signedTx.To().String()).
			Str("value", signedTx.Value().String()).
			Str("data", hex.EncodeToString(signedTx.Data())).
			Str("chainId", signedTx.ChainId().String()).
			Str("hash", signedTx.Hash().Hex()).
			Logger()

		// Broadcast tx and wait for it to be mined
		receipt, mined, err := m.broadcastTx(ctx, lgr, txModel.ChainID, prevTx, signedTx)
		if err != nil {
			lgr.Error().Err(err).Msg("failed to broadcast tx")
			return nil, err
		}

		// If the tx is mined, return the receipt
		if mined {
			return receipt, nil
		}

		// Store tx hash
		prevTx = signedTx

		lgr.Warn().Int64("bumps", i).Msg("tx not mined, bumping gas price")
	}

	lgr.Error().Msg("tx not mined after 5 attempts")

	return nil, ErrNotConfirmed
}

// broadcastTx broadcasts the given tx to the blockchain and waits for it to be mined.
func (m *txManager) broadcastTx(
	ctx context.Context,
	lgr zerolog.Logger,
	chainId uint64,
	prevTx *types.Transaction,
	newTx *types.Transaction,
) (*types.Receipt, bool, error) {
	lgr.Debug().Msg("broadcasting transaction")

	// Broadcast tx to the blockchain
	if err := m.clients[chainId].SendTransaction(ctx, newTx); err != nil {
		if errors.Is(err, txpool.ErrReplaceUnderpriced) {
			// If the given error comes in, most likely the transaction that we want to override is already mined.
			// It happens because the nonce is the same as the previous transaction.
			// Just returning a receipt here.

			lgr.Warn().Err(err).Msg("tx already mined")

			// Just to quickly make sure the previous transaction was not mined while the override was happening
			if prevTx != nil {
				receipt, err := m.clients[chainId].TransactionReceipt(ctx, prevTx.Hash())
				if err == nil {
					return receipt, true, nil
				}

				lgr.Warn().Err(err).Msg("failed to get previous tx receipt")
			}

			// Should not happen
			lgr.Error().Err(err).Msg("TRYING TO REPLACE A TX THAT IS ALREADY MINED BUT NO PREVIOUS TX FOUND")
			return nil, false, errors.Wrap(err, "tx already mined but no previous tx found")
		} else if strings.HasPrefix(err.Error(), core.ErrNonceTooLow.Error()) {
			// Previous transaction could be mined here
			if prevTx != nil {
				receipt, err := m.clients[chainId].TransactionReceipt(ctx, prevTx.Hash())
				if err == nil {
					return receipt, true, nil
				}

				lgr.Warn().Err(err).Msg("failed to get previous tx receipt")
			}

			lgr.Warn().Msg("ACCOUNT NONCE IS BROKEN, RESENDING TRANSACTION")

			// Just returning false and no error to trigger resending a new transaction with the relevant nonce
			return nil, false, nil
		}

		// If the error is not related to the nonce, return the error
		lgr.Error().Err(err).Msg("failed to broadcast tx")
		return nil, false, errors.Wrap(err, "failed to send tx")
	}

	lgr.Debug().Msg("tx broadcasted, waiting for confirmation")

	// Create a context with the deadline
	mineTx, cancel := context.WithTimeout(ctx, m.bumpInterval)
	defer cancel()

	// Wait for the tx to be mined
	receipt, err := m.waitMined(mineTx, lgr, chainId, newTx)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			lgr.Debug().Msg("stopped waiting for tx, deadline exceeded")

			// Context deadline exceeded, tx is not mined yet.
			return nil, false, nil
		} else {
			lgr.Error().Err(err).Msg("failed to wait for tx")
			return nil, false, errors.Wrap(err, "failed to wait for tx")
		}
	}

	lgr.Debug().Msg("tx mined")

	return receipt, true, nil
}

// suggestGasPrice calculates the gas price for the tx based on the current gas price and the suggested gas price
func (m *txManager) suggestGasPrice(ctx context.Context, chainId uint64, currentGasPrice *big.Int, coef int64) (*big.Int, error) {
	suggestedGasPrice, err := m.clients[chainId].SuggestGasPrice(ctx)
	if err != nil {
		return nil, err
	}

	if currentGasPrice == nil {
		return bumpGasPrice(suggestedGasPrice, coef), nil
	}

	if suggestedGasPrice.Cmp(currentGasPrice) > 0 {
		return bumpGasPrice(suggestedGasPrice, coef), nil
	}

	return bumpGasPrice(currentGasPrice, coef), nil
}

// waitMined waits for tx to be mined on the blockchain.
// It stops waiting when the context is canceled.
func (m *txManager) waitMined(ctx context.Context, lgr zerolog.Logger, chainId uint64, tx *types.Transaction) (*types.Receipt, error) {
	queryTicker := time.NewTicker(m.blockTime)
	defer queryTicker.Stop()

	for {
		receipt, err := m.clients[chainId].TransactionReceipt(ctx, tx.Hash())
		if err == nil {
			return receipt, nil
		}

		if errors.Is(err, ethereum.NotFound) {
			lgr.Trace().Msg("transaction not yet mined")
		} else {
			lgr.Trace().Err(err).Msg("receipt retrieval failed")
		}

		// Wait for the next round.
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-queryTicker.C:
		}
	}
}

// bumpGasPrice bumps the gas price by the priority coefficient
func bumpGasPrice(gasPrice *big.Int, coef int64) *big.Int {
	if gasPrice == nil {
		return big.NewInt(0)
	}

	// Create a big.Int from the percentage
	percentBigInt := big.NewInt(coef)

	// Calculate the multiplier (1 + N/100) as a big.Int
	// To handle percentages, we first convert the percentage to 1 + N/100
	hundred := big.NewInt(100) //nolint:mnd
	multiplier := new(big.Int).Add(hundred, percentBigInt)

	// Multiply gasPrice by the multiplier
	newGasPrice := new(big.Int).Mul(gasPrice, multiplier)

	// Divide by 100 to get the final result
	newGasPrice.Div(newGasPrice, hundred)

	return newGasPrice
}
