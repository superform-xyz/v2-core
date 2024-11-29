package pricer

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/google/uuid"
	"github.com/pkg/errors"
	"github.com/rs/zerolog/log"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/contracts"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"github.com/superform-xyz/v2-core/relayer/services/listener"
	"github.com/superform-xyz/v2-core/relayer/services/monitor"
)

const (
	PricerEvent = "0x3dad79e8b0ebc64e0dbce0cee3d781072c1afdbae17f98f9031338708a957fe5"
)

type Price struct {
	bridge   config.Chain
	contract *contracts.SuperBridge
	blocksQ  data.BlocksQ
	pricesQ  data.PricesQ
	listener listener.Listener
	close    chan struct{}
}

type PriceData struct {
	AssetAddress common.Address
	AssetPrice   *big.Int
	ShareAddress common.Address
	SharePrice   *big.Int
}

// New creates a new Bridge instance.
func New(
	blocksQ data.BlocksQ,
	pricesQ data.PricesQ,
	bridgeConfig config.Chain,
	listenerCfg config.Runner,
) (monitor.Processor, error) {
	contract, err := contracts.NewSuperBridge(bridgeConfig.Contracts.BridgeContract, bridgeConfig.Client)
	if err != nil {
		return nil, errors.Wrap(err, "failed to get contract ABI")
	}

	closeCh := make(chan struct{})
	return &Price{
		contract: contract,
		bridge:   bridgeConfig,
		blocksQ:  blocksQ,
		pricesQ:  pricesQ,
		close:    closeCh,
		listener: listener.NewListener(
			bridgeConfig.Client,
			closeCh,
			blocksQ,
			bridgeConfig.Contracts.BridgeContract,
			[]common.Hash{common.HexToHash(PricerEvent)},
			bridgeConfig.Contracts.BridgeBlock,
			listenerCfg,
		),
	}, nil
}

// Start starts the monitor service.
func (b *Price) Start(ctx context.Context) {
	go func() {
		logsCh := make(chan types.Log)
		go b.listener.ListenEvents(ctx, logsCh)
		go b.processEvents(ctx, logsCh)
	}()
}

// Stop stops the monitor service.
func (b *Price) Stop(_ context.Context) {
	close(b.close)
}

func (b *Price) processEvents(ctx context.Context, logsCh <-chan types.Log) {
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
		}
	}
}

func (b *Price) setHandledBlock(blockNumber uint64) error {
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

func (b *Price) processEvent(ctx context.Context, event types.Log) error {
	topic := event.Topics[0].Hex()
	switch topic {
	case PricerEvent:
		pricer, err := b.contract.ParsePricer(event)
		if err != nil {
			return errors.Wrapf(err, "failed to parse event=%s", PricerEvent)
		}
		return b.handlePricer(ctx, pricer)
	default:
		return errors.Errorf("unknown topic %s", topic)
	}
}

func (b *Price) handlePricer(ctx context.Context, pricer *contracts.SuperBridgePricer) error {
	log.Info().Interface("pricer", pricer).Msg("handling pricer")
	uint256Ty, _ := abi.NewType("uint256", "uint256", nil)
	addressTy, _ := abi.NewType("address", "address", nil)

	arguments := abi.Arguments{
		{Type: addressTy},
		{Type: uint256Ty},
		{Type: addressTy},
		{Type: uint256Ty},
	}

	unpacked, err := arguments.Unpack(pricer.Data)
	if err != nil {
		return errors.Wrap(err, "failed to unpack pricer data")
	}

	if len(unpacked) != 4 {
		return errors.New("unexpected number of elements in unpacked data")
	}

	priceData := &PriceData{
		AssetAddress: unpacked[0].(common.Address),
		AssetPrice:   unpacked[1].(*big.Int),
		ShareAddress: unpacked[2].(common.Address),
		SharePrice:   unpacked[3].(*big.Int),
	}

	if err = b.pricesQ.Upsert(data.Price{
		ID:         uuid.NewString(),
		ChainID:    pricer.DestinationChainId.Uint64(),
		Vault:      priceData.ShareAddress,
		Asset:      priceData.AssetAddress,
		AssetPrice: priceData.AssetPrice,
		SharePrice: priceData.SharePrice,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}); err != nil {
		return errors.Wrap(err, "failed to upsert price")
	}

	return nil
}
