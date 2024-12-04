package bridge

import (
	"context"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/google/uuid"
	"github.com/pkg/errors"
	"github.com/rs/zerolog/log"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/contracts"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"github.com/superform-xyz/v2-core/relayer/pkg/txmngr"
	"github.com/superform-xyz/v2-core/relayer/services/listener"
	"github.com/superform-xyz/v2-core/relayer/services/monitor"
)

// Bridge represents the superform monitor service.
type Bridge struct {
	tx       txmngr.TxManager
	bridge   config.Chain
	contract *abi.ABI
	blocksQ  data.BlocksQ
	listener listener.Listener
	bridges  map[uint64]config.Chain
	close    chan struct{}
}

// New creates a new Bridge instance.
func New(
	tx txmngr.TxManager,
	blocksQ data.BlocksQ,
	bridge uint64,
	bridges map[uint64]config.Chain,
	listenerCfg config.Runner,
) (monitor.Processor, error) {
	bridgeConfig, ok := bridges[bridge]
	if !ok {
		return nil, errors.New("monitor not found")
	}

	contract, err := contracts.SuperBridgeMetaData.GetAbi()
	if err != nil {
		return nil, errors.Wrap(err, "failed to get contract ABI")
	}

	closeCh := make(chan struct{})
	return &Bridge{
		tx:       tx,
		contract: contract,
		bridge:   bridges[bridge],
		blocksQ:  blocksQ,
		bridges:  bridges,
		close:    closeCh,
		listener: listener.NewListener(
			bridgeConfig.Client,
			closeCh,
			blocksQ,
			bridgeConfig.Contracts.BridgeContract,
			[]common.Hash{contract.Events["Msg"].ID},
			bridgeConfig.Contracts.BridgeBlock,
			listenerCfg,
		),
	}, nil
}

// Start starts the monitor service.
func (b *Bridge) Start(ctx context.Context) {
	go func() {
		logsCh := make(chan types.Log)
		go b.listener.ListenEvents(ctx, logsCh)
		go b.processEvents(ctx, logsCh)
	}()
}

// Stop stops the monitor service.
func (b *Bridge) Stop(_ context.Context) {
	close(b.close)
}

func (b *Bridge) processEvents(ctx context.Context, logsCh <-chan types.Log) {
	for {
		select {
		case event := <-logsCh:
			if err := b.processEvent(ctx, event); err != nil {
				log.Error().Err(err).Msg("failed to process event")
				continue
			}

			// Higher block number to prevent handling the same block continuously
			if err := b.setHandledBlock(event.BlockNumber + 1); err != nil {
				log.Error().Err(err).Msg("failed to store last handled block")
				continue
			}
		case <-b.close:
			log.Info().Msg("monitor monitor stopped")
			return
		default:
			continue
		}
	}
}

func (b *Bridge) setHandledBlock(blockNumber uint64) error {
	if err := b.blocksQ.Upsert(data.Block{
		ID:       uuid.New().String(),
		ChainID:  b.bridge.ChainID,
		Contract: b.bridge.Contracts.BridgeContract,
		Number:   blockNumber,
	}); err != nil {
		return errors.Wrap(err, "failed to upsert block")
	}
	return nil
}

func (b *Bridge) processEvent(ctx context.Context, event types.Log) error {
	topic := event.Topics[0].Hex()
	switch topic {
	case b.contract.Events["Msg"].ID.Hex():
		var msg contracts.SuperBridgeMsg
		if err := b.unpackLog(&msg, "Msg", event); err != nil {
			return errors.Wrap(err, "failed to parse Msg event")
		}
		return b.handleMsg(ctx, msg)
	default:
		return errors.Errorf("unknown topic %s", topic)
	}
}

func (b *Bridge) handleMsg(ctx context.Context, msg contracts.SuperBridgeMsg) error {
	log.Info().Interface("msg", msg).Msg("handling msg")

	// Get destination monitor address
	dstBridge, ok := b.bridges[msg.DestinationChainId.Uint64()]
	if !ok {
		return errors.Errorf("destination chain (%d) not found in config ", msg.DestinationChainId.Uint64())
	}

	// Prepare tx txData
	txData, err := b.contract.Pack("release", msg.DestinationContract, msg.Data)
	if err != nil {
		return errors.Wrap(err, "failed to pack release tx txData")
	}

	// Send tx to the tx manager
	txId, err := b.tx.SendTxAsync(
		ctx,
		msg.DestinationChainId.Uint64(),
		dstBridge.Contracts.BridgeContract,
		txData,
		900000, //nolint:mnd
	)
	if err != nil {
		log.Error().Err(err).Msg("failed to send tx")
		return errors.Wrap(err, "failed to send tx")
	}

	// Wait for completion
	tx, err := b.tx.WaitTxCompleted(ctx, txId)
	if err != nil {
		return errors.Wrap(err, "failed to wait for tx completion")
	}

	if tx.Status == data.ErroredTxStatus {
		log.Error().Str("error", tx.Msg).Msg("failed to process tx")
		return errors.Errorf("failed to process tx, msg=%s", tx.Msg)
	}

	if tx.Receipt.Status == types.ReceiptStatusFailed {
		return errors.New("tx failed")
	}

	log.Info().Str("txId", txId).Msg("tx completed")
	return nil
}

func (b *Bridge) unpackLog(out interface{}, event string, log types.Log) error {
	// Anonymous events are not supported.
	if len(log.Topics) == 0 {
		return errors.New("anonymous events are not supported")
	}

	if log.Topics[0] != b.contract.Events[event].ID {
		return errors.New("event signature mismatch")
	}

	if len(log.Data) > 0 {
		if err := b.contract.UnpackIntoInterface(out, event, log.Data); err != nil {
			return err
		}
	}

	var indexed abi.Arguments
	for _, arg := range b.contract.Events[event].Inputs {
		if arg.Indexed {
			indexed = append(indexed, arg)
		}
	}

	return abi.ParseTopics(out, indexed, log.Topics[1:])
}
