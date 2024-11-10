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
	"github.com/superform-xyz/v2-core/relayer/pkg/contracts"
	"github.com/superform-xyz/v2-core/relayer/pkg/txmngr"
)

/*
== Logs ==
  Deployer address: 0xFA9eEc9FBA16303eaE51EB0ef3F7e090035e3e1A
  Relayer address: 0x8C91d7EADfFc9F9921092cA14C3e498cD8cDe0d3
  Deploying on Destination Chain (sepolia)...
  SuperBridge deployed at: 0x7549E4e79A9272878764B20357057613C0b8bbCa
  SuperVault deployed at: 0xb8a62E3cf08647E98E8158b40fBFaB5D2a959A35
  SuperUSD deployed at: 0x8e4E2828BB8bc831965eB7d5185Eef33a70f2561
  Deploying on Source Chain (base)...
  SuperBridge deployed at: 0x465f943A68ee2f9A986C4F12c41C8F13eaCa663B
  SuperVault deployed at: 0xfc664A7393847cA7930CfDaD4Ef3EbC6aaA20307
  SuperUSD deployed at: 0xE22262fb6Bb32FA88b4A7C3c0578D6464cAD03E3
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

// Start starts the bridge service.
func (b *Bridge) Start(ctx context.Context) {
	go b.startBridgesMonitor(ctx)
}

// Stop stops the bridge service.
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
			events := make(chan types.Log, 100) //nolint:mnd
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
		900000, //nolint:mnd
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
