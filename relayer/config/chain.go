package config

import (
	"context"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/rs/zerolog/log"
)

// Chain contains the chain config
type Chain struct {
	// Name is the chain name
	Name string `mapstructure:"name"`

	// RPC is the chain RPC address
	RPC string `mapstructure:"rpc"`

	// ChainID is the chain ID
	ChainID uint64 `mapstructure:"chain_id"`

	// BridgeContract is the bridge contract address
	BridgeContract string `mapstructure:"bridge_contract"`

	// BridgeContractDeploymentBlock is the bridge contract deployment block
	BridgeContractDeploymentBlock uint64 `mapstructure:"bridge_contract_deployment_block"`
}

// Client returns the chain RPC client
func (c *Chain) Client(ctx context.Context) *ethclient.Client {
	// Create RPC client
	cl, err := ethclient.Dial(c.RPC)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to dial monad RPC")
	}

	// Check chain ID
	chainId, err := cl.ChainID(ctx)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to get chain ID")
	}

	if chainId.Uint64() != c.ChainID {
		log.Fatal().
			Uint64("expected", c.ChainID).
			Uint64("actual", chainId.Uint64()).
			Msg("chain ID mismatch")
	}

	return cl
}
