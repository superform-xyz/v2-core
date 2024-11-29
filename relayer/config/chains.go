package config

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

type Chains map[uint64]Chain

type Chain struct {
	Name      string            `mapstructure:"name" json:"name"`
	RPC       string            `mapstructure:"rpc" json:"rpc"`
	Client    *ethclient.Client `mapstructure:"rpc" json:"-"`
	ChainID   uint64            `mapstructure:"chain_id" json:"chain_id"`
	Contracts Contracts         `mapstructure:"contracts" json:"contracts"`
}

type Contracts struct {
	BridgeContract common.Address `mapstructure:"bridge_contract" json:"bridge_contract"`
	BridgeBlock    uint64         `mapstructure:"bridge_block" json:"bridge_block"`
}

func (c Chains) Clients() map[uint64]*ethclient.Client {
	clients := make(map[uint64]*ethclient.Client)
	for _, chain := range conf.Chains {
		clients[chain.ChainID] = chain.Client
	}
	return clients
}
