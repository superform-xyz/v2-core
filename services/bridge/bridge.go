package bridge

import (
	"context"
	"errors"
	"sync"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/rs/zerolog/log"
	"github.com/superform-xyz/v2-core/pkg/contracts"
	"github.com/superform-xyz/v2-core/pkg/txmngr"
)

/*
== Logs ==
  Deploying on Destination Chain...
  SuperBridge deployed at: 0xc23e64FF756224a9f49C89A921dcE2F4da5b5146
  SuperVault deployed at: 0x8748F09Fd8E8D9C05aFce58c81E2E7dC8be29834
  SuperUSD deployed at: 0xc2c1ef95Cc34aCF24cDc5cD011f77F2bF1D5502c
  Deploying on Source Chain...
  SuperBridge deployed at: 0x5Ceb39773d11e51a8Ec24BDA70d27629E87418E0
  SuperVault deployed at: 0xD323d24469810AF385Dfa97ec58f0787f1a234D1
  SuperUSD deployed at: 0xF4417Af5416A8Dc21fD92cCf6F2a49eCc80d043D

*/

var (
	// superBridgeABI is the ABI of the SuperBridge contract
	superBridgeABI *abi.ABI
)

func init() {
	var err error
	if superBridgeABI, err = contracts.SuperBridgeMetaData.GetAbi(); err != nil {
		log.Fatal().Err(err).Msg("failed to get SuperBridge ABI")
	}
}

// EthClient represents the Ethereum client interface.
type EthClient interface {
	bind.ContractTransactor
	bind.ContractBackend
	bind.DeployBackend
}

// BridgeConfig represents the bridge configuration.
type BridgeConfig struct {
	ChainID         uint64
	Address         common.Address
	Client          EthClient
	DeploymentBlock uint64
}

// Bridge represents the superform bridge service.
type Bridge struct {
	tx        txmngr.TxManager
	bridges   map[uint64]BridgeConfig
	processes sync.WaitGroup
	close     chan struct{}
}

// New creates a new Bridge instance.
func New(
	tx txmngr.TxManager,
	bridges map[uint64]BridgeConfig,
) *Bridge {
	return &Bridge{
		tx:      tx,
		bridges: bridges,
		close:   make(chan struct{}),
	}
}

// Monitor bridge contract on all chain
// Handle Msg events from the bridge contract

func (b *Bridge) Start(ctx context.Context) {
	go b.startBridgesMonitor(ctx)
}

func (b *Bridge) Stop() {
	close(b.close)
	b.processes.Wait()
}

func (b *Bridge) startBridgesMonitor(ctx context.Context) {
	var wg sync.WaitGroup
	for _, bridge := range b.bridges {
		wg.Add(1)
		go func(bridge BridgeConfig) {
			defer wg.Done()

			// Create Msg event subscription for the bridge contract
			events := make(chan types.Log, 100)
			sub, err := bridge.Client.SubscribeFilterLogs(ctx, ethereum.FilterQuery{
				// FromBlock: new(big.Int).SetUint64(bridge.DeploymentBlock),
				Addresses: []common.Address{bridge.Address},
				Topics:    [][]common.Hash{{superBridgeABI.Events["Msg"].ID}},
			}, events)
			if err != nil {
				log.Fatal().Err(err).Msg("failed to subscribe to logs")
				return
			}

			defer sub.Unsubscribe()

			log.Debug().Str("address", bridge.Address.Hex()).Msg("subscribed to logs")

			for {
				select {
				case err = <-sub.Err():
					log.Error().Err(err).Msg("subscription error")
					return
				case event := <-events:
					var msg contracts.SuperBridgeMsg
					if err = unpackLog(&msg, "Msg", event); err != nil {
						log.Error().Err(err).Msg("failed to unpack log")
						continue
					}

					go b.handleMsg(ctx, &msg)
				case <-b.close:
					log.Info().Msg("bridge monitor stopped")
					return
				}
			}
		}(bridge)
	}
	wg.Wait()
}

func (b *Bridge) handleMsg(ctx context.Context, msg *contracts.SuperBridgeMsg) {
	b.processes.Add(1)
	defer b.processes.Done()

	log.Info().Interface("msg", msg).Msg("handling msg")

	// Get destination bridge address
	dstBridge, ok := b.bridges[msg.DestinationChainId.Uint64()]
	if !ok {
		log.Error().Uint64("chainId", msg.DestinationChainId.Uint64()).Msg("destination chain not found in config")
		return
	}

	// Prepare tx data
	data, err := superBridgeABI.Pack("release", msg.DestinationContract, msg.Data)
	if err != nil {
		log.Error().Err(err).Msg("failed to pack data")
		return
	}

	// Send tx to the tx manager
	txId, err := b.tx.SendTxAsync(
		ctx,
		msg.DestinationChainId.Uint64(),
		dstBridge.Address,
		data,
		900000,
	)
	if err != nil {
		log.Error().Err(err).Msg("failed to send tx")
		return
	}

	// Wait for completion
	tx, err := b.tx.WaitTxCompleted(ctx, txId)
	if err != nil {
		log.Error().Err(err).Msg("failed to wait for tx completion")
		return
	}

	if tx.Status == txmngr.TxStatusErrored {
		log.Error().Str("error", tx.Msg).Msg("failed to process tx")
		return
	}

	if tx.Receipt.Status == types.ReceiptStatusFailed {
		log.Error().Err(err).Msg("tx failed")
		return
	}

	log.Info().Str("txId", txId).Msg("tx completed")
}

func unpackLog(out interface{}, event string, log types.Log) error {
	// Anonymous events are not supported.
	if len(log.Topics) == 0 {
		return errors.New("anonymous events are not supported")
	}

	if log.Topics[0] != superBridgeABI.Events[event].ID {
		return errors.New("event signature mismatch")
	}

	if len(log.Data) > 0 {
		if err := superBridgeABI.UnpackIntoInterface(out, event, log.Data); err != nil {
			return err
		}
	}

	var indexed abi.Arguments
	for _, arg := range superBridgeABI.Events[event].Inputs {
		if arg.Indexed {
			indexed = append(indexed, arg)
		}
	}

	return abi.ParseTopics(out, indexed, log.Topics[1:])
}
