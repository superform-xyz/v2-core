package cmd

import (
	"context"

	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/graceful"
	"github.com/superform-xyz/v2-core/relayer/services/monitor"
	"github.com/superform-xyz/v2-core/relayer/services/processors/pricer"
	"github.com/urfave/cli/v3"
)

var pricerCmd = &cli.Command{
	Name:   "pricer",
	Usage:  "Start the Superform Pricer",
	Action: startPricer,
}

func startPricer(ctx context.Context, _ *cli.Command) error {
	conf := setUpApp()

	processors := make([]monitor.Processor, 0, len(conf.Chains))
	for chainId := range conf.Chains {
		processor, err := pricer.New(
			conf.DB.BlocksQ(),
			conf.DB.PricesQ(),
			conf.Chains[chainId],
			conf.Listener,
		)
		if err != nil {
			return errors.Wrapf(err, "failed to create processor chainId=%d", chainId)
		}

		processors = append(processors, processor)
	}

	pricesSvc, err := monitor.New(processors)
	if err != nil {
		return errors.Wrap(err, "failed to create prices monitor")
	}
	pricesSvc.Start(ctx)

	startHealthcheckServer(conf.HealthcheckServerPort)

	return graceful.ShutDown(func() error {
		pricesSvc.Stop(ctx)
		return nil
	})
}
