package cmd

import (
	"context"
	"time"

	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/graceful"
	"github.com/superform-xyz/v2-core/relayer/pkg/txmngr"
	"github.com/superform-xyz/v2-core/relayer/services/monitor"
	"github.com/superform-xyz/v2-core/relayer/services/processors/bridge"
	"github.com/urfave/cli/v3"
)

var bridgeCmd = &cli.Command{
	Name:   "monitor",
	Usage:  "Start the Superform Bridge",
	Action: startBridge,
}

func startBridge(ctx context.Context, _ *cli.Command) error {
	conf := setUpApp()

	sender, auth := conf.GetTxAuth(ctx)
	txMngr := txmngr.New(
		conf.DB.TransactionsQ(),
		conf.Chains.Clients(),
		sender,
		time.Second*36,
		time.Second*12,
		auth,
	)
	txMngr.Start(ctx)

	processors := make([]monitor.Processor, 0, len(conf.Chains))
	for chainId := range conf.Chains {
		processor, err := bridge.New(txMngr, conf.DB.BlocksQ(), chainId, conf.Chains, conf.Listener)
		if err != nil {
			return errors.Wrapf(err, "failed to create processor chainId=%d", chainId)
		}

		processors = append(processors, processor)
	}

	bridgesMonitor, err := monitor.New(processors)
	if err != nil {
		return errors.Wrap(err, "failed to create bridges monitor")
	}
	bridgesMonitor.Start(ctx)

	startHealthcheckServer(conf.HealthcheckServerPort)

	return graceful.ShutDown(func() error {
		bridgesMonitor.Stop(ctx)
		txMngr.Stop()
		return nil
	})
}
