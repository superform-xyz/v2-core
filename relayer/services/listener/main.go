package listener

import (
	"context"
	"database/sql"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/pkg/errors"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/backoff"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
)

const (
	serviceName   = "listener"
	maxBlockRange = 50000
)

type Listener interface {
	ListenEvents(ctx context.Context, logsCh chan<- types.Log)
}

type listener struct {
	log zerolog.Logger

	close   <-chan struct{}
	client  *ethclient.Client
	blocksQ data.BlocksQ

	timeout  time.Duration
	attempts uint

	Topics        []common.Hash
	ListenAddress common.Address
	StartBlock    uint64
}

func NewListener(
	client *ethclient.Client,
	closeCh <-chan struct{},
	blocksQ data.BlocksQ,
	address common.Address,
	topics []common.Hash,
	StartBlock uint64,
	cfg config.Runner,
) Listener {
	return &listener{
		log:           log.With().Str("service", serviceName).Str("address", address.String()).Logger(),
		close:         closeCh,
		client:        client,
		blocksQ:       blocksQ,
		timeout:       cfg.Timeout,
		attempts:      cfg.Attempts,
		ListenAddress: address,
		Topics:        topics,
		StartBlock:    StartBlock,
	}
}

func (l *listener) ListenEvents(ctx context.Context, logsCh chan<- types.Log) {
	errCh := make(chan error)

	go backoff.Exponential(func() error {
		if err := l.listen(ctx, logsCh); err != nil {
			l.log.Error().Err(err).Msg("failed to listen")
			return err
		}
		return nil
	}, l.attempts, l.timeout, errCh)

	select {
	case err := <-errCh:
		if err != nil {
			l.log.Fatal().Err(err).Msg("failed running event listener")
		}
	}
}

func (l *listener) listen(ctx context.Context, logsCh chan<- types.Log) error {
	l.log.Info().Msg("start listening events")

	startBlock, err := l.getStartBlockNumber(ctx)
	if err != nil {
		return errors.Wrap(err, "failed to get start block number")
	}

	if startBlock != 0 {
		if err = l.readEvents(ctx, logsCh, startBlock); err != nil {
			return errors.Wrap(err, "failed to read events")
		}
	}

	if err = l.listenEvents(ctx, logsCh); err != nil {
		return errors.Wrap(err, "failed to listen events")
	}

	l.log.Info().Msg("finish listening events")
	return nil
}

func (l *listener) getStartBlockNumber(ctx context.Context) (uint64, error) {
	chainID, err := l.client.ChainID(ctx)
	if err != nil {
		return 0, errors.Wrap(err, "failed to get chain ID")
	}

	block, err := l.blocksQ.FilterByChainIds(chainID.Uint64()).FilterByContracts(l.ListenAddress).Get()
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return 0, errors.Wrapf(err, "failed to filter block for chain=%d, contract=%s", chainID.Uint64(), l.ListenAddress.String())
	}

	if block == nil {
		return l.StartBlock, nil
	}

	return max(l.StartBlock, block.Number), nil
}

func (l *listener) readEvents(ctx context.Context, logsCh chan<- types.Log, startBlock uint64) error {
	l.log.Info().Uint64("start_block", startBlock).Msg("start reading events")

	header, err := l.client.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "failed to get latest block header")
	}

	for i := startBlock; i <= header.Number.Uint64(); i += maxBlockRange {
		l.log.Debug().Uint64("start", i).Uint64("end", startBlock+maxBlockRange).Msg("filtering logs")
		logs, err := l.client.FilterLogs(ctx, ethereum.FilterQuery{
			Topics:    [][]common.Hash{l.Topics},
			Addresses: []common.Address{l.ListenAddress},
			FromBlock: new(big.Int).SetUint64(startBlock),
			ToBlock:   new(big.Int).SetUint64(startBlock + maxBlockRange),
		})
		if err != nil {
			return errors.Wrapf(err, "failed to filter logs address=%s from_block=%d", l.ListenAddress, startBlock)
		}

		for _, event := range logs {
			logsCh <- event
		}

		l.log.Debug().Int("events", len(logs)).Msg("found event")
	}

	l.log.Info().Msg("finish reading events")
	return nil
}

func (l *listener) listenEvents(ctx context.Context, logsCh chan<- types.Log) error {
	l.log.Info().Msg("subscribe for events")

	logs := make(chan types.Log)

	subscription, err := l.client.SubscribeFilterLogs(
		ctx,
		ethereum.FilterQuery{
			Addresses: []common.Address{l.ListenAddress},
			Topics:    [][]common.Hash{l.Topics},
		},
		logs,
	)
	if err != nil {
		return errors.Wrap(err, "failed to subscribe to logs")
	}

	defer subscription.Unsubscribe()
	for {
		select {
		case <-l.close:
			l.log.Info().Msg("unsubscribe from events")
			return nil
		case err = <-subscription.Err():
			return errors.Wrap(err, "failed to listen logs")
		case vLog := <-logs:
			logsCh <- vLog
		}
	}
}
