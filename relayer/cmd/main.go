package main

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"time"

	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	v2core "github.com/superform-xyz/v2-core/relayer"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/ethawskmssigner"
	"github.com/superform-xyz/v2-core/relayer/pkg/graceful"
	"github.com/superform-xyz/v2-core/relayer/pkg/healthcheck"
	"github.com/superform-xyz/v2-core/relayer/pkg/txmngr"
	"github.com/superform-xyz/v2-core/relayer/pkg/zlogsentry"
	"github.com/superform-xyz/v2-core/relayer/services/bridge"
	"github.com/urfave/cli/v3"
)

var (
	configPathFlag = &cli.StringFlag{
		Name:     "config",
		Aliases:  []string{"c"},
		Value:    "/app/config.yaml",
		Usage:    "path to the config file",
		Required: true,
	}
)

func init() {
	// UNIX Time is faster and smaller than most timestamps
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
}

func main() {
	mainCmd := &cli.Command{
		Name: "Superform V2 Relayer services",
		Flags: []cli.Flag{
			configPathFlag,
		},
		Commands: []*cli.Command{
			{
				Name:   "bridge",
				Usage:  "start the Superform Bridge",
				Action: startBridge,
			},
			{
				Name:   "automation",
				Usage:  "start the Superform Automation",
				Action: startAutomation,
			},
			{
				Name:   "pricer",
				Usage:  "start the Superform Pricer",
				Action: startPricer,
			},
		},
		Version: v2core.Version,
	}

	if err := mainCmd.Run(context.Background(), os.Args); err != nil {
		log.Fatal().Err(err).Msg("failed to start the app")
	}
}

// bridge launches the bridge component of the superform v2
func startBridge(ctx context.Context, cmd *cli.Command) error {
	// Init config
	conf := config.Load(cmd.String(configPathFlag.Name))

	// Set up logger
	setupLogger(&conf)

	// Print config and app details
	conf.Print()
	v2core.PrintVersion()

	// Create clients
	clients := make(map[uint64]*ethclient.Client)
	for _, chain := range conf.Chains {
		clients[chain.ChainID] = chain.Client(ctx)
	}

	// Create clients
	txMngrClients := make(map[uint64]txmngr.EthClient)
	for _, chain := range conf.Chains {
		txMngrClients[chain.ChainID] = clients[chain.ChainID]
	}

	// Create tx manager
	txMngrDb := txmngr.NewInmemDB()
	sender, auth := getTxAuth(ctx, &conf)
	txMngr := txmngr.New(txMngrDb, txMngrClients, sender, time.Second*36, time.Second*12, auth) //nolint:mnd
	txMngr.Start(ctx)

	// Create bridges configs
	bridges := make(map[uint64]bridge.BridgeConfig)
	for _, chain := range conf.Chains {
		bridges[chain.ChainID] = bridge.BridgeConfig{
			ChainID:         chain.ChainID,
			Address:         common.HexToAddress(chain.BridgeContract),
			Client:          clients[chain.ChainID],
			DeploymentBlock: chain.BridgeContractDeploymentBlock,
		}
	}

	// TODO: Complete setup here
	brdigeSvc := bridge.New(txMngr, bridges)
	brdigeSvc.Start(ctx)

	// Start the healthcheck server
	startHealthcheckServer(conf.HealthcheckServerHost)

	return graceful.ShutDown(func() error {
		// TODO: Shutdown services here
		brdigeSvc.Stop()
		txMngr.Stop()

		return nil
	})
}

// automation launches the automation component of the superform v2
func startAutomation(ctx context.Context, cmd *cli.Command) error {
	// Init config
	conf := config.Load(cmd.String(configPathFlag.Name))

	// Set up logger
	setupLogger(&conf)

	// Print config and app details
	conf.Print()
	v2core.PrintVersion()

	// TODO: Complete setup here

	// Start the healthcheck server
	startHealthcheckServer(conf.HealthcheckServerHost)

	return graceful.ShutDown(func() error {
		// TODO: Shutdown services here

		return nil
	})
}

// automation launches the automation component of the superform v2
func startPricer(ctx context.Context, cmd *cli.Command) error {
	// Init config
	conf := config.Load(cmd.String(configPathFlag.Name))

	// Set up logger
	setupLogger(&conf)

	// Print config and app details
	conf.Print()
	v2core.PrintVersion()

	// TODO: Complete setup here

	// Start the healthcheck server
	startHealthcheckServer(conf.HealthcheckServerHost)

	return graceful.ShutDown(func() error {
		// TODO: Shutdown services here

		return nil
	})
}

// startHealthcheckServer starts a simple HTTP server for healthchecks
func startHealthcheckServer(port int) {
	http.HandleFunc("/health", healthcheck.HealthCheck())

	go func() {
		if err := http.ListenAndServe(fmt.Sprintf(":%d", port), nil); err != nil {
			log.Fatal().Err(err).Msg("failed to start healthcheck server")
		}
	}()
}

// setupLogger initializes zerolog based on the app config
func setupLogger(conf *config.Config) {
	// Set up log leve
	if conf.LogLevel != "" {
		if parsedLevel, err := zerolog.ParseLevel(conf.LogLevel); err == nil {
			zerolog.SetGlobalLevel(parsedLevel)
		} else {
			log.Fatal().Err(err).Msgf("failed to parse log level: %s", conf.LogLevel)
		}
	} else {
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
	}

	// Init sending logs to sentry if DSN is provided
	if conf.SentryDSN != "" {
		w, err := zlogsentry.New(
			conf.SentryDSN,
			zlogsentry.WithEnvironment(conf.Env),
			zlogsentry.WithRelease(v2core.Version),
		)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to init zerolog Sentry plugin")
		}

		log.Logger = zerolog.New(zerolog.MultiLevelWriter(os.Stdout, w)).With().Timestamp().Logger()
	}
}

func getTxAuth(ctx context.Context, conf *config.Config) (addr common.Address, auth func(uint64) (*bind.TransactOpts, error)) {
	if conf.KMSPrivateKeyID != "" {
		awsCfg, err := awsconfig.LoadDefaultConfig(context.Background())
		if err != nil {
			log.Fatal().Err(err).Msg("failed to load AWS config")
		}

		kmsSvc := kms.NewFromConfig(awsCfg)

		pubKey, err := ethawskmssigner.GetPubKey(ctx, kmsSvc, conf.KMSPrivateKeyID)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to get public key")
		}

		addr = crypto.PubkeyToAddress(*pubKey)

		log.Info().Str("address", addr.Hex()).Msg("Using public key from AWS KMS")

		auth = func(chainId uint64) (*bind.TransactOpts, error) {
			return ethawskmssigner.NewAwsKmsTransactorWithChainID(ctx, kmsSvc, conf.KMSPrivateKeyID, new(big.Int).SetUint64(chainId))
		}
	} else {
		privateKey, err := crypto.HexToECDSA(conf.PrivateKey)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to parse private key")
		}

		publicKey, ok := privateKey.Public().(*ecdsa.PublicKey)
		if !ok {
			log.Fatal().Msg("failed to get public key")
		}

		addr = crypto.PubkeyToAddress(*publicKey)
		auth = func(chainId uint64) (*bind.TransactOpts, error) {
			return bind.NewKeyedTransactorWithChainID(privateKey, new(big.Int).SetUint64(chainId))
		}
	}

	return
}
