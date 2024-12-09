package cmd

import (
	"context"
	"encoding/json"
	"io"
	"math/big"
	"os"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/contracts"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"github.com/superform-xyz/v2-core/relayer/pkg/data/pg"
	"github.com/superform-xyz/v2-core/relayer/pkg/graceful"
	"github.com/superform-xyz/v2-core/relayer/services/automation"
	"github.com/urfave/cli/v3"
)

var (
	seedPath      string
	automationCmd = &cli.Command{
		Name:   "automation",
		Usage:  "Start the Superform Automation module",
		Action: startAutomation,
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:        "seed",
				Aliases:     []string{"s"},
				Value:       "seed.json",
				Usage:       "Path to the seed file",
				Required:    true,
				Destination: &seedPath,
			},
		},
	}
)

func startAutomation(ctx context.Context, _ *cli.Command) error {
	conf := setUpApp()
	auto := automation.New(
		conf.DB.TasksQ(),
		initHandlers(ctx, conf),
		conf.Automation,
	)

	if err := seedData(conf); err != nil {
		return errors.Wrap(err, "failed to init seed data")
	}

	auto.Start()

	startHealthcheckServer(conf.HealthcheckServerPort)

	return graceful.ShutDown(func() error {
		auto.Stop()
		return nil
	})
}

func initHandlers(ctx context.Context, conf config.Config) map[string]automation.TaskHandler {
	_, auth := conf.GetTxAuth(ctx)
	return map[string]automation.TaskHandler{
		"pingPrice": func(input []byte) (output []byte, err error) {
			var inputData struct {
				ChainID  uint64 `json:"chain_id"`
				Contract string `json:"contract"`
			}

			if err = json.Unmarshal(input, &inputData); err != nil {
				return nil, errors.Wrap(err, "failed to parse input data")
			}

			bridgeCfg := conf.Chains[inputData.ChainID]
			contract, err := contracts.NewSuperBridge(bridgeCfg.Contracts.BridgeContract, bridgeCfg.Client)
			if err != nil {
				return nil, errors.Wrap(err, "failed to create new super monitor contract")
			}

			txOpts, err := auth(inputData.ChainID)
			if err != nil {
				return nil, errors.Wrap(err, "failed to get new tx auth options")
			}

			tx, err := contract.FetchPrice(txOpts, new(big.Int).SetUint64(inputData.ChainID), common.HexToAddress(inputData.Contract))
			if err != nil {
				return nil, errors.Wrap(err, "failed to fetch price")
			}

			_, err = waitMined(ctx, txOpts.From, tx, bridgeCfg.Client)
			if err != nil {
				return nil, errors.Wrap(err, "failed to wait for price fetcher method")
			}

			return nil, nil
		},
	}
}

func waitMined(ctx context.Context, from common.Address, tx *types.Transaction, client *ethclient.Client) (*types.Receipt, error) {
	receipt, err := bind.WaitMined(ctx, client, tx)
	if err != nil {
		return nil, errors.Wrap(err, "failed to get mined tx")
	}

	if receipt.Status == types.ReceiptStatusFailed {
		txErr, err := getTxError(ctx, tx, from, client)
		if err != nil {
			return nil, errors.Wrap(err, "failed to get tx error")
		}

		return nil, errors.Wrap(txErr, "transaction failed")
	}

	return receipt, nil
}

func getTxError(ctx context.Context, tx *types.Transaction, txSender common.Address, client *ethclient.Client) (error, error) {
	msg := ethereum.CallMsg{
		From:     txSender,
		To:       tx.To(),
		Gas:      tx.Gas(),
		GasPrice: tx.GasPrice(),
		Value:    tx.Value(),
		Data:     tx.Data(),
	}

	res, err := client.CallContract(ctx, msg, nil)
	if err != nil {
		return nil, errors.Wrap(err, "failed to make call")
	}

	return errors.New(string(res)), nil
}

func seedData(cfg config.Config) error {
	jsonFile, err := os.Open(seedPath)
	if err != nil {
		return errors.Wrapf(err, "failed to open json file: %s", seedPath)
	}
	defer jsonFile.Close()

	jsonData, err := io.ReadAll(jsonFile)
	if err != nil {
		return errors.Wrap(err, "failed to read json file")
	}

	var tasks []data.Task
	if err = json.Unmarshal(jsonData, &tasks); err != nil {
		return errors.Wrap(err, "failed to unmarshal json file")
	}

	for _, task := range tasks {
		if err = cfg.DB.TasksQ().Insert(task); err != nil && !errors.As(err, &pg.ErrDuplicateKeyConstraint) {
			return errors.Wrapf(err, "failed to insert task, id=%s", task.ID)
		}
	}

	return nil
}
