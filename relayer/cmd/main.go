package cmd

import (
	"context"
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/urfave/cli/v3"
)

var (
	configPath string
)

func init() {
	// UNIX Time is faster and smaller than most timestamps
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
}

func Run() bool {
	mainCmd := &cli.Command{
		Name: "Superform V2 Relayer services",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:        "config",
				Aliases:     []string{"c"},
				Value:       "config.yaml",
				Usage:       "Path to the config file",
				Required:    true,
				Destination: &configPath,
			},
		},
		Commands: []*cli.Command{
			migrationCmd,
			bridgeCmd,
			automationCmd,
			pricerCmd,
		},
		Version: Version,
	}

	if err := mainCmd.Run(context.Background(), os.Args); err != nil {
		log.Fatal().Err(err).Msg("failed to start the app")
		return false
	}

	return true
}
