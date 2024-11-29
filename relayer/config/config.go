package config

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"math/big"
	"sync"
	"time"

	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/superform-xyz/v2-core/relayer/pkg/ethawskmssigner"
)

var (
	loadOnce sync.Once
	conf     Config
)

// Config contains app config
type Config struct {
	LogLevel              zerolog.Level     `mapstructure:"log_level" env:"LOG_LEVEL" default:"info" json:"log_level"`
	Env                   string            `mapstructure:"environment" env:"ENVIRONMENT" default:"development" json:"environment"`
	SentryDSN             string            `mapstructure:"sentry_dsn" env:"SENTRY_DSN" json:"sentry_dsn"`
	PrivateKey            *ecdsa.PrivateKey `mapstructure:"private_key" env:"PRIVATE_KEY" json:"-"`
	KMSPrivateKeyID       string            `mapstructure:"kms_private_key_id" env:"KMS_PRIVATE_KEY_ID" json:"-"`
	HealthcheckServerPort int               `mapstructure:"healthcheck_server_port" env:"HEALTHCHECK_SERVER_PORT" default:"6060" json:"healthcheck_server_port"`
	Chains                Chains            `mapstructure:"chains" json:"chains"`
	DB                    Database          `mapstructure:"db" json:"db"`
	Automation            Runner            `mapstructure:"automation" json:"automation"`
	Listener              Runner            `mapstructure:"listener" json:"listener"`
}

type Runner struct {
	Attempts uint          `mapstructure:"attempts" json:"attempts" default:"3"`
	Timeout  time.Duration `mapstructure:"timeout" json:"timeout" default:"15s"`
}

// String returns the string representation of the config
func (c *Config) String() string {
	raw, err := json.Marshal(c)
	if err != nil {
		log.Fatal().Err(err).Msg("unable to marshal config to string")
	}

	return string(raw)
}

// Print prints the config to the console
func (c *Config) Print() {
	raw, err := json.Marshal(c)
	if err != nil {
		log.Fatal().Err(err).Msg("unable to marshal config to string")
	}

	log.Debug().RawJSON("config", raw).Msg("config")
}

func (c *Config) GetTxAuth(ctx context.Context) (addr common.Address, auth func(uint64) (*bind.TransactOpts, error)) {
	if c.KMSPrivateKeyID != "" {
		awsCfg, err := awsconfig.LoadDefaultConfig(ctx)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to load AWS config")
		}

		kmsSvc := kms.NewFromConfig(awsCfg)

		pubKey, err := ethawskmssigner.GetPubKey(ctx, kmsSvc, c.KMSPrivateKeyID)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to get public key")
		}

		addr = crypto.PubkeyToAddress(*pubKey)

		log.Info().Str("address", addr.Hex()).Msg("Using public key from AWS KMS")

		auth = func(chainId uint64) (*bind.TransactOpts, error) {
			return ethawskmssigner.NewAwsKmsTransactorWithChainID(ctx, kmsSvc, c.KMSPrivateKeyID, new(big.Int).SetUint64(chainId))
		}
	} else {
		publicKey, ok := c.PrivateKey.Public().(*ecdsa.PublicKey)
		if !ok {
			log.Fatal().Msg("failed to get public key")
		}

		addr = crypto.PubkeyToAddress(*publicKey)
		auth = func(chainId uint64) (*bind.TransactOpts, error) {
			return bind.NewKeyedTransactorWithChainID(c.PrivateKey, new(big.Int).SetUint64(chainId))
		}
	}

	return
}
