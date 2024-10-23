package main

import (
	"context"
	"fmt"
	"net/http"
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	v2relayer "github.com/superform-xyz/v2-relayer"
	"github.com/superform-xyz/v2-relayer/config"
	"github.com/superform-xyz/v2-relayer/pkg/graceful"
	"github.com/superform-xyz/v2-relayer/pkg/healthcheck"
	"github.com/superform-xyz/v2-relayer/pkg/zlogsentry"
	"github.com/urfave/cli/v3"
)

func init() {
	// UNIX Time is faster and smaller than most timestamps
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
}

func main() {
	mainCmd := &cli.Command{
		Name: "Superform V2 Relayer services",
		Commands: []*cli.Command{
			{
				Name:   "bridge",
				Usage:  "start the Superform Bridge",
				Action: bridge,
			},
		},
		Version: v2relayer.Version,
	}

	if err := mainCmd.Run(context.Background(), os.Args); err != nil {
		log.Fatal().Err(err).Msg("failed to start the app")
	}
}

// bridge launches the bridge component of the superform v2
func bridge(ctx context.Context, cmd *cli.Command) error {
	// Init config
	conf := config.Load()

	// Set up logger
	setupLogger(&conf)

	// Print config and app details
	conf.Print()
	v2relayer.PrintVersion()

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
		w, err := zlogsentry.New(conf.SentryDSN, zlogsentry.WithEnvironment(conf.Env), zlogsentry.WithRelease(v2relayer.Version))
		if err != nil {
			log.Fatal().Err(err).Msg("failed to init zerolog Sentry plugin")
		}

		log.Logger = zerolog.New(zerolog.MultiLevelWriter(os.Stdout, w)).With().Timestamp().Logger()
	}
}
